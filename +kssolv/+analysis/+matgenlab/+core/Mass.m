function obj = Mass(val, unit)
%MASS Construct a scalar mass quantity.
obj = kssolv.analysis.matgenlab.core.FloatWithUnit(val, unit, "mass");
end
