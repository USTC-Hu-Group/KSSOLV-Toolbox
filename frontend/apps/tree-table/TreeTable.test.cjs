const {test} = require('node:test');
const assert = require('node:assert/strict');
const {readFileSync} = require('node:fs');
const vm = require('node:vm');

const source = readFileSync(require('node:path').join(__dirname, 'TreeTable.html'), 'utf8')
  .match(/<script>([\s\S]*?)<\/script>/)[1];

function client(data) {
  const listeners = new Map(), events = [], steps = [];
  const rows = {items: [], replaceChildren() {this.items = [];}};
  const context = vm.createContext({window: {addEventListener() {}},
    document: {getElementById: () => ({children: [{}, rows]})}, console});
  vm.runInContext(source, context);
  context.steps = steps;
  vm.runInContext('buildTable = (_, rows) => {steps.push("render"); rows.items.push("project");}; resizeCount = 0; addResizableColumns = () => {resizeCount++;}; handleBackspaceKey = () => {};', context);
  const component = {Data: data, addEventListener: (name, callback) => listeners.set(name, callback),
    sendEventToMATLAB: name => {steps.push(name); events.push(name);}};
  context.setup(component);
  return {component, events, steps, rows, get resizeCount() {return context.resizeCount;},
    update: () => listeners.get('DataChanged')()};
}

test('initial project data renders before readiness, even if DataChanged was missed', () => {
  const c = client('{"name":"project"}');
  assert.deepEqual(c.steps, ['render', 'ClientReady']);
  c.update();
  assert.deepEqual(c.events, ['ClientReady']);
  assert.deepEqual(c.rows.items, ['project'], 'initial data plus DataChanged must not duplicate rows');
  assert.equal(c.resizeCount, 1, 'header handles must not accumulate on data refresh');
});

test('late initial data announces readiness only after a successful render', () => {
  const c = client(undefined);
  assert.deepEqual(c.events, []);
  c.component.Data = 'invalid JSON';
  assert.throws(c.update);
  assert.deepEqual(c.events, []);
  c.component.Data = '{"name":"project"}';
  c.update();
  assert.deepEqual(c.steps, ['render', 'ClientReady']);
});
