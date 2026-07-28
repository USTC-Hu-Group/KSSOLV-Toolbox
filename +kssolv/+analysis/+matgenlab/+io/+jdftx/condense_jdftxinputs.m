function value = condense_jdftxinputs(jdftxinput, jdftxstructure)
%CONDENSE_JDFTXINPUTS Combine calculation parameters and structure tags.
structural = kssolv.analysis.matgenlab.io.jdftx.JDFTXInfile. ...
    from_jdftxstructure(jdftxstructure);
base = jdftxinput.copy();
base.strip_structure_tags();
value = structural + base;
end
