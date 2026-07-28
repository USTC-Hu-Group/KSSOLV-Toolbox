function result=triangular_coord(coordinates)
%TRIANGULAR_COORD Project reduced ternary coordinates into an equilateral triangle.
matrix=[1,0;.5,sqrt(3)/2];
result=double(coordinates)*matrix;
end
