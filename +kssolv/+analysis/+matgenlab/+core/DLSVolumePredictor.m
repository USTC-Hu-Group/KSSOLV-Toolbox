classdef DLSVolumePredictor
    %DLSVOLUMEPREDICTOR Data-mined lattice-scaling volume predictor.

    properties (SetAccess = protected)
        cutoff (1,1) double = 4
        min_scaling (1,1) double = 0.5
        max_scaling (1,1) double = 1.5
    end

    methods
        function obj = DLSVolumePredictor(cutoff, minScaling, maxScaling)
            if nargin >= 1 && ~isempty(cutoff), obj.cutoff = double(cutoff); end
            if nargin >= 2
                if isempty(minScaling), obj.min_scaling = NaN;
                else, obj.min_scaling = double(minScaling);
                end
            end
            if nargin >= 3
                if isempty(maxScaling), obj.max_scaling = NaN;
                else, obj.max_scaling = double(maxScaling);
                end
            end
        end

        function volume = predict(obj, structure, icsdVol)
            if nargin < 3, icsdVol = false; end
            electronegativities = zeros(1, structure.num_sites);
            for index = 1:structure.num_sites
                electronegativities(index) = structure.get_site(index).specie.X;
            end
            stdX = std(electronegativities, 1);
            parameters = obj.bondParameters();

            supported = cell(1, 0);
            estimated = containers.Map("KeyType", "char", "ValueType", "double");
            for index = 1:structure.num_sites
                site = structure.get_site(index);
                radius = site.specie.atomic_radius;
                if isempty(radius) || isnan(radius), continue; end
                supported{end + 1} = site; %#ok<AGROW>
                symbol = char(site.specie.symbol);
                if isfield(parameters, symbol)
                    row = parameters.(symbol);
                    estimated(symbol) = double(row.r) + double(row.k) * stdX;
                end
            end
            if isempty(supported)
                error("KSSOLV:Matgenlab:DLSVolumePredictor:NoSupportedSites", ...
                    "No sites have an atomic radius.");
            end
            reduced = kssolv.analysis.matgenlab.core.Structure.from_sites(supported);
            smallestRatio = Inf;
            for index = 1:reduced.num_sites
                site1 = reduced.get_site(index);
                neighbors = reduced.get_neighbors(site1, ...
                    site1.specie.atomic_radius + obj.cutoff);
                for neighborIndex = 1:numel(neighbors)
                    neighbor = neighbors{neighborIndex};
                    symbol1 = char(site1.specie.symbol);
                    symbol2 = char(neighbor.specie.symbol);
                    if isKey(estimated, symbol1) && isKey(estimated, symbol2)
                        expected = estimated(symbol1) + estimated(symbol2);
                    else
                        expected = site1.specie.atomic_radius + ...
                            neighbor.specie.atomic_radius;
                    end
                    smallestRatio = min(smallestRatio, ...
                        neighbor.nn_distance / expected);
                end
            end
            if ~isfinite(smallestRatio)
                error("KSSOLV:Matgenlab:DLSVolumePredictor:NoBonds", ...
                    "Could not find any bonds within the given cutoff.");
            end

            factor = (1 / smallestRatio)^3;
            if icsdVol, factor = factor * 1.05; end
            if ~isnan(obj.min_scaling), factor = max(obj.min_scaling, factor); end
            if ~isnan(obj.max_scaling), factor = min(obj.max_scaling, factor); end
            volume = structure.volume * factor;
        end

        function structure = get_predicted_structure(obj, structure, icsdVol)
            if nargin < 3, icsdVol = false; end
            volume = obj.predict(structure, icsdVol);
            structure = structure.copy();
            structure = structure.scale_lattice(volume);
        end
    end

    methods (Static, Access = protected)
        function parameters = bondParameters()
            persistent cached
            if isempty(cached)
                here = fileparts(mfilename("fullpath"));
                cached = jsondecode(fileread( ...
                    fullfile(here, "+data", "dls_bond_params.json")));
            end
            parameters = cached;
        end
    end
end
