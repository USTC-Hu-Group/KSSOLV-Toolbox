function obj = Temp(val, unit)
%TEMP Construct a scalar temperature quantity.
obj = kssolv.analysis.matgenlab.core.FloatWithUnit(val, unit, "temperature");
end
