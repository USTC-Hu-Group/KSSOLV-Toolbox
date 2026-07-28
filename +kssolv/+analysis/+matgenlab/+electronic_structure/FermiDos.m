classdef FermiDos < kssolv.analysis.matgenlab.electronic_structure.Dos
    %FERMIDOS Carrier concentrations and Fermi-level inversion from a DOS.

    properties (SetAccess = immutable)
        structure
        nelecs (1,1) double
        volume (1,1) double
        de (1,:) double
        idx_vbm (1,1) double
        idx_cbm (1,1) double
        idx_mid_gap (1,1) double
        idx_h_integration (1,1) double
        idx_e_integration (1,1) double
        tdos (1,:) double
    end

    properties (Constant)
        A_to_cm = 1e-8
    end

    methods
        function obj = FermiDos(dos, structure, nelecs, bandgap)
            if nargin < 2 || isempty(structure)
                if isprop(dos, "structure")
                    structure = dos.structure;
                else
                    error("KSSOLV:Matgenlab:FermiDos:MissingStructure", ...
                        "Structure object is not provided and not present in dos.");
                end
            end
            if nargin < 3 || isempty(nelecs)
                nelecs = structure.composition.total_electrons;
            end
            if nargin < 4
                bandgap = [];
            end
            obj@kssolv.analysis.matgenlab.electronic_structure.Dos( ...
                dos.efermi, dos.energies, dos.densities);
            obj.structure = structure;
            obj.nelecs = double(nelecs);
            obj.volume = structure.volume;
            energies = obj.energies;
            obj.de = [diff(energies), 0];
            [cbm, vbm] = obj.get_cbm_vbm();
            [~, obj.idx_vbm] = min(abs(energies - vbm));
            [~, obj.idx_cbm] = min(abs(energies - cbm));
            obj.idx_mid_gap = floor((obj.idx_vbm + obj.idx_cbm) / 2);
            obj.idx_h_integration = max( ...
                obj.idx_mid_gap - 1, obj.idx_vbm);
            obj.idx_e_integration = min( ...
                obj.idx_mid_gap + 1, obj.idx_cbm);
            total = obj.get_densities();
            normalization = trapz( ...
                energies(1:obj.idx_h_integration), ...
                total(1:obj.idx_h_integration));
            obj.tdos = total * obj.nelecs / normalization;
            if ~isempty(bandgap) && bandgap ~= 0
                delta = (double(bandgap) - (cbm - vbm)) / 2;
                % Immutable superclass energies cannot be reassigned; the
                % scissored energy grid is constructed through a temporary.
                shifted = energies;
                shifted(1:obj.idx_mid_gap-1) = ...
                    shifted(1:obj.idx_mid_gap-1) - delta;
                shifted(obj.idx_mid_gap:end) = ...
                    shifted(obj.idx_mid_gap:end) + delta;
                obj = obj.withEnergies(shifted);
            end
        end

        function [electrons, holes] = ...
                get_e_h_concs(obj, fermiLevel, temperature)
            scale = obj.volume * obj.A_to_cm^3;
            electronRange = obj.idx_e_integration:numel(obj.energies);
            holeRange = 1:obj.idx_h_integration;
            electrons = trapz(obj.energies(electronRange), ...
                obj.tdos(electronRange) .* ...
                kssolv.analysis.matgenlab.electronic_structure.f0( ...
                obj.energies(electronRange), fermiLevel, temperature)) / scale;
            holes = trapz(obj.energies(holeRange), ...
                obj.tdos(holeRange) .* ...
                kssolv.analysis.matgenlab.electronic_structure.f0( ...
                -obj.energies(holeRange), -fermiLevel, temperature)) / scale;
        end

        function value = get_doping(obj, fermiLevel, temperature)
            [electrons, holes] = ...
                obj.get_e_h_concs(fermiLevel, temperature);
            value = holes - electrons;
        end

        function fermi = get_fermi(obj, concentration, temperature, ...
                rtol, nstep, step, precision)
            if nargin < 4 || isempty(rtol), rtol = 0.01; end
            if nargin < 5 || isempty(nstep), nstep = 50; end
            if nargin < 6 || isempty(step), step = 0.1; end
            if nargin < 7 || isempty(precision), precision = 8; end
            fermi = obj.efermi;
            relativeError = inf;
            for iteration = 1:precision
                range = (-nstep:nstep) * step + fermi;
                calculated = arrayfun(@(level) ...
                    obj.get_doping(level, temperature), range);
                relativeError = abs(calculated / concentration - 1);
                [~, index] = min(relativeError);
                fermi = range(index);
                step = step / 10;
            end
            if min(relativeError) > rtol
                error("KSSOLV:Matgenlab:FermiDos:ConvergenceFailure", ...
                    "Could not find fermi within the requested tolerance.");
            end
        end

        function fermi = get_fermi_interextrapolated(obj, ...
                concentration, temperature, warnUser, cRef, varargin)
            if nargin < 4 || isempty(warnUser), warnUser = true; end
            if nargin < 5 || isempty(cRef), cRef = 1e10; end
            try
                fermi = obj.get_fermi( ...
                    concentration, temperature, varargin{:});
                return
            catch exception
                if warnUser
                    warning("KSSOLV:Matgenlab:FermiDos:Interpolation", ...
                        "%s", exception.message);
                end
            end
            if abs(concentration) < cRef
                if abs(concentration) < 1e-10
                    concentration = 1e-10;
                end
                magnitude = max(10, abs(concentration) * 10);
                f2 = obj.get_fermi_interextrapolated( ...
                    magnitude, temperature, false, cRef, varargin{:});
                f1 = obj.get_fermi_interextrapolated( ...
                    -magnitude, temperature, false, cRef, varargin{:});
                c2 = log(abs(1 + obj.get_doping(f2, temperature)));
                c1 = -log(abs(1 + obj.get_doping(f1, temperature)));
                slope = (f2 - f1) / (c2 - c1);
                fermi = f2 + slope * ...
                    (sign(concentration) * log(abs(1 + concentration)) - c2);
                return
            end
            fRef = obj.get_fermi_interextrapolated( ...
                sign(concentration) * cRef, temperature, false, cRef, ...
                varargin{:});
            fNew = obj.get_fermi_interextrapolated( ...
                concentration / 10, temperature, false, cRef, varargin{:});
            cLog = sign(concentration) * log(abs(concentration));
            cNewLog = sign(concentration) * ...
                log(abs(obj.get_doping(fNew, temperature)));
            slope = (fNew - fRef) / ...
                (cNewLog - sign(concentration) * 10);
            fermi = fNew + slope * (cLog - cNewLog);
        end

        function value = as_dict(obj)
            value = as_dict@kssolv.analysis.matgenlab. ...
                electronic_structure.Dos(obj);
            value.x_class = "FermiDos";
            value.structure = obj.structure.as_dict();
            value.nelecs = obj.nelecs;
        end
    end

    methods (Static)
        function obj = from_dict(value)
            dos = kssolv.analysis.matgenlab.electronic_structure.Dos. ...
                from_dict(value);
            structure = kssolv.analysis.matgenlab.core.Structure. ...
                from_dict(value.structure);
            obj = kssolv.analysis.matgenlab.electronic_structure. ...
                FermiDos(dos, structure, value.nelecs);
        end
    end

    methods (Access = private)
        function value = withEnergies(obj, energies)
            base = kssolv.analysis.matgenlab.electronic_structure.Dos( ...
                obj.efermi, energies, obj.densities);
            value = kssolv.analysis.matgenlab.electronic_structure. ...
                FermiDos(base, obj.structure, obj.nelecs);
        end
    end
end
