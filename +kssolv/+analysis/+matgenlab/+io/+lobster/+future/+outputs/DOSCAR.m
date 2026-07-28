classdef DOSCAR < kssolv.analysis.matgenlab.io.lobster.future.LobsterFile
    %#ok<*MCSCT,*ALIGN,*AGROW,*ISCL,*MCNPN,*STOUT,*UNRCH,*MCCBU,*MSNU>
    %DOSCAR Total and orbital-projected LOBSTER DOS reader.
    properties
        is_lcfo (1,1) logical = false
    end
    properties (Dependent, SetAccess = private)
        efermi
        energies
    end
    methods
        function obj = DOSCAR(varargin)
            obj@kssolv.analysis.matgenlab.io.lobster.future.LobsterFile(varargin{:});
        end
        function process(obj), obj.parse_file(); end
        function parse_file(obj)
            linesValue = obj.iterate_lines();
            blocks = {};
            centersValue = {};
            orbitalsValue = {};
            efermiFound = [];
            index = 6;
            while index <= numel(linesValue)
                segments = split(string(linesValue{index}), ";");
                header = sscanf(segments(1), "%f").';
                if numel(header) < 5 || header(end) ~= 1
                    index = index + 1;
                    continue
                end
                count = header(3);
                if isempty(efermiFound), efermiFound = header(4); end
                if numel(segments) >= 2 && strlength(strtrim(segments(2))) > 0
                    center = strtrim(segments(2));
                    centersValue{end + 1} = center;
                    zValue = regexp(center, "^Z=\s*(\d+)$", "tokens", "once");
                    if ~isempty(zValue)
                        element = kssolv.analysis.matgenlab.core.Element. ...
                            from_Z(str2double(zValue{1}));
                        centersValue{end} = char(element.symbol);
                    end
                end
                if numel(segments) >= 3 && strlength(strtrim(segments(3))) > 0
                    orbitalsValue{end + 1} = regexp( ...
                        strtrim(segments(3)), "\s+", "split");
                end
                table = [];
                for row = 1:count
                    index = index + 1;
                    values = sscanf(linesValue{index}, "%f").';
                    if isempty(table), table = zeros(count, numel(values)); end
                    table(row, :) = values;
                end
                blocks{end + 1} = table;
                index = index + 1;
            end
            if isempty(blocks)
                error("KSSOLV:Matgenlab:Lobster:DOSCAR", ...
                    "No DOS blocks were found.");
            end
            total = blocks{1};
            obj.spins = {"up"};
            if size(total, 2) == 5, obj.spins{end + 1} = "down";
            elseif size(total, 2) ~= 3
                error("KSSOLV:Matgenlab:Lobster:DOSCAR", ...
                    "Unsupported total DOS column count.");
            end
            totalDensity = struct("up", total(:, 2).');
            integrated = struct();
            if numel(obj.spins) == 2
                totalDensity.down = total(:, 3).';
                integrated.up = total(:, 4).';
                integrated.down = total(:, 5).';
            else
                integrated.up = total(:, 3).';
            end
            DosClass = @kssolv.analysis.matgenlab.electronic_structure.Dos;
            obj.total_dos = DosClass(efermiFound, total(:, 1), totalDensity);
            obj.integrated_total_dos = DosClass( ...
                efermiFound, total(:, 1), integrated);
            obj.projected_dos = struct();
            counts = struct();
            for blockIndex = 2:numel(blocks)
                center = string(centersValue{blockIndex - 1});
                base = matlab.lang.makeValidName(center);
                if ~isfield(counts, base), counts.(base) = 0; end
                counts.(base) = counts.(base) + 1;
                separator = "";
                if obj.is_lcfo, separator = "_"; end
                label = matlab.lang.makeValidName(center + separator + ...
                    string(counts.(base)));
                obj.projected_dos.(label) = struct();
                table = blocks{blockIndex};
                orbitals = orbitalsValue{blockIndex - 1};
                for orbitalIndex = 1:numel(orbitals)
                    density = struct();
                    for spin = 1:numel(obj.spins)
                        column = 1 + spin + (orbitalIndex - 1) * numel(obj.spins);
                        density.(obj.spins{spin}) = table(:, column).';
                    end
                    name = matlab.lang.makeValidName(orbitals{orbitalIndex});
                    obj.projected_dos.(label).(name) = ...
                        DosClass(efermiFound, table(:, 1), density);
                end
            end
        end
        function value = get.efermi(obj), value = obj.total_dos.efermi; end
        function value = get.energies(obj), value = obj.total_dos.energies; end
        function name = get_default_filename(obj)
            if obj.is_lcfo, name = "DOSCAR.LCFO.lobster";
            else, name = "DOSCAR.lobster"; end
        end
    end
end
