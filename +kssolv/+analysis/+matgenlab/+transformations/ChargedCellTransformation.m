classdef ChargedCellTransformation < ...
        kssolv.analysis.matgenlab.transformations.AbstractTransformation
    properties (SetAccess=private)
        charge (1,1) double
    end
    methods
        function obj=ChargedCellTransformation(charge)
            if nargin<1,charge=0;end
            obj.charge=charge;
        end
        function result=apply_transformation(obj,structure,varargin)
            result=structure.copy();result=result.set_charge(obj.charge);
        end
    end
    methods (Access=protected)
        function value=inverseTransformation(~)
            value=[]; %#ok<NASGU>
            error("KSSOLV:Matgenlab:ChargedCellTransformation:Inverse", ...
                "ChargedCellTransformation has no inverse.");
        end
    end
    methods (Static)
        function obj=from_dict(value)
            obj=kssolv.analysis.matgenlab.transformations. ...
                ChargedCellTransformation(value.charge);
        end
        function obj=fromDict(value),obj= ...
                kssolv.analysis.matgenlab.transformations. ...
                ChargedCellTransformation.from_dict(value);end
    end
end
