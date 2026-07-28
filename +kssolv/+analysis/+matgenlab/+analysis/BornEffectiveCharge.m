classdef BornEffectiveCharge < handle
    %BORNEFFECTIVECHARGE Symmetry-aware collection of atomic BEC tensors.
    properties
        structure
        bec double
        pointops cell
        BEC_operations = []
    end
    methods
        function obj=BornEffectiveCharge(structure,bec,pointops,tolerance)
            if nargin<4,tolerance=1e-3;end
            obj.structure=structure;obj.bec=double(bec);
            obj.pointops=reshape(pointops,1,[]);
            if sum(obj.bec,"all")>=tolerance
                warning("KSSOLV:Matgenlab:Piezo:ChargeNeutrality", ...
                    "Input BEC tensor does not satisfy charge neutrality.");
            end
        end
        function operations=get_BEC_operations(obj,eigenTolerance, ...
                operationTolerance)
            if nargin<2,eigenTolerance=1e-5;end
            if nargin<3,operationTolerance=1e-3;end
            uniqueOps=collectOperations(obj.structure,obj.pointops);
            representatives=zeros(1,0);spectra=zeros(0,3);
            relations=zeros(obj.structure.num_sites,2);
            for site=1:obj.structure.num_sites
                values=sort(real(eig(squeeze(obj.bec(site,:,:))))).';
                match=find(all(abs(spectra-values)<= ...
                    eigenTolerance+1e-5*abs(spectra),2),1);
                if isempty(match)
                    representatives(end+1)=site; %#ok<AGROW>
                    spectra(end+1,:)=values; %#ok<AGROW>
                    relations(site,:)=[site,site];
                else
                    relations(site,:)=[site,representatives(match)];
                end
            end
            operations=cell(1,obj.structure.num_sites);
            for site=1:obj.structure.num_sites
                mapping={};
                target=squeeze(obj.bec(relations(site,1),:,:));
                source=squeeze(obj.bec(relations(site,2),:,:));
                for index=1:numel(uniqueOps)
                    transformed=uniqueOps{index}.transform_tensor(source);
                    if all(abs(transformed-target)<= ...
                            operationTolerance+1e-5*abs(target),"all")
                        mapping{end+1}=uniqueOps{index}; %#ok<AGROW>
                    end
                end
                operations{site}=struct("target",relations(site,1), ...
                    "source",relations(site,2),"operations",{mapping});
            end
            obj.BEC_operations=operations;
        end
        function tensor=get_rand_BEC(obj,maxCharge)
            if nargin<2,maxCharge=1;end
            if isempty(obj.BEC_operations),obj.get_BEC_operations();end
            count=obj.structure.num_sites;tensor=zeros(count,3,3);
            for atom=1:count
                relation=obj.BEC_operations{atom};
                if relation.target==relation.source
                    value=rand(3)-.5;
                    tensor(atom,:,:)=averageTransforms( ...
                        value,obj.pointops{atom});
                else
                    source=squeeze(tensor(relation.source,:,:));
                    tensor(atom,:,:)=averageTransforms( ...
                        source,relation.operations);
                end
            end
            displacement=squeeze(sum(tensor,1))/count;
            correction=zeros(size(tensor));
            for atom=1:count
                relation=obj.BEC_operations{atom};
                if relation.target==relation.source
                    correction(atom,:,:)=averageTransforms( ...
                        displacement,obj.pointops{atom});
                else
                    source=squeeze(correction(relation.source,:,:));
                    correction(atom,:,:)=averageTransforms( ...
                        source,relation.operations);
                end
            end
            tensor=(tensor-correction)*maxCharge;
        end
    end
end

function operations=collectOperations(structure,pointops)
operations=kssolv.analysis.matgenlab.symmetry.analyzer. ...
    SpacegroupAnalyzer(structure).get_symmetry_operations(true);
for atom=1:numel(pointops)
    for index=1:numel(pointops{atom})
        operation=pointops{atom}{index};
        if ~any(cellfun(@(item)item==operation,operations))
            operations{end+1}=operation; %#ok<AGROW>
        end
    end
end
end

function value=averageTransforms(tensor,operations)
value=zeros(size(tensor));
for index=1:numel(operations)
    value=value+operations{index}.transform_tensor(tensor);
end
if ~isempty(operations),value=value/numel(operations);end
end
