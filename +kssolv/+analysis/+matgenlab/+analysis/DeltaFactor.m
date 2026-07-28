classdef DeltaFactor < kssolv.analysis.matgenlab.analysis.PolynomialEOS
    methods
        function obj = fit(obj, order)
            if nargin < 2 || isempty(order), order = 3; end
            x = obj.volumes.^(-2/3);
            obj.eos_params = polyfit(x, obj.energies, order);
            d1 = polyder(obj.eos_params);
            d2 = polyder(d1);
            d3 = polyder(d2);
            roots1 = roots(d1);
            selected = [];
            for index = 1:numel(roots1)
                x0 = roots1(index);
                if isreal(x0) && x0 > 0 && polyval(d2,x0) > 0
                    selected = real(x0);
                    break
                end
            end
            if isempty(selected)
                throw(kssolv.analysis.matgenlab.analysis.EOSError( ...
                    "No minimum could be found."));
            end
            x0 = selected;
            v0 = x0^(-3/2);
            derivV2 = 4/9*x0^5*polyval(d2,x0);
            derivV3 = -20/9*x0^(13/2)*polyval(d2,x0) - ...
                8/27*x0^(15/2)*polyval(d3,x0);
            b0 = derivV2 / x0^(3/2);
            b1 = -1-v0*derivV3/derivV2;
            obj.params = [polyval(obj.eos_params,x0),b0,b1,v0];
        end
    end

    methods (Access = protected)
        function value = evaluate(~, volume, parameters)
            value = polyval(parameters, volume.^(-2/3));
        end
    end
end
