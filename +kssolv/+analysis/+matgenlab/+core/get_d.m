function value=get_d(slab)
%GET_D Cartesian z-spacing between the two lowest distinct atomic layers.
z=sort(slab.frac_coords(:,3));
delta=[];
for index=1:numel(z)-1
    if abs(z(index+1)-z(index))>1e-6
        delta=z(index+1)-z(index);break
    end
end
if isempty(delta)
    error("KSSOLV:Matgenlab:Surface:NoLayer", ...
        "Cannot identify any layer.");
end
cart=slab.lattice.get_cartesian_coords([0,0,delta]);
value=cart(3);
end
