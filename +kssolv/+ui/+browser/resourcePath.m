function path = resourcePath(name)
%RESOURCEPATH Resolve a browser asset from the packaged UI resources directory.
arguments
    name (1,1) string
end
path = fullfile(KSSOLV_Toolbox.UIResourcesDirectory, 'browser', name);
if ~isfile(path)
    error('KSSOLV:Browser:MissingResource', ...
        'The browser resource is missing: %s', name);
end
end
