function obj = Time(val, unit)
%TIME Construct a scalar time quantity.
obj = kssolv.analysis.matgenlab.core.FloatWithUnit(val, unit, "time");
end
