function full = generate_full_symmops(symmops, tolerance)
%GENERATE_FULL_SYMMOPS Generate closure of a set of affine operations.
if nargin < 2, tolerance = 0.1; end
if isa(symmops, "kssolv.analysis.matgenlab.core.SymmOp")
    symmops = num2cell(reshape(symmops, 1, []));
end
if ~iscell(symmops)
    error("KSSOLV:Matgenlab:Symmetry:Operations", ...
        "symmops must be a cell array or SymmOp array.");
end
identity = kssolv.analysis.matgenlab.core.SymmOp. ...
    from_rotation_and_translation(eye(3), zeros(1, 3));
full = {identity};
queue = reshape(symmops, 1, []);
maximum = 1000;
while ~isempty(queue)
    operation = queue{1};
    queue(1) = [];
    exists = any(cellfun(@(candidate) ...
        all(abs(candidate.affine_matrix - operation.affine_matrix) <= ...
        tolerance, "all"), full));
    if exists, continue; end
    prior = full;
    full{end + 1} = operation; %#ok<AGROW>
    queue{end + 1} = operation * operation; %#ok<AGROW>
    for index = 1:numel(prior)
        queue{end + 1} = operation * prior{index}; %#ok<AGROW>
        queue{end + 1} = prior{index} * operation; %#ok<AGROW>
    end
    if numel(full) > maximum
        error("KSSOLV:Matgenlab:Symmetry:NonFiniteGroup", ...
            "Generators did not close into a finite group.");
    end
end
end
