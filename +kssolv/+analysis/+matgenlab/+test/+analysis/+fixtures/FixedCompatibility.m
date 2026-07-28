classdef FixedCompatibility < kssolv.analysis.matgenlab.analysis.compatibility.Compatibility
    %FIXEDCOMPATIBILITY Test-only deterministic adjustment provider.
    properties
        adjustment_value (1,1) double = -10
        adjustment_name (1,1) string = "Fixed adjustment"
    end
    methods
        function obj=FixedCompatibility(value,name)
            if nargin>=1,obj.adjustment_value=value;end
            if nargin>=2,obj.adjustment_name=string(name);end
        end
        function values=get_adjustments(obj,~)
            values={kssolv.analysis.matgenlab.core. ...
                ConstantEnergyAdjustment(obj.adjustment_value, ...
                "name",obj.adjustment_name)};
        end
    end
end
