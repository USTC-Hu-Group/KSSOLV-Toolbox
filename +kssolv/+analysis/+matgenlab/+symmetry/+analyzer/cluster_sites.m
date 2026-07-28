function varargout = cluster_sites(molecule, tolerance, give_only_index)
%CLUSTER_SITES Group sites by radial shell and species.
%   [ORIGIN, CLUSTERS] = CLUSTER_SITES(MOL, TOL) mirrors pymatgen's
%   public helper. MATLAB indices are one-based. CLUSTERS is a cell array
%   of site arrays; with GIVE_ONLY_INDEX=true it contains index vectors.
if nargin < 2, tolerance = 0.1; end
if nargin < 3, give_only_index = false; end

radii = vecnorm(molecule.cart_coords, 2, 2);
numberSites = molecule.num_sites;
shell = zeros(numberSites, 1);
numberShells = 0;
% Single-link radial clustering matches scipy's distance-threshold
% clustering used upstream.
[sortedRadii, order] = sort(radii);
for sortedIndex = 1:numberSites
    if sortedIndex == 1 || ...
            sortedRadii(sortedIndex) - sortedRadii(sortedIndex - 1) > ...
            tolerance
        numberShells = numberShells + 1;
    end
    shell(order(sortedIndex)) = numberShells;
end
averageRadius = zeros(numberShells, 1);
for shellIndex = 1:numberShells
    averageRadius(shellIndex) = mean(radii(shell == shellIndex));
end

originIndex = [];
clusters = cell(1, 0);
clusterSpecies = strings(1, 0);
clusterShell = zeros(1, 0);
for index = 1:numberSites
    if averageRadius(shell(index)) < tolerance
        originIndex = index;
        continue
    end
    species = molecule(index).species_string;
    match = find(clusterShell == shell(index) & ...
        clusterSpecies == species, 1);
    if isempty(match)
        clusterShell(end + 1) = shell(index); %#ok<AGROW>
        clusterSpecies(end + 1) = species; %#ok<AGROW>
        clusters{end + 1} = index; %#ok<AGROW>
    else
        clusters{match}(end + 1) = index;
    end
end

if give_only_index
    origin = originIndex;
    values = clusters;
else
    if isempty(originIndex), origin = [];
    else, origin = molecule(originIndex);
    end
    values = cell(size(clusters));
    for group = 1:numel(clusters)
        values{group} = cell(1, numel(clusters{group}));
        for index = 1:numel(clusters{group})
            values{group}{index} = molecule(clusters{group}(index));
        end
    end
end
if nargout <= 1
    varargout{1} = struct("origin_site", origin, ...
        "clustered_sites", {values}, "index_base", 1);
else
    varargout{1} = origin;
    varargout{2} = values;
end
end
