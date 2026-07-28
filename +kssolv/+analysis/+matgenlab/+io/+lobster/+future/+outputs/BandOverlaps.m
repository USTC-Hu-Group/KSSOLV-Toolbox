classdef BandOverlaps < kssolv.analysis.matgenlab.io.lobster.future.LobsterFile
    %#ok<*MCSCT,*ALIGN,*AGROW,*ISCL,*MCNPN,*STOUT,*UNRCH,*MCCBU,*MSNU>
    %BANDOVERLAPS Parser and quality checks for band-overlap matrices.
    methods
        function obj = BandOverlaps(varargin)
            obj@kssolv.analysis.matgenlab.io.lobster.future.LobsterFile(varargin{:});
        end
        function parse_file_v3_2_legacy(obj), obj.parse_file([0, 1]); end
        function parse_file_v4_0(obj), obj.parse_file([1, 2]); end
        function parse_file(obj, spin_numbers)
            if nargin < 2
                if kssolv.analysis.matgenlab.io.lobster.future.LobsterFile. ...
                        check_version(obj.lobster_version, "4.0", [])
                    spin_numbers = [1, 2];
                else, spin_numbers = [0, 1]; end
            end
            linesValue = obj.iterate_lines();
            current = "up";
            obj.spins = {"up"};
            points = struct("up", []);
            deviations = struct("up", []);
            matrices = struct("up", {{}});
            currentPoint = 0;
            rowValues = {};
            for index = 1:numel(linesValue)
                line = linesValue{index};
                if contains(line, "for spin " + string(spin_numbers(1)))
                    current = "up";
                elseif contains(line, "for spin " + string(spin_numbers(2)))
                    current = "down";
                    if ~isfield(points, "down")
                        obj.spins{end + 1} = "down";
                        points.down = [];
                        deviations.down = [];
                        matrices.down = {};
                    end
                elseif contains(line, "k-point")
                    values = sscanf(line, "%*s %*s %f %f %f");
                    if numel(values) < 3
                        token = regexp(line, ...
                            "([+-]?\d*\.\d+)\s+([+-]?\d*\.\d+)\s+([+-]?\d*\.\d+)\s*$", ...
                            "tokens", "once");
                        values = str2double(token);
                    end
                    points.(current)(end + 1, :) = reshape(values(end-2:end), 1, 3);
                    currentPoint = size(points.(current), 1);
                    rowValues = {};
                elseif contains(line, "maxDeviation")
                    values = regexp(line, "([+-]?\d*\.\d+(?:[Ee][+-]?\d+)?)", ...
                        "match");
                    deviations.(current)(end + 1) = str2double(values{end});
                elseif currentPoint > 0 && ~isempty(line)
                    values = sscanf(line, "%f").';
                    if ~isempty(values), rowValues{end + 1} = values; end
                    count = numel(rowValues);
                    if count > 0 && all(cellfun(@numel, rowValues) == count)
                        matrices.(current){currentPoint} = vertcat(rowValues{:});
                    end
                end
            end
            obj.band_overlaps = struct("k_points", points, ...
                "max_deviations", deviations, "matrices", matrices);
        end
        function good = has_good_quality_max_deviation(obj, limit)
            if nargin < 2 || isempty(limit), limit = 0.1; end
            good = true;
            for spin = string(obj.spins)
                good = good && all(obj.band_overlaps.max_deviations.(spin) <= limit);
            end
        end
        function good = has_good_quality_check_occupied_bands( ...
                obj, number_up, number_down, spin_polarized, limit)
            if nargin < 3, number_down = []; end
            if nargin < 4 || isempty(spin_polarized), spin_polarized = false; end
            if nargin < 5 || isempty(limit), limit = 0.1; end
            if spin_polarized && isempty(number_down)
                error("KSSOLV:Matgenlab:Lobster:OccupiedBands", ...
                    "Down-spin occupied-band count is required.");
            end
            names = "up";
            counts = number_up;
            if spin_polarized, names(end + 1) = "down"; counts(end + 1) = number_down; end
            good = true;
            for spin = 1:numel(names)
                matrixList = obj.band_overlaps.matrices.(names(spin));
                for index = 1:numel(matrixList)
                    submatrix = matrixList{index}(1:counts(spin), 1:counts(spin));
                    good = good && all(abs(submatrix - eye(counts(spin))) <= limit, "all");
                end
            end
        end
        function name = get_default_filename(~), name = "bandOverlaps.lobster"; end
    end
    methods (Static)
        function obj = from_dict(value)
            obj = kssolv.analysis.matgenlab.io.lobster.future.LobsterFile. ...
                from_dict(value, "BandOverlaps");
        end
    end
end
