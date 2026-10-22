function imageName = buildRuntimeImage(buildResultFile, options)
%BUILDRUNTIMEIMAGE Generate/build a selective Runtime using MathWorks' API.
% Run MATLAB with -nojvm. Pass the buildresult.json from the application build.
% This builds the Runtime layer only; it does not compile the application.
arguments
    buildResultFile (1, 1) string {mustBeFile}
    options.ImageName (1, 1) string = "kssolv-runtime:local"
    options.DockerContext (1, 1) string = fullfile(pwd, "Release", "DockerRuntime")
    options.ExecuteDockerBuild (1, 1) logical = true
    options.IncludeGPU (1, 1) logical = false
    options.OptionalDependencies (1, 1) string {mustBeMember( ...
        options.OptionalDependencies, ["all", "none"])} = "none"
end

if usejava('jvm')
    error('KSSOLV:Deployment:JVMEnabled', 'Run this build with matlab -nojvm.');
end
if isMATLABReleaseOlderThan('R2025b')
    error('KSSOLV:Deployment:RuntimeRelease', ...
        'Use R2025b or newer for Runtime containers without a bundled JRE.');
end
manifest = jsondecode(fileread(buildResultFile));
if ~isfield(manifest, 'RuntimeDependencies') || isempty(manifest.RuntimeDependencies)
    error('KSSOLV:Deployment:RuntimeManifest', ...
        'The Compiler buildresult.json must contain RuntimeDependencies.');
end

gpuDependency = contains(upper(string({manifest.RuntimeDependencies.DisplayName})), "GPU");
optional = strcmpi(string({manifest.RuntimeDependencies.Optional}), "yes");
gpuDependency = gpuDependency & (~optional | options.OptionalDependencies == "all");
if ~options.IncludeGPU && any(gpuDependency)
    error('KSSOLV:Deployment:GPUDependency', ...
        ['CPU Runtime builds require a CPU application manifest. ' ...
         'Compile using scripts/docker/build_application.py, or explicitly set IncludeGPU=true.']);
end

origin = "unknown";
metadataFile = fullfile(fileparts(buildResultFile), 'runtime-metadata.json');
if isfile(metadataFile)
    metadata = jsondecode(fileread(metadataFile));
    if string(metadata.RuntimeRelease) ~= "R" + version('-release')
        error('KSSOLV:Deployment:RuntimeReleaseMismatch', ...
            'Use the same MATLAB release as the application build.');
    end
    if metadata.JVMEnabled
        error('KSSOLV:Deployment:JVMPayload', 'The application must be built with -nojvm.');
    end
    origin = string(metadata.Architecture);
end
if options.ExecuteDockerBuild && origin ~= "glnxa64"
    error('KSSOLV:Deployment:LinuxBuildRequired', ...
        ['Use the Linux application build and its runtime-metadata.json for the final Runtime image. ' ...
         'ExecuteDockerBuild=false can preview the official context from another platform.']);
end

fprintf('Runtime dependency manifest (unchanged): %s\n', buildResultFile);
fprintf('Application build architecture: %s\n', origin);
fprintf('Optional Runtime dependencies: %s\n', options.OptionalDependencies);
imageName = compiler.runtime.createDockerImage(buildResultFile, ...
    ImageName=options.ImageName, DockerContext=options.DockerContext, ...
    ExecuteDockerBuild=options.ExecuteDockerBuild, ...
    OptionalDependencies=options.OptionalDependencies, VerbosityLevel="verbose");

report = struct('RuntimeRelease', "R" + version('-release'), ...
    'MATLABVersion', string(version), 'ApplicationArchitecture', origin, ...
    'Manifest', buildResultFile, 'ImageName', string(imageName), ...
    'ExecuteDockerBuild', options.ExecuteDockerBuild, 'IncludeGPU', options.IncludeGPU, ...
    'OptionalDependencies', options.OptionalDependencies, ...
    'RuntimeDependencies', manifest.RuntimeDependencies, ...
    'JVMEnabled', false, 'ApplicationValidated', false);
writelines(jsonencode(report, PrettyPrint=true), ...
    fullfile(options.DockerContext, 'kssolv-runtime-build.json'));
end
