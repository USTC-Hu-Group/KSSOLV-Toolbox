function value=count_crystal_dof(label)
%COUNT_CRYSTAL_DOF Count lattice and Wyckoff coordinate parameters.
aflow=split(string(label),":");parts=split(aflow(1),"_");
if numel(parts)<4,error("KSSOLV:Matgenlab:Prototypes:Label", ...
        "Malformed protostructure label.");end
families=struct(a=6,m=4,o=3,t=2,h=2,c=1);
family=extractBetween(parts(2),1,1);
if ~isfield(families,char(family))
    error("KSSOLV:Matgenlab:Prototypes:Pearson", ...
        "Unknown Pearson family '%s'.",family);
end
table=kssolv.analysis.matgenlab.analysis.prototypes.internal. ...
    load_data("parameters");
value=families.(char(family))+ ...
    kssolv.analysis.matgenlab.analysis.prototypes.internal. ...
    count_from_dict(parts(4:end),table,parts(3));
end
