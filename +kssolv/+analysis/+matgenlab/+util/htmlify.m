function text = htmlify(formula)
%HTMLIFY Add HTML subscripts to a chemical formula.
text = regexprep(string(formula), ...
    '([A-Za-z\(\)])([\d\.]+)', '$1<sub>$2</sub>');
end
