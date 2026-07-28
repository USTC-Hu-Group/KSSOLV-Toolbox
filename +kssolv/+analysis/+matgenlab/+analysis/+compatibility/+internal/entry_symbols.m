function symbols=entry_symbols(entry)
%ENTRY_SYMBOLS Ordered element symbols for an entry.
symbols=string(cellfun(@(item)item.symbol,entry.elements, ...
    "UniformOutput",false));
end
