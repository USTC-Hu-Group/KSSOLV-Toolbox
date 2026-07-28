classdef RemoveSpeciesTransformation < ...
        kssolv.analysis.matgenlab.transformations.AbstractTransformation
    properties (SetAccess=private)
        species_to_remove
    end
    methods
        function obj=RemoveSpeciesTransformation(species)
            obj.species_to_remove=reshape(string(species),1,[]);
        end
        function result=apply_transformation(obj,structure,varargin)
            result=structure.copy();
            remove=false(1,result.num_sites);
            targets=cellfun(@(value) ...
                kssolv.analysis.matgenlab.core.getElSp(value), ...
                cellstr(obj.species_to_remove),"UniformOutput",false);
            for siteIndex=1:result.num_sites
                site=result(siteIndex);
                [species,amounts]=site.species.items();
                keep=true(1,numel(species));
                for speciesIndex=1:numel(species)
                    keep(speciesIndex)=~any(cellfun(@(target) ...
                        species{speciesIndex}==target,targets));
                end
                if ~any(keep)
                    remove(siteIndex)=true;
                elseif any(~keep)
                    replacement=cell(nnz(keep),2);
                    replacement(:,1)=species(keep);
                    replacement(:,2)=num2cell(amounts(keep));
                    result=result.replace(siteIndex,replacement);
                end
            end
            result=result.remove_sites(find(remove));
        end
    end
    methods (Static)
        function obj=from_dict(value)
            obj=kssolv.analysis.matgenlab.transformations. ...
                RemoveSpeciesTransformation(value.species_to_remove);
        end
        function obj=fromDict(value),obj= ...
                kssolv.analysis.matgenlab.transformations. ...
                RemoveSpeciesTransformation.from_dict(value);end
    end
end
