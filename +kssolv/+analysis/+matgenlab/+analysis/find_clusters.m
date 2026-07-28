function [maxCluster,minCluster,clusters]=find_clusters( ...
        structure,connectedMatrix)
%FIND_CLUSTERS Return sizes and memberships of bonded components.
count=structure.num_sites;
if count==0
    maxCluster=0;minCluster=0;clusters=0;return
end
if ~isequal(size(connectedMatrix),[count,count])
    error("KSSOLV:Matgenlab:Dimensionality:AdjacencyShape", ...
        "connectedMatrix must be square with one row per structure site.");
end
if any(sum(connectedMatrix,1)==0)
    maxCluster=0;minCluster=1;clusters=0;return
end
adjacency=connectedMatrix~=0;
visited=false(1,count);clusters={};sizes=[];
for start=1:count
    if visited(start),continue,end
    queue=start;visited(start)=true;members=[];
    while ~isempty(queue)
        current=queue(1);queue(1)=[];
        members(end+1)=current; %#ok<AGROW>
        neighbors=find(adjacency(current,:));
        unseen=neighbors(~visited(neighbors));
        visited(unseen)=true;queue=[queue,unseen]; %#ok<AGROW>
    end
    clusters{end+1}=sort(members); %#ok<AGROW>
    sizes(end+1)=numel(members); %#ok<AGROW>
end
maxCluster=max(sizes);minCluster=min(sizes);
end
