classdef RemoveExistingFilter < ...
        kssolv.analysis.matgenlab.alchemy.AbstractStructureFilter
    %REMOVEEXISTINGFILTER Reject structures matching an existing collection.

    properties (SetAccess = private)
        existing_structures cell
        structure_matcher
        symprec
        structure_list cell = cell(1, 0)
    end

    methods
        function obj = RemoveExistingFilter(existingStructures, ...
                structureMatcher, symprec)
            if isa(existingStructures, ...
                    "kssolv.analysis.matgenlab.core.IStructure")
                existingStructures = {existingStructures};
            elseif ~iscell(existingStructures)
                existingStructures = num2cell(existingStructures);
            end
            obj.existing_structures = reshape(existingStructures, 1, []);
            if nargin < 2 || isempty(structureMatcher)
                structureMatcher = kssolv.analysis.matgenlab.core. ...
                    StructureMatcher(0.2, 0.3, 5, true, true, false, ...
                    false, kssolv.analysis.matgenlab.core.ElementComparator());
            elseif isstruct(structureMatcher)
                structureMatcher = kssolv.analysis.matgenlab.core. ...
                    StructureMatcher.from_dict(structureMatcher);
            end
            if ~isa(structureMatcher, ...
                    "kssolv.analysis.matgenlab.core.StructureMatcher")
                error("KSSOLV:Matgenlab:RemoveExistingFilter:Matcher", ...
                    "structure_matcher must be a StructureMatcher or MSON struct.");
            end
            if nargin < 3, symprec = []; end
            obj.structure_matcher = structureMatcher;
            obj.symprec = symprec;
        end

        function accepted = test(obj, structure)
            for index = 1:numel(obj.existing_structures)
                candidate = obj.existing_structures{index};
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
            structures = cellfun(@(item) item.as_dict(), ...
                obj.existing_structures, "UniformOutput", false);
            value = struct( ...
                "x_module", "pymatgen.alchemy.filters", ...
                "x_class", "RemoveExistingFilter", ...
                "init_args", struct( ...
                "existing_structures", {structures}, ...
                "structure_matcher", obj.structure_matcher.as_dict(), ...
                "symprec", obj.symprec));
        end
    end

    methods (Static)
        function obj = from_dict(value)
            args = value.init_args;
            if isfield(args, "existing_structures")
                structures = args.existing_structures;
            else
                structures = {};
            end
            if isfield(args, "symprec"), symprec = args.symprec;
            else, symprec = []; end
            obj = kssolv.analysis.matgenlab.alchemy.RemoveExistingFilter( ...
                structures, args.structure_matcher, symprec);
        end

        function obj = fromDict(value)
            obj = kssolv.analysis.matgenlab.alchemy. ...
                RemoveExistingFilter.from_dict(value);
        end
    end
end

function number = spaceGroup(structure, symprec)
analyzer = kssolv.analysis.matgenlab.symmetry.analyzer. ...
    SpacegroupAnalyzer(structure, symprec);
number = analyzer.get_space_group_number();
end
