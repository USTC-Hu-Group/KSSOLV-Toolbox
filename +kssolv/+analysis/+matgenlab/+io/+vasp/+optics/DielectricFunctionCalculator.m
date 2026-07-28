classdef DielectricFunctionCalculator < ...
        kssolv.analysis.matgenlab.util.MSONable
    %DIELECTRICFUNCTIONCALCULATOR Post-process VASP optical calculations.
    properties
        cder_real double = []
        cder_imag double = []
        eigs double = []
        kweights double = []
        nedos (1,1) double = 0
        deltae (1,1) double = 0
        ismear (1,1) double = 0
        sigma (1,1) double = 0
        efermi (1,1) double = 0
        cshift (1,1) double = 0
        ispin (1,1) double = 1
        volume (1,1) double = 0
    end
    properties (Dependent, SetAccess = private)
        cder
    end
    methods
        function obj = DielectricFunctionCalculator(cder_real, cder_imag, ...
                eigs, kweights, nedos, deltae, ismear, sigma, efermi, ...
                cshift, ispin, volume)
            if nargin == 0, return; end
            values = {cder_real, cder_imag, eigs, kweights, nedos, ...
                deltae, ismear, sigma, efermi, cshift, ispin, volume};
            names = {"cder_real", "cder_imag", "eigs", "kweights", ...
                "nedos", "deltae", "ismear", "sigma", "efermi", ...
                "cshift", "ispin", "volume"};
            for index = 1:numel(names)
                obj.(names{index}) = values{index};
            end
            if ~isequal(size(obj.cder_real), size(obj.cder_imag))
                error("KSSOLV:Matgenlab:Optics:CderShape", ...
                    "cder_real and cder_imag must have identical shapes.");
            end
        end

        function value = get.cder(obj)
            value = complex(obj.cder_real, obj.cder_imag);
        end

        function [egrid, epsilon] = get_epsilon(obj, idir, jdir, options)
            arguments
                obj
                idir (1,1) double {mustBeInteger,mustBeBetween(idir,1,3)}
                jdir (1,1) double {mustBeInteger,mustBeBetween(jdir,1,3)}
                options.efermi = []
                options.nedos = []
                options.deltae = []
                options.ismear = []
                options.sigma = []
                options.cshift = []
                options.mask = []
            end
            efermiValue = obj.defaultValue(options.efermi, obj.efermi);
            nedosValue = obj.defaultValue(options.nedos, obj.nedos);
            deltaeValue = obj.defaultValue(options.deltae, obj.deltae);
            ismearValue = obj.defaultValue(options.ismear, obj.ismear);
            sigmaValue = obj.defaultValue(options.sigma, obj.sigma);
            cshiftValue = obj.defaultValue(options.cshift, obj.cshift);
            [egrid, imaginary] = ...
                kssolv.analysis.matgenlab.io.vasp.optics.epsilon_imag( ...
                obj.cder, obj.eigs, obj.kweights, efermiValue, ...
                nedosValue, deltaeValue, ismearValue, sigmaValue, ...
                idir, jdir, options.mask);
            % VASP constant.inc: 4*pi*2*ryd2ev*au2ang.
            edeps = 180.95128167484904;
            input = imaginary .* edeps .* pi ./ obj.volume;
            epsilon = kssolv.analysis.matgenlab.io.vasp.optics. ...
                kramers_kronig(input, nedosValue, deltaeValue, cshiftValue);
            if idir == jdir, epsilon = epsilon + 1; end
        end

        function [xValue, yValue, labels] = ...
                plot_weighted_transition_data(obj, idir, jdir, options)
            arguments
                obj
                idir (1,1) double {mustBeInteger,mustBeBetween(idir,1,3)}
                jdir (1,1) double {mustBeInteger,mustBeBetween(jdir,1,3)}
                options.mask = []
                options.min_val (1,1) double = 0
            end
            if isempty(options.mask)
                cderm = obj.cder;
            else
                if ~isequal(size(options.mask), size(obj.cder))
                    error("KSSOLV:Matgenlab:Optics:MaskShape", ...
                        "mask and cder must have identical shapes.");
                end
                cderm = obj.cder .* options.mask;
            end
            nonzero = find(cderm);
            if isempty(nonzero)
                error("KSSOLV:Matgenlab:Optics:EmptyMask", ...
                    "No matrix elements found. Check the mask.");
            end
            [band0, band1, ~, ~, ~] = ind2sub(size(cderm), nonzero);
            normWeights = reshape(obj.kweights, 1, []) ./ ...
                sum(obj.kweights);
            shifted = obj.eigs - obj.efermi;
            rspin = 3 - size(cderm, 4);
            xValue = zeros(1, 0);
            yValue = zeros(1, 0);
            labels = strings(1, 0);
            for ib = min(band0):max(band0)
                for jb = min(band1):max(band1)
                    for ik = 1:size(cderm, 3)
                        for spin = 1:size(cderm, 4)
                            fermiI = kssolv.analysis.matgenlab.io.vasp. ...
                                optics.step_func(shifted(ib, ik, spin) / ...
                                obj.sigma, obj.ismear);
                            fermiJ = kssolv.analysis.matgenlab.io.vasp. ...
                                optics.step_func(shifted(jb, ik, spin) / ...
                                obj.sigma, obj.ismear);
                            weight = (fermiJ - fermiI) * rspin * ...
                                normWeights(ik);
                            product = cderm(ib, jb, ik, spin, idir) * ...
                                conj(cderm(ib, jb, ik, spin, jdir));
                            energy = obj.eigs(jb, ik, spin) - ...
                                obj.eigs(ib, ik, spin);
                            matrixElement = abs(product) * weight;
                            if matrixElement > options.min_val
                                xValue(end + 1) = energy; %#ok<AGROW>
                                yValue(end + 1) = matrixElement; %#ok<AGROW>
                                labels(end + 1) = sprintf( ...
                                    "s:%d, k:%d, %d -> %d (%.2f)", ...
                                    spin - 1, ik - 1, ib - 1, jb - 1, ...
                                    energy); %#ok<AGROW>
                            end
                        end
                    end
                end
            end
        end

        function value = as_dict(obj)
            value = struct("x_module", "pymatgen.io.vasp.optics", ...
                "x_class", "DielectricFunctionCalculator", ...
                "cder_real", obj.cder_real, "cder_imag", obj.cder_imag, ...
                "eigs", obj.eigs, "kweights", obj.kweights, ...
                "nedos", obj.nedos, "deltae", obj.deltae, ...
                "ismear", obj.ismear, "sigma", obj.sigma, ...
                "efermi", obj.efermi, "cshift", obj.cshift, ...
                "ispin", obj.ispin, "volume", obj.volume);
        end
        function value = asDict(obj), value = obj.as_dict(); end
    end
    methods (Static)
        function obj = from_vasp_objects(vrun, waveder)
            bands = vrun.eigenvalues;
            if isempty(bands)
                error("KSSOLV:Matgenlab:Optics:MissingEigenvalues", ...
                    "eigenvalues cannot be empty.");
            end
            ispin = vrun.parameters.get("ISPIN");
            spinNames = {"up", "down"};
            first = bands.(spinNames{1});
            eigs = zeros(size(first, 2), size(first, 1), ispin);
            for spin = 1:ispin
                data = bands.(spinNames{spin});
                eigs(:, :, spin) = squeeze(data(:, :, 1)).';
            end
            dielectric = vrun.dielectric;
            if isempty(vrun.efermi)
                error("KSSOLV:Matgenlab:Optics:MissingFermiLevel", ...
                    "efermi cannot be empty.");
            end
            if vrun.parameters.get("ISYM") ~= 0
                error("KSSOLV:Matgenlab:Optics:SymmetryNotImplemented", ...
                    "ISYM ~= 0 is not implemented yet.");
            end
            obj = kssolv.analysis.matgenlab.io.vasp.optics. ...
                DielectricFunctionCalculator( ...
                waveder.cder_real, waveder.cder_imag, eigs, ...
                vrun.actual_kpoints_weights, ...
                vrun.parameters.get("NEDOS"), dielectric{1}(2), ...
                vrun.parameters.get("ISMEAR"), ...
                vrun.parameters.get("SIGMA"), vrun.efermi, ...
                vrun.parameters.get("CSHIFT"), ispin, ...
                vrun.final_structure.volume);
        end

        function obj = from_directory(directory)
            directory = string(directory);
            vrun = kssolv.analysis.matgenlab.io.vasp.Vasprun( ...
                fullfile(directory, "vasprun.xml"));
            subversion = lower(string(vrun.generator.get( ...
                "subversion", "")));
            if contains(subversion, "gamma")
                types = ["float64", "float32"];
            else
                types = ["complex128", "complex64"];
            end
            waveder = [];
            lastError = [];
            for dataType = types
                try
                    waveder = kssolv.analysis.matgenlab.io.vasp. ...
                        Waveder.from_binary(fullfile(directory, ...
                        "WAVEDER"), dataType);
                    break
                catch exception
                    lastError = exception;
                end
            end
            if isempty(waveder)
                throwAsCaller(lastError);
            end
            obj = kssolv.analysis.matgenlab.io.vasp.optics. ...
                DielectricFunctionCalculator.from_vasp_objects( ...
                vrun, waveder);
        end
    end
    methods (Static, Access = private)
        function value = defaultValue(value, default)
            if isempty(value), value = default; end
        end
    end
end
