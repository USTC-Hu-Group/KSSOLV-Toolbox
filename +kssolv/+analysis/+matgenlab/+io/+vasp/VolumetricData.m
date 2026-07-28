classdef VolumetricData < kssolv.analysis.matgenlab.util.MSONable
    %VOLUMETRICDATA VASP-style three-dimensional grid data.

    properties
        structure
        data (1,1) struct
        data_aug (1,1) struct = struct()
        name (1,1) string = "VolumetricData"
    end

    properties (SetAccess = private)
        dim (1,3) double
        ngridpts (1,1) double
        is_spin_polarized (1,1) logical
        is_soc (1,1) logical
    end

    properties (Dependent, SetAccess = private)
        spin_data
    end

    methods
        function obj = VolumetricData(structure, data, options)
            arguments
                structure
                data (1,1) struct
                options.distance_matrix = struct()
                options.data_aug (1,1) struct = struct()
            end
            if nargin == 0, return; end
            if ~isa(structure, "kssolv.analysis.matgenlab.core.IStructure")
                error("KSSOLV:Matgenlab:VolumetricData:Structure", ...
                    "structure must be a Structure or IStructure.");
            end
            if ~isfield(data, "total")
                error("KSSOLV:Matgenlab:VolumetricData:Total", ...
                    "Volumetric data requires a 'total' component.");
            end
            obj.structure = structure;
            obj.data = data;
            obj.data_aug = options.data_aug;
            obj.dim = size(data.total);
            if numel(obj.dim) < 3, obj.dim(3) = 1; end
            obj.ngridpts = prod(obj.dim);
            obj.is_spin_polarized = numel(fieldnames(data)) >= 2;
            obj.is_soc = numel(fieldnames(data)) >= 4;
        end

        function value = get.spin_data(obj)
            difference = zeros(obj.dim);
            if isfield(obj.data, "diff"), difference = obj.data.diff; end
            value = struct("up", 0.5 * (obj.data.total + difference), ...
                "down", 0.5 * (obj.data.total - difference));
        end

        function output = plus(obj, other)
            if isnumeric(other) && isscalar(other) && other == 0
                output = obj.copy();
                return
            end
            output = obj.linear_add(other, 1);
        end

        function output = minus(obj, other)
            output = obj.linear_add(other, -1);
        end

        function output = linear_add(obj, other, scale_factor)
            if nargin < 3, scale_factor = 1; end
            first = string(fieldnames(obj.data));
            second = string(fieldnames(other.data));
            if ~isequal(first, second)
                error("KSSOLV:Matgenlab:VolumetricData:DataKeys", ...
                    "Volumetric datasets have different component keys.");
            end
            result = struct();
            for fieldName = first.'
                result.(fieldName) = obj.data.(fieldName) + ...
                    scale_factor * other.data.(fieldName);
            end
            output = obj.copy();
            output.data = result;
            output.data_aug = struct();
        end

        function output = copy(obj)
            if isa(obj, "kssolv.analysis.matgenlab.io.vasp.Chgcar")
                output = kssolv.analysis.matgenlab.io.vasp.Chgcar( ...
                    obj.poscar, obj.data, obj.data_aug);
            elseif isa(obj, "kssolv.analysis.matgenlab.io.vasp.Locpot")
                output = kssolv.analysis.matgenlab.io.vasp.Locpot( ...
                    obj.poscar, obj.data, data_aug = obj.data_aug);
            elseif isa(obj, "kssolv.analysis.matgenlab.io.vasp.Elfcar")
                output = kssolv.analysis.matgenlab.io.vasp.Elfcar( ...
                    obj.poscar, obj.data);
            else
                output = kssolv.analysis.matgenlab.io.vasp.VolumetricData( ...
                    obj.structure, obj.data, data_aug = obj.data_aug);
            end
            output.name = obj.name;
        end

        function obj = scale(obj, factor)
            names = fieldnames(obj.data);
            for index = 1:numel(names)
                obj.data.(names{index}) = obj.data.(names{index}) * factor;
            end
        end

        function value = value_at(obj, x, y, z)
            query = [x,y,z];
            indices = query .* (obj.dim - 1) + 1;
            value = interpn(obj.data.total, indices(1), indices(2), ...
                indices(3), "linear");
        end

        function output = linear_slice(obj, p1, p2, n)
            if nargin < 4, n = 100; end
            p1 = reshape(double(p1), 1, []);
            p2 = reshape(double(p2), 1, []);
            if numel(p1) ~= 3 || numel(p2) ~= 3
                error("KSSOLV:Matgenlab:VolumetricData:Slice", ...
                    "p1 and p2 must contain three coordinates.");
            end
            points = p1 + linspace(0, 1, n).' .* (p2 - p1);
            output = zeros(n, 1);
            for index = 1:n
                output(index) = obj.value_at(points(index, 1), ...
                    points(index, 2), points(index, 3));
            end
        end

        function output = get_integrated_diff(obj, ind, radius, nbins)
            if nargin < 4, nbins = 1; end
            validateattributes(ind, {'numeric'}, ...
                {'scalar','integer','>=',1,'<=',obj.structure.num_sites});
            validateattributes(radius, {'numeric'}, ...
                {'scalar','real','finite','nonnegative'});
            validateattributes(nbins, {'numeric'}, ...
                {'scalar','integer','positive'});
            radii = (1:nbins).' * radius / nbins;
            output = [radii, zeros(nbins, 1)];
            if ~obj.is_spin_polarized, return; end
            [gx, gy, gz] = ndgrid(0:obj.dim(1)-1, ...
                0:obj.dim(2)-1, 0:obj.dim(3)-1);
            fractional = [gx(:) / obj.dim(1), ...
                gy(:) / obj.dim(2), gz(:) / obj.dim(3)];
            [points, distances] = obj.structure.lattice. ...
                get_points_in_sphere(fractional, ...
                obj.structure(ind).coords, radius, zip_results = false);
            indices = round(mod(points, 1) .* obj.dim);
            indices = mod(indices, obj.dim) + 1;
            linear = sub2ind(obj.dim, indices(:,1), ...
                indices(:,2), indices(:,3));
            values = obj.data.diff(linear);
            edges = linspace(0, radius, nbins + 1);
            bins = discretize(distances, edges);
            valid = ~isnan(bins);
            histogram = accumarray(bins(valid), values(valid), ...
                [nbins,1], @sum, 0);
            output(:,2) = cumsum(histogram) / obj.ngridpts;
        end

        function value = get_axis_grid(obj, ind)
            ind = obj.axisIndex(ind);
            value = (0:obj.dim(ind)-1) / obj.dim(ind) * ...
                obj.structure.lattice.abc(ind);
        end

        function value = get_average_along_axis(obj, ind)
            ind = obj.axisIndex(ind);
            axes = setdiff(1:3, ind);
            value = squeeze(mean(mean(obj.data.total, axes(1)), axes(2)));
            value = reshape(value, 1, []);
        end

        function to_hdf5(obj, filename)
            if isfile(filename)
                delete(filename);
            end
            obj.writeHdf5Array(filename, "/lattice", ...
                obj.structure.lattice.matrix);
            atomicNumbers = reshape(int32(obj.structure.atomic_numbers), [], 1);
            h5create(filename, "/Z", numel(atomicNumbers), ...
                Datatype = "int32");
            h5write(filename, "/Z", atomicNumbers);
            obj.writeHdf5Array(filename, "/fcoords", ...
                obj.structure.frac_coords);
            species = strings(obj.structure.num_sites, 1);
            for index = 1:obj.structure.num_sites
                species(index) = ...
                    obj.structure.get_site(index).species_string;
            end
            h5create(filename, "/species", numel(species), ...
                Datatype = "string");
            h5write(filename, "/species", species);
            names = fieldnames(obj.data);
            for index = 1:numel(names)
                obj.writeHdf5Array(filename, ...
                    "/vdata/" + string(names{index}), ...
                    obj.data.(names{index}));
            end
            augmentationNames = fieldnames(obj.data_aug);
            for index = 1:numel(augmentationNames)
                obj.writeHdf5Array(filename, ...
                    "/vdata_aug/" + string(augmentationNames{index}), ...
                    obj.data_aug.(augmentationNames{index}));
            end
            h5writeatt(filename, "/", "name", char(obj.name));
            h5writeatt(filename, "/", "structure_json", ...
                char(kssolv.analysis.matgenlab.util.encode( ...
                    obj.structure)));
        end

        function to_cube(obj, filename, comment)
            if nargin < 3, comment = ""; end
            conversion = kssolv.analysis.matgenlab.core.ang_to_bohr();
            lines = strings(6 + obj.structure.num_sites, 1);
            lines(1) = "# Cube file for " + obj.structure.formula + ...
                " generated by Pymatgen";
            lines(2) = "# " + string(comment);
            lines(3) = sprintf("\t %d 0.000000 0.000000 0.000000", ...
                obj.structure.num_sites);
            lattice = obj.structure.lattice.matrix;
            for axis = 1:3
                voxel = lattice(axis, :) / obj.dim(axis) * conversion;
                lines(axis + 3) = sprintf( ...
                    "\t %d %.6f %.6f %.6f", obj.dim(axis), voxel);
            end
            coordinates = obj.structure.cart_coords * conversion;
            atomicNumbers = obj.structure.atomic_numbers;
            for index = 1:obj.structure.num_sites
                lines(index + 6) = sprintf( ...
                    "\t %d 0.000000 %.15g %.15g %.15g ", ...
                    atomicNumbers(index), coordinates(index, :));
            end
            text = strjoin(lines, newline) + newline;
            ordered = permute(obj.data.total, [3, 2, 1]);
            values = ordered(:);
            chunks = strings(ceil(numel(values) / 6), 1);
            for chunkIndex = 1:numel(chunks)
                first = (chunkIndex - 1) * 6 + 1;
                last = min(first + 5, numel(values));
                entries = strings(1, last - first + 1);
                for valueIndex = first:last
                    prefix = "";
                    if values(valueIndex) > 0, prefix = " "; end
                    entries(valueIndex - first + 1) = ...
                        prefix + sprintf("%.6e ", values(valueIndex));
                end
                chunks(chunkIndex) = join(entries, "");
            end
            text = text + strjoin(chunks, newline);
            if mod(numel(values), 6) == 0, text = text + newline; end
            kssolv.analysis.matgenlab.io.vasp.VaspIOUtils. ...
                writeText(filename, text);
        end

        function write_file(obj, file_name, vasp4_compatible)
            if nargin < 3, vasp4_compatible = false; end
            poscar = kssolv.analysis.matgenlab.io.vasp.Poscar(obj.structure);
            if obj.name ~= "VolumetricData", comment = obj.name;
            else, comment = poscar.comment;
            end
            lines = strings(0, 1);
            lines(end + 1) = comment;
            lines(end + 1) = "   1.00000000000000";
            lattice = obj.structure.lattice.matrix;
            for index = 1:3
                lines(end + 1) = sprintf(" %12.6f%12.6f%12.6f", ...
                    lattice(index, :)); %#ok<AGROW>
            end
            if ~vasp4_compatible
                lines(end + 1) = strjoin(compose("%5s", ...
                    poscar.site_symbols), "");
            end
            lines(end + 1) = strjoin(compose("%6d", poscar.natoms), "");
            lines(end + 1) = "Direct";
            for index = 1:obj.structure.num_sites
                lines(end + 1) = sprintf("%10.6f%10.6f%10.6f", ...
                    obj.structure.frac_coords(index, :)); %#ok<AGROW>
            end
            lines(end + 1) = " ";
            text = strjoin(lines, newline) + newline;
            components = "total";
            if obj.is_spin_polarized
                if obj.is_soc, components = ["total","diff_x","diff_y","diff_z"];
                else, components = ["total","diff"];
                end
            end
            for component = components
                text = text + obj.renderGrid(obj.data.(component));
                if isfield(obj.data_aug, component)
                    text = text + obj.renderAugmentation( ...
                        obj.data_aug.(component));
                end
            end
            kssolv.analysis.matgenlab.io.vasp.VaspIOUtils. ...
                writeText(file_name, text);
        end

        function value = as_dict(obj)
            classParts = split(string(class(obj)), ".");
            value = struct("x_module", "pymatgen.io.vasp.outputs", ...
                "x_class", classParts(end), ...
                "structure", obj.structure.as_dict(), ...
                "data", obj.data, "data_aug", obj.data_aug);
        end

        function value = asDict(obj)
            value = obj.as_dict();
        end
    end

    methods (Static)
        function obj = from_hdf5(filename, varargin)
            info = h5info(filename, "/vdata");
            data = struct();
            for index = 1:numel(info.Datasets)
                name = string(info.Datasets(index).Name);
                raw = h5read(filename, "/vdata/" + name);
                data.(name) = permute(raw, ndims(raw):-1:1);
            end
            dataAug = struct();
            rootInfo = h5info(filename);
            groupNames = string({rootInfo.Groups.Name});
            if any(groupNames == "/vdata_aug")
                infoAug = h5info(filename, "/vdata_aug");
                for index = 1:numel(infoAug.Datasets)
                    name = string(infoAug.Datasets(index).Name);
                    raw = h5read(filename, "/vdata_aug/" + name);
                    dataAug.(name) = permute(raw, ndims(raw):-1:1);
                end
            end
            try
                encoded = string(h5readatt( ...
                    filename, "/", "structure_json"));
                structure = ...
                    kssolv.analysis.matgenlab.util.decode(encoded);
            catch
                lattice = h5read(filename, "/lattice").';
                fractional = h5read(filename, "/fcoords").';
                atomicNumbers = double(h5read(filename, "/Z"));
                species = cell(1, numel(atomicNumbers));
                for index = 1:numel(species)
                    species{index} = ...
                        kssolv.analysis.matgenlab.core.Element. ...
                        from_Z(atomicNumbers(index));
                end
                structure = ...
                    kssolv.analysis.matgenlab.core.Structure( ...
                        lattice, species, fractional);
            end
            obj = kssolv.analysis.matgenlab.io.vasp.VolumetricData( ...
                structure, data, data_aug = dataAug);
            try
                obj.name = string(h5readatt(filename, "/", "name"));
            catch
            end
            if ~isempty(varargin)
                error("KSSOLV:Matgenlab:VolumetricData:Hdf5Options", ...
                    "Unsupported from_hdf5 options were supplied.");
            end
        end

        function obj = from_cube(filename)
            text = string( ...
                kssolv.analysis.matgenlab.io.vasp.VaspIOUtils. ...
                readText(filename));
            lines = splitlines(text);
            if numel(lines) < 6
                error("KSSOLV:Matgenlab:VolumetricData:CubeHeader", ...
                    "Cube file must contain at least six header lines.");
            end
            header = sscanf(lines(3), "%f").';
            if numel(header) < 4
                error("KSSOLV:Matgenlab:VolumetricData:CubeHeader", ...
                    "Invalid cube atom-count/origin line.");
            end
            numberAtoms = round(header(1));
            conversion = ...
                kssolv.analysis.matgenlab.core.UnitConstants.bohr_to_angstrom;
            origin = header(2:4) * conversion;
            dimensions = zeros(1, 3);
            voxels = zeros(3, 3);
            for axis = 1:3
                row = sscanf(lines(axis + 3), "%f").';
                if numel(row) < 4
                    error("KSSOLV:Matgenlab:VolumetricData:CubeVoxel", ...
                        "Invalid cube voxel line %d.", axis + 3);
                end
                dimensions(axis) = round(row(1));
                voxels(axis, :) = row(2:4) * conversion;
            end
            species = cell(1, numberAtoms);
            coordinates = zeros(numberAtoms, 3);
            for index = 1:numberAtoms
                row = sscanf(lines(index + 6), "%f").';
                if numel(row) < 5
                    error("KSSOLV:Matgenlab:VolumetricData:CubeAtom", ...
                        "Invalid cube atom line %d.", index + 6);
                end
                species{index} = ...
                    kssolv.analysis.matgenlab.core.Element.from_Z( ...
                        round(row(1)));
                coordinates(index, :) = row(3:5) * conversion - origin;
            end
            lattice = voxels .* dimensions.';
            structure = kssolv.analysis.matgenlab.core.Structure( ...
                lattice, species, coordinates, ...
                coords_are_cartesian = true);
            payload = strjoin(lines(7 + numberAtoms:end), " ");
            values = sscanf(payload, "%f");
            expected = prod(dimensions);
            if numel(values) ~= expected
                error("KSSOLV:Matgenlab:VolumetricData:CubeData", ...
                    "Expected %d cube values but parsed %d.", ...
                    expected, numel(values));
            end
            ordered = reshape(values, ...
                [dimensions(3), dimensions(2), dimensions(1)]);
            total = permute(ordered, [3, 2, 1]);
            obj = kssolv.analysis.matgenlab.io.vasp.VolumetricData( ...
                structure, struct("total", total));
        end

        function obj = from_dict(value)
            structure = kssolv.analysis.matgenlab.core.Structure. ...
                from_dict(value.structure);
            dataAug = struct();
            if isfield(value, "data_aug") && ~isempty(value.data_aug)
                dataAug = value.data_aug;
            end
            className = "VolumetricData";
            if isfield(value, "x_class"), className = string(value.x_class); end
            switch className
                case "Chgcar"
                    obj = kssolv.analysis.matgenlab.io.vasp.Chgcar( ...
                        structure, value.data, dataAug);
                case "Locpot"
                    obj = kssolv.analysis.matgenlab.io.vasp.Locpot( ...
                        structure, value.data, data_aug = dataAug);
                case "Elfcar"
                    obj = kssolv.analysis.matgenlab.io.vasp.Elfcar( ...
                        structure, value.data);
                otherwise
                    obj = kssolv.analysis.matgenlab.io.vasp.VolumetricData( ...
                        structure, value.data, data_aug = dataAug);
            end
        end

        function obj = fromDict(value)
            obj = kssolv.analysis.matgenlab.io.vasp.VolumetricData. ...
                from_dict(value);
        end

        function [poscar, data, data_aug] = parse_file(filename)
            text = string( ...
                kssolv.analysis.matgenlab.io.vasp.VaspIOUtils. ...
                readText(filename));
            lines = splitlines(text);
            poscar = [];
            boundary = 0;
            for index = 8:numel(lines)
                if strlength(strtrim(lines(index))) ~= 0, continue; end
                try
                    poscar = kssolv.analysis.matgenlab.io.vasp.Poscar. ...
                        from_str(strjoin(lines(1:index - 1), newline), ...
                        read_velocities = false);
                    boundary = index;
                    break
                catch
                end
            end
            if isempty(poscar)
                error("KSSOLV:Matgenlab:VolumetricData:Poscar", ...
                    "Could not parse POSCAR from volumetric data file.");
            end
            datasets = cell(1, 0);
            augmentations = cell(1, 0);
            lineIndex = boundary + 1;
            while lineIndex <= numel(lines)
                line = strtrim(lines(lineIndex));
                lineIndex = lineIndex + 1;
                if line == "", continue; end
                if startsWith(line, "augmentation occupancies")
                    if isempty(augmentations)
                        error("KSSOLV:Matgenlab:VolumetricData:Augmentation", ...
                            "Augmentation data precedes its grid.");
                    end
                    imaginary = contains(line, "(imaginary part)");
                    values = sscanf(line, "%*[^0-9]%d %d").';
                    if numel(values) < 2
                        tokens = regexp(line, "(\d+)\s+(\d+)\s*$", ...
                            "tokens", "once");
                        values = cellfun(@str2double, tokens);
                    end
                    key = values(1);
                    count = values(2);
                    [payload, lineIndex] = ...
                        kssolv.analysis.matgenlab.io.vasp.VolumetricData. ...
                        collectNumbers(lines, lineIndex, count);
                    map = augmentations{end};
                    if imaginary
                        if isKey(map, key)
                            map(key) = complex(map(key), payload); %#ok<NASGU>
                        else
                            map(key) = complex( ...
                                zeros(size(payload)), payload); %#ok<NASGU>
                        end
                    else
                        map(key) = payload; %#ok<NASGU>
                    end
                elseif contains(line, ".")
                    continue
                else
                    dims = sscanf(line, "%d").';
                    if numel(dims) ~= 3
                        error("KSSOLV:Matgenlab:VolumetricData:Dimensions", ...
                            "Expected three grid dimensions.");
                    end
                    [payload, lineIndex] = ...
                        kssolv.analysis.matgenlab.io.vasp.VolumetricData. ...
                        collectNumbers(lines, lineIndex, prod(dims));
                    datasets{end + 1} = reshape(payload, dims); %#ok<AGROW>
                    augmentations{end + 1} = containers.Map( ...
                        "KeyType", "double", "ValueType", "any"); %#ok<AGROW>
                end
            end
            if isempty(datasets)
                error("KSSOLV:Matgenlab:VolumetricData:MissingGrid", ...
                    "No volumetric grid was found.");
            end
            if numel(datasets) == 4
                reference = sign(1.01 * datasets{2} + ...
                    1.02 * datasets{3} + 1.03 * datasets{4});
                data = struct("total", datasets{1}, ...
                    "diff_x", datasets{2}, "diff_y", datasets{3}, ...
                    "diff_z", datasets{4}, "diff", ...
                    sqrt(datasets{2}.^2 + datasets{3}.^2 + ...
                    datasets{4}.^2) .* reference);
                data_aug = struct("total", augmentations{1}, ...
                    "diff_x", augmentations{2}, ...
                    "diff_y", augmentations{3}, ...
                    "diff_z", augmentations{4});
            elseif numel(datasets) == 2
                data = struct("total", datasets{1}, "diff", datasets{2});
                data_aug = struct("total", augmentations{1}, ...
                    "diff", augmentations{2});
            else
                data = struct("total", datasets{1});
                data_aug = struct("total", augmentations{1});
            end
        end
    end

    methods (Access = private)
        function writeHdf5Array(~, filename, dataset, value)
            value = double(value);
            order = ndims(value):-1:1;
            encoded = permute(value, order);
            h5create(filename, dataset, size(encoded), ...
                Datatype = "double");
            h5write(filename, dataset, encoded);
        end

        function index = axisIndex(~, input)
            if ismember(input, [1,2,3]), index = input;
            elseif input == 0, index = 1;
            else
                error("KSSOLV:Matgenlab:VolumetricData:Axis", ...
                    "Axis must be 1, 2, or 3 (0 is accepted for Python axis 0).");
            end
        end

        function text = renderGrid(obj, grid)
            text = sprintf("   %d   %d   %d\n", obj.dim);
            values = grid(:);
            for start = 1:5:numel(values)
                stop = min(start + 4, numel(values));
                rendered = arrayfun(@obj.formatFortranFloat, ...
                    values(start:stop));
                text = text + " " + strjoin(rendered, " ");
                if stop - start + 1 < 5, text = text + " "; end
                text = text + newline;
            end
        end

        function text = renderAugmentation(obj, augmentation)
            text = "";
            if isa(augmentation, "containers.Map")
                keys_ = sort(cell2mat(keys(augmentation)));
                for key = keys_
                    values = augmentation(key);
                    text = text + sprintf( ...
                        "augmentation occupancies   %d %3d\n", ...
                        key, numel(values));
                    text = text + obj.renderValues(values, false);
                    if ~isreal(values)
                        text = text + sprintf( ...
                            ['augmentation occupancies ' ...
                            '(imaginary part)   %d %3d\n'], ...
                            key, numel(values));
                        text = text + obj.renderValues(imag(values), false);
                    end
                end
            elseif isstring(augmentation) || iscellstr(augmentation)
                text = strjoin(string(augmentation), newline) + newline;
            end
        end

        function text = renderValues(obj, values, useComplex)
            if nargin < 3, useComplex = false; end
            if ~useComplex, values = real(values); end
            text = "";
            values = values(:);
            for start = 1:5:numel(values)
                stop = min(start + 4, numel(values));
                rendered = arrayfun(@obj.formatFortranFloat, ...
                    values(start:stop));
                text = text + " " + strjoin(rendered, " ");
                if stop - start + 1 < 5, text = text + " "; end
                text = text + newline;
            end
        end

        function output = formatFortranFloat(~, value)
            text = sprintf("%.10E", value);
            exponent = str2double(extractAfter(text, "E"));
            mantissa = extractBefore(text, "E");
            if value >= 0
                digits = erase(mantissa, ".");
                output = "0." + extractBefore(digits, 12) + ...
                    sprintf("E%+03d", exponent + 1);
            else
                digits = erase(extractAfter(mantissa, 1), ".");
                output = "-." + extractBefore(digits, 12) + ...
                    sprintf("E%+03d", exponent + 1);
            end
        end
    end

    methods (Static, Access = private)
        function [values, next] = collectNumbers(lines, first, count)
            values = zeros(count, 1);
            used = 0;
            next = first;
            while used < count && next <= numel(lines)
                row = sscanf(lines(next), "%f");
                next = next + 1;
                take = min(numel(row), count - used);
                values(used + 1:used + take) = row(1:take);
                used = used + take;
            end
            if used ~= count
                error("KSSOLV:Matgenlab:VolumetricData:GridValues", ...
                    "Expected %d values, got %d.", count, used);
            end
        end
    end
end
