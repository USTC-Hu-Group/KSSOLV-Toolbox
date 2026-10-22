const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const source = fs.readFileSync(path.join(__dirname,
    '../../../+kssolv/+ui/resources/browser/online-fill-figure.js'), 'utf8');
function fixture(inFigure = true) {
    const styles = [];
    const document = {
        getElementById(id) { return styles.find(style => style.id === id); },
        createElement() { return {}; },
        head: {appendChild(style) { styles.push(style); }},
    };
    const pane = {parentElement: {}, attributes: new Map()};
    const chain = [];
    let parent = pane;
    // Real Runtime nodes expose generated IDs rather than the MATLAB Tag.
    for (const type of ['figure layout', 'figure frame', 'scrollable', 'figure contents',
        'grid', 'grid scrollable', 'grid contents', 'HTML widget', 'iframe']) {
        const node = {type, parentElement: parent, ownerDocument: document,
            attributes: new Map([['data-tag', 'generated-' + chain.length]]),
            setAttribute(name, value) { this.attributes.set(name, value); }};
        chain.push(node); parent = node;
    }
    const frame = chain.at(-1);
    frame.closest = selector => {assert.equal(selector, '.figureContentPane');return inFigure ? pane : null;};
    const window = {frameElement: frame};
    return {window, chain, pane, styles};
}
const f = fixture();
vm.runInNewContext(source, {window: f.window});
assert(f.chain.every(node => node.attributes.has('data-kssolv-fill-size')),
    'Stale widget and all intermediate pixel sizes must be overridden');
assert(!f.pane.attributes.has('data-kssolv-fill-size'), 'Native splitter bounds remain authoritative');
vm.runInNewContext(source, {window: f.window});
assert.equal(f.styles.length, 1, 'Share one stylesheet across views');
const dialog = fixture(false);
vm.runInNewContext(source, {window: dialog.window});
assert(dialog.chain.every(node => !node.attributes.has('data-kssolv-fill-size')),
    'Do not stretch controls outside a docked single-view figure');
vm.runInNewContext(source, {window: {frameElement: null}});
console.log('PASS Online fill: generated IDs, full ancestor chain, native bounds, stylesheet reuse, non-figure isolation');
