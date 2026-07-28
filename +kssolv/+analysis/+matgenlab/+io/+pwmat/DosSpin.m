classdef DosSpin < kssolv.analysis.matgenlab.util.MSONable
    %DOSSPIN Parser for PWmat DOS.* and projected DOS files.

    properties (SetAccess = private)
        filename (1,1) string
    end

    properties (Access = private)
        labelData (1,:) string
        dosData double
    end

    properties (Dependent, SetAccess = private)
        labels
        dos
    end

    methods
        function obj = DosSpin(filename)
            obj.filename = string(filename);
            text = ...
                kssolv.analysis.matgenlab.io.pwmat.PWmatIOUtils. ...
                read_text(filename);
            lines = splitlines(text);
            header = regexp(strtrim(char(lines(1))), '\s+', "split");
            if numel(header) < 2
                error("KSSOLV:Matgenlab:PWmat:DosHeader", ...
                    "DOS file has no labels.");
            end
            obj.labelData = string(header(2:end));
            rows = lines(2:end);
            rows(strlength(strtrim(rows)) == 0) = [];
            obj.dosData = zeros(numel(rows), numel(obj.labelData));
            for index = 1:numel(rows)
                values = sscanf(char(rows(index)), "%f").';
                if numel(values) ~= numel(obj.labelData)
                    error("KSSOLV:Matgenlab:PWmat:DosColumns", ...
                        "DOS row %d has %d columns; expected %d.", ...
                        index, numel(values), numel(obj.labelData));
                end
                obj.dosData(index, :) = values;
            end
        end

        function value = get.labels(obj), value = obj.labelData; end
        function value = get.dos(obj), value = obj.dosData; end

        function value = get_partial_dos(obj, part)
            index = find(upper(obj.labelData) == ...
                upper(string(part)), 1);
            if isempty(index)
                error("KSSOLV:Matgenlab:PWmat:PartialDos", ...
                    "'%s' is not a DOS label.", string(part));
            end
            value = obj.dosData(:, index);
        end

        function value = asDict(obj)
            value = struct("x_module", "pymatgen.io.pwmat.outputs", ...
                "x_class", "DosSpin", "filename", obj.filename);
        end
    end

    methods (Static)
        function obj = from_dict(value)
            obj = kssolv.analysis.matgenlab.io.pwmat.DosSpin( ...
                value.filename);
        end

        function obj = fromDict(value)
            obj = kssolv.analysis.matgenlab.io.pwmat.DosSpin. ...
                from_dict(value);
        end
    end
end
