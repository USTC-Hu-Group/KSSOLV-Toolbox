function value=get_linearly_independent_vectors(vectors)
%GET_LINEARLY_INDEPENDENT_VECTORS First independent three-dimensional rows.
if iscell(vectors),vectors=cell2mat(cellfun(@(x)reshape(x,1,[]), ...
        vectors,"UniformOutput",false).');end
value=zeros(0,size(vectors,2));currentRank=0;
for index=1:size(vectors,1)
    candidate=vectors(index,:);
    if any(candidate~=0)&&rank([value;candidate])>currentRank
        value(end+1,:)=candidate; %#ok<AGROW>
        currentRank=currentRank+1;
    end
    if currentRank==3,break,end
end
end
