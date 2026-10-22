// Run with Node.js; no browser or third-party packages are required.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const source = fs.readFileSync(path.join(__dirname,
    '../../../+kssolv/+ui/resources/browser/online-html-bootstrap.js'), 'utf8');

function fixture() {
    const tasks = [];
    const listeners = new Map();
    const context = {
        window: {},
        document: {documentElement: {dataset: {}}},
        queueMicrotask(callback) { tasks.push(callback); },
    };
    const component = {
        Data: {revision: 1},
        addEventListener(name, callback) {
            const callbacks = listeners.get(name) || [];
            callbacks.push(callback);
            listeners.set(name, callbacks);
        },
    };
    vm.runInNewContext(source, context);
    return {
        context, component,
        flush() { while (tasks.length) tasks.shift()(); },
        emit(name) {
            for (const callback of listeners.get(name) || []) {
                callback({Data: component.Data});
            }
        },
    };
}

{
    const f = fixture();
    let calls = 0;
    const seen = [];
    f.context.window.setup = function (component) {
        calls++;
        component.addEventListener('DataChanged', event => seen.push(event.Data.revision));
    };
    f.context.window.setup(f.component);
    f.component.Data = {revision: 2};
    f.emit('DataChanged');
    f.flush();
    assert.equal(calls, 1);
    assert.deepEqual(seen, [2]);
    assert.equal(f.context.document.documentElement.dataset.kssolvOnlineSetup, 'started');
}

{
    const f = fixture();
    let calls = 0;
    const seen = [];
    // UIHTML setup and its initial data event precede module evaluation.
    f.context.window.setup(f.component);
    f.emit('DataChanged');
    f.component.Data = {revision: 2};
    f.context.window.setup = function (component) {
        calls++;
        component.addEventListener('DataChanged', event => seen.push(event.Data.revision));
    };
    // Current data, rather than the value at registration, must be replayed.
    f.component.Data = {revision: 3};
    f.flush();
    assert.equal(calls, 1);
    assert.deepEqual(seen, [3]);
    f.component.Data = {revision: 4};
    f.emit('DataChanged');
    assert.deepEqual(seen, [3, 4]);
    f.context.window.setup(f.component);
    assert.equal(calls, 1);
}

{
    const f = fixture();
    const seen = [];
    let lateSubscribe;
    f.context.window.setup(f.component);
    f.context.window.setup = component => {
        lateSubscribe = () => component.addEventListener('DataChanged',
            event => seen.push(event.Data.revision));
    };
    f.component.Data = {revision: 7};
    f.emit('DataChanged');
    lateSubscribe();
    f.component.Data = {revision: 8};
    f.flush();
    assert.deepEqual(seen, [8]);
}

console.log('PASS Online HTML bootstrap: both load orders, latest-data replay, late subscription');
