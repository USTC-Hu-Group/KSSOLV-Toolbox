function value = str2l(letter)
%STR2L Convert spectroscopic angular-momentum notation to an integer.
letters = "spdfghi";
value = strfind(char(letters), lower(char(string(letter))));
if isempty(value) || numel(value) ~= 1
    error("KSSOLV:Matgenlab:Abinit:AngularMomentum", ...
        "Unknown angular-momentum label '%s'.", string(letter));
end
value = value - 1;
end
