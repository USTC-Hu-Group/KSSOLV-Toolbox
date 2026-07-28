function value=get_protostructure_label_from_spg_analyzer( ...
        spg_analyzer,varargin)
%GET_PROTOSTRUCTURE_LABEL_FROM_SPG_ANALYZER Label an analyzer result.
options=struct("raise_errors",false);
options=kssolv.analysis.matgenlab.analysis.prototypes.internal. ...
    options(options,varargin);
symmetrized=spg_analyzer.get_symmetrized_structure();
spaceGroupNumber=spg_analyzer.get_space_group_number();
pearsonSymbol=spg_analyzer.get_pearson_symbol();
prototypeFormula=kssolv.analysis.matgenlab.analysis.prototypes. ...
    get_prototype_formula_from_composition(symmetrized.composition);
numberOrbits=numel(symmetrized.equivalent_sites);
multiplicities=zeros(1,numberOrbits);
elements=strings(1,numberOrbits);
letters=strings(1,numberOrbits);
for orbit=1:numberOrbits
    sites=symmetrized.equivalent_sites{orbit};
    multiplicities(orbit)=numel(sites);
    elements(orbit)=sites{1}.species_string;
    letters(orbit)=regexprep(symmetrized.wyckoff_symbols(orbit),"\d","");
end
[allWyckoffs,elementAmounts]= ...
    kssolv.analysis.matgenlab.analysis.prototypes.internal. ...
    element_wyckoffs_from_orbits(multiplicities,elements,letters, ...
    spaceGroupNumber);
value=kssolv.analysis.matgenlab.analysis.prototypes.internal. ...
    validate_label(prototypeFormula,pearsonSymbol,spaceGroupNumber, ...
    allWyckoffs,symmetrized.chemical_system,elementAmounts, ...
    symmetrized.composition,logical(options.raise_errors));
end
