classdef CSMInfiniteRatioFunction < kssolv.analysis.matgenlab.analysis.chemenv.utils.AbstractRatioFunction
    %CSMINFINITERATIOFUNCTION Infinite continuous-symmetry ratio functions.
    methods
        function obj=CSMInfiniteRatioFunction(varargin)
            obj@kssolv.analysis.matgenlab.analysis.chemenv.utils. ...
                AbstractRatioFunction(varargin{:});
        end
        function value=power2_inverse_decreasing(obj,input)
            value=kssolv.analysis.matgenlab.analysis.chemenv.utils. ...
                power2_inverse_decreasing(input,"edges",[0,obj.options.max_csm]);
        end
        function value=power2_inverse_power2_decreasing(obj,input)
            value=kssolv.analysis.matgenlab.analysis.chemenv.utils. ...
                power2_inverse_power2_decreasing(input,"edges", ...
                [0,obj.options.max_csm]);
        end
        function value=fractions(obj,data)
            if isempty(data),value=[];return,end
            zeros_=abs(data)<1e-10;
            if nnz(zeros_)==1
                value=zeros(size(data));value(zeros_)=1;return
            elseif nnz(zeros_)>1
                error("KSSOLV:Matgenlab:ChemEnv:ZeroCSM", ...
                    "More than one continuous symmetry measure equals zero.");
            end
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
            value=struct(power2_inverse_decreasing={{"max_csm"}}, ...
                power2_inverse_power2_decreasing={{"max_csm"}});
        end
    end
end
