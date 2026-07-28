function text = unicodeify_species(specie_string)
%UNICODEIFY_SPECIES Add Unicode superscripts to an oxidation-state string.
text = string(specie_string);
plain = ["0","1","2","3","4","5","6","7","8","9","+","-"];
unicode = ["⁰","¹","²","³","⁴","⁵","⁶","⁷","⁸","⁹","⁺","⁻"];
for idx = 1:numel(plain), text = replace(text, plain(idx), unicode(idx)); end
end
