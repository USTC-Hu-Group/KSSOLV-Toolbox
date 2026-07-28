classdef CSMFiniteRatioFunction < kssolv.analysis.matgenlab.analysis.chemenv.utils.AbstractRatioFunction
    %CSMFINITERATIOFUNCTION Finite continuous-symmetry ratio functions.
    methods
        function obj=CSMFiniteRatioFunction(varargin)
            obj@kssolv.analysis.matgenlab.analysis.chemenv.utils. ...
                AbstractRatioFunction(varargin{:});
        end
        function value=power2_decreasing_exp(obj,input)
            value=kssolv.analysis.matgenlab.analysis.chemenv.utils. ...
                power2_decreasing_exp(input,"edges",[0,obj.options.max_csm], ...
                "alpha",obj.options.alpha);
        end
        function value=smootherstep(obj,input)
            value=kssolv.analysis.matgenlab.analysis.chemenv.utils. ...
                smootherstep(input,"edges",[obj.options.lower_csm, ...
                obj.options.upper_csm],"inverse",true);
        end
        function value=smoothstep(obj,input)
            % Frozen upstream intentionally delegates this spelling to smootherstep.
            value=obj.smootherstep(input);
        end
        function value=fractions(obj,data)
            if isempty(data),value=[];return,end
            weights=obj.evaluate(data);total=sum(weights);
            if total>0,value=weights/total;else,value=[];end
        end
        function value=ratios(obj,data),value=obj.fractions(data);end
        function value=mean_estimator(obj,data)
            if isempty(data),value=[];return,end
            if isscalar(data),value=data;return,end
            fractions_=obj.fractions(data);
            if isempty(fractions_),value=[];else,value=sum(fractions_.*data);end
        end
    end
    methods (Access=protected)
        function value=allowed_functions(~)
            value=struct(power2_decreasing_exp={{"max_csm","alpha"}}, ...
                smoothstep={{"lower_csm","upper_csm"}}, ...
                smootherstep={{"lower_csm","upper_csm"}});
        end
    end
end
