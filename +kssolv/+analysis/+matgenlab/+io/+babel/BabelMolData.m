classdef BabelMolData < handle
    %BABELMOLDATA Native, inspectable analogue of an OpenBabel OBMol.
    %
    % This object deliberately contains no OpenBabel process integration.
    % It is the interchange value used by BabelMolAdaptor when no explicitly
    % injected OpenBabel-compatible MATLAB backend is present.

    properties
        molecule = []
        species cell = cell(1, 0)
        coordinates double = zeros(0, 3)
        bonds double = zeros(0, 3)
        dimension (1,1) double = 3
        conformers cell = cell(1, 0)
    end

    properties (Dependent, SetAccess = private)
        atoms
    end

    methods
        function obj = BabelMolData(molecule, bonds, dimension, conformers)
            if nargin < 1
                molecule = kssolv.analysis.matgenlab.core.Molecule( ...
                    strings(0, 1), zeros(0, 3), charge_spin_check = false);
            end
            if nargin < 2 || isempty(bonds), bonds = zeros(0, 3); end
            if nargin < 3 || isempty(dimension), dimension = 3; end
            if isstruct(molecule) && isfield(molecule, "x_babel_raw")
                obj.species = reshape(cellstr(string(molecule.species)), 1, []);
                obj.coordinates = double(molecule.coordinates);
                molecule = [];
            else
                obj.molecule = molecule;
                obj.species = reshape(molecule.species, 1, []);
                obj.coordinates = molecule.cart_coords;
            end
            if nargin < 4 || isempty(conformers)
                if isempty(molecule)
                    conformers = cell(1, 0);
                else
                    conformers = {molecule};
                end
            end
            obj.bonds = double(bonds);
            obj.dimension = double(dimension);
            obj.conformers = reshape(conformers, 1, []);
        end

        function value = get.atoms(obj)
            value = obj.getMolecule().sites;
        end

        function value = NumAtoms(obj)
            value = numel(obj.species);
        end

        function value = GetDimension(obj)
            value = obj.dimension;
        end

        function value = NumConformers(obj)
            value = numel(obj.conformers);
        end

        function value = NumRotors(obj)
            % Acyclic single bonds whose endpoints both have degree > 1.
            if isempty(obj.bonds)
                value = 0;
                return
            end
            endpoints = obj.bonds(:, 1:2);
            degrees = accumarray(endpoints(:), 1, ...
                [numel(obj.species), 1]);
            single = obj.bonds(:, 3) == 1;
            value = sum(single & degrees(obj.bonds(:, 1)) > 1 & ...
                degrees(obj.bonds(:, 2)) > 1);
        end

        function SetConformer(obj, index)
            % OpenBabel indices are zero based.
            index = double(index) + 1;
            if index < 1 || index > numel(obj.conformers)
                error("KSSOLV:Matgenlab:Babel:ConformerIndex", ...
                    "Conformer index is outside the available range.");
            end
            obj.setMolecule(obj.conformers{index});
        end

        function value = getMolecule(obj)
            if isempty(obj.molecule)
                obj.molecule = kssolv.analysis.matgenlab.core.Molecule( ...
                    obj.species, obj.coordinates, ...
                    charge_spin_check = false);
            end
            value = obj.molecule;
        end

        function setMolecule(obj, value)
            obj.molecule = value.copy();
            obj.species = reshape(value.species, 1, []);
            obj.coordinates = value.cart_coords;
        end
    end
end
