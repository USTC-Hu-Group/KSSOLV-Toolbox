classdef Birch < kssolv.analysis.matgenlab.analysis.EOSBase
    methods (Access = protected)
        function value = evaluate(~, volume, parameters)
            e0=parameters(1); b0=parameters(2);
            b1=parameters(3); v0=parameters(4);
            strain = (v0./volume).^(2/3)-1;
            value = e0 + 9/8*b0*v0.*strain.^2 + ...
                9/16*b0*v0*(b1-4).*strain.^3;
        end
    end
end
