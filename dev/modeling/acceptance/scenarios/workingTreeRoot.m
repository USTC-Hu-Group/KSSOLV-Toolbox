function root = workingTreeRoot()
%WORKINGTREEROOT Resolve and enforce the acceptance-test source tree.
%
% Interactive MATLAB sessions often have a released KSSOLV Add-On earlier
% on the path.  Acceptance must never silently test that installed copy.

scenarioDirectory = fileparts(mfilename("fullpath"));
root = fileparts(fileparts(fileparts(fileparts(scenarioDirectory))));
addpath(root, "-begin");
rehash path
expected = string(fullfile(root, "KSSOLV_Toolbox.m"));
resolved = string(which("KSSOLV_Toolbox"));
if resolved ~= expected
    error("KSSOLV:Modeling:AcceptanceSourceMismatch", ...
        "Acceptance resolved KSSOLV_Toolbox from '%s', not the working " + ...
        "tree '%s'. Close KSSOLV, run 'clear classes', and retry.", ...
        resolved, expected);
end
end
