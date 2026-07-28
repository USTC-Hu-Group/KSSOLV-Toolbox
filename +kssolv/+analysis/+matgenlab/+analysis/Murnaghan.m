classdef Murnaghan < kssolv.analysis.matgenlab.analysis.EOSBase
    methods (Access = protected)
        function value = evaluate(~, volume, parameters)
            e0=parameters(1); b0=parameters(2);
            b1=parameters(3); v0=parameters(4);
            value = e0 + b0.*volume./b1 .* ...
                (((v0./volume).^b1)./(b1-1)+1) - v0*b0/(b1-1);
        end
    end
end
