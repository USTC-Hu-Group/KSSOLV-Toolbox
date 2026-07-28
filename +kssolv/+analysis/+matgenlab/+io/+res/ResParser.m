classdef ResParser
    %RESPARSER Parser for ShelX RES text, including AIRSS extensions.

    properties (SetAccess = private)
        line (1,1) double = 0
        filename (1,1) string = ""
        source (1,1) string = ""
    end

    methods
        function obj = ResParser()
        end
    end

    methods (Static)
        function value = parse_str(source)
            value = kssolv.analysis.matgenlab.io.res.ResParser. ...
                parse_text(string(source));
        end

        function value = parse_file(filename)
            value = kssolv.analysis.matgenlab.io.res.ResParser. ...
                parse_text(kssolv.analysis.matgenlab.io.res.ResIOUtils. ...
                read_text(filename));
        end

        function value = from_str(source)
            value = kssolv.analysis.matgenlab.io.res.ResParser. ...
                parse_str(source);
        end

        function value = from_file(filename)
            value = kssolv.analysis.matgenlab.io.res.ResParser. ...
                parse_file(filename);
        end
    end

    methods (Static, Access = private)
        function value = parse_text(source)
            lines = splitlines(string(source));
            title = [];
            rems = strings(1, 0);
            cellRecord = [];
            sfac = [];
            index = 1;
            while index <= numel(lines)
                line = char(lines(index));
                index = index + 1;
                trimmed = strtrim(line);
                if isempty(trimmed), continue; end
                separator = regexp(trimmed, '\s', 'once');
                rest = "";
                if isempty(separator)
                    tag = string(trimmed);
                else
                    tag = string(trimmed(1:separator - 1));
                    rest = string(strtrim(trimmed(separator + 1:end)));
                end
                switch tag
                    case "TITL"
                        title = kssolv.analysis.matgenlab.io.res. ...
                            ResParser.parse_titl(rest);
                    case "REM"
                        rems(end + 1) = rest; %#ok<AGROW>
                    case "CELL"
                        cellRecord = kssolv.analysis.matgenlab.io.res. ...
                            ResParser.parse_cell(rest);
                    case "LATT"
                        % AIRSS emits LATT -1; pymatgen deliberately ignores it.
                    case "SFAC"
                        [sfac, index] = ...
                            kssolv.analysis.matgenlab.io.res.ResParser. ...
                            parse_sfac(rest, lines, index);
                    otherwise
                        error("KSSOLV:Matgenlab:ResParseError", ...
                            "Skipping line '%s': tag '%s' is not recognized.", ...
                            line, tag);
                end
            end
            if isempty(cellRecord) || isempty(sfac)
                error("KSSOLV:Matgenlab:ResParseError", ...
                    "Did not encounter CELL or SFAC entry when parsing.");
            end
            value = kssolv.analysis.matgenlab.io.res.Res( ...
                title, rems, cellRecord, sfac);
        end

        function value = parse_titl(line)
            fields = regexp(strtrim(char(line)), '\s+', 'split');
            if numel(fields) < 6 || ...
                    (isscalar(fields) && isempty(fields{1}))
                value = [];
                return
            end
            seed = string(fields{1});
            numeric = cellfun(@str2double, fields(2:6));
            if any(isnan(numeric))
                error("KSSOLV:Matgenlab:ResParseError", ...
                    "Failed to parse numeric TITL fields.");
            end
            spacegroup = "P1";
            appearances = 1;
            if numel(fields) >= 7
                rest = strjoin(string(fields(7:end)), " ");
                group = regexp(char(rest), '\(([^)]*)\)', ...
                    'tokens', 'once');
                if ~isempty(group), spacegroup = string(group{1}); end
                count = regexp(char(rest), 'n\s*-\s*([+-]?\d+)', ...
                    'tokens', 'once');
                if ~isempty(count), appearances = str2double(count{1}); end
            end
            value = kssolv.analysis.matgenlab.io.res.AirssTITL( ...
                seed, numeric(1), numeric(2), numeric(3), numeric(4), ...
                numeric(5), spacegroup, appearances);
        end

        function value = parse_cell(line)
            fields = regexp(strtrim(char(line)), '\s+', 'split');
            if numel(fields) ~= 7
                error("KSSOLV:Matgenlab:ResParseError", ...
                    "Failed to parse CELL '%s'; expected 7 fields.", line);
            end
            values = cellfun(@str2double, fields);
            if any(isnan(values))
                error("KSSOLV:Matgenlab:ResParseError", ...
                    "Failed to parse numeric CELL fields.");
            end
            value = kssolv.analysis.matgenlab.io.res.ResCELL(values(1), ...
                values(2), values(3), values(4), values(5), ...
                values(6), values(7));
        end

        function value = parse_ion(line)
            fields = regexp(strtrim(char(line)), '\s+', 'split');
            if ~ismember(numel(fields), [6, 7])
                error("KSSOLV:Matgenlab:ResParseError", ...
                    "Failed to parse ion entry '%s'; expected 6 or 7 fields.", ...
                    line);
            end
            specieNumber = str2double(fields{2});
            values = cellfun(@str2double, fields(3:6));
            spin = [];
            if numel(fields) == 7, spin = str2double(fields{7}); end
            if isnan(specieNumber) || any(isnan(values)) || ...
                    (~isempty(spin) && isnan(spin))
                error("KSSOLV:Matgenlab:ResParseError", ...
                    "Failed to parse numeric ion fields in '%s'.", line);
            end
            value = kssolv.analysis.matgenlab.io.res.Ion(fields{1}, ...
                specieNumber, values(1:3), values(4), spin);
        end

        function [value, index] = parse_sfac(line, lines, index)
            text = strtrim(char(line));
            if isempty(text), species = strings(1, 0);
            else, species = string(regexp(text, '\s+', 'split'));
            end
            ions = cell(1, 0);
            foundEnd = false;
            while index <= numel(lines)
                current = string(lines(index));
                index = index + 1;
                if strtrim(current) == "END"
                    foundEnd = true;
                    break
                end
                ions{end + 1} = ...
                    kssolv.analysis.matgenlab.io.res.ResParser. ...
                    parse_ion(current); %#ok<AGROW>
            end
            if ~foundEnd
                error("KSSOLV:Matgenlab:ResParseError", ...
                    "Encountered end of file before END tag at end of SFAC block.");
            end
            value = kssolv.analysis.matgenlab.io.res.ResSFAC(species, ions);
        end
    end
end
