// Keyboard events do not bubble out of an iframe. Relay the original trusted
// event so the app applies one shared shortcut and modal/focus policy.
(function () {
    function relay(event) {
        try {
            const handle = window.parent.__kssolvOnlineShortcut;
            if (typeof handle === 'function') handle(event);
        } catch (_) { /* An unrelated cross-origin parent is not an app host. */ }
    }
    window.addEventListener('keydown', relay, true);
    window.addEventListener('unload', function () {
        window.removeEventListener('keydown', relay, true);
    }, {once:true});
}());
