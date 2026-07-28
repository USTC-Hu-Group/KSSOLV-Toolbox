classdef DeformStructureTransformation < ...
        kssolv.analysis.matgenlab.transformations.AbstractTransformation
    properties (SetAccess=private)
        deformation (3,3) double
    end
    methods
        function obj=DeformStructureTransformation(deformation)
            if nargin<1,deformation=eye(3);end
            obj.deformation=double(deformation);
            kssolv.analysis.matgenlab.core.Deformation(obj.deformation);
        end
        function result=apply_transformation(obj,structure,varargin)
            deformation_=kssolv.analysis.matgenlab.core. ...
                Deformation(obj.deformation);
            result=deformation_.apply_to_structure(structure);
        end
    end
    methods (Access=protected)
        function value=inverseTransformation(obj)
            value=kssolv.analysis.matgenlab.transformations. ...
                DeformStructureTransformation(inv(obj.deformation));
        end
    end
    methods (Static)
        function obj=from_dict(value)
            obj=kssolv.analysis.matgenlab.transformations. ...
                DeformStructureTransformation(value.deformation);
        end
        function obj=fromDict(value),obj= ...
                kssolv.analysis.matgenlab.transformations. ...
                DeformStructureTransformation.from_dict(value);end
    end
end
