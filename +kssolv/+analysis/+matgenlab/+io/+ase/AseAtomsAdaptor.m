classdef AseAtomsAdaptor
    %ASEATOMSADAPTOR Bridge native SiteCollection and neutral ASE data.

    methods (Static)
        function atoms = get_atoms(structure, msonable, varargin)
            if nargin < 2 || isempty(msonable), msonable = true; end
            if ~structure.is_ordered
                error("KSSOLV:Matgenlab:ASE:Disordered", ...
                    "ASE Atoms only supports ordered structures");
            end
            atoms = structure.to_ase_atoms();
            properties = structure.site_properties;
            arrays = properties;
            [arrays, initialCharges] = takeField(arrays, "charge");
            [arrays, initialMagmoms] = takeField(arrays, "magmom");
            [arrays, finalCharges] = takeField(arrays, "final_charge");
            [arrays, finalMagmoms] = takeField(arrays, "final_magmom");
            [arrays, selectiveDynamics] = ...
                takeField(arrays, "selective_dynamics");
            if ~isempty(initialCharges)
                arrays.initial_charges = rowValues(initialCharges);
            end
            if ~isempty(initialMagmoms)
                arrays.initial_magmoms = rowValues(initialMagmoms);
            end
            constraints = {};
            if ~isempty(selectiveDynamics)
                free = rows(selectiveDynamics);
                fixed = ~logical(free);
                masks = unique(fixed, "rows");
                for index = 1:size(masks, 1)
                    members = find(all(fixed == masks(index, :), 2)) - 1;
                    if any(masks(index, :))
                        constraints{end + 1} = struct( ...
                            "indices", reshape(members, 1, []), ...
                            "mask", masks(index, :)); %#ok<AGROW>
                    end
                end
            end
            oxidation = zeros(1, structure.num_sites);
            hasOxidation = false;
            for index = 1:structure.num_sites
                specie = structure.species{index};
                if isprop(specie, "oxi_state")
                    oxidation(index) = specie.oxi_state;
                    hasOxidation = true;
                end
            end
            if hasOxidation, arrays.oxi_states = oxidation; end
            atoms.arrays = arrays;
            atoms.constraints = constraints;
            if isa(structure, "kssolv.analysis.matgenlab.core.IStructure")
                atoms.info = structure.structure_properties;
            else
                atoms.info = structure.molecule_properties;
                atoms.charge = structure.charge;
                atoms.spin_multiplicity = structure.spin_multiplicity;
            end
            results = struct();
            if ~isempty(finalCharges)
                results.charges = rowValues(finalCharges);
            end
            if ~isempty(finalMagmoms)
                results.magmoms = rowValues(finalMagmoms);
            end
            if ~isempty(fieldnames(results))
                atoms.calc = struct("results", results);
            end
            for index = 1:2:numel(varargin)
                atoms.(char(string(varargin{index}))) = varargin{index + 1};
            end
            if msonable
                atoms = kssolv.analysis.matgenlab.io.ase.MSONAtoms(atoms);
            end
        end

        function structure = get_structure(atoms, cls, varargin)
            if nargin < 2 || isempty(cls), cls = "Structure"; end
            atoms = neutralStruct(atoms);
            if contains(string(cls), "Molecule", IgnoreCase = true)
                structure = kssolv.analysis.matgenlab.io.ase. ...
                    AseAtomsAdaptor.get_molecule(atoms, cls, varargin{:});
                return
            end
            [siteProperties, oxidation] = sitePropertiesFromAtoms(atoms);
            lattice = kssolv.analysis.matgenlab.core.Lattice( ...
                double(atoms.cell), logical(reshape(atoms.pbc, 1, [])));
            structure = kssolv.analysis.matgenlab.core.Structure( ...
                lattice, atoms.symbols, double(atoms.positions), ...
                varargin{:}, ...
                coords_are_cartesian = true, ...
                site_properties = siteProperties, ...
                properties = fieldOr(atoms, "info", struct()));
            if ~isempty(oxidation)
                structure = structure.add_oxidation_state_by_site(oxidation);
            end
        end

        function molecule = get_molecule(atoms, cls, varargin)
            if nargin < 2 || isempty(cls), cls = "Molecule"; end %#ok<NASGU>
            atoms = neutralStruct(atoms);
            [siteProperties, oxidation] = sitePropertiesFromAtoms(atoms);
            charge = fieldOr(atoms, "charge", []);
            if isempty(charge)
                charge = 0;
                if isfield(siteProperties, "charge")
                    charge = round(sum(cell2mat( ...
                        siteProperties.charge)));
                end
            end
            multiplicity = fieldOr(atoms, "spin_multiplicity", []);
            if isempty(multiplicity)
                multiplicity = 1;
                if isfield(siteProperties, "magmom")
                    multiplicity = round(sum(cell2mat( ...
                        siteProperties.magmom))) + 1;
                end
            end
            molecule = kssolv.analysis.matgenlab.core.Molecule( ...
                atoms.symbols, double(atoms.positions), ...
                varargin{:}, ...
                charge = charge, spin_multiplicity = multiplicity, ...
                site_properties = siteProperties, ...
                properties = fieldOr(atoms, "info", struct()));
            if ~isempty(oxidation)
                molecule = molecule.add_oxidation_state_by_site(oxidation);
            end
        end
    end
end

function value = neutralStruct(atoms)
if isa(atoms, "kssolv.analysis.matgenlab.io.ase.MSONAtoms")
    value = atoms.to_struct();
elseif isstruct(atoms)
    value = atoms;
else
    error("KSSOLV:Matgenlab:ASE:Representation", ...
        "ASE input must be MSONAtoms or a neutral struct.");
end
end

function [properties, oxidation] = sitePropertiesFromAtoms(atoms)
properties = fieldOr(atoms, "arrays", struct());
[properties, initialCharges] = takeField(properties, "initial_charges");
[properties, initialMagmoms] = takeField(properties, "initial_magmoms");
[properties, oxidation] = takeField(properties, "oxi_states");
if ~isempty(initialCharges), properties.charge = initialCharges; end
if ~isempty(initialMagmoms), properties.magmom = initialMagmoms; end
if isfield(atoms, "calc") && ~isempty(atoms.calc)
    results = atoms.calc;
    if isfield(results, "results"), results = results.results; end
    if isfield(results, "charges")
        properties.final_charge = results.charges;
    end
    if isfield(results, "magmoms")
        properties.final_magmom = results.magmoms;
    end
end
if isfield(atoms, "constraints") && ~isempty(atoms.constraints)
    selective = true(numel(atoms.symbols), 3);
    constraints = atoms.constraints;
    if isstruct(constraints), constraints = num2cell(constraints); end
    for index = 1:numel(constraints)
        constraint = constraints{index};
        selective(constraint.indices + 1, :) = ...
            repmat(~logical(constraint.mask), ...
            numel(constraint.indices), 1);
    end
    properties.selective_dynamics = selective;
end
names = string(fieldnames(properties));
for name = reshape(names, 1, [])
    values = properties.(char(name));
    if isnumeric(values) || islogical(values)
        if ~isvector(values) && size(values, 1) == numel(atoms.symbols)
            properties.(char(name)) = ...
                reshape(num2cell(values, 2), 1, []);
        end
    end
end
end

function [input, value] = takeField(input, name)
value = [];
if isfield(input, name)
    value = input.(name);
    input = rmfield(input, name);
end
end

function value = fieldOr(input, name, defaultValue)
if isfield(input, name), value = input.(name);
else, value = defaultValue;
end
end

function value = rowValues(input)
if iscell(input)
    try
        value = cell2mat(reshape(input, 1, []));
    catch
        value = input;
    end
else
    value = input;
end
end

function value = rows(input)
if iscell(input), value = vertcat(input{:});
else, value = input;
end
end
