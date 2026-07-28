classdef MoleculeMatcher < kssolv.analysis.matgenlab.util.MSONable
    %MOLECULEMATCHER OpenBabel-backed topology-aware molecule matcher.

    properties (SetAccess = private)
        tolerance (1,1) double
        mapper
    end

    methods
        function obj = MoleculeMatcher(tolerance, mapper)
            if nargin < 1, tolerance = 0.01; end
            if nargin < 2 || isempty(mapper)
                mapper = kssolv.analysis.matgenlab.core.InchiMolAtomMapper();
            end
            obj.tolerance = double(tolerance);
            obj.mapper = mapper;
        end

        function tf = fit(obj, molecule1, molecule2)
            tf = obj.get_rmsd(molecule1, molecule2) < obj.tolerance;
        end

        function value = get_rmsd(obj, molecule1, molecule2)
            [labels1, labels2] = ...
                obj.mapper.uniform_labels(molecule1, molecule2);
            if isempty(labels1) || isempty(labels2)
                value = Inf;
                return
            end
            first = kssolv.analysis.matgenlab.core.Molecule( ...
                molecule1.species_and_occu(labels1), ...
                molecule1.cart_coords(labels1, :), charge_spin_check = false);
            second = kssolv.analysis.matgenlab.core.Molecule( ...
                molecule2.species_and_occu(labels2), ...
                molecule2.cart_coords(labels2, :), charge_spin_check = false);
            [~, ~, value] = ...
                kssolv.analysis.matgenlab.core.KabschMatcher(second). ...
                match(first);
        end

        function groups = group_molecules(obj, molecules)
            molecules = reshape(molecules, 1, []);
            groups = cell(1, 0);
            for index = 1:numel(molecules)
                placed = false;
                for group = 1:numel(groups)
                    if obj.fit(groups{group}{1}, molecules{index})
                        groups{group}{end + 1} = molecules{index};
                        placed = true;
                        break
                    end
                end
                if ~placed
                    groups{end + 1} = {molecules{index}}; %#ok<AGROW,CCAT1>
                end
            end
        end

        function value = asDict(obj)
            value = struct("x_module", ...
                "pymatgen.core.molecule_matcher", ...
                "x_class", "MoleculeMatcher", ...
                "tolerance", obj.tolerance, ...
                "mapper", obj.mapper.as_dict());
        end

        function value = as_dict(obj), value = obj.asDict(); end
    end

    methods (Static)
        function obj = from_dict(value)
            mapper = kssolv.analysis.matgenlab.core. ...
                AbstractMolAtomMapper.from_dict(value.mapper);
            obj = kssolv.analysis.matgenlab.core.MoleculeMatcher( ...
                value.tolerance, mapper);
        end
    end
end
