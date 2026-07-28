classdef ChargeBalanceFilter < ...
        kssolv.analysis.matgenlab.alchemy.AbstractStructureFilter
    %CHARGEBALANCEFILTER Retain structures with zero net charge.

    methods
        function accepted = test(~, structure)
            accepted = abs(structure.charge) <= 1e-9;
        end

        function value = asDict(~)
            value = struct( ...
                "x_module", "pymatgen.alchemy.filters", ...
                "x_class", "ChargeBalanceFilter", "x_version", []);
        end
    end

    methods (Static)
        function obj = from_dict(~)
            obj = kssolv.analysis.matgenlab.alchemy.ChargeBalanceFilter();
        end

        function obj = fromDict(value)
            obj = kssolv.analysis.matgenlab.alchemy. ...
                ChargeBalanceFilter.from_dict(value);
        end
    end
end
