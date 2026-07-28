function matrix=to_matrix(xx,yy,zz,xy,yz,xz)
%TO_MATRIX Assemble a symmetric dielectric tensor.
matrix=[xx,xy,xz;xy,yy,yz;xz,yz,zz];
end
