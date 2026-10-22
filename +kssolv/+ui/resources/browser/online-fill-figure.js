// Opted-in, single-view figures fill the client-owned dock immediately. MATLAB
// updates grid and HTML widget pixel sizes after a server round trip; those
// stale sizes must not hold back the iframe's viewport during splitter drags.
(function () {
    'use strict';
    const frame = window.frameElement;
    const pane = frame?.closest('.figureContentPane');
    if (!frame || !pane) return;
    const document = frame.ownerDocument;
    const marker = 'data-kssolv-fill-size';
    const styleId = 'kssolv-fill-view-style';
    if (!document.getElementById(styleId)) {
        const style = document.createElement('style');
        style.id = styleId;
        style.textContent = `
            [${marker}] {
                width: 100% !important; height: 100% !important;
                min-width: 0 !important; min-height: 0 !important;
                box-sizing: border-box;
            }
            .gbtGrid[${marker}] {
                left: 0 !important; top: 0 !important;
            }
            [data-type="matlab.ui.control.HTML"][${marker}] {
                margin: 0 !important;
            }`;
        document.head.appendChild(style);
    }
    // Leave the native pane untouched: its size, position, docking and minimum
    // bounds belong to AppContainer. Only its single-view contents opt in.
    for (let node = frame; node && node !== pane; node = node.parentElement) {
        node.setAttribute(marker, '');
    }
}());
