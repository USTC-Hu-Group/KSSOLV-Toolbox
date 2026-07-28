classdef ForceConstantMatrix < handle
    %FORCECONSTANTMATRIX Symmetry and acoustic-sum constrained force constants.
    properties
        structure
        fcm double
        pointops cell
        sharedops cell
        FCM_operations = []
    end
    methods
        function obj=ForceConstantMatrix(structure,fcm,pointops,sharedops,~)
            obj.structure=structure;obj.fcm=double(fcm);
            obj.pointops=reshape(pointops,1,[]);
            obj.sharedops=sharedops;
        end
        function operations=get_FCM_operations(obj,eigenTolerance, ...
                operationTolerance)
            if nargin<2,eigenTolerance=1e-5;end
            if nargin<3,operationTolerance=1e-5;end
            uniqueOps=collectOperations(obj.structure,obj.pointops);
            count=obj.structure.num_sites;passed=cell(1,0);
            relations=cell(1,0);
            for first=1:count
                for second=first:count
                    spectrum=sort(real(eig(obj.block4(first,second)))).';
                    match=[];
                    for index=1:numel(passed)
                        if all(abs(passed{index}.spectrum-spectrum)<= ...
                                eigenTolerance+1e-5* ...
                                abs(passed{index}.spectrum))
                            match=index;break
                        end
                    end
                    if isempty(match)
                        relation=struct("a",first,"b",second, ...
                            "c",second,"d",first);
                        passed{end+1}=struct("a",first,"b",second, ...
                            "spectrum",spectrum); %#ok<AGROW>
                    else
                        relation=struct("a",first,"b",second, ...
                            "c",passed{match}.a,"d",passed{match}.b);
                    end
                    relations{end+1}=relation; %#ok<AGROW>
                end
            end
            operations=cell(size(relations));
            for entry=1:numel(relations)
                relation=relations{entry};mapping={};good=false;
                source=obj.block4(relation.c,relation.d);
                target=obj.block4(relation.a,relation.b);
                for index=1:numel(uniqueOps)
                    transformed=uniqueOps{index}.transform_tensor(source);
                    if all(abs(transformed-target)<= ...
                            operationTolerance+1e-5*abs(target),"all")
                        mapping{end+1}=uniqueOps{index};good=true; %#ok<AGROW>
                    end
                end
                if (relation.a==relation.d&&relation.b==relation.c)|| ...
                        (relation.a==relation.c&&relation.b==relation.d)
                    good=true;
                end
                if ~good
                    temporary=relation.c;relation.c=relation.d;
                    relation.d=temporary;mapping={};
                    source=obj.block4(relation.d,relation.c);
                    for index=1:numel(uniqueOps)
                        transformed=uniqueOps{index}. ...
                            transform_tensor(source).';
                        if all(abs(transformed-target)<= ...
                                operationTolerance+1e-5*abs(target),"all")
                            mapping{end+1}=uniqueOps{index}; %#ok<AGROW>
                        end
                    end
                end
                relation.operations=mapping;operations{entry}=relation;
            end
            obj.FCM_operations=operations;
        end
        function matrix=get_unstable_FCM(obj,maxForce)
            if nargin<2,maxForce=1;end
            obj.requireOperations();
            count=obj.structure.num_sites;
            matrix=(2/maxForce)*ones(3*count);
            for entry=1:numel(obj.FCM_operations)
                relation=obj.FCM_operations{entry};
                target=blockIndices(relation.a,relation.b);
                reverse=blockIndices(relation.b,relation.a);
                same=relation.a==relation.b&& ...
                    relation.a==relation.c&&relation.a==relation.d;
                transpose=relation.a==relation.d&& ...
                    relation.b==relation.c;
                if ~transpose&&~same
                    source=blockIndices(relation.c,relation.d);
                    matrix(target{:})=averageTransforms( ...
                        matrix(source{:}),relation.operations);
                    matrix(reverse{:})=matrix(target{:}).';
                    continue
                end
                value=(rand(3)-.5)*maxForce;
                value=averageTransforms(value, ...
                    obj.sharedops{relation.a,relation.b});
                if relation.a~=relation.b
                    for index=1:numel(relation.operations)
                        transformed=relation.operations{index}. ...
                            transform_tensor(value.');
                        value=(value+transformed)/2;
                    end
                else
                    value=(value+value.')/2;
                end
                matrix(target{:})=value;matrix(reverse{:})=value.';
            end
        end
        function matrix=get_symmetrized_FCM(obj,matrix,~)
            obj.requireOperations();matrix=double(matrix);
            for entry=1:numel(obj.FCM_operations)
                relation=obj.FCM_operations{entry};
                target=blockIndices(relation.a,relation.b);
                reverse=blockIndices(relation.b,relation.a);
                same=relation.a==relation.b&& ...
                    relation.a==relation.c&&relation.a==relation.d;
                transpose=relation.a==relation.d&& ...
                    relation.b==relation.c;
                if ~transpose&&~same
                    source=blockIndices(relation.c,relation.d);
                    matrix(target{:})=averageTransforms( ...
                        matrix(source{:}),relation.operations);
                    matrix(reverse{:})=matrix(target{:}).';
                    continue
                end
                value=averageTransforms(matrix(target{:}), ...
                    obj.sharedops{relation.a,relation.b});
                if relation.a~=relation.b
                    for index=1:numel(relation.operations)
                        transformed=relation.operations{index}. ...
                            transform_tensor(value.');
                        value=(value+transformed)/2;
                    end
                else
                    value=(value+value.')/2;
                end
                matrix(target{:})=value;matrix(reverse{:})=value.';
            end
        end
        function matrix=get_stable_FCM(obj,matrix,acousticIterations)
            if nargin<3,acousticIterations=10;end
            matrix=double(matrix);
            for attempt=0:20
                [vectors,diagonal]=eig(matrix,"vector");
                [~,order]=sort(abs(diagonal));
                maximum=max(-diagonal);
                for index=4:numel(diagonal)
                    position=order(index);
                    if diagonal(position)>1e-6
                        diagonal(position)=-maximum*rand();
                    end
                end
                matrix=real(vectors*diag(diagonal)*vectors.');
                matrix=obj.get_symmetrized_FCM(matrix);
                matrix=obj.get_asum_FCM(matrix,acousticIterations);
                values=eig(matrix);[~,order]=sort(abs(values));
                if all(values(order(4:end))<=1e-6),break,end
                if attempt==20,break,end
            end
        end
        function matrix=get_asum_FCM(obj,matrix,iterations)
            if nargin<3,iterations=15;end
            obj.requireOperations();count=obj.structure.num_sites;
            correction=ones(3*count);
            for iteration=1:iterations
                source=real(matrix);pastRow=1;
                total=zeros(3);
                for column=1:count
                    indices=blockIndices(1,column);
                    total=total+source(indices{:});
                end
                total=total/count;
                for entry=1:numel(obj.FCM_operations)
                    relation=obj.FCM_operations{entry};
                    target=blockIndices(relation.a,relation.b);
                    reverse=blockIndices(relation.b,relation.a);
                    same=relation.a==relation.b&& ...
                        relation.a==relation.c&&relation.a==relation.d;
                    transpose=relation.a==relation.d&& ...
                        relation.b==relation.c;
                    if ~transpose&&~same
                        mapped=blockIndices(relation.c,relation.d);
                        correction(target{:})=averageTransforms( ...
                            correction(mapped{:}),relation.operations);
                        correction(reverse{:})=correction(target{:}).';
                        continue
                    end
                    currentRow=relation.a;
                    if currentRow~=pastRow
                        total=zeros(3);
                        for column=1:count
                            indices=blockIndices(currentRow,column);
                            total=total+source(indices{:});
                        end
                        for column=1:currentRow-1
                            indices=blockIndices(currentRow,column);
                            total=total-correction(indices{:});
                        end
                        total=total/(count-currentRow+1);
                    end
                    pastRow=currentRow;
                    value=averageTransforms(total, ...
                        obj.sharedops{relation.a,relation.b});
                    if relation.a~=relation.b
                        for index=1:numel(relation.operations)
                            transformed=relation.operations{index}. ...
                                transform_tensor(value.');
                            value=(value+transformed)/2;
                        end
                    else
                        value=(value+value.')/2;
                    end
                    correction(target{:})=value;
                    correction(reverse{:})=value.';
                end
                matrix=matrix-correction;
            end
        end
        function forceConstants=get_rand_FCM(obj,acousticIterations,force)
            if nargin<2,acousticIterations=15;end
            if nargin<3,force=10;end
            count=obj.structure.num_sites;
            dynamic=obj.get_unstable_FCM(force);
            dynamic=obj.get_stable_FCM(dynamic,acousticIterations);
            masses=zeros(1,count);
            for index=1:count
                masses(index)=obj.structure.sites{index}.specie.atomic_mass;
            end
            forceConstants=zeros(count,count,3,3);
            for first=1:count
                for second=1:count
                    indices=blockIndices(first,second);
                    forceConstants(first,second,:,:)= ...
                        dynamic(indices{:})* ...
                        sqrt(masses(first)*masses(second));
                end
            end
        end
    end
    methods (Access=private)
        function value=block4(obj,first,second)
            value=squeeze(obj.fcm(first,second,:,:));
        end
        function requireOperations(obj)
            if isempty(obj.FCM_operations)
                error("KSSOLV:Matgenlab:Piezo:Operations", ...
                    "Run get_FCM_operations before generating an FCM.");
            end
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

function indices=blockIndices(first,second)
indices={(3*first-2):(3*first),(3*second-2):(3*second)};
end

function value=averageTransforms(tensor,operations)
if isempty(operations),value=zeros(size(tensor));return,end
value=zeros(size(tensor));
for index=1:numel(operations)
    value=value+operations{index}.transform_tensor(tensor);
end
value=value/numel(operations);
end
