classdef ConnectedSite
    %CONNECTEDSITE Neighbor site plus image, index, weight and distance.
    properties (SetAccess=immutable)
        site
        jimage (1,3) double
        index (1,1) double
        weight
        dist (1,1) double
    end
    methods
        function obj=ConnectedSite(site,jimage,index,weight,dist)
            obj.site=site;obj.jimage=reshape(double(jimage),1,3);
            obj.index=index;obj.weight=weight;obj.dist=dist;
        end
    end
end
