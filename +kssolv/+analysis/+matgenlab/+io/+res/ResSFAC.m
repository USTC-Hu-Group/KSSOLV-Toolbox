classdef ResSFAC
    %RESSFAC Species declaration and atomic records in a RES file.

    properties (SetAccess = private)
        species (1,:) string = strings(1,0)
        ions cell = cell(1,0)
    end

    methods
        function obj = ResSFAC(species, ions)
            if nargin == 0, return; end
            obj.species = reshape(string(species), 1, []);
            if ~iscell(ions), ions = num2cell(ions); end
            if ~all(cellfun(@(item) isa(item, ...
                    "kssolv.analysis.matgenlab.io.res.Ion"), ions))
                error("KSSOLV:Matgenlab:Res:SFACIons", ...
                    "SFAC ions must be Ion objects.");
            end
            obj.ions = reshape(ions, 1, []);
        end

        function value = string(obj)
            fields = compose("%-2s", obj.species);
            header = "SFAC " + strjoin(fields, " ");
            if isempty(obj.ions)
                value = header + newline + "END" + newline;
                return
            end
            lines = cellfun(@string, obj.ions, "UniformOutput", false);
            value = header + newline + ...
                strjoin(string(lines), newline) + newline + ...
                "END" + newline;
        end

        function value = char(obj), value = char(string(obj)); end

        function value = as_dict(obj)
            records = cellfun(@(item) item.as_dict(), obj.ions, ...
                "UniformOutput", false);
            value = struct("species", obj.species, "ions", {records});
        end
    end

    methods (Static)
        function obj = from_dict(value)
            raw = value.ions;
            if isstruct(raw), raw = num2cell(raw); end
            ions = cellfun(@(item) ...
                kssolv.analysis.matgenlab.io.res.Ion.from_dict(item), ...
                raw, "UniformOutput", false);
            obj = kssolv.analysis.matgenlab.io.res.ResSFAC( ...
                value.species, ions);
        end
    end
end
