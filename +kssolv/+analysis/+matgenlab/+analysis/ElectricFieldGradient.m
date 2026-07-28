classdef ElectricFieldGradient < ...
        kssolv.analysis.matgenlab.core.SquareTensor
    %ELECTRICFIELDGRADIENT NMR electric-field-gradient tensor.

    properties (Dependent, SetAccess = private)
        principal_axis_system
        V_xx
        V_yy
        V_zz
        asymmetry
    end

    methods
        function obj = ElectricFieldGradient(input, vscale)
            if nargin < 2, vscale = []; end
            if isvector(input) && numel(input) == 3
                input = diag(double(input));
            end
            if ~isequal(size(input), [3,3])
                error("KSSOLV:Matgenlab:ElectricFieldGradient:InvalidShape", ...
                    "ElectricFieldGradient input must be length 3 or 3-by-3.");
            end
            obj@kssolv.analysis.matgenlab.core.SquareTensor(input, vscale);
        end

        function value = get.principal_axis_system(obj)
            value = kssolv.analysis.matgenlab.analysis. ...
                ElectricFieldGradient(diag(sort(eig(double(obj)))));
        end

        function value = get.V_xx(obj)
            diagonal = diag(double(obj.principal_axis_system));
            [~, order] = sort(abs(diagonal));
            value = diagonal(order(1));
        end

        function value = get.V_yy(obj)
            diagonal = diag(double(obj.principal_axis_system));
            [~, order] = sort(abs(diagonal));
            value = diagonal(order(2));
        end

        function value = get.V_zz(obj)
            diagonal = diag(double(obj.principal_axis_system));
            [~, order] = sort(abs(diagonal));
            value = diagonal(order(3));
        end

        function value = get.asymmetry(obj)
            value = abs((obj.V_yy - obj.V_xx) / obj.V_zz);
        end

        function value = coupling_constant(obj, specie)
            if isa(specie, "kssolv.analysis.matgenlab.core.Site") || ...
                    isa(specie, ...
                    "kssolv.analysis.matgenlab.core.PeriodicSite")
                specie = specie.specie;
            end
            isotope = "";
            if ischar(specie) || isstring(specie)
                text = string(specie);
                pieces = split(text, "-");
                specie = kssolv.analysis.matgenlab.core.Species(pieces(1));
                if numel(pieces) > 1, isotope = text; end
            elseif isa(specie, "kssolv.analysis.matgenlab.core.Element")
                specie = kssolv.analysis.matgenlab.core.Species(specie.symbol);
            end
            if ~isa(specie, "kssolv.analysis.matgenlab.core.Species")
                error("KSSOLV:Matgenlab:ElectricFieldGradient:InvalidSpecies", ...
                    "Invalid species for quadrupolar coupling.");
            end
            quadrupole = specie.get_nmr_quadrupole_moment(isotope);
            elementaryCharge = -1.60217662e-19;
            planck = 6.62607004e-34;
            couplingMHz = elementaryCharge * double(quadrupole) * ...
                obj.V_zz * 1e-17 / planck;
            value = kssolv.analysis.matgenlab.core.FloatWithUnit( ...
                couplingMHz, "MHz");
        end
    end
end
