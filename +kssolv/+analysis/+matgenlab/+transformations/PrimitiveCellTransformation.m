classdef PrimitiveCellTransformation < ...
        kssolv.analysis.matgenlab.transformations.AbstractTransformation
    properties (SetAccess=private)
        tolerance (1,1) double
    end
    methods
        function obj=PrimitiveCellTransformation(tolerance)
            if nargin<1,tolerance=.5;end
            obj.tolerance=tolerance;
        end
        function result=apply_transformation(obj,structure,varargin)
            result=structure.get_primitive_structure(obj.tolerance);
        end
    end
    methods (Static)
        function obj=from_dict(value)
            obj=kssolv.analysis.matgenlab.transformations. ...
                PrimitiveCellTransformation(value.tolerance);
        end
        function obj=fromDict(value),obj= ...
                kssolv.analysis.matgenlab.transformations. ...
                PrimitiveCellTransformation.from_dict(value);end
    end
end
