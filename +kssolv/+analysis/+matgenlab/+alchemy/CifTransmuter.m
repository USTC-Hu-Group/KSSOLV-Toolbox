classdef CifTransmuter < ...
        kssolv.analysis.matgenlab.alchemy.StandardTransmuter
    %CIFTRANSMUTER Build a transmuter from one or more CIF data blocks.

    methods
        function obj = CifTransmuter(cifString, transformations, ...
                primitive, extendCollection)
            if nargin < 2, transformations = {}; end
            if nargin < 3, primitive = true; end
            if nargin < 4, extendCollection = false; end
            blocks = splitCifBlocks(cifString);
            transformed = cell(1, numel(blocks));
            for index = 1:numel(blocks)
                transformed{index} = ...
                    kssolv.analysis.matgenlab.alchemy. ...
                    TransformedStructure.from_cif_str( ...
                    blocks{index}, {}, primitive);
            end
            obj@kssolv.analysis.matgenlab.alchemy.StandardTransmuter( ...
                transformed, transformations, extendCollection);
        end
    end

    methods (Static)
        function obj = from_filenames(filenames, transformations, ...
                primitive, extendCollection)
            if nargin < 2, transformations = {}; end
            if nargin < 3, primitive = true; end
            if nargin < 4, extendCollection = false; end
            if ischar(filenames) || (isstring(filenames) && isscalar(filenames))
                filenames = {filenames};
            elseif isstring(filenames)
                filenames = cellstr(filenames);
            end
            contents = cell(1, numel(filenames));
            for index = 1:numel(filenames)
                contents{index} = fileread(filenames{index});
            end
            obj = kssolv.analysis.matgenlab.alchemy.CifTransmuter( ...
                strjoin(contents, newline), transformations, ...
                primitive, extendCollection);
        end
    end
end

function blocks = splitCifBlocks(value)
text = char(string(value));
starts = regexp(text, '(?m)^\s*data[^\r\n]*', "start");
if isempty(starts)
    error("KSSOLV:Matgenlab:CifTransmuter:NoDataBlocks", ...
        "CIF string contains no data blocks.");
end
blocks = cell(1, numel(starts));
for index = 1:numel(starts)
    if index < numel(starts), stop = starts(index + 1) - 1;
    else, stop = numel(text);
    end
    blocks{index} = text(starts(index):stop);
end
end
