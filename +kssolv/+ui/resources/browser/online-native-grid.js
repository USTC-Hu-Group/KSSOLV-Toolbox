// Preserve MATLAB's fixed/fit/fr tracks, while letting controls fill the
// browser's current grid cells instead of delayed server pixel dimensions.
const pane = window.frameElement?.closest('.figureContentPane');
const grid = pane?.querySelector('.gbtGrid');
if (!grid) return;
pane.setAttribute('data-kssolv-native-grid', '');
for (let node = grid; node && node !== pane; node = node.parentElement) {
    node.setAttribute('data-kssolv-native-root', '');
}
const document = pane.ownerDocument;
const id = 'kssolv-native-grid-style';
if (!document.getElementById(id)) {
    const style = document.createElement('style');
    style.id = id;
    style.textContent = `
        [data-kssolv-native-root] {
            width: 100% !important; height: 100% !important;
            min-width: 0; min-height: 0; box-sizing: border-box;
        }
        .gbtGrid[data-kssolv-native-root] { left: 0 !important; top: 0 !important; }
        [data-kssolv-native-grid] .gbtGridContents > * {
            width: 100% !important; height: 100% !important;
            min-width: 0; min-height: 0; box-sizing: border-box;
        }
        [data-kssolv-native-grid] .gbtAccordion > .scrollableContentsNode {
            width: 100% !important;
        }
        [data-kssolv-native-grid] .gbtGridContents > .vc-widget > .mwSizeMixin {
            width: 100% !important; height: 100% !important; box-sizing: border-box;
        }
        [data-kssolv-native-grid] .gbtGridContents > .vc-widget .mwAlignmentNode {
            max-width: 100% !important;
        }`;
    document.head.appendChild(style);
}
