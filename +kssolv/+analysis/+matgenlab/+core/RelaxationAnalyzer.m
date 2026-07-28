classdef RelaxationAnalyzer
    %RELAXATIONANALYZER Compare aligned initial and final structures.

    properties (SetAccess = protected)
        initial
        final
    end

    methods
        function obj = RelaxationAnalyzer(initialStructure, finalStructure)
            if initialStructure.formula ~= finalStructure.formula
                error("KSSOLV:Matgenlab:RelaxationAnalyzer:FormulaMismatch", ...
                    "Initial and final structures have different formulas.");
            end
            obj.initial = initialStructure;
            obj.final = finalStructure;
        end

        function value = get_percentage_volume_change(obj)
            value = obj.final.volume / obj.initial.volume - 1;
        end

        function value = get_percentage_lattice_parameter_changes(obj)
            value = struct( ...
                "a", obj.final.lattice.a / obj.initial.lattice.a - 1, ...
                "b", obj.final.lattice.b / obj.initial.lattice.b - 1, ...
                "c", obj.final.lattice.c / obj.initial.lattice.c - 1);
        end

        function value = get_percentage_bond_dist_changes(obj, maxRadius)
            if nargin < 2, maxRadius = 3; end
            value = cell(obj.initial.num_sites, obj.initial.num_sites);
            for first = 1:obj.initial.num_sites
                for second = first + 1:obj.initial.num_sites
                    initialDistance = ...
                        obj.initial.get_distance(first, second);
                    if initialDistance < maxRadius
                        finalDistance = ...
                            obj.final.get_distance(first, second);
                        value{first, second} = ...
                            finalDistance / initialDistance - 1;
                    end
                end
            end
        end
    end
end
