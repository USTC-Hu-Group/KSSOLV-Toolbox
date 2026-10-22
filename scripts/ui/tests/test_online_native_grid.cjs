const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const source = fs.readFileSync(path.join(__dirname,
    '../../../+kssolv/+ui/resources/browser/online-native-grid.js'), 'utf8');
const styles = [];
const document = {
    getElementById: id => styles.find(s => s.id === id),
    createElement: () => ({}), head: {appendChild: s => styles.push(s)},
};
const node = parentElement => ({parentElement, attrs: new Map(),
    setAttribute(name, value) {this.attrs.set(name, value);}});
const pane = node(null); pane.ownerDocument = document;
const frame = node(pane); const contents = node(frame); const grid = node(contents);
pane.querySelector = selector => {assert.equal(selector, '.gbtGrid'); return grid;};
const window = {frameElement: {closest: () => pane}};
const run = window => vm.runInNewContext('(function(){' + source + '})();', {window});
run(window);
assert(pane.attrs.has('data-kssolv-native-grid'));
assert(!pane.attrs.has('data-kssolv-native-root'), 'Do not override native pane bounds');
for (const n of [frame, contents, grid]) assert(n.attrs.has('data-kssolv-native-root'));
run(window); assert.equal(styles.length, 1);
run({frameElement: null});
run({frameElement: {closest: () => ({querySelector: () => null})}});
assert.equal(styles.length, 1, 'Ignore figures without native grids');
console.log('PASS native grid: scoped root chain, native bounds, stylesheet reuse, missing grid isolation');
