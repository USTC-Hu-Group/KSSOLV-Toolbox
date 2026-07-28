function value=matrixTimesVector(matrix,vector)
%MATRIXTIMESVECTOR Matrix-vector product.
value=(matrix*reshape(vector,[],1)).';
end
