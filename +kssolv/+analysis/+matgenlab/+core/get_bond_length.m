function lengthValue = get_bond_length(sp1, sp2, bond_order)
%GET_BOND_LENGTH Return the database bond length or atomic-radii fallback.
if nargin < 3, bond_order = 1; end
first = kssolv.analysis.matgenlab.core.get_el_sp(sp1);
second = kssolv.analysis.matgenlab.core.get_el_sp(sp2);
try
    lengths = kssolv.analysis.matgenlab.core.obtain_all_bond_lengths( ...
        first, second);
    if ~isKey(lengths, double(bond_order))
        error("KSSOLV:Matgenlab:Bonds:MissingOrder", ...
            "Requested bond order is absent.");
    end
    lengthValue = lengths(double(bond_order));
catch exception
    if ~startsWith(exception.identifier, "KSSOLV:Matgenlab:Bonds:")
        rethrow(exception)
    end
    warning("KSSOLV:Matgenlab:Bonds:AtomicRadiusFallback", ...
        "No order %g bond length found; returning atomic radius sum.", ...
        bond_order);
    lengthValue = first.atomic_radius + second.atomic_radius;
end
end
