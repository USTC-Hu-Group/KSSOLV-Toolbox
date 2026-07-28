classdef TagContainer < kssolv.analysis.matgenlab.io.jdftx.AbstractTag
    %TAGCONTAINER Ordered collection of named JDFTx subtags.
    properties
        subtags struct = struct()
        subtag_names string = strings(0, 1)
        linebreak_nth_entry = []
    end

    methods
        function obj = TagContainer(varargin)
            obj@kssolv.analysis.matgenlab.io.jdftx.AbstractTag();
            obj.is_tag_container = true;
            obj.allow_list_representation = true;
            obj = kssolv.analysis.matgenlab.io.jdftx.assign_options( ...
                obj, varargin{:});
            if isempty(obj.subtag_names)
                obj.subtag_names = string(fieldnames(obj.subtags));
            end
        end

        function [valid, message] = validate_value_bounds(obj, tag, value)
            valid = true;
            messages = strings(0, 1);
            entries = obj.entry_cells(value);
            for entry_idx = 1:numel(entries)
                entry = entries{entry_idx};
                if ~isstruct(entry)
                    valid = false;
                    messages(end + 1) = "Container value is not a struct."; %#ok<AGROW>
                    continue
                end
                for idx = 1:numel(obj.subtag_names)
                    name = obj.subtag_names(idx);
                    field = matlab.lang.makeValidName(name);
                    if isfield(entry, field)
                        tag_obj = obj.get_subtag(name);
                        [ok, msg] = tag_obj.validate_value_bounds( ...
                            name, entry.(field));
                        valid = valid && ok;
                        if ~ok
                            messages(end + 1) = msg; %#ok<AGROW>
                        end
                    end
                end
            end
            message = join(messages, newline);
            if ~valid && strlength(message) == 0
                message = "Value for tag '" + string(tag) + "' is invalid.";
            end
        end

        function [tag, valid, fixed] = validate_value_type(obj, tag, value, options)
            arguments
                obj
                tag
                value
                options.try_auto_type_fix (1, 1) logical = false
            end
            tag = string(tag);
            fixed = value;
            entries = obj.entry_cells(value);
            valid = ~isempty(entries) || (isstruct(value) && isempty(fieldnames(value)));
            for entry_idx = 1:numel(entries)
                if ~isstruct(entries{entry_idx})
                    valid = false;
                    continue
                end
                entry = entries{entry_idx};
                for idx = 1:numel(obj.subtag_names)
                    name = obj.subtag_names(idx);
                    field = matlab.lang.makeValidName(name);
                    tag_obj = obj.get_subtag(name);
                    if isfield(entry, field)
                        [~, ok, replacement] = tag_obj.validate_value_type( ...
                            name, entry.(field), ...
                            try_auto_type_fix = options.try_auto_type_fix);
                        valid = valid && ok;
                        entry.(field) = replacement;
                    elseif ~tag_obj.optional
                        valid = false;
                    end
                end
                entries{entry_idx} = entry;
            end
            if obj.can_repeat
                fixed = entries;
            elseif ~isempty(entries)
                fixed = entries{1};
            end
        end

        function value = read(obj, tag, value_string)
            tokens = regexp(strtrim(string(value_string)), "\s+", "split");
            tokens = tokens(strlength(tokens) > 0);
            result = struct();
            cursor = 1;
            for idx = 1:numel(obj.subtag_names)
                name = obj.subtag_names(idx);
                tag_obj = obj.get_subtag(name);
                if cursor > numel(tokens)
                    if ~tag_obj.optional
                        error("KSSOLV:Matgenlab:JDFTX:MissingSubtag", ...
                            "Required subtag '%s' missing from '%s'.", name, tag);
                    end
                    continue
                end
                if tag_obj.write_tagname
                    location = find(tokens(cursor:end) == name, 1);
                    if isempty(location)
                        if ~tag_obj.optional
                            error("KSSOLV:Matgenlab:JDFTX:MissingSubtag", ...
                                "Required subtag '%s' missing from '%s'.", ...
                                name, tag);
                        end
                        continue
                    end
                    cursor = cursor + location;
                end
                count = max(1, tag_obj.get_token_len() - ...
                    double(tag_obj.write_tagname));
                stop = min(numel(tokens), cursor + count - 1);
                raw = join(tokens(cursor:stop), " ");
                result.(matlab.lang.makeValidName(name)) = ...
                    tag_obj.read(name, raw);
                cursor = stop + 1;
            end
            value = result;
        end

        function text = write(obj, tag, value)
            entries = obj.entry_cells(value);
            rendered = strings(numel(entries), 1);
            for entry_idx = 1:numel(entries)
                entry = entries{entry_idx};
                pieces = strings(0, 1);
                for idx = 1:numel(obj.subtag_names)
                    name = obj.subtag_names(idx);
                    field = matlab.lang.makeValidName(name);
                    if isfield(entry, field)
                        pieces(end + 1) = strtrim(obj.get_subtag(name). ...
                            write(name, entry.(field))); %#ok<AGROW>
                    end
                end
                body = join(pieces, " ");
                rendered(entry_idx) = strtrim( ...
                    write@kssolv.analysis.matgenlab.io.jdftx.AbstractTag( ...
                    obj, tag, body));
            end
            text = join(rendered, newline) + " ";
        end

        function value = get_token_len(obj)
            value = double(obj.write_tagname);
            for idx = 1:numel(obj.subtag_names)
                tag_obj = obj.get_subtag(obj.subtag_names(idx));
                if ~tag_obj.optional
                    value = value + tag_obj.get_token_len();
                end
            end
        end

        function result = get_list_representation(obj, tag, value)
            entries = obj.entry_cells(value);
            result = cell(size(entries));
            for entry_idx = 1:numel(entries)
                entry = entries{entry_idx};
                flat = {};
                for idx = 1:numel(obj.subtag_names)
                    name = obj.subtag_names(idx);
                    field = matlab.lang.makeValidName(name);
                    if isfield(entry, field)
                        flat{end + 1} = entry.(field); %#ok<AGROW>
                    end
                end
                if ~isempty(obj.linebreak_nth_entry)
                    flat = reshape(flat, obj.linebreak_nth_entry, []).';
                end
                result{entry_idx} = flat;
            end
            if ~obj.can_repeat
                result = result{1};
            elseif ~iscell(value)
                error("KSSOLV:Matgenlab:JDFTX:RepeatRequiresCell", ...
                    "Repeatable tag '%s' requires a cell array.", tag);
            end
        end

        function result = get_dict_representation(obj, tag, value)
            if isstruct(value)
                result = value;
                return
            end
            if obj.can_repeat
                if ~iscell(value)
                    error("KSSOLV:Matgenlab:JDFTX:RepeatRequiresCell", ...
                        "Repeatable tag '%s' requires a cell array.", tag);
                end
                result = cellfun(@(x) obj.list_to_struct(x), value, ...
                    "UniformOutput", false);
            else
                result = obj.list_to_struct(value);
            end
        end
    end

    methods (Access = private)
        function tag_obj = get_subtag(obj, name)
            tag_obj = obj.subtags.(matlab.lang.makeValidName(name));
        end

        function entries = entry_cells(obj, value)
            if obj.can_repeat
                if iscell(value)
                    entries = value;
                elseif isstruct(value) && numel(value) > 1
                    entries = num2cell(value);
                else
                    entries = {value};
                end
            else
                entries = {value};
            end
        end

        function result = list_to_struct(obj, value)
            if isnumeric(value)
                value = num2cell(value);
            end
            while iscell(value) && isscalar(value) && iscell(value{1})
                value = value{1};
            end
            result = struct();
            cursor = 1;
            for idx = 1:min(numel(obj.subtag_names), numel(value))
                name = obj.subtag_names(idx);
                result.(matlab.lang.makeValidName(name)) = value{cursor};
                cursor = cursor + 1;
            end
        end
    end
end
