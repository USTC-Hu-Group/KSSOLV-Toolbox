function matrix3d=from_2d_to_3d(matrix2d)
%FROM_2D_TO_3D Embed an in-plane transformation in three dimensions.
matrix3d=eye(3);
matrix3d(1:2,1:2)=double(matrix2d);
end
