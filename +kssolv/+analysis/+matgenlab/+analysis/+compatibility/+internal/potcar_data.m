function values=potcar_data(kind,hashes)
%POTCAR_DATA Expected public POTCAR symbols or fingerprints.
kind=upper(string(kind));
if kind=="MIT",setName="MITRelaxSet";
else,setName="MPRelaxSet";end
source=which("kssolv.analysis.matgenlab.io.vasp."+setName);
path=fullfile(fileparts(source),"+sets_data",setName+".json");
config=jsondecode(fileread(path));
raw=config.POTCAR;
names=fieldnames(raw);values=struct();
sample=raw.(names{end});
if hashes&&~isstruct(sample)
    error("KSSOLV:Matgenlab:Compatibility:PotcarHashUnavailable", ...
        "Cannot check hashes because this input set has no hash metadata.");
end
for index=1:numel(names)
    name=names{index};item=raw.(name);
    if isstruct(item)
        if hashes,key="hash";else,key="symbol";end
        values.(name)=string(item.(key));
    else
        values.(name)=string(item);
    end
end
end
