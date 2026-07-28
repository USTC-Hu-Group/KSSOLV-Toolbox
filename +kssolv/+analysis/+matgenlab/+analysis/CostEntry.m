classdef CostEntry < kssolv.analysis.matgenlab.analysis.PDEntry
    %COSTENTRY Phase-diagram entry carrying a cost-data citation.

    properties
        reference (1,1) string = ""
    end

    methods
        function obj = CostEntry(composition, cost, name, reference)
            if nargin == 0
                composition = kssolv.analysis.matgenlab.core.Composition();
                cost = 0;
                name = "";
                reference = "";
            elseif nargin < 4
                reference = "";
            end
            obj@kssolv.analysis.matgenlab.analysis.PDEntry( ...
                composition, cost, "name", name);
            reference = string(reference);
            if strlength(reference) > 0 && ...
                    ~kssolv.analysis.matgenlab.analysis.CostEntry. ...
                    isValidBibtex(reference)
                error("KSSOLV:Matgenlab:CostEntry:InvalidReference", ...
                    "Invalid format for cost reference; expected BibTeX.");
            end
            obj.reference = reference;
        end

        function text = char(obj)
            text = sprintf("CostEntry : %s with cost = %.4f", ...
                obj.formula, obj.energy);
        end

        function data = as_dict(obj)
            data = as_dict@kssolv.analysis.matgenlab.analysis.PDEntry(obj);
            data.x_module = "pymatgen.analysis.cost";
            data.x_class = "CostEntry";
            data.reference = obj.reference;
        end
    end

    methods (Static, Access = private)
        function valid = isValidBibtex(reference)
            reference = strip(reference);
            valid = ~isempty(regexp(char(reference), ...
                '^@\w+\s*\{\s*[^,]+,.*\}\s*$', "once"));
        end
    end
end
