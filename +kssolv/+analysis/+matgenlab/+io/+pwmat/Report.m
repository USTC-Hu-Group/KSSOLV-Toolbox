classdef Report < kssolv.analysis.matgenlab.util.MSONable
    %REPORT Parser for PWmat REPORT band and k-point data.

    properties (SetAccess = private)
        filename (1,1) string
    end

    properties (Access = private)
        spinValue (1,1) double
        numKpoints (1,1) double
        numBands (1,1) double
        eigenvalueData double
        kpointData double
        kpointWeightData double
        hspData
    end

    properties (Dependent, SetAccess = private)
        spin
        n_kpoints
        n_bands
        eigenvalues
        kpoints
        kpoints_weight
        hsps
    end

    methods
        function obj = Report(filename)
            obj.filename = string(filename);
            text = ...
                kssolv.analysis.matgenlab.io.pwmat.PWmatIOUtils. ...
                read_text(filename);
            lines = splitlines(text);
            obj.spinValue = scalarAfter(lines, "SPIN");
            obj.numKpoints = scalarAfter(lines, "NUM_KPT");
            obj.numBands = scalarAfter(lines, "NUM_BAND");
            obj.eigenvalueData = obj.parseEigen(lines);
            [obj.kpointData, obj.kpointWeightData, obj.hspData] = ...
                obj.parseKpoints(lines);
        end

        function value = get.spin(obj), value = obj.spinValue; end
        function value = get.n_kpoints(obj), value = obj.numKpoints; end
        function value = get.n_bands(obj), value = obj.numBands; end
        function value = get.eigenvalues(obj), value = obj.eigenvalueData; end
        function value = get.kpoints(obj), value = obj.kpointData; end
        function value = get.kpoints_weight(obj)
            value = obj.kpointWeightData;
        end
        function value = get.hsps(obj), value = obj.hspData; end

        function value = asDict(obj)
            value = struct("x_module", "pymatgen.io.pwmat.outputs", ...
                "x_class", "Report", "filename", obj.filename);
        end
    end

    methods (Access = private)
        function values = parseEigen(obj, lines)
            rows = ...
                kssolv.analysis.matgenlab.io.pwmat.ListLocator. ...
                locate_all_lines(lines, "eigen energies, in eV") + 1;
            expected = obj.spinValue * obj.numKpoints;
            if numel(rows) ~= expected
                error("KSSOLV:Matgenlab:PWmat:ReportEigenSections", ...
                    "REPORT has %d eigen sections; expected %d.", ...
                    numel(rows), expected);
            end
            lineCount = ceil(obj.numBands / 5);
            values = zeros(obj.spinValue, obj.numKpoints, obj.numBands);
            for spinIndex = 1:obj.spinValue
                for kpointIndex = 1:obj.numKpoints
                    location = rows((spinIndex - 1) * ...
                        obj.numKpoints + kpointIndex);
                    text = strjoin(lines( ...
                        location + 1:location + lineCount), " ");
                    parsed = sscanf(char(text), "%f").';
                    if numel(parsed) < obj.numBands
                        error("KSSOLV:Matgenlab:PWmat:ReportEigenvalues", ...
                            "An eigen section has fewer than %d values.", ...
                            obj.numBands);
                    end
                    values(spinIndex, kpointIndex, :) = ...
                        parsed(1:obj.numBands);
                end
            end
        end

        function [points, weights, labels] = parseKpoints(obj, lines)
            rows = ...
                kssolv.analysis.matgenlab.io.pwmat.ListLocator. ...
                locate_all_lines(lines, "total number of K-point:") + 1;
            if isempty(rows)
                error("KSSOLV:Matgenlab:PWmat:ReportKpoints", ...
                    "REPORT has no k-point table.");
            end
            start = rows(1);
            points = zeros(obj.numKpoints, 3);
            weights = zeros(1, obj.numKpoints);
            labels = containers.Map( ...
                "KeyType", "char", "ValueType", "any");
            for index = 1:obj.numKpoints
                fields = regexp(strtrim(char(lines(start + index))), ...
                    '\s+', "split");
                if numel(fields) < 4
                    error("KSSOLV:Matgenlab:PWmat:ReportKpoints", ...
                        "A k-point row has fewer than four fields.");
                end
                points(index, :) = cellfun(@str2double, fields(1:3));
                weights(index) = str2double(fields{4});
                if any(isnan(points(index, :))) || isnan(weights(index))
                    error("KSSOLV:Matgenlab:PWmat:ReportKpoints", ...
                        "A k-point row contains nonnumeric data.");
                end
                if numel(fields) == 5
                    labels(fields{5}) = points(index, :);
                end
            end
        end
    end

    methods (Static)
        function obj = from_dict(value)
            obj = kssolv.analysis.matgenlab.io.pwmat.Report( ...
                value.filename);
        end

        function obj = fromDict(value)
            obj = kssolv.analysis.matgenlab.io.pwmat.Report. ...
                from_dict(value);
        end
    end
end

function value = scalarAfter(lines, content)
locations = ...
    kssolv.analysis.matgenlab.io.pwmat.ListLocator. ...
    locate_all_lines(lines, content) + 1;
if isempty(locations)
    error("KSSOLV:Matgenlab:PWmat:ReportHeader", ...
        "REPORT does not contain '%s'.", content);
end
fields = regexp(strtrim(char(lines(locations(1)))), '\s+', "split");
value = str2double(fields{end});
if isnan(value)
    error("KSSOLV:Matgenlab:PWmat:ReportHeader", ...
        "REPORT '%s' value is not numeric.", content);
end
end
