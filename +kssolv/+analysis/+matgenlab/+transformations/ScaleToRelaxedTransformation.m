classdef ScaleToRelaxedTransformation < ...
        kssolv.analysis.matgenlab.transformations.AbstractTransformation
    properties (SetAccess=private)
        params_percent_change (1,6) double
        unrelaxed_structure
        relaxed_structure
        species_map
    end
    methods
        function obj=ScaleToRelaxedTransformation( ...
                unrelaxed,relaxed,speciesMap)
            if nargin<3,speciesMap=[];end
            before=[unrelaxed.lattice.lengths,unrelaxed.lattice.angles];
            after=[relaxed.lattice.lengths,relaxed.lattice.angles];
            obj.params_percent_change=after./before;
            obj.unrelaxed_structure=unrelaxed;
            obj.relaxed_structure=relaxed;
            obj.species_map=speciesMap;
        end
        function result=apply_transformation(obj,structure,varargin)
            params=[structure.lattice.lengths,structure.lattice.angles].* ...
                obj.params_percent_change;
            lattice=kssolv.analysis.matgenlab.core.Lattice. ...
                from_parameters(params(1),params(2),params(3), ...
                params(4),params(5),params(6));
            if isempty(obj.species_map)
                matcher=kssolv.analysis.matgenlab.core.StructureMatcher();
                speciesMap=matcher. ...
                    get_best_electronegativity_anonymous_mapping( ...
                    obj.unrelaxed_structure,structure);
                if isempty(speciesMap)
                    error("KSSOLV:Matgenlab:ScaleToRelaxed:Species", ...
                        "Could not infer an anonymous species mapping.");
                end
            else
                normalized=kssolv.analysis.matgenlab.transformations. ...
                    internal.Utils.normalizeMap(obj.species_map);
                speciesMap=struct();
                keys_=normalized.keys();
                for mapIndex=1:numel(keys_)
                    source=kssolv.analysis.matgenlab.core. ...
                        getElSp(keys_{mapIndex});
                    speciesMap.(char(source.symbol))= ...
                        normalized(keys_{mapIndex});
                end
            end
            species=cell(1,obj.relaxed_structure.num_sites);
            for index=1:numel(species)
                symbol=char(obj.relaxed_structure(index).specie.symbol);
                if ~isfield(speciesMap,symbol)
                    error("KSSOLV:Matgenlab:ScaleToRelaxed:Species", ...
                        "No species mapping is available for '%s'.",symbol);
                end
                species{index}=speciesMap.(symbol);
            end
            result=kssolv.analysis.matgenlab.core.Structure( ...
                lattice,species,obj.relaxed_structure.frac_coords);
        end
    end
    methods (Static)
        function obj=from_dict(value)
            obj=kssolv.analysis.matgenlab.transformations. ...
                ScaleToRelaxedTransformation(value.unrelaxed_structure, ...
                value.relaxed_structure,value.species_map);
        end
        function obj=fromDict(value),obj= ...
                kssolv.analysis.matgenlab.transformations. ...
                ScaleToRelaxedTransformation.from_dict(value);end
    end
end
