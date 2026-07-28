classdef BirchMurnaghan < kssolv.analysis.matgenlab.analysis.EOSBase
    methods (Access = protected)
        function value = evaluate(~, volume, parameters)
            e0=parameters(1); b0=parameters(2);
            b1=parameters(3); v0=parameters(4);
            eta = (v0./volume).^(1/3);
            value = e0 + 9*b0*v0/16 .* (eta.^2-1).^2 .* ...
                (6+b1.*(eta.^2-1)-4*eta.^2);
        end
    end
end
