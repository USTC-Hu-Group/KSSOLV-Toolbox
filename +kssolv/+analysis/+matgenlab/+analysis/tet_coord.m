function result=tet_coord(coordinates)
%TET_COORD Project reduced quaternary coordinates into a regular tetrahedron.
matrix=[1,0,0;.5,sqrt(3)/2,0;.5,sqrt(3)/6,sqrt(6)/3];
result=double(coordinates)*matrix;
end
