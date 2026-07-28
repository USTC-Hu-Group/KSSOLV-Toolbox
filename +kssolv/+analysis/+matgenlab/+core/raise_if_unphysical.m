function output = raise_if_unphysical(elasticTensor, operation, varargin)
%RAISE_IF_UNPHYSICAL Validate elastic moduli before evaluating a property.
if elasticTensor.k_vrh < 0 || elasticTensor.g_vrh < 0
    error("KSSOLV:Matgenlab:ElasticTensor:Unphysical", ...
        "Bulk or shear modulus is negative, property cannot be determined.");
end
if nargin < 2 || isempty(operation)
    output = elasticTensor;
else
    output = operation(elasticTensor, varargin{:});
end
end
