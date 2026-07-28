classdef BSEOutput
    %BSEOUTPUT Parser for FIESTA BSE output logs.

    properties (SetAccess = private)
        filename (1,1) string
        exiton
    end

    methods
        function obj = BSEOutput(filename)
            obj.filename = string(filename);
            text = kssolv.analysis.matgenlab.io.fiesta.FiestaIOUtils. ...
                read_text(filename);
            obj.exiton = parseJob(text);
        end
    end
end

function results = parseJob(output)
results = containers.Map("KeyType", "char", "ValueType", "any");
parseResults = false;
parseTime = false;
lines = splitlines(string(output));
for index = 1:numel(lines)
    line = lines(index);
    if parseTime
        if ~isempty(regexp(char(line), ...
                '\s*program returned normally\s*', "once"))
            results("end_normally") = true;
        end
        time = regexp(char(line), ...
            '^\s*total\s+time:\s+([\d.]+).*$', "tokens", "once");
        if ~isempty(time), results("total_time") = string(time{1}); end
    end

    if parseResults
        if contains(line, ...
                "FULL BSE main valence -> conduction transitions weight:")
            parseTime = true;
            parseResults = false;
            continue
        end
        exiton = regexp(char(line), ...
            '^exiton\s+(\d+):\s+([\d.]+)\(\s+([-\d.]+)\)\s+\|.*', ...
            "tokens", "once");
        if ~isempty(exiton)
            results(char(string(exiton{1}))) = struct( ...
                "bse_eig", string(exiton{2}), ...
                "osc_strength", string(exiton{3}));
        end
    end

    if contains(line, ...
            "FULL BSE eig.(eV), osc. strength and dipoles:")
        parseResults = true;
    end
end
end
