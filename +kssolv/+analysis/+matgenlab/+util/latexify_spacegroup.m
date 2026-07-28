function text = latexify_spacegroup(spacegroup_symbol)
%LATEXIFY_SPACEGROUP Format subscripts and overbars in a space-group symbol.
text = regexprep(string(spacegroup_symbol), '_(\d+)', '$_{$1}$');
text = regexprep(text, '-(\d)', '$\\overline{$1}$');
end
