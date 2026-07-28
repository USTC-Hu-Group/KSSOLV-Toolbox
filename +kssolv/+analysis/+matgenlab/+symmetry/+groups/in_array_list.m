function tf = in_array_list(array_list, array, tolerance)
%IN_ARRAY_LIST Test whether an array is present within a numerical stack.
if nargin < 3, tolerance = 1e-5; end
if isempty(array_list)
    tf = false;
    return
end
array = double(array);
if iscell(array_list)
    tf = any(cellfun(@(candidate) ...
        isequal(size(candidate), size(array)) && ...
        all(abs(double(candidate) - array) <= tolerance, "all"), ...
        array_list));
    return
end
if ismatrix(array_list) && isrow(array)
    tf = any(all(abs(double(array_list) - array) <= tolerance, 2));
    return
end
dimensions = size(array_list);
if isequal(dimensions, size(array))
    tf = all(abs(double(array_list) - array) <= tolerance, "all");
    return
end
tf = false;
for index = 1:dimensions(1)
    candidate = reshape(array_list(index, :), size(array));
    if all(abs(double(candidate) - array) <= tolerance, "all")
        tf = true;
        return
    end
end
end
