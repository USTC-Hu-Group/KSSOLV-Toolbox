function value=changebasis(first,second,normal,points)
%CHANGEBASIS Express row points in an orthonormal column-vector basis.
matrix=[reshape(first,[],1),reshape(second,[],1),reshape(normal,[],1)];
value=(matrix\points.').';
end
