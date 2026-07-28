classdef CovalentRadius
    %COVALENTRADIUS Covalent radii from Cordero et al. (2008).

    methods (Static)
        function values = radius()
            persistent cached
            if isempty(cached)
                here = fileparts(mfilename("fullpath"));
                cached = jsondecode(fileread( ...
                    fullfile(here, "+data", "covalent_radii_2008.json")));
            end
            values = cached;
        end
    end
end
