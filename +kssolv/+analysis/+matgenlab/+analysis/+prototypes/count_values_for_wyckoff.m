function value=count_values_for_wyckoff( ...
        element_wyckoffs,counts,spg_num,lookup_dict)
%COUNT_VALUES_FOR_WYCKOFF Scale table values by Wyckoff-position counts.
element_wyckoffs=reshape(string(element_wyckoffs),1,[]);
counts=reshape(string(counts),1,[]);
if numel(element_wyckoffs)~=numel(counts)
    error("KSSOLV:Matgenlab:Prototypes:CountLength", ...
        "Wyckoff letters and counts must have the same length.");
end
table=kssolv.analysis.matgenlab.analysis.prototypes.internal. ...
    map_get(lookup_dict,string(spg_num),struct());
value=0;
for index=1:numel(counts)
    factor=kssolv.analysis.matgenlab.analysis.prototypes.internal. ...
        map_get(table,element_wyckoffs(index),[]);
    if isempty(factor)
        error("KSSOLV:Matgenlab:Prototypes:UnknownWyckoff", ...
            "Unknown Wyckoff position %s for space group %s.", ...
            element_wyckoffs(index),string(spg_num));
    end
    value=value+str2double(counts(index))*factor;
end
end
