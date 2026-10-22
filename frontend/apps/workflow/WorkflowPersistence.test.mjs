import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import { URL } from 'node:url';
import { test } from 'node:test';
import ts from 'typescript';

// Execute the actual component's setup with a graph that reports history
// changes during reset, as X6 does. No browser or new dependencies required.
const source = fs.readFileSync(new URL('src/components/MainWindow.vue', import.meta.url), 'utf8');
const script = source.match(/<script setup lang="ts">([\s\S]*?)<\/script>/)[1];
const compiled = ts.transpileModule(script, {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 },
}).outputText;

function openCanvas(data) {
  const events = [];
  const listeners = new Map();
  let mounted;
  const graphs = [];
  class Graph {
    static registerEdge() {}
    static registerConnector() {}
    constructor() {
      graphs.push(this);
      this.handlers = new Map();
      this.cells = [];
    }
    use() {}
    bindKey() {}
    centerContent() {}
    zoomToFit() {}
    on(name, handler) {
      this.handlers.set(name, handler);
    }
    createNode(cell) {
      return cell;
    }
    createEdge(cell) {
      return cell;
    }
    resetCells(cells) {
      this.cells = cells;
      this.handlers.get('history:change')?.();
    }
    fromJSON(json) {
      this.resetCells(Array.isArray(json) ? json : json.cells);
    }
    toJSON() {
      return { cells: this.cells };
    }
    getSelectedCells() {
      return [];
    }
    getNodes() {
      return this.cells.filter((cell) => cell.shape === 'dag-node');
    }
    select() {}
  }
  const matlab = {
    Data: JSON.stringify(data),
    addEventListener(name, handler) {
      listeners.set(name, handler);
    },
    sendEventToMATLAB(name, value) {
      events.push({ name, value });
    },
  };
  const context = {
    exports: {},
    JSON,
    MATLAB: matlab,
    document: { documentElement: { clientWidth: 800, clientHeight: 600 } },
    window: { addEventListener() {} },
    require(name) {
      if (name === 'vue')
        return {
          ref: (value) => ({ value }),
          onMounted: (handler) => {
            mounted = handler;
          },
          onUnmounted() {},
        };
      if (name === '@antv/x6') return { Graph };
      if (name === '@antv/x6-vue-shape') return { getTeleport() {}, register() {} };
      if (name.startsWith('@antv/x6-plugin-')) {
        return new Proxy({}, { get: () => class {} });
      }
      if (name.endsWith('dag.json')) return { default: [{ id: 'demo', shape: 'dag-node' }] };
      if (name.endsWith('.vue')) return {};
      throw Error(`Unexpected import: ${name}`);
    },
  };
  vm.runInNewContext(compiled, context);
  mounted();
  return { events, listeners, graph: graphs[0], matlab };
}

const node = { id: 'saved-node', shape: 'dag-node', data: { label: 'Saved', status: 'default' } };
for (const data of [[node], { cells: [node] }, [], { cells: [] }]) {
  test(`initial canvas preserves ${JSON.stringify(data)}`, () => {
    const { events, listeners, graph } = openCanvas(data);
    const expected = Array.isArray(data) ? data : data.cells;
    assert.deepEqual(graph.cells, expected);
    const exports = events.filter((event) => event.name === 'GraphExportToJSON');
    assert.equal(exports.length, 1);
    assert.deepEqual(JSON.parse(exports[0].value).cells, expected);
    listeners.get('workflowOpenSettingsWindow')();
    const settings = events.filter((event) => event.name === 'OpenSettingsWindow');
    assert.deepEqual(
      settings.map((event) => event.value),
      expected.length ? ['saved-node'] : [],
    );
  });
}

test('subsequent MATLAB canvas updates preserve restored node IDs', () => {
  const { matlab, listeners, events, graph } = openCanvas({ cells: [node] });
  const renamed = { ...node, id: 'another-saved-node' };
  matlab.Data = JSON.stringify({ cells: [renamed] });
  listeners.get('DataChanged')();
  assert.deepEqual(graph.cells, [renamed]);
  listeners.get('workflowOpenSettingsWindow')();
  assert.deepEqual(events.at(-1), { name: 'OpenSettingsWindow', value: renamed.id });
});
