// Webpack plugin for the module-order experiment (W51), 12 October 2026.
//
// W51: the export holds two identical chunks, and which of two pages gets
// which chunk id varied once in about 50 builds. The suspected cause is the
// order of compilation.modules, which is the order in which modules finished
// resolving, a timing. This plugin perturbs that order on purpose and can
// sort it away.
//
//   MODULE_JITTER_SEED  when set, every module request waits 0-15 ms before
//                       it resolves, the wait taken from a hash of the seed,
//                       the context and the request; each seed gives another
//                       timing and so another module order
//   MODULE_SORT         1 to sort the client compilation's modules by
//                       identifier at the start of Compilation.seal(),
//                       before webpack makes any chunk
//   MODULE_LOG_DIR      folder for one log per compilation: a hash of the
//                       module order as it reached seal (before any sort)
//                       and the number of modules; nothing when unset
//   MODULE_LOG_TAG      first part of each log's name
//   MODULE_CHUNK_LOG    1 to also log the client's chunks once their ids are
//                       set, one line each in the order of compilation.chunks:
//                       id, name, number of modules, a hash of the sorted
//                       module identifiers, a hash of the root modules in the
//                       order webpack derives the chunk's id from, and ids
//   MODULE_ROOT_LOG     1 to list, under each unnamed chunk's line, its root
//                       modules' identifiers (local paths: private data only)
//   MODULE_SORT_CONNECTIONS  1 to also sort, at seal, every client module's
//                       outgoing and incoming connections by a key from the
//                       source (fix candidate a); out for outgoing only
//   CHUNK_IDS_BY_CONTENT 1 to give every unnamed client chunk its id from a
//                       hash of all its sorted module identifiers and its
//                       chunk groups' names, before webpack numbers the rest
//                       (fix candidate b)
//
// A log is named TAG-MS-PID-COMPILER.txt, as in entry-order-plugin.js.
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');

const byIdentifier = (a, b) => {
  const x = a.identifier();
  const y = b.identifier();
  return x < y ? -1 : x > y ? 1 : 0;
};

const compareStrings = (x, y) => (x < y ? -1 : x > y ? 1 : 0);

// A connection's place in the source: its dependency's type, location and
// index in the parent block, none of which depends on build timing.
const dependencyKey = (moduleGraph, dependency) => {
  if (!dependency) return '';
  const loc = dependency.loc ? JSON.stringify(dependency.loc) : '';
  return `${dependency.type || ''}|${loc}|${moduleGraph.getParentBlockIndex(dependency)}`;
};

const sortConnections = (moduleGraph, modules, incomingToo) => {
  const key = (module, connection) => `${module ? module.identifier() : ''}|${dependencyKey(moduleGraph, connection.dependency)}`;
  const byTarget = (a, b) => compareStrings(key(a.module, a), key(b.module, b));
  const byOrigin = (a, b) => compareStrings(key(a.originModule, a), key(b.originModule, b));
  for (const module of modules) {
    const outgoing = moduleGraph.getOutgoingConnections(module);
    if (typeof outgoing.sortWith === 'function') outgoing.sortWith(byTarget);
    if (!incomingToo) continue;
    const incoming = moduleGraph.getIncomingConnections(module);
    if (typeof incoming.sortWith === 'function') incoming.sortWith(byOrigin);
  }
};

// A chunk group by its name, or, unnamed, by where it is loaded from.
const groupKey = (shorten, group) => {
  if (group.name) return `name:${group.name}`;
  const origins = (group.origins || []).map((o) => `${o.module ? shorten(o.module.identifier()) : ''}|${o.request || ''}|${o.loc ? JSON.stringify(o.loc) : ''}`);
  return `origins:${origins.sort().join(',')}`;
};

const assignContentIds = (compilation, chunks) => {
  const graph = compilation.chunkGraph;
  // Identifiers hold absolute paths; relative to the context, the key does
  // not depend on where the tree is checked out.
  const shorten = (identifier) => compilation.requestShortener.shorten(identifier);
  const used = new Set();
  for (const chunk of compilation.chunks) if (chunk.id !== null) used.add(String(chunk.id));
  const items = [];
  for (const chunk of chunks) {
    if (chunk.id !== null || chunk.name) continue;
    const modules = [...graph.getChunkModulesIterable(chunk)].map((m) => shorten(m.identifier())).sort();
    const groups = [...chunk.groupsIterable].map((g) => groupKey(shorten, g)).sort();
    items.push({ chunk, key: `${modules.join('\n')}\0${groups.join('\n')}` });
  }
  const keys = items.map((i) => i.key);
  if (new Set(keys).size !== keys.length) throw new Error('ModuleOrderPlugin: two unnamed chunks with the same key');
  items.sort((a, b) => compareStrings(a.key, b.key));
  let range = 1000;
  while (range < items.length * 20 + used.size) range *= 10;
  for (const { chunk, key } of items) {
    for (let salt = 0; ; salt++) {
      const id = parseInt(crypto.createHash('sha256').update(`${key}\0${salt}`).digest('hex').slice(0, 12), 16) % range;
      if (!used.has(String(id))) {
        used.add(String(id));
        chunk.id = id;
        chunk.ids = [id];
        break;
      }
    }
  }
};

module.exports = class ModuleOrderPlugin {
  constructor(compilerName) {
    this.compilerName = compilerName;
  }

  apply(compiler) {
    const seed = process.env.MODULE_JITTER_SEED;
    if (seed) {
      compiler.hooks.normalModuleFactory.tap('ModuleOrderPlugin', (factory) => {
        factory.hooks.beforeResolve.tapPromise('ModuleOrderPlugin', (data) => {
          const digest = crypto.createHash('sha256').update(`${seed}\0${data.context}\0${data.request}`).digest();
          return new Promise((resolve) => setTimeout(resolve, digest[0] % 16));
        });
      });
    }
    compiler.hooks.thisCompilation.tap('ModuleOrderPlugin', (compilation) => {
      compilation.hooks.seal.tap('ModuleOrderPlugin', () => {
        const dir = process.env.MODULE_LOG_DIR;
        if (dir) {
          const ids = [...compilation.modules].map((m) => m.identifier());
          const hash = crypto.createHash('sha256').update(ids.join('\n')).digest('hex').slice(0, 16);
          const tag = process.env.MODULE_LOG_TAG || 'build';
          const file = `${tag}-${Date.now()}-${process.pid}-${this.compilerName}.txt`;
          fs.writeFileSync(path.join(dir, file), `${hash} ${ids.length}\n`);
        }
        if (process.env.MODULE_SORT === '1' && this.compilerName === 'client') {
          const sorted = [...compilation.modules].sort(byIdentifier);
          compilation.modules.clear();
          for (const m of sorted) compilation.modules.add(m);
        }
        const connections = process.env.MODULE_SORT_CONNECTIONS;
        if ((connections === '1' || connections === 'out') && this.compilerName === 'client') {
          sortConnections(compilation.moduleGraph, compilation.modules, connections === '1');
        }
      });
      if (process.env.CHUNK_IDS_BY_CONTENT === '1' && this.compilerName === 'client') {
        compilation.hooks.chunkIds.tap('ModuleOrderPlugin', (chunks) => assignContentIds(compilation, chunks));
      }
      compilation.hooks.afterOptimizeChunkIds.tap('ModuleOrderPlugin', (chunks) => {
        const dir = process.env.MODULE_LOG_DIR;
        if (!dir || process.env.MODULE_CHUNK_LOG !== '1' || this.compilerName !== 'client') return;
        const graph = compilation.chunkGraph;
        const hash = (text) => crypto.createHash('sha256').update(text).digest('hex').slice(0, 12);
        const lines = [];
        for (const chunk of chunks) {
          const modules = [...graph.getChunkModulesIterable(chunk)].map((m) => m.identifier()).sort();
          const roots = graph.getChunkRootModules(chunk).map((m) => m.identifier());
          lines.push([chunk.id, chunk.name || '-', modules.length, hash(modules.join('\n')), hash(roots.join(',')), (chunk.ids || []).join('+')].join(' '));
          if (process.env.MODULE_ROOT_LOG === '1' && !chunk.name) {
            for (const root of roots) lines.push(`  root ${root}`);
          }
        }
        const tag = process.env.MODULE_LOG_TAG || 'build';
        fs.writeFileSync(path.join(dir, `${tag}-${Date.now()}-${process.pid}-chunks.txt`), lines.join('\n') + '\n');
      });
    });
  }
};
