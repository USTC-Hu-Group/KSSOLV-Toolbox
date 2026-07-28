function value=validate_label(prototypeFormula,pearsonSymbol,spgNum, ...
        allWyckoffs,chemicalSystem,elementAmounts,composition,raiseErrors)
%VALIDATE_LABEL Construct a label and validate Wyckoff multiplicities.
value=string(prototypeFormula)+"_"+string(pearsonSymbol)+"_"+ ...
    string(spgNum)+"_"+string(allWyckoffs)+":"+string(chemicalSystem);
observed=kssolv.analysis.matgenlab.core.Composition( ...
    elementAmounts).reduced_formula;
expected=composition.reduced_formula;
if observed~=expected
    message="Invalid WP multiplicities - "+value+", expected "+ ...
        observed+" to be "+expected;
    if raiseErrors
        error("KSSOLV:Matgenlab:Prototypes:InvalidMultiplicities", ...
            "%s",message);
    end
    value=message;
end
end
