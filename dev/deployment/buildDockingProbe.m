function buildDockingProbe(outputDirectory)
%BUILDDOCKINGPROBE Compile the isolated figure-document regression probe.
arguments
    outputDirectory (1,1) string
end
probeDirectory = fileparts(mfilename('fullpath'));
toolboxDirectory = fileparts(fileparts(probeDirectory));
addpath(toolboxDirectory);
options = compiler.build.StandaloneApplicationOptions( ...
    fullfile(probeDirectory, 'dockingProbe.m'));
options.OutputDir = outputDirectory;
options.ExecutableName = 'dockingProbe';
options.TreatInputsAsNumeric = false;
options.ObfuscateArchive = false;
if ispc
    compiler.build.standaloneWindowsApplication(options);
else
    compiler.build.standaloneApplication(options);
end
end
