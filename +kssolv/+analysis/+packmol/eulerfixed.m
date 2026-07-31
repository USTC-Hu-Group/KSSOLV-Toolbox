function rotation = eulerfixed(beta, gamma, theta)
%EULERFIXED Packmol's fixed-molecule x/y/z Euler rotation matrix.

c1 = cos(beta); s1 = sin(beta);
c2 = cos(gamma); s2 = sin(gamma);
c3 = cos(theta); s3 = sin(theta);
rotation = [ ...
     c2*c3, -c2*s3,  s2; ...
     c1*s3 + c3*s1*s2, c1*c3 - s1*s2*s3, -c2*s1; ...
     s1*s3 - c1*c3*s2, c1*s2*s3 + c3*s1, c1*c2];
end
