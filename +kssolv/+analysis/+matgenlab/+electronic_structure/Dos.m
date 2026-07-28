classdef Dos < kssolv.analysis.matgenlab.util.MSONable
    %DOS Spin-resolved electronic density of states.
    %
    % MATLAB identifiers are case-insensitive, so this class covers both
    % upstream ``Dos`` and the newer ``DOS`` spelling.  The constructor
    % accepts either (efermi, energies, densities[, norm_vol]) or
    % (energies, density_matrix, efermi).

    properties (SetAccess = immutable)
        efermi (1,1) double
        energies (1,:) double
        densities (1,1) struct
        norm_vol = []
    end

    properties (Dependent, SetAccess = private)
        x
        y
        ydim
    end

    methods
        function obj = Dos(first, second, third, normVolume)
            if nargin < 4
                normVolume = [];
            end
            if ~isscalar(first) && isscalar(third) && isnumeric(second)
                energies = first;
                densityInput = second;
                efermi = third;
            else
                efermi = first;
                energies = second;
                densityInput = third;
            end
            energies = reshape(double(energies), 1, []);
            densities = ...
                kssolv.analysis.matgenlab.electronic_structure.Dos. ...
                normalizeDensities(densityInput);
            names = fieldnames(densities);
            volume = 1;
            if ~isempty(normVolume)
                volume = double(normVolume);
            end
            for index = 1:numel(names)
                densities.(names{index}) = ...
                    reshape(double(densities.(names{index})), 1, []) / volume;
                if numel(densities.(names{index})) ~= numel(energies)
                    error("KSSOLV:Matgenlab:Dos:SizeMismatch", ...
                        "Every density channel must match energies.");
                end
            end
            obj.efermi = double(efermi);
            obj.energies = energies;
            obj.densities = densities;
            obj.norm_vol = normVolume;
        end

        function value = get.x(obj)
            value = obj.energies;
        end

        function value = get.y(obj)
            if isfield(obj.densities, "up")
                value = obj.densities.up(:);
            else
                value = obj.densities.down(:);
                return
            end
            if isfield(obj.densities, "down")
                value(:, 2) = obj.densities.down(:);
            end
        end

        function value = get.ydim(obj)
            value = size(obj.y);
            value = value(2:end);
        end

        function value = get_densities(obj, spin)
            if nargin < 2 || isempty(spin)
                names = fieldnames(obj.densities);
                value = zeros(size(obj.densities.(names{1})));
                for index = 1:numel(names)
                    value = value + obj.densities.(names{index});
                end
                return
            end
            field = ...
                kssolv.analysis.matgenlab.electronic_structure.Dos. ...
                spinField(spin);
            if ~isfield(obj.densities, field)
                error("KSSOLV:Matgenlab:Dos:MissingSpin", ...
                    "The requested spin channel is absent.");
            end
            value = obj.densities.(field);
        end

        function value = get_smeared_densities(obj, sigma)
            spacing = mean(diff(obj.energies));
            value = obj.densities;
            names = fieldnames(value);
            for index = 1:numel(names)
                value.(names{index}) = ...
                    kssolv.analysis.matgenlab.electronic_structure.Dos. ...
                    gaussianFilter(value.(names{index}), sigma / spacing);
            end
        end

        function value = get_interpolated_value(obj, energy)
            value = struct();
            names = fieldnames(obj.densities);
            for index = 1:numel(names)
                name = names{index};
                value.(name) = interp1(obj.energies, ...
                    obj.densities.(name), energy, "linear");
            end
        end

        function [gap, cbm, vbm] = get_interpolated_gap( ...
                obj, tol, absTol, spin)
            if nargin < 2 || isempty(tol), tol = 1e-4; end
            if nargin < 3 || isempty(absTol), absTol = false; end
            if nargin < 4, spin = []; end
            total = obj.get_densities(spin);
            if ~absTol
                tol = tol * sum(total) / numel(total);
            end
            below = find(obj.energies < obj.efermi & total > tol);
            above = find(obj.energies > obj.efermi & total > tol);
            if isempty(below) || isempty(above)
                gap = 0;
                cbm = obj.efermi;
                vbm = obj.efermi;
                return
            end
            vbmStart = max(below);
            cbmStart = min(above);
            if vbmStart == cbmStart || vbmStart == cbmStart - 1
                gap = 0;
                cbm = obj.efermi;
                vbm = obj.efermi;
                return
            end
            vbm = interp1( ...
                total(vbmStart:vbmStart+1), ...
                obj.energies(vbmStart:vbmStart+1), tol, "linear");
            cbm = interp1( ...
                total(cbmStart-1:cbmStart), ...
                obj.energies(cbmStart-1:cbmStart), tol, "linear");
            gap = cbm - vbm;
        end

        function [cbm, vbm] = get_cbm_vbm(obj, tol, absTol, spin)
            if nargin < 2, tol = []; end
            if nargin < 3, absTol = []; end
            if nargin < 4, spin = []; end
            [~, cbm, vbm] = obj.get_interpolated_gap(tol, absTol, spin);
        end

        function gap = get_gap(obj, tol, absTol, spin)
            if nargin < 2, tol = []; end
            if nargin < 3, absTol = []; end
            if nargin < 4, spin = []; end
            [cbm, vbm] = obj.get_cbm_vbm(tol, absTol, spin);
            gap = max(cbm - vbm, 0);
        end

        function value = plus(obj, other)
            if ~isequal(obj.energies, other.energies)
                error("KSSOLV:Matgenlab:Dos:IncompatibleEnergies", ...
                    "Energies of both DOS are not compatible.");
            end
            value = kssolv.analysis.matgenlab.electronic_structure.Dos( ...
                obj.efermi, obj.energies, ...
                kssolv.analysis.matgenlab.electronic_structure. ...
                add_densities(obj.densities, other.densities));
        end

        function value = as_dict(obj)
            keys = cell(1, 0);
            channels = cell(1, 0);
            if isfield(obj.densities, "up")
                keys{end + 1} = '1';
                channels{end + 1} = obj.densities.up;
            end
            if isfield(obj.densities, "down")
                keys{end + 1} = '-1';
                channels{end + 1} = obj.densities.down;
            end
            serialized = containers.Map(keys, channels, ...
                "UniformValues", false);
            value = struct( ...
                "x_module", "pymatgen.electronic_structure.dos", ...
                "x_class", classShortName(obj), ...
                "efermi", obj.efermi, ...
                "energies", obj.energies, ...
                "densities", serialized);
        end

        function value = asDict(obj)
            value = obj.as_dict();
        end
    end

    methods (Static)
        function obj = from_dict(value)
            densities = struct();
            if isa(value.densities, "containers.Map")
                densities.up = value.densities("1");
                if isKey(value.densities, "-1")
                    densities.down = value.densities("-1");
                end
            else
                if isfield(value.densities, "x1")
                    densities.up = value.densities.x1;
                elseif isfield(value.densities, "up")
                    densities.up = value.densities.up;
                end
                if isfield(value.densities, "x_1")
                    densities.down = value.densities.x_1;
                elseif isfield(value.densities, "down")
                    densities.down = value.densities.down;
                end
            end
            obj = kssolv.analysis.matgenlab.electronic_structure.Dos( ...
                value.efermi, value.energies, densities);
        end
    end

    methods (Static, Access = private)
        function value = normalizeDensities(input)
            if isstruct(input)
                value = struct();
                names = fieldnames(input);
                for index = 1:numel(names)
                    field = names{index};
                    normalized = ...
                        kssolv.analysis.matgenlab.electronic_structure.Dos. ...
                        spinField(field);
                    value.(normalized) = input.(field);
                end
            elseif isa(input, "containers.Map")
                value = struct();
                keys = input.keys;
                for index = 1:numel(keys)
                    field = ...
                        kssolv.analysis.matgenlab.electronic_structure.Dos. ...
                        spinField(keys{index});
                    value.(field) = input(keys{index});
                end
            elseif isnumeric(input)
                if isvector(input)
                    value = struct("up", reshape(input, 1, []));
                elseif size(input, 2) == 1 || size(input, 2) == 2
                    value = struct("up", reshape(input(:, 1), 1, []));
                    if size(input, 2) == 2
                        value.down = reshape(input(:, 2), 1, []);
                    end
                elseif size(input, 1) == 1 || size(input, 1) == 2
                    value = struct("up", reshape(input(1, :), 1, []));
                    if size(input, 1) == 2
                        value.down = reshape(input(2, :), 1, []);
                    end
                else
                    error("KSSOLV:Matgenlab:Dos:InvalidDensities", ...
                        "Numeric densities must contain one or two channels.");
                end
            else
                error("KSSOLV:Matgenlab:Dos:InvalidDensities", ...
                    "Unsupported density mapping.");
            end
            if isempty(fieldnames(value))
                error("KSSOLV:Matgenlab:Dos:MissingDensities", ...
                    "At least one spin density channel is required.");
            end
        end

        function value = spinField(spin)
            if isa(spin, ...
                    "kssolv.analysis.matgenlab.electronic_structure.Spin")
                spin = double(spin);
            end
            text = lower(string(spin));
            if any(text == ["1", "up", "x1"])
                value = "up";
            elseif any(text == ["-1", "down", "x_1"])
                value = "down";
            else
                error("KSSOLV:Matgenlab:Dos:InvalidSpin", ...
                    "Spin must be up/1 or down/-1.");
            end
        end

        function output = gaussianFilter(input, sigma)
            if sigma <= 0
                output = input;
                return
            end
            radius = round(4 * sigma);
            offsets = -radius:radius;
            weights = exp(-0.5 * (offsets / sigma).^2);
            weights = weights / sum(weights);
            input = reshape(double(input), 1, []);
            count = numel(input);
            output = zeros(size(input));
            for center = 1:count
                indices = center + offsets;
                for index = 1:numel(indices)
                    candidate = indices(index);
                    while candidate < 1 || candidate > count
                        if candidate < 1
                            candidate = 1 - candidate;
                        else
                            candidate = 2 * count + 1 - candidate;
                        end
                    end
                    output(center) = output(center) + ...
                        weights(index) * input(candidate);
                end
            end
        end
    end
end

function value = classShortName(obj)
name = split(string(class(obj)), ".");
value = name(end);
end
