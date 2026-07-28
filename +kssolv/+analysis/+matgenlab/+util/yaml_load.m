function value=yaml_load(filename)
%YAML_LOAD Parse YAML through MATLAB's bundled yaml2json executable.
%
% No Python or third-party runtime is used. The converter ships with MATLAB
% and supports aliases, flow collections, quoted scalars, and the YAML
% constructs used by phonopy.
filename=string(filename);
if ~isfile(filename)
    error("KSSOLV:Matgenlab:Yaml:MissingFile", ...
        "YAML file '%s' does not exist.",filename);
end
converter=fullfile(matlabroot,"bin",computer("arch"), ...
    "toolbox","shared","yaml2json","yaml2json");
if ispc,converter=converter+".exe";end
if ~isfile(converter)
    error("KSSOLV:Matgenlab:Yaml:Converter", ...
        "MATLAB's yaml2json executable was not found.");
end
command=sprintf('"%s" < "%s"',converter,filename);
[status,text]=system(command);
if status~=0
    error("KSSOLV:Matgenlab:Yaml:Parse", ...
        "Unable to parse '%s': %s",filename,strtrim(text));
end
value=jsondecode(text);
end
