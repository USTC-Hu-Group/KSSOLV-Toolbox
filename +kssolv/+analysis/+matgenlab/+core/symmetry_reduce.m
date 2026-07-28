function mapping = symmetry_reduce(tensors, structure, tol, options)
%SYMMETRY_REDUCE Reduce symmetrically equivalent tensors.
arguments
    tensors cell
    structure
    tol (1,1) double {mustBePositive} = 1e-8
    options.symprec (1,1) double {mustBePositive} = 0.1
end
if isempty(tensors)
    mapping = kssolv.analysis.matgenlab.core.TensorMapping({}, {}, tol);
    return
end
tensors = cellfun(@(value) normalizeTensor(value), tensors, ...
    UniformOutput=false);
operations = ...
    kssolv.analysis.matgenlab.core.Tensor.symmetry_operations( ...
    structure, options.symprec);
mapping = kssolv.analysis.matgenlab.core.TensorMapping( ...
    tensors(1), {{}}, tol);
for tensorIndex = 2:numel(tensors)
    tensor = tensors{tensorIndex};
    uniqueTensor = true;
    keys = mapping.keys();
    for keyIndex = 1:numel(keys)
        key = keys{keyIndex};
        for operationIndex = 1:numel(operations)
            transformed = key.transform(operations{operationIndex});
            if all(abs(double(transformed)-double(tensor)) <= tol,"all")
                values = mapping(key);
                values{end+1} = operations{operationIndex}; %#ok<AGROW>
                mapping(key) = values;
                uniqueTensor = false;
                break
            end
        end
        if ~uniqueTensor
            break
        end
    end
    if uniqueTensor
        mapping(tensor) = {};
    end
end
end

function tensor = normalizeTensor(value)
if isa(value,"kssolv.analysis.matgenlab.core.Tensor")
    tensor = value;
else
    tensor = kssolv.analysis.matgenlab.core.Tensor(value);
end
end
