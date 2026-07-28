classdef PoscarTransmuter < ...
        kssolv.analysis.matgenlab.alchemy.StandardTransmuter
    %POSCARTRANSMUTER Build a transmuter from POSCAR text.

    methods
        function obj = PoscarTransmuter(poscarString, transformations, ...
                extendCollection)
            if nargin < 2, transformations = {}; end
            if nargin < 3, extendCollection = false; end
            transformed = kssolv.analysis.matgenlab.alchemy. ...
                TransformedStructure.from_poscar_str(poscarString);
            obj@kssolv.analysis.matgenlab.alchemy.StandardTransmuter( ...
                {transformed}, transformations, extendCollection);
        end
    end

    methods (Static)
        function obj = from_filenames(filenames, transformations, ...
                extendCollection)
            if nargin < 2, transformations = {}; end
            if nargin < 3, extendCollection = false; end
            if ischar(filenames) || (isstring(filenames) && isscalar(filenames))
                filenames = {filenames};
            elseif isstring(filenames)
                filenames = cellstr(filenames);
            end
            transformed = cell(1, numel(filenames));
            for index = 1:numel(filenames)
                transformed{index} = ...
                    kssolv.analysis.matgenlab.alchemy. ...
                    TransformedStructure.from_poscar_str( ...
                    fileread(filenames{index}));
            end
            obj = kssolv.analysis.matgenlab.alchemy.StandardTransmuter( ...
                transformed, transformations, extendCollection);
        end
    end
end
