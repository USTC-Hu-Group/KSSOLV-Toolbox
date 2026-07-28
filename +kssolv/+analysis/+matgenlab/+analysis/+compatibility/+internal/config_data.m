function config=config_data(kind)
%CONFIG_DATA Load an upstream compatibility YAML file.
switch upper(string(kind))
    case "MP2020"
        file="MP2020Compatibility.yaml";
    case "SMOOTHPES"
        file="SmoothPESCompatibility.yaml";
    case "MIT"
        file="MITCompatibility.yaml";
    otherwise
        file="MPCompatibility.yaml";
end
config=kssolv.analysis.matgenlab.util.yaml_load( ...
    kssolv.analysis.matgenlab.analysis.compatibility.internal.config_path(file));
end
