classdef OverwriteMagmomMode
    %OVERWRITEMAGMOMMODE Policies for replacing input magnetic moments.
    enumeration
        none (1)
        respect_sign (2)
        respect_zeros (3)
        replace_all (4)
        replace_all_if_undefined (5)
        normalize (6)
    end
    properties (SetAccess=immutable)
        code (1,1) double
    end
    methods
        function obj=OverwriteMagmomMode(code),obj.code=code;end
        function value=char(obj)
            names=["none","respect_sign","respect_zeros","replace_all", ...
                "replace_all_if_undefined","normalize"];
            value=char(names(obj.code));
        end
        function value=string(obj),value=string(char(obj));end
    end
end
