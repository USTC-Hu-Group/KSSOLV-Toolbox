classdef DiffractionPattern < kssolv.analysis.matgenlab.core.Spectrum
    %DIFFRACTIONPATTERN Powder diffraction peaks and Miller-index families.

    properties
        hkls cell
        d_hkls double
    end

    methods
        function obj = DiffractionPattern(x, y, hkls, d_hkls)
            if nargin == 0
                x = zeros(0, 1);
                y = zeros(0, 1);
                hkls = cell(0, 1);
                d_hkls = zeros(0, 1);
            end
            obj@kssolv.analysis.matgenlab.core.Spectrum( ...
                x, y, hkls, d_hkls);
            obj.hkls = reshape(hkls, [], 1);
            obj.d_hkls = reshape(double(d_hkls), [], 1);
            if numel(obj.hkls) ~= numel(obj.x) || ...
                    numel(obj.d_hkls) ~= numel(obj.x)
                error("KSSOLV:Matgenlab:DiffractionPattern:Length", ...
                    "x, y, hkls, and d_hkls must have equal lengths.");
            end
        end

        function value = as_dict(obj)
            value = struct( ...
                "x_module", "pymatgen.analysis.diffraction.core", ...
                "x_class", "DiffractionPattern", ...
                "x", obj.x, ...
                "y", obj.y, ...
                "hkls", {obj.hkls}, ...
                "d_hkls", obj.d_hkls);
        end

        function value = asDict(obj)
            value = obj.as_dict();
        end

        function result = copy(obj)
            result = kssolv.analysis.matgenlab.analysis. ...
                DiffractionPattern(obj.x, obj.y, obj.hkls, obj.d_hkls);
        end
    end

    methods (Static)
        function obj = from_dict(value)
            obj = kssolv.analysis.matgenlab.analysis.DiffractionPattern( ...
                value.x, value.y, value.hkls, value.d_hkls);
        end
    end

    methods (Access = protected)
        function result = construct(obj, x, y)
            result = kssolv.analysis.matgenlab.analysis. ...
                DiffractionPattern(x, y, obj.hkls, obj.d_hkls);
        end
    end
end
