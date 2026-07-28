classdef RemoveDuplicatesFilter < ...
        kssolv.analysis.matgenlab.alchemy.AbstractStructureFilter
    %REMOVEDUPLICATESFILTER Stateful duplicate structure filter.

    properties (SetAccess = private)
        structure_matcher
        symprec
        structure_list cell = cell(1, 0)
    end

    methods
        function obj = RemoveDuplicatesFilter(structureMatcher, symprec)
            if nargin < 1 || isempty(structureMatcher)
                structureMatcher = kssolv.analysis.matgenlab.core. ...
                    StructureMatcher(0.2, 0.3, 5, true, true, false, ...
                    false, kssolv.analysis.matgenlab.core.ElementComparator());
            elseif isstruct(structureMatcher)
                structureMatcher = kssolv.analysis.matgenlab.core. ...
                    StructureMatcher.from_dict(structureMatcher);
            end
            if ~isa(structureMatcher, ...
                    "kssolv.analysis.matgenlab.core.StructureMatcher")
                error("KSSOLV:Matgenlab:RemoveDuplicatesFilter:Matcher", ...
                    "structure_matcher must be a StructureMatcher or MSON struct.");
            end
            if nargin < 2, symprec = []; end
            obj.structure_matcher = structureMatcher;
            obj.symprec = symprec;
        end

        function accepted = test(obj, structure)
            for index = 1:numel(obj.structure_list)
                candidate = obj.structure_list{index};
                if ~isempty(obj.symprec) && ...
                        spaceGroup(candidate, obj.symprec) ~= ...
                        spaceGroup(structure, obj.symprec)
                    continue
                end
                if obj.structure_matcher.fit(candidate, structure)
                    accepted = false;
                    return
                end
            end
            obj.structure_list{end + 1} = structure;
            accepted = true;
        end

        function value = asDict(obj)
            value = struct( ...
                "x_module", "pymatgen.alchemy.filters", ...
                "x_class", "RemoveDuplicatesFilter", "x_version", [], ...
                "structure_matcher", obj.structure_matcher.as_dict(), ...
                "symprec", obj.symprec);
        end
    end

    methods (Static)
        function obj = from_dict(value)
            obj = kssolv.analysis.matgenlab.alchemy.RemoveDuplicatesFilter( ...
                value.structure_matcher, value.symprec);
        end

        function obj = fromDict(value)
            obj = kssolv.analysis.matgenlab.alchemy. ...
                RemoveDuplicatesFilter.from_dict(value);
        end
    end
end

function number = spaceGroup(structure, symprec)
analyzer = kssolv.analysis.matgenlab.symmetry.analyzer. ...
    SpacegroupAnalyzer(structure, symprec);
number = analyzer.get_space_group_number();
end
