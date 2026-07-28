classdef DisorderOrderedTransformation < ...
        kssolv.analysis.matgenlab.transformations.AbstractTransformation
    properties (SetAccess=private)
        max_sites_to_merge (1,1) double
    end
    methods
        function obj=DisorderOrderedTransformation(maxSites)
            if nargin<1,maxSites=2;end
            obj.max_sites_to_merge=maxSites;
        end
        function result=apply_transformation(obj,structure,returnRankedList)
            if nargin<3,returnRankedList=false;end
            if ~structure.is_ordered
                error("KSSOLV:Matgenlab:DisorderOrdered:Input", ...
                    "This transformation requires an ordered structure.");
            end
            [species,amounts]=structure.composition.items();
            partitions=kssolv.analysis.matgenlab.transformations. ...
                DisorderOrderedTransformation.speciesPartitions( ...
                1:numel(species),obj.max_sites_to_merge);
            outputs=cell(1,numel(partitions));
            for partitionIndex=1:numel(partitions)
                partition=partitions{partitionIndex};
                mapping=cell(0,2);
                for blockIndex=1:numel(partition)
                    selected=partition{blockIndex};
                    if numel(selected)<2,continue,end
                    total=sum(amounts(selected));
                    mixture=cell(numel(selected),2);
                    for index=1:numel(selected)
                        mixture(index,:)={species{selected(index)}, ...
                            amounts(selected(index))/total};
                    end
                    for index=1:numel(selected)
                        mapping(end+1,:)={species{selected(index)}, ...
                            mixture}; %#ok<AGROW>
                    end
                end
                transformed=kssolv.analysis.matgenlab.transformations. ...
                    SubstitutionTransformation(mapping). ...
                    apply_transformation(structure);
                outputs{partitionIndex}=struct( ...
                    "structure",transformed,"mapping",{mapping});
            end
            if isempty(outputs),result=[];return,end
            count=kssolv.analysis.matgenlab.transformations.internal.Utils. ...
                rankedCount(returnRankedList);
            if count==0,result=outputs{1}.structure;
            else,result=outputs(1:min(count,numel(outputs)));end
        end
    end
    methods (Access=protected)
        function value=oneToMany(~),value=true;end
    end
    methods (Static)
        function output=speciesPartitions(values,maxComponents)
            all=kssolv.analysis.matgenlab.transformations. ...
                DisorderOrderedTransformation.partitionRecursive(values);
            keep=false(1,numel(all));keys=zeros(numel(all),2);
            for index=1:numel(all)
                sizes=cellfun(@numel,all{index});
                keep(index)=max(sizes)<=maxComponents&&any(sizes>1);
                keys(index,:)=[max(sizes),-numel(sizes)];
            end
            all=all(keep);keys=keys(keep,:);
            [~,order]=sortrows(keys,[1,2]);
            output=all(order);
        end
        function obj=from_dict(value)
            obj=kssolv.analysis.matgenlab.transformations. ...
                DisorderOrderedTransformation(value.max_sites_to_merge);
        end
        function obj=fromDict(value),obj= ...
                kssolv.analysis.matgenlab.transformations. ...
                DisorderOrderedTransformation.from_dict(value);end
    end
    methods (Static,Access=private)
        function output=partitionRecursive(values)
            if isscalar(values)
                output={{values}};
                return
            end
            first=values(1);
            smaller=kssolv.analysis.matgenlab.transformations. ...
                DisorderOrderedTransformation. ...
                partitionRecursive(values(2:end));
            output=cell(1,0);
            for index=1:numel(smaller)
                partition=smaller{index};
                for block=1:numel(partition)
                    inserted=partition;
                    inserted{block}=[first,inserted{block}];
                    output{end+1}=inserted; %#ok<AGROW>
                end
                output{end+1}=[{first},partition]; %#ok<AGROW>
            end
        end
    end
end
