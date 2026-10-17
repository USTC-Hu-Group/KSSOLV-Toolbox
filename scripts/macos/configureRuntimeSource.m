function cleanup = configureRuntimeSource(delivery, metadata)
%CONFIGURERUNTIMESOURCE Select an offline compiler ZIP for this call only.
cleanup = onCleanup(@() []);
if delivery ~= "installer", return; end
override = string(getenv('MATLAB_RUNTIME_INSTALLER'));
if override == "" && ~isempty(mcrinstaller), return; end
if override == ""
    override = fullfile(getenv('HOME'), 'Library', 'Application Support', ...
        'MathWorks', 'MatlabRuntimeCache', "MCRInstaller" + string(metadata.RuntimeVersion), ...
        "MATLAB_Runtime_" + string(metadata.RuntimeRelease) + "_maca64.zip");
end
assert(isfile(override), 'KSSOLV:Packaging:MissingRuntimeSource', ...
    'Run compiler.runtime.download or set MATLAB_RUNTIME_INSTALLER to its matching ZIP.');
% The no-JVM downloader can leave this setting unregistered. Use only a
% temporary value and remove any group/setting introduced by this call.
root = settings;
createdGroup = ~hasGroup(root, 'matlabCompiler');
if createdGroup
    addGroup(root, 'matlabCompiler', Hidden=true);
    cleanup = onCleanup(@() removeGroup(root, 'matlabCompiler'));
end
group = root.matlabCompiler;
key = 'RuntimeInstaller_maca64';
createdSetting = ~hasSetting(group, key);
if createdSetting
    addSetting(group, key, Hidden=true);
    if ~createdGroup
        cleanup = onCleanup(@() removeSetting(group, key));
    end
end
setting = group.(key);
if ~createdGroup && ~createdSetting
    hadTemporary = hasTemporaryValue(setting);
    previous = [];
    if hadTemporary, previous = setting.TemporaryValue; end
    cleanup = onCleanup(@() restoreTemporary(setting, hadTemporary, previous));
end
setting.TemporaryValue = char(override);
assert(~isempty(mcrinstaller), 'KSSOLV:Packaging:InvalidRuntimeSource', ...
    'The official compiler rejected the specified Runtime installer ZIP.');
end

function restoreTemporary(setting, hadTemporary, previous)
if hadTemporary
    setting.TemporaryValue = previous;
elseif hasTemporaryValue(setting)
    clearTemporaryValue(setting);
end
end
