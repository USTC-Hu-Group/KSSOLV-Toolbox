function equilibrium = find_eq_stress(strains, stresses, tol)
%FIND_EQ_STRESS Find the stress associated with a zero strain state.
if nargin < 3, tol = 1e-10; end
count = sequenceLength(strains);
matches = cell(1, 0);
for index = 1:count
    strain = sequenceItem(strains, index);
    if all(abs(double(strain)) < tol, "all")
        matches{end + 1} = kssolv.analysis.matgenlab.core.Stress( ...
            sequenceItem(stresses, index)); %#ok<AGROW>
    end
end
if isempty(matches)
    warning("KSSOLV:Matgenlab:Elasticity:NoEquilibriumStress", ...
        "No eq state found, returning zero voigt stress.");
    equilibrium = kssolv.analysis.matgenlab.core.Stress(zeros(3));
    return
end
reference = double(matches{1});
for index = 2:numel(matches)
    if max(abs(double(matches{index}) - reference), [], "all") > 1e-8
        error("KSSOLV:Matgenlab:Elasticity:EquilibriumStress", ...
            "Multiple stresses found for equilibrium strain state; " + ...
            "specify equilibrium stress or remove extraneous stresses.");
    end
end
equilibrium = matches{1};
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
