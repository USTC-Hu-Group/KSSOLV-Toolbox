function value=get_protostructure_label(structure,method,varargin)
%GET_PROTOSTRUCTURE_LABEL Dispatch protostructure symmetry detection.
switch lower(string(method))
    case "aflow"
        value=kssolv.analysis.matgenlab.analysis.prototypes. ...
            get_protostructure_label_from_aflow(structure,varargin{:});
    case "spglib"
        value=kssolv.analysis.matgenlab.analysis.prototypes. ...
            get_protostructure_label_from_spglib(structure,varargin{:});
    case "moyopy"
        value=kssolv.analysis.matgenlab.analysis.prototypes. ...
            get_protostructure_label_from_moyopy(structure,varargin{:});
    otherwise
        error("KSSOLV:Matgenlab:Prototypes:Method", ...
            "Invalid method: %s",string(method));
end
end
