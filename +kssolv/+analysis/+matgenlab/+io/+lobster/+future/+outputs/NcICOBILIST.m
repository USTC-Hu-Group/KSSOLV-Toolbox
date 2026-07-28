classdef NcICOBILIST < ...
        kssolv.analysis.matgenlab.io.lobster.future.outputs.ICOXXLIST
    %#ok<*MCSCT,*ALIGN,*AGROW,*ISCL,*MCNPN,*STOUT,*UNRCH,*MCCBU,*MSNU>
    %NCICOBILIST Multi-center integrated COBI list reader.
    methods
        function obj = NcICOBILIST(varargin)
            obj@kssolv.analysis.matgenlab.io.lobster.future.outputs. ...
                ICOXXLIST(varargin{:});
            obj.icoxxlist_type = "COBI";
        end
        function parse_file(obj)
            linesValue = obj.iterate_lines();
            obj.interactions = {};
            obj.spins = {};
            currentSpin = "";
            counter = 0;
            for index = 1:numel(linesValue)
                line = linesValue{index};
                spin = regexp(line, "(?i)for spin\s+(\d)", "tokens", "once");
                if ~isempty(spin)
                    if str2double(spin{1}) == 1, currentSpin = "up";
                    else, currentSpin = "down"; counter = 0; end
                    if ~any(string(obj.spins) == currentSpin)
                        obj.spins{end + 1} = char(currentSpin);
                    end
                    continue
                end
                match = regexp(line, ...
                    "^\s*(\d+)\s+(\d+)\s+(-?\d+\.\d+)\s+(.+)$", ...
                    "tokens", "once");
                if isempty(match), continue; end
                parts = split(string(match{4}), "->");
                centers = cell(1, numel(parts));
                cells = cell(1, numel(parts));
                orbitals = cell(1, numel(parts));
                length = [];
                for part = 1:numel(parts)
                    token = regexp(char(parts(part)), ...
                        "^\s*([A-Za-z]+\d+)(?:\[(-?\d+\s+-?\d+\s+-?\d+)\])?" + ...
                        "(?:\[([^]]+)\])?(?:\(([^)]+)\))?", ...
                        "tokens", "once");
                    if isempty(token)
                        centers{part} = char(strtrim(parts(part)));
                        cells{part} = [];
                        orbitals{part} = [];
                        continue
                    end
                    centers{part} = token{1};
                    if numel(token) >= 2 && ~isempty(token{2})
                        cells{part} = sscanf(token{2}, "%d").';
                    else, cells{part} = []; end
                    if numel(token) >= 3 && ~isempty(token{3})
                        orbitals{part} = token{3};
                    else, orbitals{part} = []; end
                    if numel(token) >= 4 && ~isempty(token{4})
                        length = str2double(token{4});
                    end
                end
                if currentSpin == "down"
                    counter = counter + 1;
                    value = obj.interactions{counter};
                    value.icoxx.down = str2double(match{3});
                    obj.interactions{counter} = value;
                else
                    value = struct("index", str2double(match{1}), ...
                        "centers", {centers}, "cells", {cells}, ...
                        "orbitals", {orbitals}, "length", length, ...
                        "icoxx", struct("up", str2double(match{3})));
                    obj.interactions{end + 1} = value;
                end
            end
            if isempty(obj.spins), obj.spins = {"up"}; end
            obj.data = nan(numel(obj.interactions), numel(obj.spins));
            obj.process_data_into_interactions(false);
        end
        function name = get_default_filename(~), name = "NcICOBILIST.lobster"; end
    end
end
