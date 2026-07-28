function value=vol_tetra(v1,v2,v3,v4)
%VOL_TETRA Volume of a tetrahedron from its four Cartesian vertices.
value=abs(dot(v1-v4,cross(v2-v4,v3-v4)))/6;
end
