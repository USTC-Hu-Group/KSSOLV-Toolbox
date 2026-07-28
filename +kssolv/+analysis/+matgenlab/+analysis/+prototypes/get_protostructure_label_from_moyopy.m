function value=get_protostructure_label_from_moyopy(structure,varargin)
%GET_PROTOSTRUCTURE_LABEL_FROM_MOYOPY Label using a native symmetry backend.
% MATLAB has no Moyopy binding. The frozen API is reproduced with the bundled
% native spglib engine at the requested precision and without fallback.
options=struct("raise_errors",false,"symprec",0.1);
options=kssolv.analysis.matgenlab.analysis.prototypes.internal. ...
    options(options,varargin);
value=kssolv.analysis.matgenlab.analysis.prototypes. ...
    get_protostructure_label_from_spglib(structure, ...
    logical(options.raise_errors),double(options.symprec),[]);
end
