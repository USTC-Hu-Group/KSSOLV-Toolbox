classdef BandStructureSymmLine < ...
        kssolv.analysis.matgenlab.electronic_structure.BandStructure
    %BANDSTRUCTURESYMMLINE Band structure along labeled symmetry branches.

    properties (SetAccess = private)
        distance (1,:) double
        branches cell
    end

    methods
        function obj = BandStructureSymmLine(kpoints, eigenvalues, lattice, ...
                efermi, labels, coordsAreCartesian, structure, projections)
            if nargin < 6, coordsAreCartesian = false; end
            if nargin < 7, structure = []; end
            if nargin < 8, projections = struct(); end
            obj@kssolv.analysis.matgenlab.electronic_structure. ...
                BandStructure(kpoints, eigenvalues, lattice, efermi, ...
                labels, coordsAreCartesian, structure, projections);
            count = numel(obj.kpoints);
            obj.distance = zeros(1, count);
            groups = cell(1, 0);
            current = zeros(1, 0);
            previous = obj.kpoints{1};
            previousLabel = previous.label;
            for index = 1:count
                point = obj.kpoints{index};
                if ~isempty(point.label) && ~isempty(previousLabel)
                    obj.distance(index) = indexValue(obj.distance, index-1);
                else
                    obj.distance(index) = indexValue(obj.distance, index-1) + ...
                        norm(point.cart_coords - previous.cart_coords);
                end
                if ~isempty(point.label) && ~isempty(previousLabel) && ...
                        ~isempty(current)
                    groups{end+1} = current; %#ok<AGROW>
                    current = zeros(1,0);
                end
                current(end+1) = index; %#ok<AGROW>
                previous = point;
                previousLabel = point.label;
            end
            if ~isempty(current), groups{end+1} = current; end
            obj.branches = cell(1, numel(groups));
            for index = 1:numel(groups)
                group = groups{index};
                obj.branches{index} = struct( ...
                    "start_index", group(1), ...
                    "end_index", group(end), ...
                    "name", string(obj.kpoints{group(1)}.label) + "-" + ...
                    string(obj.kpoints{group(end)}.label));
            end
        end

        function value = get_equivalent_kpoints(obj, index)
            if isempty(obj.kpoints{index}.label)
                value = index;
            else
                label = obj.kpoints{index}.label;
                value = find(cellfun(@(point) ...
                    isequal(point.label, label), obj.kpoints));
            end
        end

        function value = get_branch(obj, index)
            equivalents = obj.get_equivalent_kpoints(index);
            value = cell(1, 0);
            for pointIndex = equivalents
                for branchIndex = 1:numel(obj.branches)
                    branch = obj.branches{branchIndex};
                    if pointIndex >= branch.start_index && ...
                            pointIndex <= branch.end_index
                        record = branch;
                        record.index = pointIndex;
                        value{end+1} = record; %#ok<AGROW>
                    end
                end
            end
        end

        function value = apply_scissor(obj, newBandGap)
            bands = obj.bands;
            if obj.is_metal()
                maximum = 0;
                names = fieldnames(bands);
                for spinIndex = 1:numel(names)
                    array = bands.(names{spinIndex});
                    for bandIndex = 1:size(array, 1)
                        if any(array(bandIndex,:) < obj.efermi) && ...
                                any(array(bandIndex,:) > obj.efermi)
                            maximum = max(maximum, bandIndex);
                        end
                    end
                end
                for spinIndex = 1:numel(names)
                    bands.(names{spinIndex})(maximum:end, :) = ...
                        bands.(names{spinIndex})(maximum:end, :) + newBandGap;
                end
                newFermi = obj.efermi;
            else
                shift = newBandGap - obj.get_band_gap().energy;
                threshold = obj.get_cbm().energy;
                names = fieldnames(bands);
                for spinIndex = 1:numel(names)
                    array = bands.(names{spinIndex});
                    array(array >= threshold) = array(array >= threshold) + shift;
                    bands.(names{spinIndex}) = array;
                end
                newFermi = obj.efermi + shift;
            end
            labels = containers.Map( ...
                "KeyType", "char", "ValueType", "any");
            keys = obj.labels_dict.keys;
            for index = 1:numel(keys)
                labels(keys{index}) = obj.labels_dict(keys{index}).frac_coords;
            end
            coordinates = cell2mat(cellfun(@(point) point.frac_coords, ...
                obj.kpoints, UniformOutput=false).');
            value = kssolv.analysis.matgenlab.electronic_structure. ...
                BandStructureSymmLine(coordinates, bands, obj.lattice_rec, ...
                newFermi, labels, false, obj.structure, obj.projections);
        end

        function value = as_dict(obj)
            value = as_dict@kssolv.analysis.matgenlab. ...
                electronic_structure.BandStructure(obj);
            value.branches = obj.branches;
        end
    end
end

function value = indexValue(array, index)
if index < 1, value = 0; else, value = array(index); end
end
