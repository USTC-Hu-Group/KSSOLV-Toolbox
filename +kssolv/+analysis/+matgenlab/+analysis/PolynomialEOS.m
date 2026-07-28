classdef PolynomialEOS < kssolv.analysis.matgenlab.analysis.EOSBase
    methods
        function obj = fit(obj, order)
            if nargin < 2 || isempty(order)
                error("KSSOLV:Matgenlab:EOS:MissingPolynomialOrder", ...
                    "PolynomialEOS.fit requires an order.");
            end
            obj.eos_params = polyfit(obj.volumes, obj.energies, order);
            obj = obj.setPolynomialParams();
        end
    end

    methods (Access = protected)
        function value = evaluate(~, volume, parameters)
            value = polyval(parameters, volume);
        end

        function obj = setPolynomialParams(obj)
            derivative = polyder(obj.eos_params);
            candidates = roots(derivative);
            candidates = real(candidates(abs(imag(candidates)) < 1e-9));
            second = polyder(derivative);
            candidates = candidates(polyval(second,candidates) > 0);
            if isempty(candidates)
                throw(kssolv.analysis.matgenlab.analysis.EOSError( ...
                    "No minimum could be found."));
            end
            [~, index] = min(abs(candidates - ...
                obj.volumes(obj.energies == min(obj.energies))));
            v0 = candidates(index);
            e0 = polyval(obj.eos_params, v0);
            third = polyder(second);
            b0 = v0 * polyval(second, v0);
            db0dv = polyval(second,v0) + v0*polyval(third,v0);
            b1 = -v0 * db0dv / b0;
            obj.params = [e0,b0,b1,v0];
        end
    end
end
