classdef InternalStrainTensor < handle
    %INTERNALSTRAINTENSOR Symmetry-aware atomic internal-strain tensors.
    properties
        structure
        ist double
        pointops cell
        IST_operations cell = cell(1,0)
    end
    methods
        function obj=InternalStrainTensor(structure,ist,pointops,tolerance)
            if nargin<4,tolerance=1e-3;end
            obj.structure=structure;obj.ist=double(ist);
            obj.pointops=reshape(pointops,1,[]);
            transposed=permute(obj.ist,[1,2,4,3]);
            if max(abs(obj.ist-transposed),[],"all")>tolerance
                warning("KSSOLV:Matgenlab:Piezo:InternalSymmetry", ...
                    "Input IST does not satisfy standard symmetries.");
            end
        end
        function operations=get_IST_operations(obj,operationTolerance)
            if nargin<2,operationTolerance=1e-3;end
            uniqueOps=collectOperations(obj.structure,obj.pointops);
            operations=cell(1,obj.structure.num_sites);
            for atom=1:obj.structure.num_sites
                mapping={};
                target=squeeze(obj.ist(atom,:,:,:));
                for source=1:atom-1
                    value=squeeze(obj.ist(source,:,:,:));
                    for index=1:numel(uniqueOps)
                        transformed=uniqueOps{index}.transform_tensor(value);
                        if all(abs(transformed-target)<= ...
                                operationTolerance+1e-5*abs(target),"all")
                            mapping{end+1}=struct("source",source, ...
                                "operation",uniqueOps{index}); %#ok<AGROW>
                        end
                    end
                end
                operations{atom}=mapping;
            end
            obj.IST_operations=operations;
        end
        function tensor=get_rand_IST(obj,maxForce)
            if nargin<2,maxForce=1;end
            if isempty(obj.IST_operations),obj.get_IST_operations();end
            count=obj.structure.num_sites;tensor=zeros(count,3,3,3);
            for atom=1:count
                mappings=obj.IST_operations{atom};
                if isempty(mappings)
                    value=rand(3,3,3)-.5;
                    for dimension=1:3
                        slice=squeeze(value(dimension,:,:));
                        value(dimension,:,:)=(slice+slice.')/2;
                    end
                    tensor(atom,:,:,:)=averageTransforms( ...
                        value,obj.pointops{atom});
                else
                    value=zeros(3,3,3);
                    for index=1:numel(mappings)
                        mapping=mappings{index};
                        source=squeeze(tensor(mapping.source,:,:,:));
                        value=value+mapping.operation. ...
                            transform_tensor(source);
                    end
                    tensor(atom,:,:,:)=value/numel(mappings);
                end
            end
            tensor=tensor*maxForce;
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
