function obj = TempArray(val, unit)
%TEMPARRAY Construct an array temperature quantity.
obj = kssolv.analysis.matgenlab.core.ArrayWithUnit(val, unit, "temperature");
end
