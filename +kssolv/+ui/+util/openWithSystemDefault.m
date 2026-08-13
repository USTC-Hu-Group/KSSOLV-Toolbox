function openWithSystemDefault(filePath)
%OPENWITHSYSTEMDEFAULT Open a file using the operating-system default app.

arguments
    filePath {mustBeTextScalar}
end

filePath = string(filePath);
if ~isfile(filePath) && ~isfolder(filePath)
    error("KSSOLV:UI:SystemOpen:PathNotFound", ...
        "The path does not exist: %s", filePath);
end

if ispc
    winopen(char(filePath));
    return
end

quotedPath = kssolv.ui.util.shellQuote(filePath);
if ismac
    [status, output] = system("open " + quotedPath);
else
    [status, output] = system( ...
        "xdg-open " + quotedPath + " >/dev/null 2>&1");
end
if status ~= 0
    error("KSSOLV:UI:SystemOpen:Failed", ...
        "Unable to open '%s': %s", filePath, strip(string(output)));
end
end
