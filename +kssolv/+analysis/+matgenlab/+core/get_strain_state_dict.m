function groups = get_strain_state_dict( ...
        strains, stresses, equilibriumStress, tol, addEquilibrium, sortValues)
%GET_STRAIN_STATE_DICT Group Voigt stress-strain data by strain direction.
if nargin < 3, equilibriumStress = []; end
if nargin < 4, tol = 1e-10; end
if nargin < 5, addEquilibrium = true; end
if nargin < 6, sortValues = true; end
count = sequenceLength(strains);
if sequenceLength(stresses) ~= count
    error("KSSOLV:Matgenlab:Elasticity:Length", ...
        "Strain and stress lists must have equal lengths.");
end
voigtStrains = zeros(count, 6);
voigtStresses = zeros(count, 6);
for index = 1:count
    strain = kssolv.analysis.matgenlab.core.Strain( ...
        sequenceItem(strains, index)).zeroed(tol);
    stress = kssolv.analysis.matgenlab.core.Stress( ...
        sequenceItem(stresses, index)).zeroed(tol);
    voigtStrains(index, :) = strain.voigt;
    voigtStresses(index, :) = stress.voigt;
end
patterns = abs(voigtStrains) > 1e-10;
uniquePatterns = unique(patterns, "rows", "stable");
uniquePatterns(~any(uniquePatterns, 2), :) = [];
if addEquilibrium
    if isempty(equilibriumStress)
        equilibriumStress = ...
            kssolv.analysis.matgenlab.core.find_eq_stress( ...
            strains, stresses, tol);
    end
    equilibriumVoigt = ...
        kssolv.analysis.matgenlab.core.Stress( ...
        equilibriumStress).voigt;
end
groups = repmat(struct( ...
    "state", [], "strains", [], "stresses", []), ...
    1, size(uniquePatterns, 1));
for patternIndex = 1:size(uniquePatterns, 1)
    pattern = uniquePatterns(patternIndex, :);
    selected = all(patterns == pattern, 2);
    selectedStrains = voigtStrains(selected, :);
    selectedStresses = voigtStresses(selected, :);
    active = find(pattern);
    reference = selectedStrains(end, active);
    [~, minimumIndex] = min(abs(reference));
    state = selectedStrains(end, :) / reference(minimumIndex);
    if addEquilibrium
        selectedStrains(end + 1, :) = zeros(1, 6); %#ok<AGROW>
        selectedStresses(end + 1, :) = equilibriumVoigt; %#ok<AGROW>
    end
    if sortValues
        [~, order] = sort(selectedStrains(:, active(1)));
        selectedStrains = selectedStrains(order, :);
        selectedStresses = selectedStresses(order, :);
    end
    groups(patternIndex) = struct( ...
        "state", state, "strains", selectedStrains, ...
        "stresses", selectedStresses);
end
end

function value = sequenceLength(items)
if iscell(items), value = numel(items); else, value = size(items, 1); end
end

function value = sequenceItem(items, index)
if iscell(items)
    value = items{index};
else
    indices = repmat({':'}, 1, ndims(items));
    indices{1} = index;
    value = squeeze(items(indices{:}));
end
end
