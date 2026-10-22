function enableClientGridSizing(figure)
%ENABLECLIENTGRIDSIZING Keep Online native controls inside their CSS grid cells.
% Native grid tracks already describe fixed, fit and flexible dimensions. The
% bridge removes delayed pixel dimensions only inside this opted-in figure.
if ~isKSSOLVOnline(), return, end
script = fileread(kssolv.ui.browser.resourcePath('online-native-grid.js'));
uihtml(figure, Position=[0 0 1 1], Tag='KSSOLVNativeGridSizing', ...
    HTMLSource=['<!doctype html><html><head></head><body><script>', ...
    'function setup(){', script, '}</script></body></html>']);
end
