function value = str2float(text)
%STR2FLOAT Convert CIF numeric text after removing uncertainty brackets.
value = kssolv.analysis.matgenlab.io.cif.CifParser.str2float(text);
end
