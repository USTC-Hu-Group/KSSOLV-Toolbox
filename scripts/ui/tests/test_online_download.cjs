// Verify authorization failures never become browser downloads, and prepared
// data stays usable after the Connector authorization has expired or been used.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const html = fs.readFileSync(path.join(__dirname,
    '../../../+kssolv/+ui/resources/browser/online-files.html'), 'utf8');
const source = html.match(/<script>([\s\S]*?)<\/script>/)[1];

function fixture(filename = 'silicon.cif', bytes = 1485, extra = {}) {
    const elements = new Map();
    for (const id of ['title', 'description', 'files', 'filename', 'action',
        'download', 'cancel', 'finish', 'copy', 'status', 'limits', 'progress', 'bar', 'percentage']) {
        elements.set(id, {hidden: true, disabled: false, click() {}, removeAttribute(name) { delete this[name]; }});
    }
    const events = new Map();
    const lifecycle = new Map();
    const sent = [], fetched = [], revoked = [], replies = [], blobs = [];
    const context = {
        document: {getElementById: id => elements.get(id), body:{setAttribute() {}}},
        Blob,
        window: {parent: extra.host, addEventListener: (name, callback) => lifecycle.set(name, callback)},
        AbortController,
        setTimeout, clearTimeout,
        btoa,
        URL: {
            createObjectURL(blob) { blobs.push(blob); return 'blob:test-' + blobs.length; },
            revokeObjectURL(url) { revoked.push(url); },
        },
        fetch(url, options) {
            fetched.push({url, options});
            const reply = replies.shift();
            assert.ok(reply, 'unexpected fetch');
            return typeof reply === 'function' ? reply() : Promise.resolve(reply);
        },
    };
    vm.runInNewContext(source, context);
    context.setup({
        sendEventToMATLAB(name, data) {
            sent.push({name, data});
            if (name === 'upload' && !extra.manualAck) queueMicrotask(() => events.get('ack')({}));
        },
        addEventListener(name, callback) { events.set(name, callback); },
    });
    const emit = (name, Data) => events.get(name)({Data});
    emit('configure', {mode: 'download', title: 'Download file', filename,
        fileBytes: bytes, maxFileBytes: 128 * 1024 * 1024, maxTotalBytes:128 * 1024 * 1024, requireConfirmation: true,
        ...extra.configuration});
    return {elements, sent, fetched, revoked, replies, blobs, emit,
        close: () => lifecycle.get('pagehide')()};
}

(async () => {
    const settle = () => new Promise(resolve => setImmediate(resolve));
    for (const [filename, size] of [['硅 #1.cif', 1485], ['project.ks', 6133396]]) {
        const f = fixture(filename, size);
        const link = f.elements.get('download');
        assert.equal(link.hidden, true);
        assert.equal(link.href, undefined);
        assert.equal(f.sent.at(-1).name, 'requestDownload');

        // An expired or previously consumed authorization stays in the dialog.
        f.replies.push({ok: false, status: 403});
        await f.emit('downloadURL', {url: '/download/expired'});
        assert.equal(link.hidden, true);
        assert.equal(f.elements.get('finish').hidden, true);
        assert.match(f.elements.get('status').textContent, /HTTP 403/);
        assert.equal(f.elements.get('action').disabled, false);
        await f.elements.get('action').onclick();
        assert.equal(f.sent.at(-1).name, 'requestDownload');

        f.replies.push({ok: true, arrayBuffer: async () => new ArrayBuffer(size)});
        await f.emit('downloadURL', {url: '/download/fresh'});
        assert.equal(link.download, filename);
        assert.equal(link.hidden, false);
        assert.equal(link.href, 'blob:test-1');
        assert.equal(f.fetched[1].options.credentials, 'same-origin');
        assert.equal(f.fetched[1].options.cache, 'no-store');

        // Repeated saves consume neither the old authorization nor a new one.
        for (let i = 0; i < 5; i++) link.onclick();
        assert.equal(f.fetched.length, 2);
        assert.equal(link.href, 'blob:test-1');
        assert.equal(f.elements.get('finish').hidden, false);
        f.elements.get('finish').onclick();
        assert.equal(f.sent.at(-1).name, 'downloadConfirmed');
        f.close();
        assert.deepEqual(f.revoked, ['blob:test-1']);
        assert.equal(link.href, undefined);
    }

    {
        const f = fixture();
        f.replies.push({ok: true, arrayBuffer: async () => new ArrayBuffer(10)});
        await f.emit('downloadURL', {url: '/download/truncated'});
        assert.equal(f.elements.get('download').hidden, true);
        assert.match(f.elements.get('status').textContent, /Incomplete file/);
        assert.equal(f.blobs.length, 0);
    }

    {
        const f = fixture();
        let release;
        f.replies.push(() => new Promise(resolve => { release = resolve; }));
        const pending = f.emit('downloadURL', {url: '/download/pending'});
        f.close();
        assert.equal(f.fetched[0].options.signal.aborted, true);
        release({ok: true, arrayBuffer: async () => new ArrayBuffer(1485)});
        await pending;
        assert.equal(f.blobs.length, 0);
        assert.equal(f.elements.get('download').hidden, true);
    }

    {
        let picker;
        const host = {showOpenFilePicker: async options => {
            picker = options;
            return [{getFile: async () => ({name:'fixture.ks', size:3,
                slice: (start, end) => new Blob(['abc']).slice(start, end)})}];
        }};
        const f = fixture('fixture.ks', 3, {host, configuration:{mode:'open', accept:'.ks', multiple:false}});
        await settle();
        assert.deepEqual(Array.from(picker.types[0].accept['application/octet-stream']), ['.ks']);
        assert.equal(picker.multiple, false);
        assert.equal(f.sent.find(x => x.name === 'upload').data.bytes, 'YWJj');
        assert.equal(f.sent.at(-1).name, 'complete');
    }

    {
        let picker, closed = false;
        const received = [];
        const host = {showSaveFilePicker: async options => {
            picker = options;
            return {name:'chosen.ks', createWritable: async () => ({
                write: async blob => { received.push(blob); },
                close: async () => { closed = true; }, abort: async () => {},
            })};
        }};
        const choose = fixture('suggested.ks', 100, {host,
            configuration:{mode:'save', id:'save-choice', accept:'.ks'}});
        await settle();
        assert.equal(picker, undefined, 'server preparation must not open a destructive save picker');
        assert.equal(choose.sent.at(-1).name, 'save');
        assert.equal(choose.sent.at(-1).data.name, 'suggested.ks');
        choose.close();

        // Only a complete, verified response may reach the native picker.
        const save = fixture('chosen.ks', 100, {host, configuration:{destinationId:'save-choice'}});
        assert.equal(picker, undefined);
        save.replies.push({ok:true, arrayBuffer:async () => new ArrayBuffer(100)});
        await save.emit('downloadURL', {url:'/download/fresh'});
        assert.equal(received[0].size, 100);
        assert.equal(picker.suggestedName, 'chosen.ks');
        assert.equal(closed, true);
        assert.equal(save.sent.at(-1).name, 'nativeDownloadComplete');
        assert.equal(save.elements.get('download').textContent, 'Browser download');
        save.emit('failure', 'Invalid client filename.');
        assert.equal(save.elements.get('cancel').disabled, false,
            'a server rejection after native saving must remain cancellable');
        assert.equal(save.elements.get('action').textContent, 'Save as…');
        await save.elements.get('action').onclick();
        assert.equal(save.fetched.length, 1, 'retry saving reuses verified data');
    }

    {
        const host = {showOpenFilePicker: async () => { throw {name:'AbortError'}; }};
        const f = fixture('cancel.ks', 100, {host, configuration:{mode:'open'}});
        await settle();
        assert.equal(f.sent.at(-1).name, 'cancel');
        assert.equal(f.sent.some(x => x.name === 'upload'), false);
    }

    {
        let calls = 0;
        const host = {showSaveFilePicker: async () => {
            if (++calls === 1) throw {name:'SecurityError'};
            return {name:'retry.ks',createWritable:async()=>({write:async()=>{},close:async()=>{},abort:async()=>{}})};
        }};
        const f = fixture('retry.ks', 100, {host});
        assert.equal(calls,0);
        f.replies.push({ok:true,arrayBuffer:async()=>new ArrayBuffer(100)});
        await f.emit('downloadURL',{url:'/download/ready'});
        assert.equal(f.elements.get('action').textContent, 'Save as…');
        assert.equal(f.sent.some(x => x.name === 'nativeDownloadComplete'), false);
        await f.elements.get('action').onclick();
        assert.equal(calls, 2);
        assert.equal(f.sent.at(-1).name, 'nativeDownloadComplete');
        assert.equal(f.fetched.length,1,'gesture retry reuses verified data');
    }

    {
        let existing='KEEP-EXISTING-FILE';
        const host={showSaveFilePicker:async()=>{existing='';throw Error('must not select a destination');}};
        const f=fixture('existing.ks',100,{host});
        f.replies.push({ok:false,status:500});
        await f.emit('downloadURL',{url:'/download/failure'});
        assert.equal(existing,'KEEP-EXISTING-FILE');
        f.replies.push({ok:true,arrayBuffer:async()=>new ArrayBuffer(99)});
        await f.emit('downloadURL',{url:'/download/truncated'});
        assert.equal(existing,'KEEP-EXISTING-FILE');
        let release;
        f.replies.push(()=>new Promise(resolve=>{release=resolve;}));
        const downloading=f.emit('downloadURL',{url:'/download/cancel'});
        f.elements.get('cancel').onclick();
        release({ok:true,arrayBuffer:async()=>new ArrayBuffer(100)});
        await downloading;
        assert.equal(existing,'KEEP-EXISTING-FILE');
    }

    {
        let aborted = false;
        const host = {showSaveFilePicker: async () => ({name:'failed.ks',
            createWritable: async () => ({
                write: async () => { throw new Error('Disk full'); },
                close: async () => { assert.fail('failed write must not commit'); },
                abort: async () => { aborted = true; },
            })})};
        const f = fixture('failed.ks', 100, {host});
        await settle();
        f.replies.push({ok:true, arrayBuffer:async () => new ArrayBuffer(100)});
        await f.emit('downloadURL', {url:'/download/fresh'});
        assert.equal(aborted, true);
        assert.equal(f.sent.some(x => x.name === 'nativeDownloadComplete'), false);
        assert.match(f.elements.get('status').textContent, /Disk full/);
        assert.equal(f.elements.get('action').disabled, false);
    }

    {
        // Progress follows acknowledgements rather than reads from local disk.
        // A 128 MiB file is accepted; either per-file or aggregate overflow is rejected.
        const cap = 128 * 1024 * 1024;
        const f = fixture('boundary.ks', cap, {configuration:{mode:'open'}});
        const input = f.elements.get('files');
        // Exercise the full boundary in chunks without an additional 128 MiB input Blob.
        input.files = [{name:'boundary.ks', size:cap,
            slice:(start,end) => ({arrayBuffer:async () => new ArrayBuffer(end-start)})}];
        await input.onchange();
        assert.equal(f.sent.at(-1).name, 'complete');
        assert.equal(f.sent.filter(x=>x.name==='upload').length, 1024);
        assert.equal(f.elements.get('bar').value, 100);
        input.files = [{name:'over.ks', size:cap+1}];
        const before = f.sent.length;
        await input.onchange();
        assert.equal(f.sent.length, before);
        assert.match(f.elements.get('status').textContent, /exceeds/);
        input.files = [{name:'one.ks',size:cap}, {name:'two.ks',size:1}];
        await input.onchange();
        assert.equal(f.sent.length, before);
    }
    {
        let committed = false;
        const progress = [];
        const f = fixture('stream.ks', 12, {host:{showSaveFilePicker:async () => ({
            name:'stream.ks', createWritable:async () => ({
                write:async blob => progress.push(blob.size),
                close:async () => { assert.equal(f.elements.get('bar').value,100); committed=true; },
                abort:async () => {},
            })})}});
        await settle();
        const chunks = [new Uint8Array(3),new Uint8Array(3),new Uint8Array(6)];
        f.replies.push({ok:true,body:{getReader:()=>({
            read:async () => chunks.length ? {value:chunks.shift(),done:false} : {done:true},
            releaseLock() {}, cancel:async () => {},
        })}});
        await f.emit('downloadURL',{url:'/download/stream'});
        assert.deepEqual(progress, [12], 'native saving receives the complete verified Blob');
        assert.equal(committed,true);
        assert.equal(f.elements.get('percentage').textContent,'100%');
    }

    {
        const f = fixture('ack.ks', 256 * 1024, {manualAck:true,configuration:{mode:'open'}});
        f.elements.get('files').files=[{name:'ack.ks',size:256 * 1024,
            slice:(start,end)=>new Blob([new Uint8Array(256 * 1024)]).slice(start,end)}];
        const uploading=f.elements.get('files').onchange();
        await settle();
        assert.equal(f.elements.get('bar').value,0,'reading/sending is not acknowledgement');
        f.emit('ack',{});await settle();
        assert.equal(f.elements.get('bar').value,50);
        f.emit('ack',{});await uploading;
        assert.equal(f.elements.get('bar').value,100);
    }
    {
        const f=fixture('cancel.ks',3);
        let release;
        f.replies.push(()=>new Promise(resolve=>{release=resolve;}));
        const downloading=f.emit('downloadURL',{url:'/download/cancel'});
        f.elements.get('cancel').onclick();
        assert.equal(f.fetched[0].options.signal.aborted,true);
        release({ok:true,arrayBuffer:async()=>new ArrayBuffer(3)});
        await downloading;
        assert.equal(f.blobs.length,0);
        assert.equal(f.sent.at(-1).name,'cancel');
    }

    {
        const writes=[];
        const f=fixture('plot.png',3,{configuration:{clipboardMode:'image',requireConfirmation:false},host:{
            showSaveFilePicker(){throw new Error('Copy must not open a save picker');},
            ClipboardItem:class {constructor(data){this.data=data;}},
            navigator:{clipboard:{write:async items=>writes.push(items)}}
        }});
        f.replies.push({ok:true,arrayBuffer:async()=>new Uint8Array([1,2,3]).buffer});
        await f.emit('downloadURL',{url:'/download/plot'});
        assert.equal(writes.length,1);assert.equal(writes[0][0].data['image/png'].type,'image/png');
        assert.match(f.elements.get('status').textContent,/Copied to clipboard/);
        assert.equal(f.elements.get('copy').disabled,false);f.close();
    }
    {
        const f=fixture('plot.png',3,{configuration:{clipboardMode:'image'},host:{
            ClipboardItem:class {constructor(data){this.data=data;}},
            navigator:{clipboard:{write:async()=>{throw new Error('Permission denied');}}}
        }});
        f.replies.push({ok:true,arrayBuffer:async()=>new Uint8Array([1,2,3]).buffer});
        await f.emit('downloadURL',{url:'/download/denied'});
        assert.match(f.elements.get('status').textContent,/Permission denied/);
        assert.equal(f.elements.get('copy').disabled,false);
        assert.equal(f.elements.get('download').hidden,false,'Permission failure keeps file download usable');f.close();
    }
    {
        let copied;
        const svg='<svg xmlns="http://www.w3.org/2000/svg"><path d="M0 0L1 1"/></svg>';
        const bytes=new TextEncoder().encode(svg);
        const f=fixture('plot.svg',bytes.length,{configuration:{clipboardMode:'vector'},host:{
            ClipboardItem:class {static supports(){return false;} constructor(data){copied=data;}},
            navigator:{clipboard:{write:async()=>{}}}
        }});
        f.replies.push({ok:true,arrayBuffer:async()=>bytes.buffer});
        await f.emit('downloadURL',{url:'/download/vector'});
        assert.equal(await copied['text/plain'].text(),svg);
        assert.match(f.elements.get('status').textContent,/SVG source copied/);f.close();
    }
    {
        let selectedModule,wroteOfficial=false;
        const f=fixture('plot.png',3,{configuration:{clipboardMode:'image'},host:{
            require(ids,resolve){selectedModule=ids[0];resolve({write:async()=>{wroteOfficial=true;}});},
            DataTransfer:class {constructor(){this.items={add(){}};}},
            File:class extends Blob {constructor(parts,name,options){super(parts,options);this.name=name;}}
        }});
        f.replies.push({ok:true,arrayBuffer:async()=>new Uint8Array([1,2,3]).buffer});
        await f.emit('downloadURL',{url:'/download/official'});
        assert.equal(selectedModule,'mw-clipboard/client/NavigatorService');
        assert.equal(wroteOfficial,true);assert.match(f.elements.get('status').textContent,/Copied to clipboard/);f.close();
    }
    console.log('PASS Online files: native pickers, verified downloads, cancellation, authorization, and browser/official graphics clipboard');
})().catch(error => { console.error(error); process.exitCode = 1; });
