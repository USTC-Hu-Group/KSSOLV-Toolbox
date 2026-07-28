function wrapped = unitized(unit, func)
%UNITIZED Return a function handle assigning UNIT to the result of FUNC.
%
% MATLAB has no decorator syntax. Use:
%   wrapped = unitized("eV", @myFunction);
arguments
    unit (1,1) string
    func (1,1) function_handle
end
wrapped = @(varargin) assignUnit(func(varargin{:}), unit);
end

function result = assignUnit(value, unit)
if isempty(value)
    result = value;
elseif isa(value, "kssolv.analysis.matgenlab.core.FloatWithUnit") || ...
        isa(value, "kssolv.analysis.matgenlab.core.ArrayWithUnit")
    result = value.to(unit);
else
    result = kssolv.analysis.matgenlab.core.obj_with_unit(value, unit);
end
end
