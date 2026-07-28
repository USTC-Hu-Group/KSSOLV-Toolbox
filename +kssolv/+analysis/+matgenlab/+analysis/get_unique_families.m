function families = get_unique_families(hkls)
%GET_UNIQUE_FAMILIES Group Miller indices that differ by signs/permutation.
%
% MATLAB cannot use a numeric tuple as a dictionary key. The equivalent
% result is a struct array with fields ``hkl`` and ``multiplicity``.

if isempty(hkls)
    families = struct("hkl", {}, "multiplicity", {});
    return
end
if iscell(hkls)
    rows = cellfun(@(value) reshape(double(value), 1, []), ...
        hkls, "UniformOutput", false);
else
    values = double(hkls);
    rows = mat2cell(values, ones(size(values, 1), 1), size(values, 2));
end

groups = cell(1, 0);
for index = 1:numel(rows)
    row = rows{index};
    match = 0;
    for groupIndex = 1:numel(groups)
        if isequal(sort(abs(row)), sort(abs(groups{groupIndex}{1})))
            match = groupIndex;
            break
        end
    end
    if match == 0
        groups{end + 1} = {row}; %#ok<AGROW>
    else
        groups{match}{end + 1} = row;
    end
end

families = repmat(struct("hkl", [], "multiplicity", 0), 1, numel(groups));
for groupIndex = 1:numel(groups)
    members = vertcat(groups{groupIndex}{:});
    [~, order] = sortrows(members);
    representative = members(order(end), :);
    families(groupIndex) = struct( ...
        "hkl", representative, ...
        "multiplicity", size(members, 1));
end
end
