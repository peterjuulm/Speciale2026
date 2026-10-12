// Webpack plugin for the entry-order experiment (W47), 12 October 2026.
//
// At the start of Compilation.seal(), before webpack creates any chunk, it
// writes the compilation's entry names in their order to a file, one name
// per line. With ENTRY_SORT=1 it then sorts the client compilation's entries
// by name, so the chunk graph no longer depends on the order in which Next
// added them.
//
//   ENTRY_LOG_DIR  folder for the logs; nothing is written when unset
//   ENTRY_LOG_TAG  first part of each log's name, e.g. the run's label
//   ENTRY_SORT     1 to sort the client's entries
//
// A log is named TAG-MS-PID-COMPILER.txt; MS is Date.now(), so the control
// build's logs sort before the experiment's.
const fs = require('fs');
const path = require('path');

module.exports = class EntryOrderPlugin {
  constructor(compilerName) {
    this.compilerName = compilerName;
  }

  apply(compiler) {
    compiler.hooks.thisCompilation.tap('EntryOrderPlugin', (compilation) => {
      compilation.hooks.seal.tap('EntryOrderPlugin', () => {
        const dir = process.env.ENTRY_LOG_DIR;
        if (dir) {
          const tag = process.env.ENTRY_LOG_TAG || 'build';
          const file = `${tag}-${Date.now()}-${process.pid}-${this.compilerName}.txt`;
          fs.writeFileSync(path.join(dir, file), [...compilation.entries.keys()].join('\n') + '\n');
        }
        if (process.env.ENTRY_SORT === '1' && this.compilerName === 'client') {
          const sorted = [...compilation.entries].sort(([a], [b]) => (a < b ? -1 : a > b ? 1 : 0));
          compilation.entries.clear();
          for (const [name, entry] of sorted) compilation.entries.set(name, entry);
        }
      });
    });
  }
};
