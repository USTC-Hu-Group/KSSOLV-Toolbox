classdef AbstractTag < kssolv.analysis.matgenlab.io.jdftx.ClassPrintFormatter
    %ABSTRACTTAG Common JDFTx tag validation and serialization behavior.
    properties
        multiline_tag (1, 1) logical = false
        can_repeat (1, 1) logical = false
        write_tagname (1, 1) logical = true
        write_value (1, 1) logical = true
        optional (1, 1) logical = true
        defer_until_struc (1, 1) logical = false
        is_tag_container (1, 1) logical = false
        allow_list_representation (1, 1) logical = false
    end

    methods
        function obj = AbstractTag(varargin)
            obj = kssolv.analysis.matgenlab.io.jdftx.assign_options( ...
                obj, varargin{:});
        end

        function [tag, valid, fixed] = validate_value_type(~, tag, value, varargin)
            tag = string(tag);
            valid = true;
            fixed = value;
        end

        function value = is_equal_to(obj, val1, obj2, val2)
            if ~isa(obj2, class(obj))
                value = false;
                return
            end
            if obj.can_repeat
                left = obj.as_cell(val1);
                right = obj.as_cell(val2);
                if numel(left) ~= numel(right)
                    value = false;
                    return
                end
                used = false(size(right));
                for idx = 1:numel(left)
                    hit = find(~used & cellfun(@(x) isequaln(left{idx}, x), ...
                        right), 1);
                    if isempty(hit)
                        value = false;
                        return
                    end
                    used(hit) = true;
                end
                value = true;
            else
                value = isequaln(val1, val2);
            end
        end

        function [valid, message] = validate_value_bounds(~, ~, ~)
            valid = true;
            message = "";
        end

        function value = read(~, ~, value_string)
            value = strtrim(string(value_string));
        end

        function text = write(obj, tag, value)
            pieces = strings(0, 1);
            if obj.write_tagname
                pieces(end + 1) = string(tag);
            end
            if obj.write_value
                pieces(end + 1) = kssolv.analysis.matgenlab.io.jdftx. ...
                    value_string(value);
            end
            text = strtrim(join(pieces, " ")) + " ";
        end

        function value = get_token_len(obj)
            value = double(obj.write_tagname) + double(obj.write_value);
        end

        function value = get_list_representation(~, tag, ~)
            value = []; %#ok<NASGU>
            error("KSSOLV:Matgenlab:JDFTX:NoListRepresentation", ...
                "Tag '%s' has no list representation.", string(tag));
        end

        function value = get_dict_representation(~, tag, ~)
            value = []; %#ok<NASGU>
            error("KSSOLV:Matgenlab:JDFTX:NoDictRepresentation", ...
                "Tag '%s' has no dictionary representation.", string(tag));
        end
    end

    methods (Access = protected)
        function values = as_cell(~, value)
            if iscell(value)
                values = value;
            else
                values = {value};
            end
        end
    end
end
