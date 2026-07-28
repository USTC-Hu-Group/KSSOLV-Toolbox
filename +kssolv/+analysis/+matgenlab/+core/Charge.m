function obj = Charge(val, unit)
%CHARGE Construct a scalar charge quantity.
obj = kssolv.analysis.matgenlab.core.FloatWithUnit(val, unit, "charge");
end
