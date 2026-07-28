classdef Ordering
    %ORDERING Collinear magnetic ordering classification.
    enumeration
        FM (1)
        AFM (2)
        FiM (3)
        NM (4)
        Unknown (5)
    end
    properties (SetAccess=immutable)
        code (1,1) double
    end
    methods
        function obj=Ordering(code),obj.code=code;end
        function value=char(obj)
            names=["FM","AFM","FiM","NM","Unknown"];
            value=char(names(obj.code));
        end
        function value=string(obj),value=string(char(obj));end
    end
end
