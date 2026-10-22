function folder = preferenceDirectory(varargin)
%PREFERENCEDIRECTORY Resolve preferences and optional child path components.
% Preserve the desktop preference root and use persistent Online storage.
% This function only resolves paths; callers create directories as needed.
if isKSSOLVOnline()
    folder = kssolv.util.userDataDirectory();
else
    folder = fullfile(prefdir, 'KSSOLV');
end
if ~isempty(varargin)
    folder = fullfile(folder, varargin{:});
end
end
