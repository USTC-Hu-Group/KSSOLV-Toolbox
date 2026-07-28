classdef PartialRemoveSitesTransformation < ...
        kssolv.analysis.matgenlab.transformations.AbstractTransformation
    properties (Constant)
        ALGO_FAST = 0
        ALGO_COMPLETE = 1
        ALGO_BEST_FIRST = 2
        ALGO_ENUMERATE = 3
    end
    properties (SetAccess = private)
        indices cell
        fractions double
        algo (1,1) double
    end
    methods
        function obj = PartialRemoveSitesTransformation( ...
                indices, fractions, algo)
            if nargin < 3, algo = obj.ALGO_COMPLETE; end
            if ~iscell(indices)
                if isvector(indices), indices = {indices};
                else
                    indices = mat2cell(indices, ...
                        ones(1,size(indices,1)), size(indices,2));
                end
            end
            if numel(indices) ~= numel(fractions)
                error("KSSOLV:Matgenlab:PartialRemoveSites:Length", ...
                    "indices and fractions must have equal lengths.");
            end
            obj.indices = cellfun(@(value) ...
                reshape(double(value),1,[]), indices, ...
                "UniformOutput", false);
            obj.fractions = reshape(double(fractions), 1, []);
            obj.algo = double(algo);
            if any(obj.fractions < 0 | obj.fractions > 1)
                error("KSSOLV:Matgenlab:PartialRemoveSites:Fraction", ...
                    "Removal fractions must lie between zero and one.");
            end
        end

        function result = apply_transformation( ...
                obj, structure, returnRankedList)
            if nargin < 3, returnRankedList = false; end
            for group = 1:numel(obj.indices)
                kssolv.analysis.matgenlab.transformations.internal.Utils. ...
                    validateIndices(obj.indices{group}, structure.num_sites);
            end
            if ~ismember(obj.algo, [obj.ALGO_FAST,obj.ALGO_COMPLETE, ...
                    obj.ALGO_BEST_FIRST,obj.ALGO_ENUMERATE])
                error("KSSOLV:Matgenlab:PartialRemoveSites:Algorithm", ...
                    "Invalid removal algorithm.");
            end
            choices = cell(1, numel(obj.indices));
            for group = 1:numel(obj.indices)
                amount = numel(obj.indices{group}) * obj.fractions(group);
                if abs(amount - round(amount)) > 1e-3
                    error("KSSOLV:Matgenlab:PartialRemoveSites:Integer", ...
                        "Fraction to remove must be consistent with " + ...
                        "integer amounts in the structure.");
                end
                choices{group} = ...
                    kssolv.analysis.matgenlab.transformations.internal. ...
                    Utils.choose(obj.indices{group}, round(amount));
            end
            selections = ...
                kssolv.analysis.matgenlab.transformations.internal.Utils. ...
                productChoices(choices);
            ranked = cell(1, numel(selections));
            try
                ewald = kssolv.analysis.matgenlab.core. ...
                    EwaldSummation(structure);
                useEwald = true;
            catch
                ewald = [];
                useEwald = false;
            end
            for index = 1:numel(selections)
                removed = unique(selections{index});
                candidate = structure.copy();
                candidate = candidate.remove_sites(removed);
                candidate = candidate.get_sorted_structure();
                if useEwald
                    energy = ewald.compute_partial_energy(removed);
                else
                    energy = 0;
                end
                ranked{index} = struct( ...
                    "structure", candidate, "energy", energy, ...
                    "energy_above_minimum", 0, ...
                    "removed_indices",removed);
            end
            energies = cellfun(@(entry) entry.energy, ranked);
            [~, order] = sort(energies);
            ranked = ranked(order);
            % COMPLETE and ENUMERATE expose symmetrically distinct results.
            if ismember(obj.algo, [obj.ALGO_COMPLETE,obj.ALGO_ENUMERATE]) ...
                    && numel(ranked) > 1
                analyzer=kssolv.analysis.matgenlab.symmetry.analyzer. ...
                    SpacegroupAnalyzer(structure,.2);
                operations=analyzer.get_space_group_operations();
                uniqueEntries = cell(1,0);
                for index = 1:numel(ranked)
                    removedSites=arrayfun(@(siteIndex) ...
                        structure(siteIndex), ...
                        ranked{index}.removed_indices, ...
                        "UniformOutput",false);
                    duplicate=false;
                    for prior=1:numel(uniqueEntries)
                        priorSites=arrayfun(@(siteIndex) ...
                            structure(siteIndex), ...
                            uniqueEntries{prior}.removed_indices, ...
                            "UniformOutput",false);
                        energyClose=abs((ranked{index}.energy- ...
                            uniqueEntries{prior}.energy)/ ...
                            max(1,ranked{index}.structure.num_sites))<1e-5;
                        if energyClose&&operations. ...
                                are_symmetrically_equivalent( ...
                                removedSites,priorSites,.2)
                            duplicate=true;break
                        end
                    end
                    if ~duplicate
                        uniqueEntries{end+1} = ranked{index}; %#ok<AGROW>
                    end
                end
                ranked = uniqueEntries;
            end
            minimum = ranked{1}.energy;
            atoms = max(1, structure.composition.num_atoms);
            for index = 1:numel(ranked)
                ranked{index}.energy_above_minimum = ...
                    (ranked{index}.energy - minimum) / atoms;
                ranked{index}=rmfield(ranked{index},"removed_indices");
            end
            count = kssolv.analysis.matgenlab.transformations.internal. ...
                Utils.rankedCount(returnRankedList);
            if count == 0
                result = ranked{1}.structure;
            else
                result = ranked(1:min(count,numel(ranked)));
            end
        end
    end
    methods (Access = protected)
        function value = oneToMany(~), value = true; end
    end
    methods (Static)
        function obj = from_dict(value)
            obj = kssolv.analysis.matgenlab.transformations. ...
                PartialRemoveSitesTransformation(value.indices, ...
                value.fractions, value.algo);
        end
        function obj = fromDict(value), obj = ...
                kssolv.analysis.matgenlab.transformations. ...
                PartialRemoveSitesTransformation.from_dict(value); end
    end
end
