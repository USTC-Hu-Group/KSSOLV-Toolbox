classdef CifFile
    %CIFFILE Collection of CIF data blocks.
    %
    % Compatible with pymatgen-core v2026.7.24, pymatgen.io.cif.CifFile.

    properties
        data containers.Map
        orig_string = []
        comment (1,1) string = "# generated using pymatgen"
    end

    properties (SetAccess = private)
        headers (1,:) string = strings(1, 0)
    end

    methods
        function obj = CifFile(data, orig_string, comment)
            if nargin < 1
                data = containers.Map("KeyType", "char", "ValueType", "any");
            end
            if nargin < 2, orig_string = []; end
            if nargin < 3 || isempty(comment), comment = "# generated using pymatgen"; end
            [obj.data, obj.headers] = obj.normalizeData(data);
            obj.orig_string = orig_string;
            obj.comment = string(comment);
        end

        function value = char(obj)
            blocks = strings(1, numel(obj.headers));
            for index = 1:numel(obj.headers)
                blocks(index) = string(obj.data(char(obj.headers(index))));
            end
            value = char(obj.comment + newline + ...
                strjoin(blocks, newline) + newline);
        end

        function value = string(obj), value = string(char(obj)); end
    end

    methods (Static)
        function obj = from_str(contents)
            text = char(string(contents));
            starts = regexp(text, "(?m)^\s*data_", "start");
            if isempty(starts)
                obj = kssolv.analysis.matgenlab.io.cif.CifFile( ...
                    containers.Map("KeyType", "char", "ValueType", "any"), text);
                return
            end
            starts(end + 1) = numel(text) + 1;
            pairs = cell(0, 2);
            for index = 1:numel(starts) - 1
                blockText = text(starts(index):starts(index + 1) - 1);
                headerToken = regexp(blockText, ...
                    "(?m)^\s*data_([^\s]+)", "tokens", "once");
                if ~isempty(headerToken) && ...
                        contains(lower(string(headerToken{1})), "powder_pattern")
                    continue
                end
                block = kssolv.analysis.matgenlab.io.cif.CifBlock.from_str(blockText);
                existing = find(string(pairs(:, 1)) == block.header, 1);
                if isempty(existing)
                    pairs(end + 1, :) = {char(block.header), block}; %#ok<AGROW>
                else
                    % Match pymatgen: the latest equal-header block wins.
                    pairs{existing, 2} = block;
                end
            end
            obj = kssolv.analysis.matgenlab.io.cif.CifFile(pairs, text);
        end

        function obj = from_file(filename)
            if ~isfile(filename)
                error("KSSOLV:Matgenlab:CifFile:MissingFile", ...
                    "CIF file '%s' does not exist.", filename);
            end
            obj = kssolv.analysis.matgenlab.io.cif.CifFile.from_str( ...
                kssolv.analysis.matgenlab.io.cif.CifFile.readText(filename));
        end

        function obj = fromString(contents), obj = ...
                kssolv.analysis.matgenlab.io.cif.CifFile.from_str(contents); end
        function obj = fromFile(filename), obj = ...
                kssolv.analysis.matgenlab.io.cif.CifFile.from_file(filename); end
    end

    methods (Access = private)
        function [map, order] = normalizeData(~, input)
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
                    name = names{index};
                    map(name) = input.(name);
                    order(end + 1) = string(name); %#ok<AGROW>
                end
            elseif iscell(input) && (isempty(input) || size(input, 2) == 2)
                for index = 1:size(input, 1)
                    name = char(string(input{index, 1}));
                    map(name) = input{index, 2};
                    order(end + 1) = string(name); %#ok<AGROW>
                end
            else
                error("KSSOLV:Matgenlab:CifFile:InvalidData", ...
                    "data must map block headers to CifBlock objects.");
            end
        end
    end

    methods (Static, Access = private)
        function text = readText(filename)
            filename = string(filename);
            lowered = lower(filename);
            if ~(endsWith(lowered, ".gz") || endsWith(lowered, ".bz2"))
                text = fileread(filename);
                return
            end
            temporary = string(tempname);
            mkdir(temporary);
            cleanup = onCleanup(@() rmdir(temporary, "s"));
            if endsWith(lowered, ".gz")
                files = gunzip(filename, temporary);
            else
                files = bunzip2(filename, temporary);
            end
            if isempty(files)
                error("KSSOLV:Matgenlab:CifFile:Decompression", ...
                    "Could not decompress '%s'.", filename);
            end
            text = fileread(files{1});
            clear cleanup
        end
    end
end
