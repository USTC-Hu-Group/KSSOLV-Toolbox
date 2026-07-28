classdef FiestaOutput
    %FIESTAOUTPUT Parser for FIESTA GW output logs.

    properties (SetAccess = private)
        filename (1,1) string
        data cell
    end

    methods
        function obj = FiestaOutput(filename)
            obj.filename = string(filename);
            text = kssolv.analysis.matgenlab.io.fiesta.FiestaIOUtils. ...
                read_text(filename);
            chunks = regexp(char(text), ...
                'GW Driver iteration', "split");
            chunks(1) = [];
            obj.data = cell(1, numel(chunks));
            for index = 1:numel(chunks)
                obj.data{index} = parseJob(chunks{index});
            end
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
        if contains(line, "Dumping eigen energies")
            parseTime = true;
            parseResults = false;
            continue
        end
        band = regexp(char(line), ...
            ['^<it.*\|\s+(\D+\d*)\s+\|\s+([-\d.]+)\s+' ...
            '([-\d.]+)\s+([-\d.]+)\s+\|\s+([-\d.]+)\s+' ...
            '([-\d.]+)\s+([-\d.]+)\s+\|\s+([-\d.]+)\s+' ...
            '([-\d.]+)\s+'], "tokens", "once");
        if ~isempty(band)
            label = strtrim(string(band{1}));
            results(char(label)) = struct("band", label, ...
                "eKS", string(band{2}), "eXX", string(band{3}), ...
                "eQP_old", string(band{4}), "z", string(band{5}), ...
                "sigma_c_Linear", string(band{6}), ...
                "eQP_Linear", string(band{7}), ...
                "sigma_c_SCF", string(band{8}), ...
                "eQP_SCF", string(band{9}));
        end
        gap = regexp(char(line), ...
            ['^<it.*\|\s+Egap_KS\s+=\s+([-\d.]+)\s+\|\s+' ...
            'Egap_QP\s+=\s+([-\d.]+)\s+\|\s+' ...
            'Egap_QP\s+=\s+([-\d.]+)\s+\|'], ...
            "tokens", "once");
        if ~isempty(gap)
            results("Gaps") = struct("Egap_KS", string(gap{1}), ...
                "Egap_QP_Linear", string(gap{2}), ...
                "Egap_QP_SCF", string(gap{3}));
        end
    end

    if contains(line, "GW Results"), parseResults = true; end
end
end
