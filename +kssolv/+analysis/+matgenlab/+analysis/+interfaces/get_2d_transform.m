function transform=get_2d_transform(startVectors,endVectors)
%GET_2D_TRANSFORM Least-squares transformation from start to end vectors.
transform=double(endVectors)*pinv(double(startVectors));
end
