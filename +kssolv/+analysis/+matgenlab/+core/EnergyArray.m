function obj = EnergyArray(val, unit)
%ENERGYARRAY Construct an array energy quantity.
obj = kssolv.analysis.matgenlab.core.ArrayWithUnit(val, unit, "energy");
end
