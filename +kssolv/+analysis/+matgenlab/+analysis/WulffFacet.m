classdef WulffFacet
    %WULFFFACET Geometry and provenance for one symmetry-expanded plane.
    properties
        normal double
        e_surf (1,1) double
        normal_pt double
        dual_pt double
        index (1,1) double
        m_ind_orig (1,1) double
        miller double
        points cell = cell(1,0)
        outer_lines double = zeros(0,2)
    end
    methods
        function obj=WulffFacet(normal,eSurf,normalPoint,dualPoint, ...
                index,originalIndex,miller)
            obj.normal=reshape(double(normal),1,[]);
            obj.e_surf=double(eSurf);
            obj.normal_pt=reshape(double(normalPoint),1,[]);
            obj.dual_pt=reshape(double(dualPoint),1,[]);
            obj.index=double(index);
            obj.m_ind_orig=double(originalIndex);
            obj.miller=reshape(double(miller),1,[]);
        end
    end
end
