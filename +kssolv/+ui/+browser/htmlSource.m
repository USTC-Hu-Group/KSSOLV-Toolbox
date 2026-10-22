function source = htmlSource(file, options)
%HTMLSOURCE Load local UI content without browser iframe file navigation.
% Online uses uihtml's supported HTML text input. A Connector base URL keeps
% relative scripts, styles and images on the authenticated, same-origin route.
arguments
    file
    options.FillFigure (1,1) logical = false
end
source = file;
if ~isKSSOLVOnline(), return, end
file = char(file);
source = fileread(file);
url = matlab.ui.internal.URLUtils.getURLToUserFile(file, false);
base = url(1:find(url == '/', 1, 'last'));
base = strrep(strrep(base, '&', '&amp;'), '"', '&quot;');
head = regexp(source, '<head(?:\s[^>]*)?>', 'end', 'once', 'ignorecase');
if isempty(head)
    error('KSSOLV:Online:HTMLHead', 'Online UI HTML requires a head element.');
end
bootstrap = ['<script>document.documentElement.dataset.kssolvOnline="true";', ...
    fileread(kssolv.ui.browser.resourcePath('online-shortcuts.js')), '</script>'];
if options.FillFigure
    bootstrap = [bootstrap, '<script>', ...
        fileread(kssolv.ui.browser.resourcePath('online-fill-figure.js')), '</script>'];
end
if ~isempty(regexpi(source, '<script[^>]*type\s*=\s*["'']module["'']', 'once'))
    bootstrap = [bootstrap, '<script>', ...
        fileread(kssolv.ui.browser.resourcePath('online-html-bootstrap.js')), '</script>'];
end
source = [source(1:head), '<base href="', base, '">', bootstrap, source(head+1:end)];
end
