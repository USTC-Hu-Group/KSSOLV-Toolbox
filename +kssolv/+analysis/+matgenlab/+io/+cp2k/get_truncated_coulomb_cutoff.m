function value=get_truncated_coulomb_cutoff(structure)
m=structure.lattice.matrix;m(abs(m)<=1e-5)=0;a=m(1,:);b=m(2,:);c=m(3,:);
d=[abs(dot(a,cross(b,c))/norm(cross(b,c))),abs(dot(b,cross(a,c))/norm(cross(a,c))),abs(dot(c,cross(a,b))/norm(cross(a,b)))];
value=floor(100*min(d)/2)/100;
end
