classdef MagneticDeformation
    %MAGNETICDEFORMATION Deformation associated with a magnetic transition.
    properties (SetAccess=immutable)
        deformation (1,1) double
        type (1,1) string
    end
    methods
        function obj=MagneticDeformation(deformation,type)
            obj.deformation=double(deformation);obj.type=string(type);
        end
    end
end
