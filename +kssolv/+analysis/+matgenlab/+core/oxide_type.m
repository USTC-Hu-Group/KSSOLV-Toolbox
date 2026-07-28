function result = oxide_type(structure, relativeCutoff, returnNbonds)
%OXIDE_TYPE Classify a structure as oxide/peroxide/superoxide/ozonide.
if nargin < 2, relativeCutoff = 1.1; end
if nargin < 3, returnNbonds = false; end
analyzer = kssolv.analysis.matgenlab.core.OxideType( ...
    structure, relativeCutoff);
if returnNbonds
    result = {analyzer.oxide_type, analyzer.nbonds};
else
    result = analyzer.oxide_type;
end
end
