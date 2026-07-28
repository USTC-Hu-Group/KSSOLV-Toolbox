function lengths = obtain_all_bond_lengths(sp1, sp2, default_bl)
%OBTAIN_ALL_BOND_LENGTHS Return known bond lengths keyed by bond order.
if nargin < 3, default_bl = []; end
symbols = sort([localSymbol(sp1), localSymbol(sp2)]);
key = char(strjoin(symbols, "|"));
data = kssolv.analysis.matgenlab.core.bond_lengths_data();
if isKey(data, key)
    source = data(key);
    lengths = containers.Map(source.keys, source.values);
elseif ~isempty(default_bl)
    lengths = containers.Map(1, double(default_bl));
else
    error("KSSOLV:Matgenlab:Bonds:MissingData", ...
        "No bond data for elements %s - %s", symbols(1), symbols(2));
end
end

function symbol = localSymbol(value)
value = kssolv.analysis.matgenlab.core.get_el_sp(value);
symbol = string(value.symbol);
end
