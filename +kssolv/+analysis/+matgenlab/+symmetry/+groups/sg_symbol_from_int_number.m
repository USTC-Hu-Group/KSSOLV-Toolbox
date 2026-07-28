function symbol = sg_symbol_from_int_number(int_number, hexagonal)
%SG_SYMBOL_FROM_INT_NUMBER Canonical space-group symbol for number.
if nargin < 2, hexagonal = true; end
record = kssolv.analysis.matgenlab.internal.SymmetryDatabase. ...
    fromNumber(int_number, hexagonal);
symbol = record.short;
if record.choice ~= "" && ...
        ismember(int_number, [146, 148, 155, 160, 161, 166, 167])
    symbol = symbol + record.choice;
end
end
