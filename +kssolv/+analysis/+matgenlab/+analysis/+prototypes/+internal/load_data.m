function value=load_data(kind)
%LOAD_DATA Load a frozen AFLOW/Wyckoff table once per MATLAB process.
persistent aflow multiplicities parameters relabelings
switch lower(string(kind))
    case "aflow"
        if isempty(aflow)
            aflow=kssolv.analysis.matgenlab.analysis.prototypes.internal. ...
                read_gzip_json(kssolv.analysis.matgenlab.analysis. ...
                prototypes.internal.data_path("aflow_prototypes.json.gz"));
        end
        value=aflow;
    case "multiplicities"
        if isempty(multiplicities)
            multiplicities=kssolv.analysis.matgenlab.analysis.prototypes. ...
                internal.read_gzip_json(kssolv.analysis.matgenlab.analysis. ...
                prototypes.internal.data_path( ...
                "wyckoff-position-multiplicities.json.gz"));
        end
        value=multiplicities;
    case "parameters"
        if isempty(parameters)
            parameters=kssolv.analysis.matgenlab.analysis.prototypes. ...
                internal.read_gzip_json(kssolv.analysis.matgenlab.analysis. ...
                prototypes.internal.data_path( ...
                "wyckoff-position-params.json.gz"));
        end
        value=parameters;
    case "relabelings"
        if isempty(relabelings)
            relabelings=kssolv.analysis.matgenlab.analysis.prototypes. ...
                internal.read_gzip_json(kssolv.analysis.matgenlab.analysis. ...
                prototypes.internal.data_path( ...
                "wyckoff-position-relabelings.json.gz"));
        end
        value=relabelings;
    otherwise
        error("KSSOLV:Matgenlab:Prototypes:Data", ...
            "Unknown prototype data table '%s'.",kind);
end
end
