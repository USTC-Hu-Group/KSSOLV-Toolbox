function [lines,stableEntries,unstableEntries]=order_phase_diagram( ...
    lines,stableEntries,unstableEntries,ordering)
%ORDER_PHASE_DIAGRAM Permute ternary plot corners by phase name.
ordering=string(ordering);
if ~iscell(stableEntries)||size(stableEntries,2)~=2
    error("KSSOLV:Matgenlab:PDPlotter:Ordering", ...
        "stableEntries must be a coordinate-entry cell table.");
end
coords=cell2mat(stableEntries(:,1));
[~,up]=max(coords(:,2));[~,left]=min(coords(:,1));[~,right]=max(coords(:,1));
cornerRows=[up,left,right];
names=cellfun(@entryName,stableEntries(cornerRows,2));
if ~all(ismember(ordering,names))
    error("KSSOLV:Matgenlab:PDPlotter:Ordering", ...
        "Ordering must name the current Up, Left, and Right terminal entries.");
end
currentVertices=[.5,sqrt(3)/2;0,0;1,0];
desiredVertices=currentVertices;
target=zeros(3,2);
for ii=1:3,target(ii,:)=desiredVertices(find(ordering==names(ii),1),:);end
transform=@(points)affineTransform(points,currentVertices,target);
for ii=1:numel(lines),lines{ii}=transform(lines{ii});end
for ii=1:size(stableEntries,1),stableEntries{ii,1}=transform(stableEntries{ii,1});end
for ii=1:size(unstableEntries,1),unstableEntries{ii,2}=transform(unstableEntries{ii,2});end
end
function output=affineTransform(points,source,target)
weights=[double(points),ones(size(points,1),1)]/[source,ones(3,1)];
output=weights*target;
end
function value=entryName(entry)
if isprop(entry,"name"),value=string(entry.name);else,value=entry.reduced_formula;end
end
