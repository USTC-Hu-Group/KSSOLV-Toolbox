classdef PerturbStructureTransformation < ...
        kssolv.analysis.matgenlab.transformations.AbstractTransformation
    properties (SetAccess=private)
        distance (1,1) double
        min_distance
    end
    methods
        function obj=PerturbStructureTransformation(distance,minDistance)
            if nargin<1,distance=.01;end
            if nargin<2,minDistance=[];end
            obj.distance=distance;obj.min_distance=minDistance;
        end
        function result=apply_transformation(obj,structure,varargin)
            result=structure.copy();
            minimum=obj.min_distance;
            if isempty(minimum),minimum=obj.distance;end
            result=result.perturb(obj.distance,minimum);
        end
    end
    methods (Static)
        function obj=from_dict(value)
            obj=kssolv.analysis.matgenlab.transformations. ...
                PerturbStructureTransformation(value.distance, ...
                value.min_distance);
        end
        function obj=fromDict(value),obj= ...
                kssolv.analysis.matgenlab.transformations. ...
                PerturbStructureTransformation.from_dict(value);end
    end
end
