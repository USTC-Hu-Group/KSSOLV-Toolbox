function obj = ChargeArray(val, unit)
%CHARGEARRAY Construct an array charge quantity.
obj = kssolv.analysis.matgenlab.core.ArrayWithUnit(val, unit, "charge");
end
