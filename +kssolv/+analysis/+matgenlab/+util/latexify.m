function text = latexify(formula, bold)
%LATEXIFY Add LaTeX subscripts to a chemical formula.
if nargin < 2, bold = false; end
if bold
    replacement = '$1$_{\mathbf{$2}}$';
else
    replacement = '$1$_{$2}$';
end
text = regexprep(string(formula), ...
    '([A-Za-z\(\)])([\d\.]+)', replacement);
end
