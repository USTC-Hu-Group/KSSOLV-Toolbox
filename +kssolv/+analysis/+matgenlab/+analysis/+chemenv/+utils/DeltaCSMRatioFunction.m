classdef DeltaCSMRatioFunction < kssolv.analysis.matgenlab.analysis.chemenv.utils.AbstractRatioFunction
    %DELTACSMRATIOFUNCTION Ratio function for differences of CSM values.
    methods
        function obj=DeltaCSMRatioFunction(varargin)
            obj@kssolv.analysis.matgenlab.analysis.chemenv.utils. ...
                AbstractRatioFunction(varargin{:});
        end
        function value=smootherstep(obj,input)
            value=kssolv.analysis.matgenlab.analysis.chemenv.utils. ...
                smootherstep(input,"edges",[obj.options.delta_csm_min, ...
                obj.options.delta_csm_max]);
        end
    end
    methods (Access=protected)
        function value=allowed_functions(~)
            value=struct(smootherstep={{"delta_csm_min","delta_csm_max"}});
        end
    end
end
