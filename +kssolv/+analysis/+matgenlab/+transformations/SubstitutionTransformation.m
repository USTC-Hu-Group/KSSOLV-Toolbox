classdef SubstitutionTransformation < ...
        kssolv.analysis.matgenlab.transformations.AbstractTransformation
    properties (SetAccess = private)
        species_map cell
    end
    methods
        function obj = SubstitutionTransformation(mapping)
            if iscell(mapping)&&isvector(mapping)&&numel(mapping)==2
                mapping=reshape(mapping,1,2);
            end
            if isa(mapping,"containers.Map")
                keys_=mapping.keys();
                pairs=cell(numel(keys_),2);
                for index=1:numel(keys_)
                    pairs(index,:)={keys_{index},mapping(keys_{index})};
                end
            elseif isstruct(mapping)
                keys_=fieldnames(mapping);
                pairs=cell(numel(keys_),2);
                for index=1:numel(keys_)
                    pairs(index,:)={keys_{index},mapping.(keys_{index})};
                end
            elseif iscell(mapping)&&size(mapping,2)==2
                pairs=mapping;
            else
                error("KSSOLV:Matgenlab:SubstitutionTransformation:Map", ...
                    "species_map must be a struct, map, or two-column cell.");
            end
            obj.species_map=pairs;
        end
        function result=apply_transformation(obj,structure,varargin)
            result=structure.copy();
            for siteIndex=1:result.num_sites
                site=result(siteIndex);
                [species,amounts]=site.species.items();
                output=kssolv.analysis.matgenlab.core.Composition();
                for speciesIndex=1:numel(species)
                    replacement=[];
                    for mapIndex=1:size(obj.species_map,1)
                        source=kssolv.analysis.matgenlab.core.getElSp( ...
                            obj.species_map{mapIndex,1});
                        if species{speciesIndex}==source
                            replacement=obj.species_map{mapIndex,2};break
                        end
                    end
                    if isempty(replacement)
                        output=output+kssolv.analysis.matgenlab.core. ...
                            Composition({species{speciesIndex}, ...
                            amounts(speciesIndex)});
                    else
                        if ischar(replacement)||isstring(replacement)|| ...
                                isa(replacement, ...
                                "kssolv.analysis.matgenlab.core.Element")|| ...
                                isa(replacement, ...
                                "kssolv.analysis.matgenlab.core.Species")
                            replacementComposition= ...
                                kssolv.analysis.matgenlab.core.Composition( ...
                                {kssolv.analysis.matgenlab.core. ...
                                getElSp(replacement),1});
                        else
                            replacementComposition= ...
                                kssolv.analysis.matgenlab.core. ...
                                Composition(replacement);
                        end
                        replacementComposition= ...
                            replacementComposition*amounts(speciesIndex);
                        output=output+replacementComposition;
                    end
                end
                result=result.replace(siteIndex,output);
            end
        end
    end
    methods (Access=protected)
        function value=inverseTransformation(obj)
            reversed=cell(size(obj.species_map));
            for index=1:size(obj.species_map,1)
                if ~(ischar(obj.species_map{index,2})|| ...
                        isstring(obj.species_map{index,2})|| ...
                        isa(obj.species_map{index,2}, ...
                        "kssolv.analysis.matgenlab.core.Element")|| ...
                        isa(obj.species_map{index,2}, ...
                        "kssolv.analysis.matgenlab.core.Species"))
                    error("KSSOLV:Matgenlab:SubstitutionTransformation:Inverse", ...
                        "Disordered substitutions do not have a unique inverse.");
                end
                reversed(index,:)={obj.species_map{index,2}, ...
                    obj.species_map{index,1}};
            end
            value=kssolv.analysis.matgenlab.transformations. ...
                SubstitutionTransformation(reversed);
        end
    end
    methods (Static)
        function obj=from_dict(value)
            obj=kssolv.analysis.matgenlab.transformations. ...
                SubstitutionTransformation(value.species_map);
        end
        function obj=fromDict(value),obj= ...
                kssolv.analysis.matgenlab.transformations. ...
                SubstitutionTransformation.from_dict(value);end
    end
end
