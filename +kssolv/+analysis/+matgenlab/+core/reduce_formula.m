function [formula, factor] = reduce_formula(sym_amt, iupac_ordering)
%REDUCE_FORMULA Reduce an integer element-amount mapping.
if nargin < 2, iupac_ordering = false; end
composition = kssolv.analysis.matgenlab.core.Composition(sym_amt);
[formula, factor] = composition.get_reduced_formula_and_factor( ...
    iupac_ordering);
end
