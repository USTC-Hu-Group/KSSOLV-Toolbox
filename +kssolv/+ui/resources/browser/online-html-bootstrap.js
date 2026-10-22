// uihtml can deliver RenderHTML before an external ES module defines setup.
// Keep the component until the application module has installed its handler.
(function () {
    document.documentElement.dataset.kssolvOnlineSetup = 'waiting';
    let handler;
    let component;
    let started = false;
    let deferred = false;
    function start() {
        if (!started && component && typeof handler === 'function') {
            started = true;
            document.documentElement.dataset.kssolvOnlineSetup = 'started';
            if (deferred) {
                const add = component.addEventListener.bind(component);
                component.addEventListener = function (name, callback) {
                    add(name, callback);
                    // RenderHTML's initial DataChanged can precede module
                    // evaluation. Late subscribers must see current data.
                    if (name === 'DataChanged') {
                        queueMicrotask(function () { callback({Data: component.Data}); });
                    }
                };
            }
            handler(component);
        }
    }
    Object.defineProperty(window, 'setup', {
        configurable: true,
        get: function () {
            return function (value) {
                component = value;
                document.documentElement.dataset.kssolvOnlineSetup = 'component';
                deferred = typeof handler !== 'function';
                start();
            };
        },
        set: function (value) {
            handler = value;
            document.documentElement.dataset.kssolvOnlineSetup = 'handler';
            start();
        }
    });
}());
