function obj = TimeArray(val, unit)
%TIMEARRAY Construct an array time quantity.
obj = kssolv.analysis.matgenlab.core.ArrayWithUnit(val, unit, "time");
end
