function value=count_distinct_wyckoff_letters(label)
%COUNT_DISTINCT_WYCKOFF_LETTERS Count unique letters in a prototype label.
aflow=split(string(label),":");parts=split(aflow(1),"_");
if numel(parts)<4
    error("KSSOLV:Matgenlab:Prototypes:Label", ...
        "Prototype label has no Wyckoff substring.");
end
wyckoffs=join(parts(4:end),"");
letters=regexp(char(wyckoffs),"[A-Za-z]","match");
value=numel(unique(string(letters)));
end
