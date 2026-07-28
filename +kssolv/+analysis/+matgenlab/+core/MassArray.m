function obj = MassArray(val, unit)
%MASSARRAY Construct an array mass quantity.
obj = kssolv.analysis.matgenlab.core.ArrayWithUnit(val, unit, "mass");
end
