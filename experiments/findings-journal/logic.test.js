// Tests for the filter, search and link logic of the findings journal.
//
//   node --test experiments/findings-journal/logic.test.js
//
// The logic is read from template.html, so the tests run the code the page ships.
// They need Node 18 or later and nothing from npm.

'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const template = fs.readFileSync(path.join(__dirname, 'template.html'), 'utf8');
const block = /<script id="journal-logic">([\s\S]*?)<\/script>/.exec(template);
assert.ok(block, 'template.html has no <script id="journal-logic"> block');
const logic = new Function(block[1] + '\nreturn JournalLogic;')();

const config = {layers: ['1', '2', '3', '4', '5', 'M'], groups: ['E', 'W', 'T', 'R']};

function record(id, layers, state, fields = {}) {
  return {id, group: id[0], layers, state, fields: {id, ...fields}};
}

// A small table with the shapes the real one has: several groups, one finding in two layers,
// ids that differ only by length (W2, W20, W27), and ids that other findings cite.
const records = [
  record('E1', ['1'], 'closed', {cause: 'Baseline', observation: 'Two clean builds with the same path gave identical DLL files'}),
  record('E2', ['1'], 'closed', {cause: 'Tool identity', observation: 'The compiler differs between machines', measured: '8/9 compiler-identity'}),
  record('E10', ['1'], 'closed', {cause: 'Locale', observation: 'The locale changed nothing; compare W27'}),
  record('W2', ['1'], 'open', {cause: 'Build path', observation: 'The PathMap flag removes the plain-text path'}),
  record('W8', ['1'], 'open', {cause: 'Build path', observation: 'WorkingDirectory holds the path to ClientApp/', measured: '15/9 runs 1 to 4'}),
  record('W14', ['M'], 'open', {cause: 'Machine resources', observation: 'The compiler never finished on one vCPU'}),
  record('W20', ['2'], 'closed', {cause: 'Ordering', observation: 'File order follows the file system'}),
  record('W27', ['1'], 'closed', {cause: 'Tool identity', observation: 'A newer compiler changes the metadata, see W2', fix: 'Pin the SDK'}),
  record('W30', ['2'], 'open', {cause: 'Permissions', observation: 'A file mode follows the umask [V]', measured: '24/9 layer2-reprotest'}),
  record('W44', ['3'], 'open', {cause: 'Unknown input', observation: 'The minifier renames variables'}),
  record('W45', ['2', '5'], 'closed', {cause: 'Version', observation: 'The image carries the tag; the compiler is not involved'}),
  record('T1', ['M'], 'rejected', {cause: 'Toolchain', observation: 'The first probe did not vary the compiler'}),
  record('R1', ['5'], 'closed', {cause: 'Containers', observation: 'Layers of the image are identical'}),
];
const view = (changes = {}) => ({...logic.DEFAULTS, ...changes});
const ids = list => list.map(item => item.id);
const find = changes => ids(logic.filterRecords(records, view(changes), config));

test('open findings alone', () => {
  assert.deepEqual(find({state: 'open'}), ['W2', 'W8', 'W14', 'W30', 'W44']);
  assert.deepEqual(find({state: 'rejected'}), ['T1']);
  assert.equal(find({state: 'closed'}).length, 7);
  assert.equal(find({}).length, records.length);
});

test('one layer, including a finding that spans two', () => {
  assert.deepEqual(find({layer: '5'}), ['W45', 'R1']);
  assert.deepEqual(find({layer: '2'}), ['W20', 'W30', 'W45']);
  assert.deepEqual(find({layer: 'M'}), ['W14', 'T1']);
  assert.deepEqual(find({layer: '4'}), []);
});

test('one group', () => {
  assert.deepEqual(find({group: 'T'}), ['T1']);
  assert.deepEqual(find({group: 'E'}), ['E1', 'E2', 'E10']);
});

test('a search term matches any field, ignoring case', () => {
  assert.deepEqual(find({q: 'compiler'}), ['E2', 'W14', 'W27', 'W45', 'T1']);
  assert.deepEqual(find({q: 'COMPILER'}), find({q: 'compiler'}));
  assert.deepEqual(find({q: 'pathmap'}), ['W2']);
  assert.deepEqual(find({q: 'layer2'}), ['W30']);      // found in "Measured in"
  assert.deepEqual(find({q: 'ordering'}), ['W20']);    // found in the title
  assert.deepEqual(find({q: 'nothing like this'}), []);
});

test('every word must match, each in any field', () => {
  assert.deepEqual(find({q: 'compiler machines'}), ['E2']);
  assert.deepEqual(find({q: 'machines compiler'}), ['E2']);
  assert.deepEqual(find({q: 'metadata pin'}), ['W27']);   // observation and fix
  assert.deepEqual(find({q: '  compiler    image  '}), ['W45']);
});

test('special characters in a search are literal', () => {
  assert.deepEqual(find({q: '[V]'}), ['W30']);
  assert.deepEqual(find({q: 'clientapp/'}), ['W8']);
  assert.deepEqual(find({q: 'a.b'}), []);   // not a pattern
  assert.deepEqual(find({q: '(.*'}), []);   // does not throw
  assert.deepEqual(find({q: '\\'}), []);
});

test('a finding id matches as a whole word and goes first', () => {
  // W27 cites W2, but W20 and W27 are different ids.
  assert.deepEqual(find({q: 'w2'}), ['W2', 'W27']);
  assert.deepEqual(find({q: 'w20'}), ['W20']);
  // E10 cites W27 and comes before it in the table. The finding itself is listed first.
  assert.deepEqual(find({q: 'W27'}), ['W27', 'E10']);
  assert.deepEqual(find({q: 'w27', sort: 'layer'}), ['W27', 'E10']);
  // Two words: no reordering, and both must match.
  assert.deepEqual(find({q: 'w27 locale'}), ['E10']);
  // A word that is not a finding id matches as plain text.
  assert.deepEqual(find({q: 'w9'}), []);
});

test('combined filters', () => {
  assert.deepEqual(find({state: 'open', layer: '1'}), ['W2', 'W8']);
  assert.deepEqual(find({state: 'open', layer: '1', q: 'path'}), ['W2', 'W8']);
  assert.deepEqual(find({state: 'open', layer: '1', q: 'workingdirectory'}), ['W8']);
  assert.deepEqual(find({state: 'open', layer: '5'}), []);
  assert.deepEqual(find({state: 'closed', layer: '2', group: 'W'}), ['W20', 'W45']);
  assert.deepEqual(find({state: 'closed', q: 'compiler', group: 'W'}), ['W27', 'W45']);
  assert.deepEqual(find({state: 'open', group: 'T'}), []);
});

test('counts show what each toggle would give', () => {
  const all = logic.facetCounts(records, view(), config);
  assert.deepEqual(all.state, {all: 13, open: 5, closed: 7, rejected: 1});
  assert.deepEqual(all.layer, {all: 13, 1: 6, 2: 3, 3: 1, 4: 0, 5: 2, M: 2});
  assert.deepEqual(all.group, {all: 13, E: 3, W: 8, T: 1, R: 1});

  // With "open" chosen the layer counts cover open findings only. The state counts do not
  // shrink: they count what you would get by choosing a different state.
  const open = logic.facetCounts(records, view({state: 'open'}), config);
  assert.deepEqual(open.layer, {all: 5, 1: 2, 2: 1, 3: 1, 4: 0, 5: 0, M: 1});
  assert.deepEqual(open.state, {all: 13, open: 5, closed: 7, rejected: 1});

  // A search narrows every group.
  const search = logic.facetCounts(records, view({q: 'compiler'}), config);
  assert.deepEqual(search.state, {all: 5, open: 1, closed: 3, rejected: 1});
  assert.equal(search.layer.all, 5);
  assert.equal(search.layer[5], 1);
});

test('the counts agree with the list', () => {
  for (const changes of [{}, {state: 'open'}, {layer: '2'}, {group: 'W', q: 'compiler'}, {state: 'closed', layer: '5'}]) {
    const counts = logic.facetCounts(records, view(changes), config);
    const shown = find(changes).length;
    // The toggle for the chosen value, or "all", equals the list length.
    assert.equal(counts.state[changes.state || 'all'], shown, JSON.stringify(changes));
    assert.equal(counts.layer[changes.layer || 'all'], shown, JSON.stringify(changes));
    assert.equal(counts.group[changes.group || 'all'], shown, JSON.stringify(changes));
  }
});

test('sort by id: group order, then number', () => {
  const shuffled = [records[10], records[2], records[0], records[12], records[11], records[1]];
  assert.deepEqual(ids(logic.sortRecords(shuffled, 'id', config)), ['E1', 'E2', 'E10', 'W45', 'T1', 'R1']);
});

test('sort by layer: lowest layer first, method last, ties by id', () => {
  assert.deepEqual(find({sort: 'layer'}), [
    'E1', 'E2', 'E10', 'W2', 'W8', 'W27',   // layer 1
    'W20', 'W30', 'W45',                    // layer 2 (W45 also spans 5)
    'W44',                                  // layer 3
    'R1',                                   // layer 5
    'W14', 'T1',                            // method
  ]);
});

test('the view survives the round trip through the address bar', () => {
  const views = [
    view({state: 'open'}),
    view({state: 'open', layer: '5'}),
    view({layer: 'M', group: 'W', sort: 'layer'}),
    view({q: 'path map'}),
    view({state: 'rejected', layer: '1', group: 'T', q: 'a&b=c #1 100% [V]', sort: 'layer'}),
    view({q: 'æøå ünï'}),
  ];
  for (const item of views) {
    const hash = logic.buildHash(item);
    assert.deepEqual(logic.parseHash(hash, config), {view: item}, hash);
  }
  // The plain page has no fragment, and no fragment means the plain page.
  assert.equal(logic.buildHash(view()), '');
  assert.deepEqual(logic.parseHash('', config), {});
  assert.equal(logic.buildHash(view({state: 'open', layer: '5'})), '#state=open&layer=5');
  assert.equal(logic.buildHash(view({q: 'path map', sort: 'layer'})), '#q=path+map&sort=layer');
  // Spaces at the ends do not make a different link.
  assert.equal(logic.buildHash(view({q: '  path  '})), '#q=path');
});

test('a finding link names a finding, whatever the case', () => {
  assert.deepEqual(logic.parseHash('#W27', config), {finding: 'W27'});
  assert.deepEqual(logic.parseHash('#w27', config), {finding: 'W27'});
  assert.deepEqual(logic.parseHash('#E1', config), {finding: 'E1'});
});

test('hand-edited or unknown fragments do not break the page', () => {
  assert.deepEqual(logic.parseHash('', config), {});
  assert.deepEqual(logic.parseHash('#', config), {});
  assert.deepEqual(logic.parseHash('#results', config), {});
  assert.deepEqual(logic.parseHash('#W27x', config), {});
  assert.deepEqual(logic.parseHash('#state=bogus&layer=9&group=Z&sort=random', config), {view: view()});
  assert.deepEqual(logic.parseHash('#STATE=open', config), {view: view()});   // keys are exact
  assert.deepEqual(logic.parseHash('#state=OPEN&layer=m&group=w', config),
    {view: view({state: 'open', layer: 'M', group: 'W'})});
  assert.doesNotThrow(() => logic.parseHash('#q=%E0%A4%A&state=%', config));
  assert.doesNotThrow(() => logic.parseHash('#__proto__=x&constructor=y', config));
  assert.equal(logic.normalizeView(null, config).state, 'all');
  assert.equal(logic.normalizeView({q: 42}, config).q, '');
});

test('highlight ranges', () => {
  const tokens = text => logic.queryTokens(text, records);
  assert.deepEqual(logic.highlightRanges('The compiler and the Compiler', tokens('compiler')), [[4, 12], [21, 29]]);
  // Overlapping words merge into one range.
  assert.deepEqual(logic.highlightRanges('pathmap', tokens('path map pathmap')), [[0, 7]]);
  assert.deepEqual(logic.highlightRanges('abcdef', tokens('abc cde')), [[0, 5]]);
  // An id marks only the whole word.
  assert.deepEqual(logic.highlightRanges('W2, W27 and w2.', tokens('w2')), [[0, 2], [12, 14]]);
  assert.deepEqual(logic.highlightRanges('nothing here', tokens('compiler')), []);
  assert.deepEqual(logic.highlightRanges('anything', []), []);
});

test('the fields where the words occur', () => {
  const tokens = logic.queryTokens('compiler', records);
  assert.deepEqual(logic.matchedFields(records.find(r => r.id === 'E2'), tokens), ['observation', 'measured']);
  assert.deepEqual(logic.matchedFields(records.find(r => r.id === 'W2'), tokens), []);
});

test('clear filters keeps the sort order', () => {
  const busy = view({state: 'open', layer: '1', group: 'W', q: 'path', sort: 'layer'});
  assert.equal(logic.hasFilters(busy), true);
  assert.equal(logic.hasFilters(view()), false);
  assert.equal(logic.hasFilters(view({sort: 'layer'})), false);
  assert.equal(logic.hasFilters(view({q: '   '})), false);
  assert.deepEqual(logic.clearFilters(busy), view({sort: 'layer'}));
});

// The page the generator wrote must agree with the logic.

test('the saved page agrees with the logic', () => {
  const page = fs.readFileSync(path.join(__dirname, '..', '..', 'journal', 'index.html'), 'utf8');
  const articles = [...page.matchAll(/<article class="finding" id="([A-Z]\d+)" data-group="([A-Z])" data-layers="([^"]*)" data-state="([a-z]+)"/g)];
  assert.ok(articles.length > 0, 'no findings in journal/index.html');
  const real = articles.map(match => record(match[1], match[3].split(' '), match[4]));

  const toggleCounts = name => Object.fromEntries([...page.matchAll(
    new RegExp('<input type="radio" name="' + name + '" value="([^"]+)"[^>]*><span class="opt-text">[^<]*<span class="count">\\(<span class="n">(\\d+)', 'g'))]
    .map(match => [match[1], Number(match[2])]));
  const layers = Object.keys(toggleCounts('layer')).filter(value => value !== 'all');
  const groups = Object.keys(toggleCounts('group')).filter(value => value !== 'all');
  const pageConfig = {layers, groups};

  // The counts that the generator wrote equal the counts the script would compute.
  const counts = logic.facetCounts(real, view(), pageConfig);
  assert.deepEqual(toggleCounts('state'), counts.state);
  assert.deepEqual(toggleCounts('layer'), counts.layer);
  assert.deepEqual(toggleCounts('group'), counts.group);
  assert.equal(counts.state.all, real.length);

  // Every finding uses a state, layer and group that the page offers.
  for (const item of real) {
    assert.ok(['open', 'closed', 'rejected'].includes(item.state), item.id);
    assert.ok(item.layers.every(layer => layers.includes(layer)), item.id);
    assert.ok(groups.includes(item.group), item.id);
  }
  // Ids are unique, so a link to one finding is unambiguous.
  assert.equal(new Set(real.map(item => item.id)).size, real.length);
});

test('the template asks for nothing from the network', () => {
  const sources = template.match(/\b(?:src|href|action|poster|data)\s*=\s*["']?(?:https?:)?\/\/[^\s"'>]*/gi) || [];
  assert.deepEqual(sources, []);
  assert.doesNotMatch(template, /<link[^>]+rel=["']?(?:stylesheet|preload|prefetch)/i);
  assert.doesNotMatch(template, /<script[^>]+\bsrc=/i);
  assert.doesNotMatch(template, /@import|url\(\s*["']?(?:https?:)?\/\//i);
  assert.doesNotMatch(template, /\b(?:fetch|XMLHttpRequest|WebSocket|EventSource|sendBeacon)\b/);
});
