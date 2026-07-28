classdef CifBlock
    %CIFBLOCK One CIF 1.1 data block.
    %
    % Compatible with pymatgen-core v2026.7.24, pymatgen.io.cif.CifBlock.
    % CIF data names are kept verbatim. Values in loops are represented by
    % cell arrays; scalar values are represented by character vectors.

    properties (Constant)
        max_len = 70
    end

    properties
        data containers.Map
        loops cell = cell(1, 0)
        header (1,1) string = ""
    end

    properties (SetAccess = private)
        key_order (1,:) string = strings(1, 0)
    end

    methods
        function obj = CifBlock(data, loops, header)
            if nargin == 0
                data = containers.Map("KeyType", "char", "ValueType", "any");
                loops = cell(1, 0);
                header = "";
            end
            [obj.data, obj.key_order] = ...
                kssolv.analysis.matgenlab.io.cif.CifBlock.normalizeData(data);
            obj.loops = ...
                kssolv.analysis.matgenlab.io.cif.CifBlock.normalizeLoops(loops);
            value = char(string(header));
            if numel(value) > 74, value = value(1:74); end
            obj.header = string(value);
        end

        function tf = eq(obj, other)
            if ~isa(other, "kssolv.analysis.matgenlab.io.cif.CifBlock") || ...
                    obj.header ~= other.header || ...
                    ~isequal(obj.loops, other.loops) || ...
                    obj.data.Count ~= other.data.Count
                tf = false;
                return
            end
            tf = true;
            for key = obj.key_order
                name = char(key);
                if ~isKey(other.data, name) || ...
                        ~isequal(obj.data(name), other.data(name))
                    tf = false;
                    return
                end
            end
        end

        function tf = ne(obj, other), tf = ~eq(obj, other); end

        function varargout = subsref(obj, reference)
            if strcmp(reference(1).type, "()") && ...
                    isscalar(reference(1).subs)
                key = char(string(reference(1).subs{1}));
                if ~isKey(obj.data, key)
                    error("KSSOLV:Matgenlab:CifBlock:MissingKey", ...
                        "CIF data name '%s' is not present.", key);
                end
                value = obj.data(key);
                if numel(reference) > 1
                    value = builtin("subsref", value, reference(2:end));
                end
                varargout{1} = value;
            else
                [varargout{1:nargout}] = builtin("subsref", obj, reference);
            end
        end

        function value = char(obj)
            lines = "data_" + obj.header;
            written = strings(1, 0);
            for key = obj.key_order
                if any(written == key), continue; end
                loop = obj.loopContaining(key);
                if ~isempty(loop)
                    lines(end + 1) = obj.loop_to_str(loop); %#ok<AGROW>
                    written = [written, string(loop)]; %#ok<AGROW>
                    continue
                end
                name = char(key);
                field = obj.format_field(obj.data(name));
                if ~contains(field, newline) && ...
                        strlength(key) + strlength(field) + 3 < obj.max_len
                    lines(end + 1) = key + "   " + field; %#ok<AGROW>
                else
                    lines(end + 1) = key; %#ok<AGROW>
                    lines(end + 1) = field; %#ok<AGROW>
                end
                written(end + 1) = key; %#ok<AGROW>
            end
            value = char(strjoin(lines, newline));
        end

        function value = string(obj), value = string(char(obj)); end

        function value = loop_to_str(obj, loop)
            loop = reshape(string(loop), 1, []);
            lines = ["loop_", " " + loop];
            columns = cell(1, numel(loop));
            numberRows = [];
            for index = 1:numel(loop)
                columns{index} = obj.asList(obj.data(char(loop(index))));
                if isempty(numberRows), numberRows = numel(columns{index}); end
                if numel(columns{index}) ~= numberRows
                    error("KSSOLV:Matgenlab:CifBlock:LoopLength", ...
                        "Loop columns must have equal lengths.");
                end
            end
            for row = 1:numberRows
                current = "";
                for column = 1:numel(columns)
                    field = obj.format_field(columns{column}{row});
                    if startsWith(field, ";")
                        if current ~= "", lines(end + 1) = current; end %#ok<AGROW>
                        lines(end + 1) = ""; %#ok<AGROW>
                        lines(end + 1) = field; %#ok<AGROW>
                        current = "";
                    elseif strlength(current) + strlength(field) + 2 < obj.max_len
                        current = current + "  " + field;
                    else
                        if current ~= "", lines(end + 1) = current; end %#ok<AGROW>
                        current = "  " + field;
                    end
                end
                if current ~= "", lines(end + 1) = current; end %#ok<AGROW>
            end
            value = strjoin(lines, newline);
        end

        function value = format_field(obj, input)
            if ismissing(string(input))
                value = "?";
                return
            end
            if isnumeric(input) || islogical(input)
                input = string(input);
            end
            value = strtrim(string(input));
            if value == ""
                value = '""';
                return
            end
            if strlength(value) > obj.max_len || contains(value, newline)
                % A CIF text field delimiter must occur at the beginning of a
                % line. Preserve existing newlines, wrapping only long words.
                text = char(value);
                wrapped = obj.wrapText(text, obj.max_len);
                value = ";" + newline + string(wrapped) + newline + ";";
                return
            end
            first = extractBetween(value, 1, 1);
            alreadyQuoted = (startsWith(value, "'") && endsWith(value, "'")) || ...
                (startsWith(value, '"') && endsWith(value, '"'));
            if (contains(value, [" ", sprintf("\t")]) || first == "_") && ...
                    ~alreadyQuoted
                if contains(value, "'"), quote = '"'; else, quote = "'"; end
                value = quote + value + quote;
            end
        end

    end

    methods (Static)
        function tokens = process_string(contents)
            % Tokenize CIF 1.1 text. Semicolon text fields, quoted values,
            % comments, CRLF and non-ASCII input follow pymatgen semantics.
            bytes = uint16(char(string(contents)));
            bytes = bytes(bytes <= 127);
            text = char(bytes);
            text = strrep(text, sprintf("\r\n"), newline);
            text = strrep(text, sprintf("\r"), newline);
            lines = regexp(text, "\n", "split");
            tokens = cell(1, 0);
            multiline = false;
            accumulated = strings(1, 0);
            for lineIndex = 1:numel(lines)
                line = lines{lineIndex};
                if multiline
                    if ~isempty(line) && line(1) == ';'
                        value = char(strjoin(accumulated, " "));
                        if startsWith(value, "_") || ...
                                any(strcmpi(value, {"loop_", "stop_", "global_"})) || ...
                                any(startsWith(lower(string(value)), ["data_", "save_"]))
                            value = [char(1), value]; %#ok<AGROW>
                        end
                        tokens{end + 1} = value; %#ok<AGROW>
                        accumulated = strings(1, 0);
                        multiline = false;
                        line = strtrim(line(2:end));
                    else
                        accumulated(end + 1) = string(line); %#ok<AGROW>
                        continue
                    end
                elseif ~isempty(line) && line(1) == ';'
                    multiline = true;
                    accumulated(end + 1) = string(strtrim(line(2:end))); %#ok<AGROW>
                    continue
                end

                position = 1;
                while position <= numel(line)
                    while position <= numel(line) && isspace(line(position))
                        position = position + 1;
                    end
                    if position > numel(line) || line(position) == '#', break; end
                    if line(position) == '''' || line(position) == '"'
                        quote = line(position);
                        position = position + 1;
                        start = position;
                        while position <= numel(line)
                            if line(position) == quote && ...
                                    (position == numel(line) || ...
                                    isspace(line(position + 1)) || ...
                                    line(position + 1) == '#')
                                break
                            end
                            position = position + 1;
                        end
                        if position > numel(line)
                            value = line(start:end);
                        else
                            value = line(start:position - 1);
                            position = position + 1;
                        end
                        if startsWith(value, "_") || ...
                                any(strcmpi(value, {"loop_", "stop_", "global_"})) || ...
                                any(startsWith(lower(string(value)), ["data_", "save_"]))
                            value = [char(1), value]; %#ok<AGROW>
                        end
                        tokens{end + 1} = value; %#ok<AGROW>
                    else
                        start = position;
                        while position <= numel(line) && ~isspace(line(position))
                            position = position + 1;
                        end
                        token = line(start:position - 1);
                        % A # only starts a comment at token boundary.
                        tokens{end + 1} = token; %#ok<AGROW>
                    end
                end
            end
            if multiline
                error("KSSOLV:Matgenlab:CifBlock:UnterminatedTextField", ...
                    "Unterminated semicolon-delimited CIF text field.");
            end
        end

        function obj = from_str(contents)
            tokens = ...
                kssolv.analysis.matgenlab.io.cif.CifBlock.process_string(contents);
            if isempty(tokens) || ~startsWith(lower(string(tokens{1})), "data_")
                error("KSSOLV:Matgenlab:CifBlock:MissingHeader", ...
                    "A CIF block must begin with a data_ header.");
            end
            header = extractAfter(string(tokens{1}), 5);
            data = containers.Map("KeyType", "char", "ValueType", "any");
            order = strings(1, 0);
            loops = cell(1, 0);
            cursor = 2;
            while cursor <= numel(tokens)
                token = string(tokens{cursor});
                lowered = lower(token);
                if lowered == "_eof" || startsWith(lowered, "data_") || ...
                        startsWith(lowered, "save_") || lowered == "global_"
                    break
                elseif startsWith(token, "_")
                    key = char(token);
                    cursor = cursor + 1;
                    if cursor <= numel(tokens)
                        next = string(tokens{cursor});
                        if startsWith(next, "_") || lower(next) == "loop_" || ...
                                startsWith(lower(next), "data_")
                            value = "";
                        else
                            value = ...
                                kssolv.analysis.matgenlab.io.cif.CifBlock.cleanToken(next);
                            cursor = cursor + 1;
                        end
                    else
                        value = "";
                    end
                    if ~isKey(data, key), order(end + 1) = string(key); end %#ok<AGROW>
                    data(key) = value;
                elseif lowered == "loop_"
                    cursor = cursor + 1;
                    columns = strings(1, 0);
                    while cursor <= numel(tokens) && startsWith(string(tokens{cursor}), "_")
                        key = string(tokens{cursor});
                        columns(end + 1) = key; %#ok<AGROW>
                        if ~isKey(data, char(key)), order(end + 1) = key; end %#ok<AGROW>
                        data(char(key)) = cell(1, 0);
                        cursor = cursor + 1;
                    end
                    if isempty(columns)
                        error("KSSOLV:Matgenlab:CifBlock:EmptyLoop", ...
                            "A loop_ must declare at least one data name.");
                    end
                    values = cell(1, 0);
                    while cursor <= numel(tokens)
                        candidate = string(tokens{cursor});
                        lowCandidate = lower(candidate);
                        if startsWith(candidate, "_") || lowCandidate == "loop_" || ...
                                startsWith(lowCandidate, "data_") || ...
                                startsWith(lowCandidate, "save_") || ...
                                lowCandidate == "stop_" || lowCandidate == "_eof"
                            if lowCandidate == "stop_", cursor = cursor + 1; end
                            break
                        end
                        values{end + 1} = ...
                            kssolv.analysis.matgenlab.io.cif.CifBlock. ...
                            cleanToken(candidate); %#ok<AGROW>
                        cursor = cursor + 1;
                    end
                    if mod(numel(values), numel(columns)) ~= 0
                        error("KSSOLV:Matgenlab:CifBlock:LoopCardinality", ...
                            "%d loop values are not a multiple of %d columns.", ...
                            numel(values), numel(columns));
                    end
                    numberRows = numel(values) / numel(columns);
                    for column = 1:numel(columns)
                        data(char(columns(column))) = ...
                            values(column:numel(columns):numberRows*numel(columns));
                    end
                    loops{end + 1} = cellstr(columns); %#ok<AGROW>
                else
                    warning("KSSOLV:Matgenlab:CifBlock:PossibleIssue", ...
                        "Possible issue in CIF file near token: %s", token);
                    cursor = cursor + 1;
                end
            end
            obj = kssolv.analysis.matgenlab.io.cif.CifBlock(data, loops, header);
            obj.key_order = order;
        end

        function obj = fromString(contents), obj = ...
                kssolv.analysis.matgenlab.io.cif.CifBlock.from_str(contents); end
    end

    methods (Access = private)
        function loop = loopContaining(obj, key)
            loop = {};
            for index = 1:numel(obj.loops)
                if any(string(obj.loops{index}) == key)
                    loop = obj.loops{index};
                    return
                end
            end
        end

        function values = asList(~, value)
            if iscell(value), values = reshape(value, 1, []);
            elseif isstring(value) && ~isscalar(value)
                values = cellstr(reshape(value, 1, []));
            elseif isnumeric(value) && ~isscalar(value)
                values = num2cell(reshape(value, 1, []));
            else, values = {value};
            end
        end

        function output = wrapText(~, input, width)
            sourceLines = regexp(input, "\r\n|\r|\n", "split");
            outputLines = strings(1, 0);
            for source = sourceLines
                remaining = char(source{1});
                while numel(remaining) > width
                    splitAt = find(isspace(remaining(1:width + 1)), 1, "last");
                    if isempty(splitAt) || splitAt == 1, splitAt = width; end
                    outputLines(end + 1) = string(strtrim(remaining(1:splitAt))); %#ok<AGROW>
                    remaining = strtrim(remaining(splitAt + 1:end));
                end
                outputLines(end + 1) = string(remaining); %#ok<AGROW>
            end
            output = char(strjoin(outputLines, newline));
        end
    end

    methods (Static, Access = private)
        function value = cleanToken(input)
            value = char(string(input));
            if ~isempty(value) && value(1) == char(1), value = value(2:end); end
        end

        function [map, order] = normalizeData(input)
            map = containers.Map("KeyType", "char", "ValueType", "any");
            order = strings(1, 0);
            if isa(input, "containers.Map")
                names = string(keys(input));
                for name = names
                    map(char(name)) = input(char(name));
                    order(end + 1) = name; %#ok<AGROW>
                end
            elseif isstruct(input)
                names = fieldnames(input);
                for index = 1:numel(names)
                    original = names{index};
                    name = original;
                    if startsWith(name, "x_"), name = name(2:end); end
                    map(name) = input.(original);
                    order(end + 1) = string(name); %#ok<AGROW>
                end
            elseif isa(input, "dictionary")
                names = string(keys(input));
                for name = reshape(names, 1, [])
                    map(char(name)) = input(name);
                    order(end + 1) = name; %#ok<AGROW>
                end
            elseif iscell(input) && size(input, 2) == 2
                for index = 1:size(input, 1)
                    name = char(string(input{index, 1}));
                    map(name) = input{index, 2};
                    order(end + 1) = string(name); %#ok<AGROW>
                end
            else
                error("KSSOLV:Matgenlab:CifBlock:InvalidData", ...
                    "data must be a struct, mapping, dictionary, or N-by-2 cell array.");
            end
        end

        function output = normalizeLoops(input)
            if isempty(input), output = cell(1, 0); return; end
            if ~iscell(input)
                error("KSSOLV:Matgenlab:CifBlock:InvalidLoops", ...
                    "loops must be a cell array of data-name groups.");
            end
            if isvector(input) && all(cellfun(@(x) ischar(x) || ...
                    (isstring(x) && isscalar(x)), input))
                output = {cellstr(string(input))};
                return
            end
            output = reshape(input, 1, []);
            for index = 1:numel(output)
                output{index} = cellstr(reshape(string(output{index}), 1, []));
            end
        end
    end
end
