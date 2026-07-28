function value=get_protostructure_label_from_spglib(structure,varargin)
%GET_PROTOSTRUCTURE_LABEL_FROM_SPGLIB Label a structure with bundled spglib.
options=struct("raise_errors",false,"init_symprec",0.1, ...
    "fallback_symprec",1e-5);
options=kssolv.analysis.matgenlab.analysis.prototypes.internal. ...
    options(options,varargin);
try
    analyzer=kssolv.analysis.matgenlab.symmetry.analyzer. ...
        SpacegroupAnalyzer(structure,double(options.init_symprec),5);
    try
        value=kssolv.analysis.matgenlab.analysis.prototypes. ...
            get_protostructure_label_from_spg_analyzer( ...
            analyzer,logical(options.raise_errors));
        attemptRecovery=contains(value,"Invalid")&& ...
            ~isempty(options.fallback_symprec);
    catch exception
        if isempty(options.fallback_symprec),rethrow(exception);end
        attemptRecovery=true;
    end
    if attemptRecovery
        refined=analyzer.get_refined_structure();
        analyzer=kssolv.analysis.matgenlab.symmetry.analyzer. ...
            SpacegroupAnalyzer(refined,double(options.fallback_symprec),-1);
        value=kssolv.analysis.matgenlab.analysis.prototypes. ...
            get_protostructure_label_from_spg_analyzer( ...
            analyzer,logical(options.raise_errors));
    end
catch exception
    if logical(options.raise_errors),rethrow(exception);end
    value=string(exception.message);
end
end
