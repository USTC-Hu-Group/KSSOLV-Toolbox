classdef AutoOxiStateDecorationTransformation < ...
        kssolv.analysis.matgenlab.transformations.AbstractTransformation
    properties (SetAccess = private)
        symm_tol (1,1) double
        max_radius (1,1) double
        max_permutations (1,1) double
        distance_scale_factor (1,1) double
        zeros_on_fail (1,1) logical
    end
    methods
        function obj = AutoOxiStateDecorationTransformation( ...
                symmTol, maxRadius, maxPermutations, ...
                distanceScaleFactor, zerosOnFail)
            if nargin < 1, symmTol = 0.1; end
            if nargin < 2, maxRadius = 4; end
            if nargin < 3, maxPermutations = 100000; end
            if nargin < 4, distanceScaleFactor = 1.015; end
            if nargin < 5, zerosOnFail = false; end
            obj.symm_tol = symmTol;
            obj.max_radius = maxRadius;
            obj.max_permutations = maxPermutations;
            obj.distance_scale_factor = distanceScaleFactor;
            obj.zeros_on_fail = logical(zerosOnFail);
        end
        function result = apply_transformation(obj, structure, varargin)
            analyzer = kssolv.analysis.matgenlab.core.BVAnalyzer( ...
                obj.symm_tol, obj.max_radius, obj.max_permutations, ...
                obj.distance_scale_factor);
            try
                result = analyzer.get_oxi_state_decorated_structure(structure);
            catch exception
                if ~obj.zeros_on_fail
                    wrapped = MException( ...
                        "KSSOLV:Matgenlab:AutoOxiState:Failed", ...
                        "BVAnalyzer failed: %s", exception.message);
                    throw(wrapped);
                end
                result = structure.copy();
                result = result.add_oxidation_state_by_site( ...
                    zeros(1,result.num_sites));
            end
        end
    end
    methods (Static)
        function obj = from_dict(value)
            obj = kssolv.analysis.matgenlab.transformations. ...
                AutoOxiStateDecorationTransformation(value.symm_tol, ...
                value.max_radius, value.max_permutations, ...
                value.distance_scale_factor, value.zeros_on_fail);
        end
        function obj = fromDict(value), obj = ...
                kssolv.analysis.matgenlab.transformations. ...
                AutoOxiStateDecorationTransformation.from_dict(value); end
    end
end
