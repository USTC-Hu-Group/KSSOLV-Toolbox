function value=fast_norm(vector)
%FAST_NORM Euclidean norm using a single dot product.
vector=double(vector);
value=sqrt(dot(vector,vector));
end
