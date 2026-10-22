async function main() {
// Regress cold-start registration and gallery actions with a MATLAB Toolstrip.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const source = fs.readFileSync(path.join(__dirname,
    '../../../+kssolv/+ui/resources/browser/sidebar.html'), 'utf8').match(/<script>([\s\S]*?)<\/script>/)[1];
class Actions {
    constructor() { this.items = new Map(); }
    addAction(action) { assert(!this.items.has(action.id)); this.items.set(action.id, action); }
    getAction(id) { return this.items.get(id); }
    removeAction(id) { assert(this.items.delete(id)); }
    executeAction(id) { return this.items.get(id).callback(); }
    destroy() { this.items.clear(); this.destroyed = true; }
}
const sharedActions = new Actions();
const sharedBuilder = {create() { throw Error('ActAsClient must not create gallery actions'); }};
class Builder {
    constructor(options) {
        assert.equal(options.isMATLABDriven, false);
        assert(options.actionService instanceof Actions);
        this.items = new Map();
    }
    create(item) { this.items.set(item.tag, item); }
    destroy(id) { this.items.delete(id); }
    cleanup() { this.items.clear(); }
}
sharedBuilder.constructor = Builder;
const gallery = {
    openPanelsGalleryDialog() { throw Error('Browser locale must not be used'); },
    _uiBuilder: sharedBuilder, _actionService: sharedActions,
    _populateGallery() {
        this._uiBuilder.create({tag:'panel'});
        this._galleryPanelId = 'panel';
        this._galleryPanelWidget = {domNode:{}};
        this._galleryCreated = this._galleryPopulated = true;
    },
    _addGalleryItem(item) { this._uiBuilder.create(item); },
    _removeGalleryItem(tag) { this._uiBuilder.destroy(tag); },
    choose(title) {
        const item = [...this._uiBuilder.items.values()].find(item => item.text === title);
        assert(item, 'Panel must be discoverable in More');
        this._actionService.executeAction(item.actionId);
    }
};
function panel(tag) {
    return {widget:{id:'widget-' + tag,domNode:{}},properties:{panelId:tag,title:tag,isOpen:true,
        set(name,value) { this[name]=value; }}};
}
let panels = [];
const changes = [], timers = new Set(), unload = new Set(), events = [];
const documents = {set(name,value) { this[name] = value; }};
const container = {
    _documentContainer:documents,
    id:'test-app', actionService:sharedActions, uiBuilder:sharedBuilder,
    _panelsGalleryManager:gallery, getPanels:()=>panels,
    selectPanel(tag) {
        const selected = panels.find(p => p.properties.panelId === tag);
        assert(selected, 'Selection must use panelId, not widget id');
        selected.properties.isOpen = selected.properties.isShowing = true;
    },
    layout:{left:{children:[{children:[{id:'ProjectBrowser'}]}, {children:[{id:'InfoBrowser'}]},
        {children:[{id:'OnlineFilesBrowser'}]}]},right:{children:[{children:[{id:'ConfigBrowser'}]},
        {children:[{id:'RunBrowser'}]}]}},
    get(name) { assert.equal(name,'panelLayout'); return this.layout; },
    set(name,value) { changes.push([name,value]); if(name==='panelLayout') this.layout=value; }
};
const nativeIcon = {style:{}};
let reconnects = 0;
const nativeButton = {controls:'widget-ProjectBrowser',icon:'genericSB',
    remove() { this.disconnected=true; },
    parentNode:{insertBefore(button) {
        assert(button.disconnected);
        // Native DragSourceController.setup loads host.icon on reconnect.
        button.avatarIcon=button.icon; reconnects++;
    }},
    shadowRoot:{querySelector:selector=>selector==='#icon20'?nativeIcon:null,
        querySelectorAll:()=>[]}
};
const listeners = new Map(), dialogs = [];
const listen = (name,fn) => { if(!listeners.has(name)) listeners.set(name,new Set()); listeners.get(name).add(fn); };
const unlisten = (name,fn) => listeners.get(name)?.delete(fn);
const styles = new Map();
let captureRoot;
const host = {
    addEventListener:listen,removeEventListener:unlisten,
    require(names,callback) {
        assert.equal(names.join(','),'mw-dialogs/Dialogs,mw-dialogs/ButtonEnum');
        callback({MODELESS:'modeless',createDialog(options) {
            dialogs.push(options);
            return {on() {},addButtonEventListener(button,fn,close) {assert.equal(close,true);},close() {}};
        }},{CLOSE:{type:'Cancel',label:'关闭'}});
    },
    uiroot:{peer:{_rootUIContainer:container}},
    document:{
        getElementById:id=>id==='uiroot'?captureRoot:styles.get(id),
        head:{appendChild:node=>styles.set(node.id,node)},
        addEventListener:listen,removeEventListener:unlisten,
        querySelectorAll:selector=>['mw-sidebar-button','*'].includes(selector)?[nativeButton]:[],
        createElement() { return {setAttribute(){},getAttribute(name){return this[name]}}; }
    },
    setInterval(fn) { timers.add(fn); return fn; },
    clearInterval(fn) { timers.delete(fn); }
};
const context = {window:{parent:host,
    addEventListener(name,fn) { if(name==='unload') unload.add(fn); },
    removeEventListener(name,fn) { if(name==='unload') unload.delete(fn); }}};
vm.runInNewContext(source,context);
const initial = ['ProjectBrowser','InfoBrowser','ConfigBrowser','RunBrowser','CommandWindow'];
const component = {Data:{online:true,galleryTitle:'Open Panels',closeLabel:'Close',panels:initial.map(tag=>({tag,title:tag}))},
    sendEventToMATLAB(name,data) { events.push({name,...data}); }};
const tick = () => [...timers].forEach(fn=>fn());
context.setup(component);
panels = initial.slice(0,3).map(panel); tick();
assert.equal(events.length,0,'RUNNING with only some peers must not initialize an empty gallery');
assert.equal(gallery._galleryPopulated,undefined);
panels = initial.map(panel); tick();
assert.equal(events.at(-1).name,'SidebarReady'); assert.equal(events.at(-1).panelCount,5);
assert.notEqual(gallery._uiBuilder,sharedBuilder);
assert.notEqual(gallery._actionService,sharedActions);
assert.equal(documents.headerStyle,'hover');
// The real manager cached its original bound method before the bridge ran.
let stopped = false;
for (const fn of listeners.get('showpanelsgallery')) fn({stopImmediatePropagation() {stopped=true;}});
assert.equal(stopped,true,'Intercept the body event rather than only replacing a method');
assert.equal(dialogs[0].title,'Open Panels');
assert.equal(dialogs[0].buttons[0].label,'Close');
assert.equal(changes.length,3,'Apply initial grouped layout and collapsed regions once');
assert.equal(nativeButton.icon,'projectsSB');
assert.equal(nativeButton.avatarIcon,nativeButton.icon,'Refresh cached drag icon as well as rendering');
assert.equal(reconnects,1);
assert.equal(panels[0].properties.icon,'projectsSB','New buttons after a move use the same catalog ID');
assert.equal(panels[0].widget.domNode.icon,'projectsSB');
assert.equal(gallery._uiBuilder.items.get('kssolv.sidebar.gallery.widget-CommandWindow').icon.id,'commandWindowSB');
assert.equal(container.layout.left.children[0].children.map(p=>p.id).join(','),'ProjectBrowser,InfoBrowser');
assert.equal(container.layout.right.children[0].children.map(p=>p.id).join(','),'ConfigBrowser,RunBrowser');
assert.equal(container.layout.left.children[1].children[0].id,'OnlineFilesBrowser','Preserve the Files drawer');
assert.equal(container.layout.right.collapsed,true);
assert.equal(container.layout.left.collapsed,false);
assert.equal(container.layout.left.children[0].children[0].collapsed,false);
assert.equal(container.layout.left.children[0].children[1].collapsed,true);
assert(changes.some(([name,value])=>name==='isRightCollapsed' && value===true));
for(const region of ['left','right']) {
    assert.equal(container.layout[region].children[0].children.map(p=>p.portion).join(','),'0.75,0.25');
}
const playURL=gallery._uiBuilder.items.get('kssolv.sidebar.gallery.widget-RunBrowser').icon;
assert(playURL.startsWith('data:image/svg+xml;'));
const playSVG=decodeURIComponent(playURL.slice(playURL.indexOf(',')+1));
assert(playSVG.includes('fill="none"'));
assert(playSVG.includes('stroke-width="1"'));
assert.equal(panels[3].properties.icon,playURL,'Drag source must share the unfilled play glyph');
const gearURL=gallery._uiBuilder.items.get('kssolv.sidebar.gallery.widget-ConfigBrowser').icon;
assert(gearURL.startsWith('data:image/svg+xml;'));
const gearSVG=decodeURIComponent(gearURL.slice(gearURL.indexOf(',')+1));
assert(!gearSVG.includes('var('),'SVG images must have resolved theme colours');
assert(gearSVG.includes('viewBox="0 0 24 24"'));
assert.equal(panels[2].properties.icon,gearURL,'Drag source and gallery must share the wireframe gear');
assert.equal(nativeButton.shadowRoot.querySelector('#icon20'),nativeIcon);
nativeButton.controls='widget-InfoBrowser'; tick();
assert.equal(nativeButton.icon,'infoMonoUI');
assert.equal(nativeIcon.icon.width,24,'Request an existing native asset for icons without a 20px variant');
assert.equal(nativeButton.avatarIcon,'infoMonoUI');
nativeButton.controls='widget-ProjectBrowser'; tick();
const expectedReconnects=reconnects;
panels[1].properties.isOpen = false;
gallery.choose('InfoBrowser');
assert.equal(panels[1].properties.isOpen,true,'More reopens a closed panel using its stable MATLAB tag');
panels.push(panel('AddedAfterStartup')); tick();
assert.equal(reconnects,expectedReconnects,'Polling does not repeatedly reconnect unchanged icons');
assert.equal(events.at(-1).panelCount,6);
gallery.choose('AddedAfterStartup');
panels[1].properties.title = 'Renamed information'; tick();
assert.equal(gallery._uiBuilder.items.size,7,'Rename replaces an item without duplicating it');
gallery.choose('Renamed information');
panels = panels.filter(p=>!['InfoBrowser','AddedAfterStartup'].includes(p.properties.panelId)); tick();
assert.equal(events.at(-1).panelCount,4,'Removing panels below the initial count must still refresh');
assert.equal(gallery._uiBuilder.items.size,5);
// Pointer capture must keep native drag events in the parent across iframe bounds.
const frameStyle = new Map([['pointer-events',['auto','important']]]);
const frame = {style:{
    getPropertyValue:name=>frameStyle.get(name)?.[0] || '',
    getPropertyPriority:name=>frameStyle.get(name)?.[1] || '',
    setProperty:(name,value,priority)=>frameStyle.set(name,[value,priority]),
    removeProperty:name=>frameStyle.delete(name)
}};
const originalQuery = host.document.querySelectorAll;
host.document.querySelectorAll = selector => selector==='iframe,object' ? [frame] : [];
const handle = {matches:()=>true};
captureRoot = {contains:node=>node===handle, setPointerCapture(id) {this.captured=id;},
    hasPointerCapture(id) {return this.captured===id;},releasePointerCapture() {delete this.captured;}};
delete container.domNode; // The real RootUIContainer controller has no DOM property.
for (const fn of listeners.get('pointerdown')) fn({button:0,pointerId:7,composedPath:()=>[handle]});
assert.equal(captureRoot.captured,7);
assert.equal(frameStyle.get('pointer-events')[0],'none');
for (const fn of listeners.get('pointerup')) fn({pointerId:99});
assert.equal(captureRoot.captured,7,'Another pointer must not terminate the active drag');
for (const fn of listeners.get('pointerup')) fn({pointerId:7});
assert.equal(captureRoot.captured,undefined);
assert.equal(frameStyle.get('pointer-events').join(','),'auto,important','Restore exact inline pointer policy');
// A second native pointer drag must capture again after pointerup, even when
// preventDefault(pointerdown) suppresses every compatibility mouse event.
for (const fn of listeners.get('pointerdown')) fn({button:0,pointerId:8,composedPath:()=>[handle]});
assert.equal(captureRoot.captured,8);
assert.equal(frameStyle.get('pointer-events')[0],'none');
for (const fn of listeners.get('pointerup')) fn({pointerId:8});
assert.equal(frameStyle.get('pointer-events').join(','),'auto,important');
// Focus loss/cancellation must also finish the native pointer-based drag,
// release capture and restore iframe policies without recursive cleanup.
class SyntheticEvent { constructor(type,options) {this.type=type;Object.assign(this,options);} }
host.PointerEvent = host.MouseEvent = SyntheticEvent;
host.document.dispatchEvent = event => {
    for (const fn of [...(listeners.get(event.type)||[])]) fn(event);
};
captureRoot.dispatchEvent = event => host.document.dispatchEvent(event);
captureRoot.releasePointerCapture = function() {
    const id=this.captured;delete this.captured;
    host.document.dispatchEvent(new SyntheticEvent('lostpointercapture',{pointerId:id}));
};
let nativeFinishes=0;
listen('pointerup',()=>nativeFinishes++);
for (const fn of listeners.get('pointerdown')) fn({button:0,pointerId:9,composedPath:()=>[handle]});
for (const fn of listeners.get('blur')) fn();
assert.equal(nativeFinishes,1);
assert.equal(captureRoot.captured,undefined);
assert.equal(frameStyle.get('pointer-events').join(','),'auto,important');
for (const fn of listeners.get('pointerdown')) fn({button:0,pointerId:10,composedPath:()=>[handle]});
host.document.dispatchEvent(new SyntheticEvent('lostpointercapture',{pointerId:10}));
assert.equal(nativeFinishes,2);
assert.equal(captureRoot.captured,undefined);
assert.equal(frameStyle.get('pointer-events').join(','),'auto,important');
host.document.querySelectorAll = originalQuery;
// Browser polling must update a native status widget without MATLAB callbacks.
let statusText, requests = 0, pendingReply;
container.uiBuilder.widgetByTag = tag => {
    assert.equal(tag,'OnlineResources');
    return {set(name,value) {assert.equal(name,'text'); statusText=value;}};
};
host.AbortController = AbortController;
host.setTimeout = setTimeout;
host.clearTimeout = clearTimeout;
host.fetch = (url,options) => {
    assert.equal(url,'/_kssolv/resources');
    assert.equal(options.credentials,'same-origin');
    assert.equal(options.cache,'no-store');
    requests++;
    return new Promise(resolve => {pendingReply=resolve;});
};
component.Data.memoryLabel='Memory'; component.Data.hostLabel='Host';
tick(); tick();
assert.equal(requests,1,'Do not overlap requests on a slow network');
pendingReply({ok:true,json:async()=>({available:true,scope:'pod',sampledAt:Date.now()/1000,
    cpuPercent:25,cpuCores:4,memoryUsedBytes:1610612736,memoryTotalBytes:8589934592})});
await new Promise(resolve=>setImmediate(resolve));
assert.equal(statusText,'CPU 25.0% (1.00/4 cores)  │  Memory 1.5 / 8.0 GiB');
tick();
assert.equal(requests,1,'Bound resource polling frequency');
// A user's header choice and resized split must survive polling and uihtml reconnection.
documents.set('headerStyle','always');
container.layout.left.children[0].children[0].portion=0.6;
container.layout.left.children[0].children[1].portion=0.4;
tick();
const oldDispose = host.__kssolvSidebar.dispose;
context.setup({...component,Data:{panels:panels.map(p=>({tag:p.properties.panelId,title:p.properties.title}))}});
assert.equal(documents.headerStyle,'always','Reconnect preserves an explicit header choice');
assert.equal(timers.size,1,'Repeated setup must replace the previous poller');
assert.equal(changes.length,3,'Reinitializing a bridge must preserve the user layout');
assert.equal(container.layout.left.children[0].children.map(p=>p.portion).join(','),'0.6,0.4');
oldDispose();
assert.equal(timers.size,1,'A stale unload must not remove the replacement bridge');
for(const dispose of [...unload]) dispose();
assert.equal(timers.size,0);
assert.equal(gallery._uiBuilder,sharedBuilder);
assert.equal(gallery._actionService,sharedActions);
assert.equal(gallery._galleryPopulated,false);
assert(!sharedActions.destroyed);
console.log('PASS sidebar: native catalog icons and drag cache, stacked defaults, delayed peers, Toolstrip isolation, dynamic gallery and cleanup');

}
main().catch(error=>{console.error(error);process.exitCode=1;});
