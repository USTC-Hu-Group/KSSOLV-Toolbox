classdef EnergyTrend
    %ENERGYTREND Polynomial-spline diagnostics for a distortion path.
    properties
        energies
    end
    methods
        function obj=EnergyTrend(energies)
            obj.energies=reshape(double(energies),1,[]);
        end
        function coefficients=spline(obj)
            x=0:numel(obj.energies)-1;
            coefficients=polyfit(x,obj.energies,min(4,numel(x)-1));
        end
        function value=smoothness(obj)
            x=0:numel(obj.energies)-1;
            difference=polyval(obj.spline(),x)-obj.energies;
            value=sqrt(mean(difference.^2));
        end
        function value=max_spline_jump(obj)
            x=0:numel(obj.energies)-1;
            value=max(obj.energies-polyval(obj.spline(),x));
        end
        function result=endpoints_minima(obj,slopeCutoff)
            if nargin<2,slopeCutoff=5e-3;end
            derivative=polyder(obj.spline());
            values=polyval(derivative,[0,numel(obj.energies)-1]);
            result=struct("polar",abs(values(2))<=slopeCutoff, ...
                "nonpolar",abs(values(1))<=slopeCutoff);
        end
    end
end
