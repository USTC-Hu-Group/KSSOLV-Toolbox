function value=count_wyckoff_positions(label)
%COUNT_WYCKOFF_POSITIONS Count occupied Wyckoff orbits.
aflow=split(string(label),":");parts=split(aflow(1),"_");
if numel(parts)<4
    error("KSSOLV:Matgenlab:Prototypes:Label", ...
        "Prototype label has no Wyckoff substring.");
end
wyckoffs=join(parts(4:end),"");
normalized=kssolv.analysis.matgenlab.analysis.prototypes.internal. ...
    prefix_wyckoff_counts(wyckoffs);
parsed=kssolv.analysis.matgenlab.analysis.prototypes. ...
    split_alpha_numeric(normalized);
value=sum(str2double(parsed.numeric));
end
