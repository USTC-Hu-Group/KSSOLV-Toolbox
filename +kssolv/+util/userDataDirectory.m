function folder = userDataDirectory()
%USERDATADIRECTORY Resolve persistent application data, including fresh Runtime.
% Keep the configured desktop location; Runtime may have no MATLAB userpath.
configured = string(getenv('KSSOLV_USER_DATA_DIR'));
if isKSSOLVOnline() && strlength(configured) > 0
    folder = char(configured);
    return
end
folders = strip(split(string(userpath), pathsep));
folders(strlength(folders) == 0) = [];
if isempty(folders)
    base = prefdir;
else
    base = char(folders(1));
end
folder = fullfile(base, 'KSSOLV_Toolbox');
end
