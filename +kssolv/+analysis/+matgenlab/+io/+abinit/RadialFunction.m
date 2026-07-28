classdef RadialFunction
    properties
        mesh double = []
        values double = []
    end
    methods
        function obj = RadialFunction(mesh, values)
            if nargin > 0, obj.mesh = mesh; obj.values = values; end
        end
        function value = to_tuple(obj), value = {obj.mesh, obj.values}; end
    end
end
