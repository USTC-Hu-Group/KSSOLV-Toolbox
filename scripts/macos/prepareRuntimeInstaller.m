function prepareRuntimeInstaller(delivery, outputDirectory)
%PREPARERUNTIMEINSTALLER Package an official Runtime-only installer, without mcc.
arguments
    delivery (1,1) string {mustBeMember(delivery,["web","installer"])}
    outputDirectory (1,1) string = ""
end
root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
buildDirectory = fullfile(root, '.buildtool', 'standalone', 'build');
metadataFile = fullfile(buildDirectory, 'runtime-metadata.json');
dependencies = fullfile(buildDirectory, 'buildresult.json');
metadata = jsondecode(fileread(metadataFile));
assert(ismac && computer('arch') == "maca64", 'KSSOLV:Packaging:Platform', ...
    'macOS Apple silicon is required.');
assert(string(metadata.RuntimeRelease) == "R" + version('-release') && ...
    string(metadata.Architecture) == "maca64" && ~metadata.JVMEnabled, ...
    'KSSOLV:Packaging:Metadata', 'Runtime metadata does not match this no-JVM build.');
if outputDirectory == ""
    outputDirectory = fullfile(buildDirectory, 'runtime-installers', delivery);
end
if ~isfolder(outputDirectory), mkdir(outputDirectory); end
name = "KSSOLV_Runtime_" + string(metadata.RuntimeRelease);
installer = fullfile(outputDirectory, name + ".app");
manifestFile = fullfile(outputDirectory, 'runtime-installer.json');
if isfolder(installer), rmdir(installer, 's'); end
if isfile(manifestFile), delete(manifestFile); end
runtimeLocationCleanup = configureRuntimeSource(delivery, metadata);
compiler.runtime.customInstaller(name, dependencies, OutputDir=outputDirectory, ...
    RuntimeDelivery=delivery, OptionalDependencies="all");
delete(runtimeLocationCleanup)
assert(isfolder(installer), 'KSSOLV:Packaging:MissingRuntimeInstaller', ...
    'The official Runtime-only installer was not created: %s', installer);
quote = @(text) "'" + replace(string(text), "'", "'" + char(34) + "'" + char(34) + "'") + "'";
[status, hashText] = system("/usr/bin/shasum -a 256 " + quote(dependencies));
assert(status == 0, 'KSSOLV:Packaging:Hash', 'Cannot hash buildresult.json.');
buildHash = extractBefore(strtrim(string(hashText)), " ");
manifest = struct('RuntimeDelivery', delivery, 'RuntimeRelease', string(metadata.RuntimeRelease), ...
    'RuntimeVersion', string(metadata.RuntimeVersion), 'Architecture', "maca64", ...
    'RuntimeBuildVersion', string(regexp(version, '^\d+\.\d+\.\d+\.\d+', 'match', 'once')), ...
    'BuildResultSHA256', buildHash, 'Installer', name + ".app");
writelines(jsonencode(manifest), manifestFile, Encoding="UTF-8");
fprintf('KSSOLV_RUNTIME_INSTALLER_READY %s %s\n', delivery, installer);
end
