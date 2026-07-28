function text = unicodeify_spacegroup(spacegroup_symbol)
%UNICODEIFY_SPACEGROUP Convert a space-group symbol to Unicode.
if strlength(string(spacegroup_symbol)) == 0, text = ""; return; end
text = kssolv.analysis.matgenlab.util.latexify_spacegroup(spacegroup_symbol);
plainLatex = ["$_{0}$","$_{1}$","$_{2}$","$_{3}$","$_{4}$", ...
    "$_{5}$","$_{6}$","$_{7}$","$_{8}$","$_{9}$"];
plain = ["_0","_1","_2","_3","_4","_5","_6","_7","_8","_9"];
unicode = ["₀","₁","₂","₃","₄","₅","₆","₇","₈","₉"];
for idx = 1:10
    text = replace(text, plainLatex(idx), unicode(idx));
    text = replace(text, plain(idx), unicode(idx));
end
text = replace(text, "$\overline{", "");
text = erase(text, "$");
text = erase(text, "{");
text = replace(text, "}", string(char(773)));
end
