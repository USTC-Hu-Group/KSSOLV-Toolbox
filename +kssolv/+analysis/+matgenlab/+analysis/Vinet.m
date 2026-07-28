classdef Vinet < kssolv.analysis.matgenlab.analysis.EOSBase
    methods (Access = protected)
        function value = evaluate(~, volume, parameters)
            e0=parameters(1); b0=parameters(2);
            b1=parameters(3); v0=parameters(4);
            eta = (volume./v0).^(1/3);
            value = e0 + 2*b0*v0/(b1-1)^2 .* ...
                (2-(5+3*b1.*(eta-1)-3*eta).* ...
                exp(-3*(b1-1).*(eta-1)/2));
        end
    end
end
