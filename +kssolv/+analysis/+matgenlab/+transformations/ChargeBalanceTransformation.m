classdef ChargeBalanceTransformation < ...
        kssolv.analysis.matgenlab.transformations.AbstractTransformation
    properties (SetAccess=private)
        charge_balance_sp (1,1) string
    end
    methods
        function obj=ChargeBalanceTransformation(species)
            obj.charge_balance_sp=string(species);
        end
        function result=apply_transformation(obj,structure)
            species=kssolv.analysis.matgenlab.core.getElSp( ...
                obj.charge_balance_sp);
            if ~isa(species,"kssolv.analysis.matgenlab.core.Species")|| ...
                    species.oxi_state==0
                amount=0;
            else
                amount=structure.charge/species.oxi_state;
            end
            present=structure.composition.amountOf(species);
            fraction=amount/present;
            if fraction<0
                error("KSSOLV:Matgenlab:ChargeBalance:Addition", ...
                    "Addition of species is not supported.");
            elseif fraction>1
                error("KSSOLV:Matgenlab:ChargeBalance:InsufficientSpecies", ...
                    "Charge balancing requires removing more species than present.");
            end
            replacement={species,1-fraction};
            transformation=kssolv.analysis.matgenlab.transformations. ...
                SubstitutionTransformation( ...
                {char(obj.charge_balance_sp),replacement});
            result=transformation.apply_transformation(structure);
        end
    end
    methods (Static)
        function obj=from_dict(value)
            obj=kssolv.analysis.matgenlab.transformations. ...
                ChargeBalanceTransformation(value.charge_balance_sp);
        end
        function obj=fromDict(value),obj= ...
                kssolv.analysis.matgenlab.transformations. ...
                ChargeBalanceTransformation.from_dict(value);end
    end
end
