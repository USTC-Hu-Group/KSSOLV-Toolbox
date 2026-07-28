function order=estimate_band_connection(previous,current,previousOrder)
%ESTIMATE_BAND_CONNECTION Match bands by maximum eigenvector overlap.
metric=abs(previous'*current);
connection=zeros(1,size(metric,1));
used=false(1,size(metric,2));
for row=1:size(metric,1)
    maximum=0; maximumIndex=1;
    for index=size(metric,2):-1:1
        if ~used(index) && metric(row,index)>maximum
            maximum=metric(row,index);
            maximumIndex=index;
        end
    end
    connection(row)=maximumIndex;
    used(maximumIndex)=true;
end
order=connection(reshape(previousOrder,1,[]));
end
