classdef HighSymmKpath < ...
        kssolv.analysis.matgenlab.symmetry.kpath.KPathBase
    %HIGHSYMMKPATH High-symmetry reciprocal paths in selectable conventions.
    properties (SetAccess=private)
        path_type (1,1) string
        label_index
        equiv_labels
        path_lengths
        prim
        conventional
        prim_rec
    end

    methods
        function obj=HighSymmKpath(structure,hasMagmoms,magmomAxis, ...
                pathType,symprec,angleTolerance,atol)
            if nargin<2||isempty(hasMagmoms),hasMagmoms=false;end
            if nargin<3,magmomAxis=[];end
            if nargin<4||isempty(pathType)
                pathType="setyawan_curtarolo";
            end
            if nargin<5||isempty(symprec),symprec=0.01;end
            if nargin<6||isempty(angleTolerance),angleTolerance=5;end
            if nargin<7||isempty(atol),atol=1e-5;end
            obj@kssolv.analysis.matgenlab.symmetry.kpath.KPathBase( ...
                structure,symprec,angleTolerance,atol);
            obj.path_type=string(pathType);
            obj.label_index=[];
            obj.equiv_labels=[];
            obj.path_lengths=[];
            switch obj.path_type
                case "setyawan_curtarolo"
                    path=kssolv.analysis.matgenlab.symmetry.kpath. ...
                        KPathSetyawanCurtarolo( ...
                        structure,symprec,angleTolerance,atol);
                    obj.copySC(path);
                case "hinuma"
                    path=kssolv.analysis.matgenlab.symmetry.kpath. ...
                        KPathSeek(structure,symprec,angleTolerance, ...
                        atol,~hasMagmoms);
                    obj.kpath=path.kpath;
                    obj.rec_lattice=structure.lattice.reciprocal_lattice;
                case "latimer_munro"
                    path=kssolv.analysis.matgenlab.symmetry.kpath. ...
                        KPathLatimerMunro(structure,hasMagmoms, ...
                        magmomAxis,symprec,angleTolerance,atol);
                    obj.kpath=path.kpath;
                    obj.rec_lattice=path.rec_lattice;
                case "all"
                    if hasMagmoms
                        error("KSSOLV:Matgenlab:HighSymmKpath:MagneticAll", ...
                            "The all convention cannot be used with magmoms.");
                    end
                    obj.combineAll(structure,magmomAxis,symprec, ...
                        angleTolerance,atol);
                otherwise
                    error("KSSOLV:Matgenlab:HighSymmKpath:PathType", ...
                        "Unknown path type '%s'.",obj.path_type);
            end
        end
    end

    methods (Static)
        function output=get_continuous_path(bandstructure)
            %GET_CONTINUOUS_PATH Eulerize and concatenate labeled branches.
            [edgeNames,branchRecords]=normalizedBranches(bandstructure);
            [walk,reversed]=eulerizedWalk(edgeNames);
            newCoordinates=zeros(0,3);
            spins=fieldnames(bandstructure.bands);
            newBands=struct();
            newProjections=struct();
            for spinIndex=1:numel(spins)
                spin=spins{spinIndex};
                newBands.(spin)=zeros(bandstructure.nb_bands,0);
                if isfield(bandstructure.projections,spin)
                    source=bandstructure.projections.(spin);
                    projectionSize=size(source);
                    newProjections.(spin)=zeros( ...
                        [bandstructure.nb_bands,0,projectionSize(3:end)]);
                end
            end
            for edgeIndex=1:numel(walk)
                record=branchRecords{walk(edgeIndex)};
                if ~reversed(edgeIndex)
                    indices=record.start_index:record.end_index;
                else
                    indices=record.end_index:-1:record.start_index;
                end
                coordinates=cell2mat(cellfun(@(point) ...
                    point.frac_coords, ...
                    bandstructure.kpoints(indices),UniformOutput=false).');
                newCoordinates=[newCoordinates;coordinates]; %#ok<AGROW>
                for spinIndex=1:numel(spins)
                    spin=spins{spinIndex};
                    newBands.(spin)=[newBands.(spin), ...
                        bandstructure.bands.(spin)(:,indices)];
                    if isfield(newProjections,spin)
                        source=bandstructure.projections.(spin);
                        newProjections.(spin)=cat(2, ...
                            newProjections.(spin),source(:,indices,:,:));
                    end
                end
            end
            labels=containers.Map("KeyType","char","ValueType","any");
            keys=bandstructure.labels_dict.keys;
            for index=1:numel(keys)
                labels(keys{index})= ...
                    bandstructure.labels_dict(keys{index}).frac_coords;
            end
            output=kssolv.analysis.matgenlab.electronic_structure. ...
                BandStructureSymmLine(newCoordinates,newBands, ...
                bandstructure.lattice_rec,bandstructure.efermi, ...
                labels,false,bandstructure.structure,newProjections);
        end
    end

    methods (Access=private)
        function copySC(obj,path)
            obj.kpath=path.kpath;
            obj.prim=path.prim;
            obj.conventional=path.conventional;
            obj.prim_rec=path.prim_rec;
            obj.rec_lattice=path.prim_rec;
        end

        function combineAll(obj,structure,magmomAxis,symprec, ...
                angleTolerance,atol)
            lm=kssolv.analysis.matgenlab.symmetry.kpath. ...
                KPathLatimerMunro(structure,false,magmomAxis, ...
                symprec,angleTolerance,atol);
            sc=kssolv.analysis.matgenlab.symmetry.kpath. ...
                KPathSetyawanCurtarolo( ...
                structure,symprec,angleTolerance,atol);
            hin=kssolv.analysis.matgenlab.symmetry.kpath. ...
                KPathSeek(structure,symprec,angleTolerance,atol,true);
            conventions={lm,sc,hin};
            points=containers.Map("KeyType","char","ValueType","any");
            paths=cell(1,0);
            labels=containers.Map("KeyType","char","ValueType","char");
            lengths=zeros(1,3);
            nextIndex=0;
            for conventionIndex=1:3
                source=conventions{conventionIndex}.kpath;
                keys=source.kpoints.keys;
                keyIndex=containers.Map("KeyType","char","ValueType","char");
                for index=1:numel(keys)
                    numericKey=sprintf("%d",nextIndex);
                    points(numericKey)=source.kpoints(keys{index});
                    labels(numericKey)=keys{index};
                    keyIndex(keys{index})=numericKey;
                    nextIndex=nextIndex+1;
                end
                for pathIndex=1:numel(source.path)
                    sourcePath=source.path{pathIndex};
                    paths{end+1}=cellfun(@(key)keyIndex(key), ...
                        sourcePath,UniformOutput=false); %#ok<AGROW>
                    lengths(conventionIndex)=lengths(conventionIndex)+ ...
                        numel(sourcePath);
                end
            end
            obj.kpath=struct("kpoints",points,"path",{paths});
            obj.label_index=labels;
            obj.path_lengths=lengths;
            obj.equiv_labels=equivalentLabels(conventions,obj.atol);
            obj.rec_lattice=structure.lattice.reciprocal_lattice;
        end
    end
end

function labels=equivalentLabels(conventions,atol)
names={"latimer_munro","setyawan_curtarolo","hinuma"};
labels=struct();
for firstIndex=1:3
    first=conventions{firstIndex}.kpath.kpoints;
    firstKeys=first.keys;
    firstName=names{firstIndex};
    labels.(firstName)=struct();
    for secondIndex=1:3
        if firstIndex==secondIndex,continue,end
        second=conventions{secondIndex}.kpath.kpoints;
        secondKeys=second.keys;
        mapping=struct();
        for keyIndex=1:numel(firstKeys)
            firstKey=firstKeys{keyIndex};
            match=firstKey;
            for candidateIndex=1:numel(secondKeys)
                candidate=secondKeys{candidateIndex};
                if norm(first(firstKey)-second(candidate))<=atol
                    match=candidate;
                    break
                end
            end
            mapping.(matlab.lang.makeValidName(firstKey))=match;
        end
        labels.(firstName).(names{secondIndex})=mapping;
    end
end
end

function [edges,records]=normalizedBranches(bandstructure)
records=bandstructure.branches;
edges=cell(numel(records),2);
for index=1:numel(records)
    record=records{index};
    pieces=split(string(record.name),"-");
    edges(index,:)={char(pieces(1)),char(pieces(end))};
end
end

function [walk,reverseFlags]=eulerizedWalk(edges)
% Add shortest paths between odd-degree vertices, then use Hierholzer.
names=unique(edges(:),"stable");
count=numel(names);
index=containers.Map(names,num2cell(1:count));
edgeList=zeros(size(edges,1),2);
original=(1:size(edges,1)).';
for edgeIndex=1:size(edges,1)
    edgeList(edgeIndex,:)=[index(edges{edgeIndex,1}), ...
        index(edges{edgeIndex,2})];
end
degree=accumarray(edgeList(:),1,[count,1]);
odd=find(mod(degree,2)==1);
while numel(odd)>=2
    start=odd(1);
    [vertices,pathEdges]=shortestUnweighted(start,odd(2:end),edgeList,count);
    target=vertices(end);
    for pathIndex=1:numel(pathEdges)
        edgeList(end+1,:)=edgeList(pathEdges(pathIndex),:); %#ok<AGROW>
        original(end+1)=original(pathEdges(pathIndex)); %#ok<AGROW>
    end
    odd(odd==start|odd==target)=[];
end
used=false(size(edgeList,1),1);
vertexStack=edgeList(1,1);
edgeStack=zeros(0,1);
circuit=zeros(0,1);
while ~isempty(vertexStack)
    vertex=vertexStack(end);
    candidate=find(~used & ...
        (edgeList(:,1)==vertex|edgeList(:,2)==vertex),1);
    if isempty(candidate)
        vertexStack(end)=[];
        if ~isempty(edgeStack)
            circuit(end+1)=edgeStack(end); %#ok<AGROW>
            edgeStack(end)=[];
        end
    else
        used(candidate)=true;
        other=edgeList(candidate,1)+edgeList(candidate,2)-vertex;
        vertexStack(end+1)=other; %#ok<AGROW>
        edgeStack(end+1)=candidate; %#ok<AGROW>
    end
end
circuit=fliplr(circuit);
walk=original(circuit).';
reverseFlags=false(size(walk));
current=edgeList(circuit(1),1);
for indexInWalk=1:numel(circuit)
    edge=edgeList(circuit(indexInWalk),:);
    reverseFlags(indexInWalk)=edge(2)~=current;
    current=edge(1)+edge(2)-current;
end
end

function [vertices,pathEdges]=shortestUnweighted(start,targets,edges,count)
queue=start;seen=false(count,1);seen(start)=true;
parent=zeros(count,1);parentEdge=zeros(count,1);finish=0;
while ~isempty(queue)
    vertex=queue(1);queue(1)=[];
    if any(targets==vertex),finish=vertex;break,end
    candidates=find(edges(:,1)==vertex|edges(:,2)==vertex);
    for edgeIndex=candidates.'
        neighbor=edges(edgeIndex,1)+edges(edgeIndex,2)-vertex;
        if ~seen(neighbor)
            seen(neighbor)=true;
            parent(neighbor)=vertex;
            parentEdge(neighbor)=edgeIndex;
            queue(end+1)=neighbor; %#ok<AGROW>
        end
    end
end
if finish==0
    error("KSSOLV:Matgenlab:HighSymmKpath:Disconnected", ...
        "The supplied k-path graph is disconnected.");
end
vertices=finish;pathEdges=zeros(0,1);
while vertices(1)~=start
    pathEdges=[parentEdge(vertices(1));pathEdges]; %#ok<AGROW>
    vertices=[parent(vertices(1));vertices]; %#ok<AGROW>
end
end
