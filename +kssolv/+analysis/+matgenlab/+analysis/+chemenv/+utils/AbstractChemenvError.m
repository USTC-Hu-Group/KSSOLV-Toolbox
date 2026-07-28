classdef AbstractChemenvError
    %ABSTRACTCHEMENVERROR Serializable ChemEnv error description.
    properties
        cls (1,1) string=""
        method (1,1) string=""
        msg (1,1) string=""
    end
    methods
        function obj=AbstractChemenvError(cls,method,msg)
            if nargin>0,obj.cls=string(cls);obj.method=string(method); ...
                    obj.msg=string(msg);end
        end
        function value=char(obj)
            value=char(obj.cls+": "+obj.method+newline+"'"+obj.msg+"'");
        end
        function value=string(obj),value=string(char(obj));end
    end
end
