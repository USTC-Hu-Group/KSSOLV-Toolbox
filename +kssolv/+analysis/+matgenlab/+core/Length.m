function obj = Length(val, unit)
%LENGTH Construct a scalar length quantity.
obj = kssolv.analysis.matgenlab.core.FloatWithUnit(val, unit, "length");
end
