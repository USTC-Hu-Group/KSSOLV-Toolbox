function result = obj_with_unit(obj, unit)
%OBJ_WITH_UNIT Attach a unit to a scalar, array, cell, or struct recursively.
unitType = kssolv.analysis.matgenlab.core.Unit.type_for_name(unit);
if isnumeric(obj) && isscalar(obj)
    result = kssolv.analysis.matgenlab.core.FloatWithUnit( ...
        obj, unit, unitType);
elseif isstruct(obj)
    result = obj;
    names = fieldnames(obj);
    for index = 1:numel(names)
        result.(names{index}) = ...
            kssolv.analysis.matgenlab.core.obj_with_unit( ...
            obj.(names{index}), unit);
    end
elseif iscell(obj)
    result = cellfun(@(value) ...
        kssolv.analysis.matgenlab.core.obj_with_unit(value, unit), ...
        obj, UniformOutput = false);
else
    result = kssolv.analysis.matgenlab.core.ArrayWithUnit( ...
        obj, unit, unitType);
end
end
