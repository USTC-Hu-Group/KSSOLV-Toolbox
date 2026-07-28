function text = unicodeify(formula)
%UNICODEIFY Replace formula digits with Unicode subscripts.
text = string(formula);
if contains(text, ".")
    error("KSSOLV:Matgenlab:String:NoUnicodeSubscriptPeriod", ...
        "No unicode character exists for subscript period.");
end
plain = ["0","1","2","3","4","5","6","7","8","9"];
unicode = ["₀","₁","₂","₃","₄","₅","₆","₇","₈","₉"];
for idx = 1:10, text = replace(text, plain(idx), unicode(idx)); end
end
