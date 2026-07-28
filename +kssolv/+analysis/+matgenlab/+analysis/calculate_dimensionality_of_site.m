function [dimensionality,vertices]=calculate_dimensionality_of_site( ...
        bondedStructure,siteIndex,incVertices)
%CALCULATE_DIMENSIONALITY_OF_SITE Rank periodic images reached from a site.
% Implements Algorithm 1 of Larsen et al., Phys. Rev. Materials 3, 034003.
if nargin<3,incVertices=false;end
if ~isa(bondedStructure, ...
        "kssolv.analysis.matgenlab.core.StructureGraph")
    error("KSSOLV:Matgenlab:Dimensionality:StructureGraph", ...
        "bondedStructure must be a StructureGraph.");
end
if ~isscalar(siteIndex)||siteIndex<1|| ...
        siteIndex>bondedStructure.structure.num_sites|| ...
        siteIndex~=fix(siteIndex)
    error("KSSOLV:Matgenlab:Dimensionality:SiteIndex", ...
        "siteIndex must identify a site in the StructureGraph.");
end
siteCount=bondedStructure.structure.num_sites;
neighbors=cell(1,siteCount);
for index=1:siteCount
    connected=bondedStructure.get_connected_sites(index);
    values=cell(numel(connected),1);
    for neighborIndex=1:numel(connected)
        item=connected{neighborIndex};
        values{neighborIndex}=struct(index=item.index,image=item.jimage);
    end
    neighbors{index}=values;
end
seenKeys=strings(1,0);
seenImages=repmat({zeros(0,3)},1,siteCount);
queueIndices=siteIndex;
queueImages=zeros(1,3);
while ~isempty(queueIndices)
    componentIndex=queueIndices(1);
    image=queueImages(1,:);
    queueIndices(1)=[];
    queueImages(1,:)=[];
    key=vertexKey(componentIndex,image);
    if any(seenKeys==key),continue,end
    seenKeys(end+1)=key; %#ok<AGROW>
    if ~rankIncreases(seenImages{componentIndex},image),continue,end
    seenImages{componentIndex}(end+1,:)=image;
    connected=neighbors{componentIndex};
    for neighborIndex=1:numel(connected)
        candidateIndex=connected{neighborIndex}.index;
        candidateImage=image+connected{neighborIndex}.image;
        candidateKey=vertexKey(candidateIndex,candidateImage);
        if any(seenKeys==candidateKey),continue,end
        if rankIncreases(seenImages{candidateIndex},candidateImage)
            queueIndices(end+1)=candidateIndex; %#ok<AGROW>
            queueImages(end+1,:)=candidateImage; %#ok<AGROW>
        end
    end
end
vertices=seenImages{siteIndex};
dimensionality=imageRank(vertices);
if ~incVertices,vertices=[];end
end

function tf=rankIncreases(seen,candidate)
tf=imageRank([seen;candidate])>size(seen,1)-1;
end

function value=imageRank(vertices)
if isempty(vertices),value=-1;return,end
if size(vertices,1)==1,value=0;return,end
value=rank(vertices(2:end,:)-vertices(1,:),1e-10);
end

function key=vertexKey(index,image)
key=string(index)+":"+join(string(round(image)),",");
end
