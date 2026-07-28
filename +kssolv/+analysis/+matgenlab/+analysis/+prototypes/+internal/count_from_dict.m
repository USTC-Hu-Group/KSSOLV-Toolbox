function value=count_from_dict(element_wyckoffs,lookup,spg_num)
%COUNT_FROM_DICT Count per-orbit values from a frozen Wyckoff table.
value=0;
for index=1:numel(element_wyckoffs)
    normalized=kssolv.analysis.matgenlab.analysis.prototypes.internal. ...
        prefix_wyckoff_counts(element_wyckoffs(index));
    parsed=kssolv.analysis.matgenlab.analysis.prototypes. ...
        split_alpha_numeric(normalized);
    value=value+kssolv.analysis.matgenlab.analysis.prototypes. ...
        count_values_for_wyckoff(parsed.alpha,parsed.numeric, ...
        string(spg_num),lookup);
end
value=round(value);
end
