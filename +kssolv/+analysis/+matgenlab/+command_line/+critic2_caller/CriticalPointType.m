classdef CriticalPointType
    %CRITICALPOINTTYPE Topological class of a Critic2 critical point.

    enumeration
        nucleus (1)
        bond (2)
        ring (3)
        cage (4)
        nnattr (5)
    end

    properties (SetAccess = immutable)
        code (1,1) double
    end

    methods
        function obj = CriticalPointType(code)
            obj.code = code;
        end

        function value = char(obj)
            names = ["nucleus", "bond", "ring", "cage", "nnattr"];
            value = char(names(obj.code));
        end

        function value = string(obj)
            value = string(char(obj));
        end

        function value = double(obj)
            value = obj.code;
        end
    end

    methods (Static)
        function value = from_value(input)
            name = lower(string(input));
            switch name
                case "nucleus"
                    value = kssolv.analysis.matgenlab.command_line. ...
                        critic2_caller.CriticalPointType.nucleus;
                case "bond"
                    value = kssolv.analysis.matgenlab.command_line. ...
                        critic2_caller.CriticalPointType.bond;
                case "ring"
                    value = kssolv.analysis.matgenlab.command_line. ...
                        critic2_caller.CriticalPointType.ring;
                case "cage"
                    value = kssolv.analysis.matgenlab.command_line. ...
                        critic2_caller.CriticalPointType.cage;
                case "nnattr"
                    value = kssolv.analysis.matgenlab.command_line. ...
                        critic2_caller.CriticalPointType.nnattr;
                otherwise
                    error("KSSOLV:Matgenlab:Critic2:CriticalPointType", ...
                        "Unknown critical-point type '%s'.", name);
            end
        end
    end
end
