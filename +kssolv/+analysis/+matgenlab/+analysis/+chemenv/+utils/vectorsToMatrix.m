function value=vectorsToMatrix(first,second)
%VECTORSTOMATRIX Outer product of two three-vectors.
value=reshape(first,[],1)*reshape(second,1,[]);
end
