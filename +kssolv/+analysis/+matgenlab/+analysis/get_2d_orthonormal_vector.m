function vector=get_2d_orthonormal_vector(linePoints)
%GET_2D_ORTHONORMAL_VECTOR Positive orthonormal direction to a 2-D line.
dx=abs(linePoints(2,1)-linePoints(1,1));
dy=abs(linePoints(2,2)-linePoints(1,2));
if abs(dx)<1e-12,theta=pi/2;else,theta=atan(dy/dx);end
vector=[sin(theta),cos(theta)];
end
