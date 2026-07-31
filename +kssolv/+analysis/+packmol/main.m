function result = main(args)
%MAIN Command-line-compatible -i/-o entry point.
arguments
    args (1,:) string
end
if numel(args) == 2 && args(1) == "-i"
    input = args(2);
    output = "";
elseif numel(args) == 4
    inputIndex = find(args == "-i", 1);
    outputIndex = find(args == "-o", 1);
    if isempty(inputIndex) || isempty(outputIndex) || ...
            inputIndex == numel(args) || outputIndex == numel(args)
        commandError();
    end
    input = args(inputIndex + 1);
    output = args(outputIndex + 1);
else
    commandError();
end
if input == output
    error("KSSOLV:Packmol:CommandLine", ...
        "Packmol expects different input and output files.");
end
result = kssolv.analysis.packmol.packmol( ...
    input, WorkingDirectory = pwd, Output = output);
end

function commandError()
error("KSSOLV:Packmol:CommandLine", ...
    "Usage: packmol -i input.inp [-o output.pdb]");
end
