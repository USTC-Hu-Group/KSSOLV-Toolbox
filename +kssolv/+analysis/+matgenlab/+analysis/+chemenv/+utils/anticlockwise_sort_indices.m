function value=anticlockwise_sort_indices(points)
%ANTICLOCKWISE_SORT_INDICES One-based angular ordering of 2-D row points.
[~,value]=sort(atan2(points(:,2),points(:,1)));
value=reshape(value,1,[]);
end
