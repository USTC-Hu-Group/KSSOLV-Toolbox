function value = get_tag_object(tag)
%GET_TAG_OBJECT Return a tag codec for a standard JDFTx command.
tag = lower(string(tag));
bool_tags = ["converge-empty-states", "dump-only", ...
    "kpoint-reduce-inversion", "symmetry-reduce-inversion"];
int_tags = ["elec-n-bands", "target-mu-outer-loop"];
float_tags = ["ion-width", "symmetry-threshold", ...
    "coulomb-truncation-ion-margin", "davidson-band-ratio"];
if tag == "dump"
    value = kssolv.analysis.matgenlab.io.jdftx.get_dump_tag_container();
elseif any(tag == bool_tags)
    value = kssolv.analysis.matgenlab.io.jdftx.BoolTag();
    if tag == "dump-only"
        value.write_value = false;
    end
elseif any(tag == int_tags)
    value = kssolv.analysis.matgenlab.io.jdftx.IntTag();
elseif any(tag == float_tags)
    value = kssolv.analysis.matgenlab.io.jdftx.FloatTag();
elseif tag == "initial-magnetic-moments"
    value = kssolv.analysis.matgenlab.io.jdftx.InitMagMomTag();
else
    value = kssolv.analysis.matgenlab.io.jdftx.StrTag();
end
end
