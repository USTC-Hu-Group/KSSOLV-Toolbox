function result = contains_peroxide(structure, relativeCutoff)
%CONTAINS_PEROXIDE True only for peroxide-classified structures.
if nargin < 2, relativeCutoff = 1.1; end
result = kssolv.analysis.matgenlab.core.oxide_type( ...
    structure, relativeCutoff) == "peroxide";
end
