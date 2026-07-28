classdef MultiformatTag < kssolv.analysis.matgenlab.io.jdftx.AbstractTag
    %MULTIFORMATTAG Dispatcher among multiple valid JDFTx tag formats.
    properties
        format_options cell = {}
    end
    methods
        function obj = MultiformatTag(varargin)
            obj@kssolv.analysis.matgenlab.io.jdftx.AbstractTag();
            obj = kssolv.analysis.matgenlab.io.jdftx.assign_options( ...
                obj, varargin{:});
        end

        function [tag, valid, fixed] = validate_value_type(obj, tag, value, options)
            arguments
                obj
                tag
                value
                options.try_auto_type_fix (1, 1) logical = false
            end
            tag = string(tag);
            valid = false;
            fixed = value;
            for idx = 1:numel(obj.format_options)
                try
                    [~, valid, fixed] = obj.format_options{idx}. ...
                        validate_value_type(tag, value, ...
                        try_auto_type_fix = options.try_auto_type_fix);
                    if valid
                        return
                    end
                catch
                end
            end
        end

        function read(~, ~, ~)
            error("KSSOLV:Matgenlab:JDFTX:DirectMultiformatRead", ...
                "Select a concrete format before reading.");
        end

        function write(~, ~, ~)
            error("KSSOLV:Matgenlab:JDFTX:DirectMultiformatWrite", ...
                "Select a concrete format before writing.");
        end

        function index = get_format_index_for_str_value(obj, tag, value)
            for idx = 1:numel(obj.format_options)
                try
                    obj.format_options{idx}.read(tag, value);
                    index = idx - 1;
                    return
                catch
                end
            end
            error("KSSOLV:Matgenlab:JDFTX:NoMatchingFormat", ...
                "No valid format for tag '%s'.", tag);
        end

        function raise_invalid_format_option_error(~, tag, index)
            error("KSSOLV:Matgenlab:JDFTX:InvalidFormatIndex", ...
                "Tag '%s' failed validation for option %d.", tag, index);
        end

        function value = get_token_len(~)
            value = []; %#ok<NASGU>
            error("KSSOLV:Matgenlab:JDFTX:DirectMultiformatLength", ...
                "Select a concrete format before requesting token length.");
        end
    end
end
