classdef Molecule < kssolv.analysis.matgenlab.core.IMolecule
    %MOLECULE Molecular collection with copy-on-write mutation methods.

    methods
        function obj = Molecule(varargin)
            obj@kssolv.analysis.matgenlab.core.IMolecule(varargin{:});
        end

        function obj = append(obj, species, coords, options)
            arguments
                obj
                species
                coords
                options.validate_proximity (1,1) logical = false
                options.properties (1,1) struct = struct()
            end
            site = kssolv.analysis.matgenlab.core.Site( ...
                species, coords, properties = options.properties);
            if options.validate_proximity
                for index = 1:obj.num_sites
                    if site.distance(obj.sites_{index}) < 0.5
                        error("KSSOLV:Matgenlab:Molecule:Proximity", ...
                            "New site is too close to an existing site.");
                    end
                end
            end
            obj.sites_{end + 1} = site;
        end

        function obj = insert(obj, index, species, coords, options)
            arguments
                obj
                index (1,1) double {mustBeInteger, mustBePositive}
                species
                coords
                options.validate_proximity (1,1) logical = false
                options.properties (1,1) struct = struct()
                options.label = missing
            end
            if index > obj.num_sites + 1
                error("KSSOLV:Matgenlab:Molecule:Index", ...
                    "Insertion index exceeds the molecule length.");
            end
            site = kssolv.analysis.matgenlab.core.Site( ...
                species, coords, properties = options.properties, ...
                label = options.label);
            if options.validate_proximity
                for existing = 1:obj.num_sites
                    if site.distance(obj.sites_{existing}) < 0.5
                        error("KSSOLV:Matgenlab:Molecule:Proximity", ...
                            "New site is too close to an existing site.");
                    end
                end
            end
            obj.sites_ = [obj.sites_(1:index-1), {site}, obj.sites_(index:end)];
        end

        function obj = substitute(obj, index, functionalGroup, bondOrder)
            if nargin < 4, bondOrder = 1; end
            [speciesValues, coordinates, properties, labels] = ...
                kssolv.analysis.matgenlab.core.prepare_functional_group( ...
                obj, index, functionalGroup, bondOrder);
            obj = obj.remove_sites(index);
            for siteIndex = 1:numel(speciesValues)
                obj = obj.append(speciesValues{siteIndex}, ...
                    coordinates(siteIndex, :), ...
                    properties = properties{siteIndex});
                site = obj.sites_{end};
                site.label = labels{siteIndex};
                obj.sites_{end} = site;
            end
        end

        function obj = remove_sites(obj, indices)
            indices = unique(reshape(double(indices), 1, []));
            arrayfun(@(index) obj.validateSiteIndex(index), indices);
            keep = true(1, obj.num_sites); keep(indices) = false;
            obj.sites_ = obj.sites_(keep);
        end

        function obj = remove_species(obj, species)
            removed = string(species);
            keep = false(1, obj.num_sites);
            for index = 1:obj.num_sites
                site = obj.sites_{index};
                [siteSpecies, amounts] = site.species.items();
                retained = ~cellfun(@(item) ...
                    any(removed == string(item)) || ...
                    any(removed == item.symbol), siteSpecies);
                if any(retained)
                    pairs = [reshape(siteSpecies(retained), [], 1), ...
                        num2cell(reshape(amounts(retained), [], 1))];
                    site.species = ...
                        kssolv.analysis.matgenlab.core.Composition(pairs);
                    obj.sites_{index} = site;
                    keep(index) = true;
                end
            end
            obj.sites_ = obj.sites_(keep);
        end

        function obj = translate_sites(obj, indices, vector)
            if nargin < 2 || isempty(indices), indices = 1:obj.num_sites; end
            if nargin < 3 || isempty(vector), vector = [0, 0, 0]; end
            vector = reshape(double(vector), 1, 3);
            for index = reshape(indices, 1, [])
                obj.validateSiteIndex(index);
                site = obj.sites_{index};
                site.coords = site.coords + vector;
                obj.sites_{index} = site;
            end
        end

        function obj = rotate_sites(obj, indices, theta, axis, anchor)
            if nargin < 2 || isempty(indices), indices = 1:obj.num_sites; end
            if nargin < 3, theta = 0; end
            if nargin < 4 || isempty(axis), axis = [0, 0, 1]; end
            if nargin < 5 || isempty(anchor), anchor = [0, 0, 0]; end
            axis = reshape(double(axis), 1, 3);
            if norm(axis) == 0
                error("KSSOLV:Matgenlab:Molecule:RotationAxis", ...
                    "Rotation axis cannot be zero.");
            end
            axis = axis / norm(axis);
            anchor = reshape(double(anchor), 1, 3);
            skew = [ ...
                0, -axis(3), axis(2)
                axis(3), 0, -axis(1)
                -axis(2), axis(1), 0];
            rotation = eye(3) + sin(theta) * skew + ...
                (1 - cos(theta)) * (skew * skew);
            for index = reshape(indices, 1, [])
                obj.validateSiteIndex(index);
                site = obj.sites_{index};
                site.coords = ...
                    (site.coords - anchor) * rotation.' + anchor;
                obj.sites_{index} = site;
            end
        end

        function obj = set_charge_and_spin(obj, charge, spin_multiplicity)
            electrons = obj.nelectrons + obj.charge - charge;
            if nargin < 3 || isempty(spin_multiplicity)
                spin_multiplicity = mod(round(electrons), 2) + 1;
            elseif obj.charge_spin_check_ && ...
                    mod(round(electrons), 2) == ...
                    mod(round(spin_multiplicity), 2)
                error("KSSOLV:Matgenlab:Molecule:ChargeSpin", ...
                    "Charge and spin multiplicity are not possible for this molecule.");
            end
            obj.explicit_charge_ = charge;
            obj.spin_multiplicity = spin_multiplicity;
        end

        function obj = apply_operation(obj, operation)
            for index = 1:obj.num_sites
                site = obj.sites_{index};
                site.coords = operation.operate(site.coords);
                obj.sites_{index} = site;
            end
        end

        function obj = perturb(obj, distance, min_distance, seed)
            if nargin < 3 || isempty(min_distance)
                min_distance = distance;
            end
            if nargin < 4 || isempty(seed), seed = randi(2^31 - 1); end
            stream = RandStream("mt19937ar", Seed = double(seed));
            for index = 1:obj.num_sites
                direction = randn(stream, 1, 3);
                direction = direction / norm(direction);
                magnitude = min_distance + ...
                    (distance - min_distance) * rand(stream);
                site = obj.sites_{index};
                site.coords = site.coords + direction * magnitude;
                obj.sites_{index} = site;
            end
        end

        function varargout = relax(obj, calculator, varargin)
            if nargin < 2 || isempty(calculator) || ...
                    ischar(calculator) || isstring(calculator)
                error("KSSOLV:Matgenlab:External:MoleculeRelaxer", ...
                    "Molecule relaxation requires an explicit MATLAB " + ...
                    "optimizer adapter.");
            end
            if isa(calculator, "function_handle")
                [varargout{1:nargout}] = calculator(obj, varargin{:});
            elseif isobject(calculator) && ismethod(calculator, "relax")
                [varargout{1:nargout}] = calculator.relax(obj, varargin{:});
            elseif isstruct(calculator) && isfield(calculator, "relax") && ...
                    isa(calculator.relax, "function_handle")
                [varargout{1:nargout}] = ...
                    calculator.relax(obj, varargin{:});
            else
                error("KSSOLV:Matgenlab:Molecule:RelaxerType", ...
                    "calculator must expose a MATLAB relaxation adapter.");
            end
        end

        function value = to(obj, filename, fmt)
            if nargin < 2, filename = ""; end
            if nargin < 3 || strlength(string(fmt)) == 0
                [~, ~, extension] = fileparts(string(filename));
                if strlength(string(filename)) == 0
                    fmt = "json";
                else
                    fmt = erase(lower(extension), ".");
                end
            end
            fmt = lower(string(fmt));
            handler = kssolv.analysis.matgenlab.io. ...
                get_molecule_format("name", fmt);
            if ~isempty(handler.write_str)
                value = string(feval(handler.write_str, obj));
                if strlength(string(filename)) > 0
                    if ~isempty(handler.write_file)
                        feval(handler.write_file, obj, filename);
                        return
                    end
                    fid = fopen(filename, "w", "n", "UTF-8");
                    if fid < 0
                        error("KSSOLV:Matgenlab:Molecule:Write", ...
                            "Cannot open '%s' for writing.", filename);
                    end
                    cleanup = onCleanup(@() fclose(fid));
                    fwrite(fid, char(value), "char");
                    clear cleanup
                end
                return
            end
            switch fmt
                case {"json", "mson"}
                    value = kssolv.analysis.matgenlab.util.encode(obj);
                case "xyz"
                    value = string(kssolv.analysis.matgenlab.io.xyz.XYZ(obj));
                otherwise
                    error("KSSOLV:Matgenlab:Molecule:UnknownFormat", ...
                        "Unsupported molecule format '%s'.", fmt);
            end
            if strlength(string(filename)) > 0
                fid = fopen(filename, "w", "n", "UTF-8");
                if fid < 0
                    error("KSSOLV:Matgenlab:Molecule:Write", ...
                        "Cannot open '%s' for writing.", filename);
                end
                cleanup = onCleanup(@() fclose(fid));
                fwrite(fid, char(value), "char");
                clear cleanup
            end
        end

        function value = to_file(obj, filename, fmt)
            if nargin < 3, fmt = ""; end
            value = obj.to(filename, fmt);
        end
    end

    methods (Static)
        function obj = from_sites(sites, options)
            arguments
                sites cell
                options.charge (1,1) double = 0
                options.spin_multiplicity = []
                options.validate_proximity (1,1) logical = false
                options.charge_spin_check (1,1) logical = true
                options.properties (1,1) struct = struct()
            end
            base = kssolv.analysis.matgenlab.core.IMolecule.from_sites( ...
                sites, charge = options.charge, ...
                spin_multiplicity = options.spin_multiplicity, ...
                validate_proximity = options.validate_proximity, ...
                charge_spin_check = options.charge_spin_check, ...
                properties = options.properties);
            obj = kssolv.analysis.matgenlab.core.Molecule( ...
                base.species_and_occu, base.cart_coords, ...
                charge = base.charge, ...
                spin_multiplicity = base.spin_multiplicity, ...
                site_properties = base.site_properties, ...
                labels = base.labels, properties = base.molecule_properties);
        end

        function obj = from_dict(value)
            base = kssolv.analysis.matgenlab.core.IMolecule.from_dict(value);
            obj = kssolv.analysis.matgenlab.core.Molecule.from_sites( ...
                base.sites, charge = base.charge, ...
                spin_multiplicity = base.spin_multiplicity, ...
                properties = base.molecule_properties);
        end

        function obj = fromDict(value)
            obj = kssolv.analysis.matgenlab.core.Molecule.from_dict(value);
        end

        function obj = from_str(input_string, fmt)
            fmt = lower(string(fmt));
            handler = kssolv.analysis.matgenlab.io. ...
                get_molecule_format("name", fmt);
            if ~isempty(handler.read_str)
                value = feval(handler.read_str, input_string);
                if isa(value, ...
                        "kssolv.analysis.matgenlab.core.Molecule")
                    obj = value;
                elseif isa(value, ...
                        "kssolv.analysis.matgenlab.core.IMolecule")
                    obj = kssolv.analysis.matgenlab.core.Molecule. ...
                        from_sites(value.sites,charge=value.charge, ...
                        spin_multiplicity=value.spin_multiplicity, ...
                        properties=value.molecule_properties);
                else
                    error("KSSOLV:Matgenlab:Molecule:RegistryType", ...
                        "Molecule format handler returned '%s'.", ...
                        class(value));
                end
                return
            end
            switch fmt
                case {"json", "mson"}
                    decoded = kssolv.analysis.matgenlab.util.decode(input_string);
                    if isa(decoded, "kssolv.analysis.matgenlab.core.Molecule")
                        obj = decoded;
                    elseif isa(decoded, ...
                            "kssolv.analysis.matgenlab.core.IMolecule")
                        obj = ...
                            kssolv.analysis.matgenlab.core.Molecule.from_sites( ...
                                decoded.sites, charge = decoded.charge, ...
                                spin_multiplicity = decoded.spin_multiplicity, ...
                                properties = decoded.molecule_properties);
                    else
                        error("KSSOLV:Matgenlab:Molecule:DecodedType", ...
                            "JSON does not contain a Molecule.");
                    end
                case "xyz"
                    xyz = ...
                        kssolv.analysis.matgenlab.io.xyz.XYZ.from_str( ...
                            input_string);
                    obj = xyz.molecule;
                otherwise
                    error("KSSOLV:Matgenlab:Molecule:UnknownFormat", ...
                        "Unsupported molecule format '%s'.", fmt);
            end
        end

        function obj = from_file(filename, fmt)
            if nargin < 2 || strlength(string(fmt)) == 0
                [~, ~, extension] = fileparts(string(filename));
                fmt = erase(lower(extension), ".");
            end
            if ~isfile(filename)
                error("KSSOLV:Matgenlab:Molecule:MissingFile", ...
                    "Molecule file '%s' does not exist.", filename);
            end
            obj = kssolv.analysis.matgenlab.core.Molecule.from_str( ...
                fileread(filename), fmt);
        end
    end
end
