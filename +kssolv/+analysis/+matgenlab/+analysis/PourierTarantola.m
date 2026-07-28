classdef PourierTarantola < kssolv.analysis.matgenlab.analysis.EOSBase
    methods (Access = protected)
        function value = evaluate(~, volume, parameters)
            e0=parameters(1); b0=parameters(2);
            b1=parameters(3); v0=parameters(4);
            squiggle = -3*log((volume./v0).^(1/3));
            value = e0 + b0*v0.*squiggle.^2/6 .* ...
                (3+squiggle.*(b1-2));
        end
    end
end
