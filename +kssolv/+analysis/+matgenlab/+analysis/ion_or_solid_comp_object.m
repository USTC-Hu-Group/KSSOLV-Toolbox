function value=ion_or_solid_comp_object(formula)
%ION_OR_SOLID_COMP_OBJECT Parse a solid composition or aqueous ion formula.
formula=string(formula);
if endsWith(formula,"(aq)")||~isempty(regexp(formula,'\[.*\]$','once'))|| ...
        contains(formula,"-")||contains(formula,"+")
    value=kssolv.analysis.matgenlab.core.Ion.from_formula(formula);
elseif endsWith(formula,"(s)")
    value=kssolv.analysis.matgenlab.core.Composition(extractBefore(formula, ...
        strlength(formula)-2));
else
    value=kssolv.analysis.matgenlab.core.Composition(formula);
end
end
