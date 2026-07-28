function value = l2str(l)
%L2STR Convert an angular-momentum quantum number to spectroscopic notation.
letters = "spdfghi";
if ~isscalar(l) || l < 0 || l ~= fix(l) || l >= strlength(letters)
    error("KSSOLV:Matgenlab:Abinit:AngularMomentum", ...
        "Angular momentum must be an integer between 0 and 6.");
end
value = extractBetween(letters, l + 1, l + 1);
end
