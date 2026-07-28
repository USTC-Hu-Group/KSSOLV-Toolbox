classdef RadialSiteDistortionTransformation < ...
        kssolv.analysis.matgenlab.transformations.AbstractTransformation
    properties (SetAccess = private)
        site_index (1,1) double
        displacement (1,1) double
        nn_only (1,1) logical
    end
    methods
        function obj = RadialSiteDistortionTransformation( ...
                siteIndex, displacement, nnOnly)
            if nargin < 2, displacement = 0.1; end
            if nargin < 3, nnOnly = false; end
            obj.site_index = double(siteIndex);
            obj.displacement = double(displacement);
            obj.nn_only = logical(nnOnly);
        end
        function result = apply_transformation(obj, structure, varargin)
            kssolv.analysis.matgenlab.transformations.internal.Utils. ...
                validateIndices(obj.site_index, structure.num_sites);
            result = structure.copy();
            origin = structure(obj.site_index);
            isPeriodic=isa(structure, ...
                "kssolv.analysis.matgenlab.core.IStructure");
            if isPeriodic
                nearestInfo = ...
                    kssolv.analysis.matgenlab.core.MinimumDistanceNN(). ...
                    get_nn_info(structure, obj.site_index);
                if isempty(nearestInfo),return,end
                nearest=max(cellfun(@(item)item.site.nn_distance,nearestInfo));
            else
                distances=vecnorm(structure.cart_coords-origin.coords,2,2);
                positive=distances(distances>1e-12);
                if isempty(positive),return,end
                nearest=min(positive);
            end
            if obj.nn_only,cutoff=nearest*1.1;
            elseif isPeriodic
                matrix = structure.lattice.matrix;
                heights = zeros(1,3);
                heights(1) = abs(dot(matrix(1,:), ...
                    cross(matrix(2,:),matrix(3,:))) / ...
                    norm(cross(matrix(2,:),matrix(3,:))));
                heights(2) = abs(dot(matrix(2,:), ...
                    cross(matrix(1,:),matrix(3,:))) / ...
                    norm(cross(matrix(1,:),matrix(3,:))));
                heights(3) = abs(dot(matrix(3,:), ...
                    cross(matrix(1,:),matrix(2,:))) / ...
                    norm(cross(matrix(1,:),matrix(2,:))));
                cutoff = floor(min(heights) / 2);
            else
                cutoff=max(distances);
            end
            moved=false(1,structure.num_sites);
            if isPeriodic
                neighbors=structure.get_neighbors(origin,cutoff);
                count=numel(neighbors);
            else
                count=structure.num_sites;
            end
            for index=1:count
                if isPeriodic
                    neighbor=neighbors{index};
                    siteIndex=neighbor.index;
                    coordinates=neighbor.coords;
                else
                    siteIndex=index;
                    coordinates=structure(index).coords;
                    if siteIndex==obj.site_index|| ...
                            distances(siteIndex)>cutoff+1e-12
                        continue
                    end
                end
                if moved(siteIndex),continue,end
                vector=coordinates-origin.coords;
                distance = norm(vector);
                magnitude = obj.displacement * nearest / distance;
                if isPeriodic
                    result=result.translate_sites(siteIndex, ...
                        vector/distance*magnitude,frac_coords=false);
                else
                    result=result.translate_sites(siteIndex, ...
                        vector/distance*magnitude);
                end
                moved(siteIndex) = true;
            end
        end
    end
    methods (Static)
        function obj = from_dict(value)
            obj = kssolv.analysis.matgenlab.transformations. ...
                RadialSiteDistortionTransformation(value.site_index, ...
                value.displacement, value.nn_only);
        end
        function obj = fromDict(value), obj = ...
                kssolv.analysis.matgenlab.transformations. ...
                RadialSiteDistortionTransformation.from_dict(value); end
    end
end
