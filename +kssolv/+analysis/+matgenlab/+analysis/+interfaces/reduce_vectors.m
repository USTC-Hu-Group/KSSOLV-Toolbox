function vectors=reduce_vectors(vector1,vector2)
%REDUCE_VECTORS Zur-McGill reduced two-vector basis.
first=double(vector1);second=double(vector2);
for iteration=1:1000
    if dot(first,second)<0
        second=-second;
        continue
    end
    if norm(first)>norm(second)
        temporary=first;first=second;second=temporary;
        continue
    end
    if norm(second)>norm(second+first)
        second=second+first;
        continue
    end
    if norm(second)>norm(second-first)
        second=second-first;
        continue
    end
    vectors=[first;second];
    return
end
error("KSSOLV:Matgenlab:ZSL:Reduction", ...
    "Vector reduction did not converge.");
end
