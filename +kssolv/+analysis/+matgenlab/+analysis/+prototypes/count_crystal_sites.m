function value=count_crystal_sites(label)
%COUNT_CRYSTAL_SITES Count atomic sites represented by a prototype label.
aflow=split(string(label),":");parts=split(aflow(1),"_");
if numel(parts)<4,error("KSSOLV:Matgenlab:Prototypes:Label", ...
        "Malformed protostructure label.");end
table=kssolv.analysis.matgenlab.analysis.prototypes.internal. ...
    load_data("multiplicities");
value=kssolv.analysis.matgenlab.analysis.prototypes.internal. ...
    count_from_dict(parts(4:end),table,parts(3));
end
