function obj = LengthArray(val, unit)
%LENGTHARRAY Construct an array length quantity.
obj = kssolv.analysis.matgenlab.core.ArrayWithUnit(val, unit, "length");
end
