function value=vec_area(vector1,vector2)
%VEC_AREA Area spanned by two vectors.
value=kssolv.analysis.matgenlab.analysis.interfaces. ...
    fast_norm(cross(vector1,vector2));
end
