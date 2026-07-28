function result = convert_strain_to_deformation(strain, shape)
%CONVERT_STRAIN_TO_DEFORMATION Find a deformation gradient for a strain.
if nargin < 2, shape = "upper"; end
metric = 2 * double(strain) + eye(3);
switch lower(string(shape))
    case "upper"
        matrix = chol(metric);
    case "symmetric"
        matrix = real(sqrtm(metric));
    otherwise
        error("KSSOLV:Matgenlab:Strain:Shape", ...
            "shape must be 'upper' or 'symmetric'.");
end
result = kssolv.analysis.matgenlab.core.Deformation(matrix);
end
