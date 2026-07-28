function text = charge_string(charge, brackets, explicit_one)
%CHARGE_STRING Format an ionic charge.
if nargin < 2, brackets = true; end
if nargin < 3, explicit_one = true; end
if charge == 0
    text = "(aq)";
    return
end
value = kssolv.analysis.matgenlab.util.formula_double_format( ...
    charge, false);
if value >= 0, text = "+" + string(value);
else, text = string(value);
end
if ~explicit_one && (text == "+1" || text == "-1")
    text = erase(text, "1");
end
if brackets, text = "[" + text + "]"; end
end
