function value=anticlockwise_sort(points)
%ANTICLOCKWISE_SORT Sort 2-D row points by polar angle.
indices=kssolv.analysis.matgenlab.analysis.chemenv.utils. ...
    anticlockwise_sort_indices(points);
value=points(indices,:);
end
