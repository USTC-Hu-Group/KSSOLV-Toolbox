classdef ParseError
    %PARSEERROR Factory for standardized unexpected-format exceptions.
    properties
        message (1,1) string = "Unexpected input format."
    end
    methods
        function obj=ParseError(message)
            if nargin>0,obj.message=string(message);end
        end
        function exception=as_exception(obj)
            exception=MException("KSSOLV:Matgenlab:ParseError", ...
                "%s",obj.message);
        end
        function throw(obj),builtin("throw",obj.as_exception());end
    end
end
