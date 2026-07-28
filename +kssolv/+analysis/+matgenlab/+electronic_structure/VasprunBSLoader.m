classdef VasprunBSLoader < handle
    %VASPRUNBSLOADER Adapt Vasprun or BandStructure data for BoltzTraP2.

    properties
        kpoints double = zeros(0, 3)
        structure = []
        proj_all struct = struct()
        ebands_all double = zeros(0)
        is_spin_polarized (1,1) logical = false
        dosweight (1,1) double = 2
        lattvec double = zeros(3)
        mommat_all = []
        mommat = []
        magmom = []
        fermi (1,1) double = 0
        UCvol (1,1) double = 0
        vbm_idx = []
        cbm_idx = []
        vbm = []
        cbm = []
        nelect_all = []
        ebands double = zeros(0)
        proj struct = struct()
        nelect = []
    end

    methods
        function obj = VasprunBSLoader(input, structure, nelect)
            if nargin == 0, return; end
            if nargin < 2, structure = []; end
            if nargin < 3, nelect = []; end
            if isa(input, "kssolv.analysis.matgenlab.io.vasp.Vasprun")
                structure = input.final_structure;
                nelect = input.parameters.get("NELECT", nelect);
                bandStructure = input.get_band_structure();
            elseif isa(input, ...
                    "kssolv.analysis.matgenlab.electronic_structure.BandStructure")
                bandStructure = input;
            else
                error("KSSOLV:Matgenlab:Boltztrap2:LoaderType", ...
                    "Input must be a Vasprun or BandStructure.");
            end
            obj.kpoints = cell2mat(cellfun(@(point) ...
                point.frac_coords, bandStructure.kpoints(:), ...
                "UniformOutput", false));
            if ~isempty(bandStructure.structure)
                obj.structure = bandStructure.structure;
            elseif ~isempty(structure)
                obj.structure = structure;
            else
                error("KSSOLV:Matgenlab:Boltztrap2:MissingStructure", ...
                    "A structure must be provided.");
            end
            obj.proj_all = struct();
            spinNames = fieldnames(bandStructure.projections);
            for index = 1:numel(spinNames)
                name = spinNames{index};
                obj.proj_all.(name) = permute( ...
                    bandStructure.projections.(name), [2, 1, 4, 3]);
            end
            bandNames = fieldnames(bandStructure.bands);
            blocks = cellfun(@(name) bandStructure.bands.(name), ...
                bandNames, "UniformOutput", false);
            obj.ebands_all = vertcat(blocks{:}) * hartreePerEv();
            obj.is_spin_polarized = bandStructure.is_spin_polarized;
            if obj.is_spin_polarized, obj.dosweight = 1; end
            obj.lattvec = obj.structure.lattice.matrix.' * bohrPerAngstrom();
            obj.fermi = bandStructure.efermi * hartreePerEv();
            obj.UCvol = obj.structure.lattice.volume * bohrPerAngstrom()^3;
            if ~bandStructure.is_metal()
                vbmData = bandStructure.get_vbm();
                cbmData = bandStructure.get_cbm();
                obj.vbm_idx = max([vbmData.band_index.up, ...
                    fieldOr(vbmData.band_index, "down", [])]);
                obj.cbm_idx = min([cbmData.band_index.up, ...
                    fieldOr(cbmData.band_index, "down", [])]);
                obj.vbm = vbmData.energy;
                obj.cbm = cbmData.energy;
            else
                obj.vbm = obj.fermi;
                obj.cbm = obj.fermi;
            end
            if ~isempty(nelect)
                obj.nelect_all = double(nelect);
            elseif ~isempty(obj.vbm_idx) && ~isempty(obj.cbm_idx)
                obj.nelect_all = obj.vbm_idx + obj.cbm_idx;
            else
                error("KSSOLV:Matgenlab:Boltztrap2:MissingElectrons", ...
                    "nelect is required for a metallic BandStructure.");
            end
            obj.bandana();
        end

        function value = get_lattvec(obj)
            if isempty(obj.lattvec)
                obj.lattvec = obj.structure.lattice.matrix.' * ...
                    bohrPerAngstrom();
            end
            value = obj.lattvec;
        end

        function value = get_volume(obj)
            if isempty(obj.UCvol) || obj.UCvol == 0
                obj.UCvol = abs(det(obj.get_lattvec()));
            end
            value = obj.UCvol;
        end

        function accepted = bandana(obj, emin, emax)
            if nargin < 2 || isempty(emin), emin = -inf; end
            if nargin < 3 || isempty(emax), emax = inf; end
            bandMinimum = min(obj.ebands_all, [], 2);
            bandMaximum = max(obj.ebands_all, [], 2);
            tooLow = sum(bandMaximum <= emin);
            accepted = bandMinimum < emax & bandMaximum > emin;
            obj.ebands = obj.ebands_all(accepted, :);
            obj.proj = struct();
            names = fieldnames(obj.proj_all);
            if numel(names) == 2
                half = numel(accepted) / 2;
                obj.proj.up = obj.proj_all.up(:, accepted(1:half), :, :);
                obj.proj.down = obj.proj_all.down(:, accepted(half+1:end), :, :);
            elseif isscalar(names)
                obj.proj.(names{1}) = obj.proj_all.(names{1})(:, accepted, :, :);
            end
            obj.nelect = obj.nelect_all - obj.dosweight * tooLow;
        end
    end

    methods (Static)
        function obj = from_file(filename)
            run = kssolv.analysis.matgenlab.io.vasp.Vasprun(filename, ...
                "parse_projected_eigen", true);
            obj = kssolv.analysis.matgenlab.electronic_structure. ...
                VasprunBSLoader(run);
        end
    end
end

function value = fieldOr(input, name, default)
if isfield(input, name), value = input.(name); else, value = default; end
end

function value = hartreePerEv()
value = 1 / 27.211386245988;
end

function value = bohrPerAngstrom()
value = 1.88972612462577;
end
