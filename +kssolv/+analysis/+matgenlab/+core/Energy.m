function obj = Energy(val, unit)
%ENERGY Construct a scalar energy quantity.
obj = kssolv.analysis.matgenlab.core.FloatWithUnit(val, unit, "energy");
end
