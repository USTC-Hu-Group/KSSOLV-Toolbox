function result = compare_sym_bands(bands, reference, selected)
%COMPARE_SYM_BANDS Compare interpolated and reference symmetry-line bands.
if nargin < 3 || isempty(selected)
    result = "No nb given";
    return
end
first = bands.bands.up;
if reference.is_spin_polarized
    second = sort([reference.bands.up; reference.bands.down], 1);
else
    second = reference.bands.up;
end
count = min(size(first, 1), size(second, 1));
first = first(1:count, :);
second = second(1:count, :);
if any(selected == 0), selected = selected + 1; end
if any(selected > count)
    result = "No nb given";
    return
end
zeroFirst = 0;
zeroSecond = 0;
if ~bands.is_metal() && ~reference.is_metal()
    zeroFirst = bands.get_vbm().energy;
    zeroSecond = reference.get_vbm().energy;
end
result = struct();
for bandIndex = reshape(selected, 1, [])
    x = first(bandIndex, :);
    y = second(bandIndex, :);
    correlationDistance = 1 - corr(x.', y.');
    record = struct("Dist", mean(abs(x - zeroFirst - y + zeroSecond)), ...
        "Corr", correlationDistance);
    for branchIndex = 1:numel(reference.branches)
        branch = reference.branches{branchIndex};
        indices = branch.start_index:branch.end_index;
        key = matlab.lang.makeValidName(char(branch.name));
        record.(key) = mean(abs(x(indices) - zeroFirst - ...
            y(indices) + zeroSecond));
    end
    result.(sprintf("band_%d", bandIndex)) = record;
end
end
