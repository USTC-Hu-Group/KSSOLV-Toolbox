function operation=get_rot(slab)
%GET_ROT Return the rotation that aligns the slab normal with Cartesian z.
newZ=kssolv.analysis.matgenlab.core.get_mi_vec(slab);
newX=slab.lattice.matrix(1,:);
newX=newX/norm(newX);
newY=cross(newZ,newX);
newY=newY/norm(newY);
rotation=[newX;newY;newZ];
operation=kssolv.analysis.matgenlab.core.SymmOp. ...
    from_rotation_and_translation(rotation,[0,0,0]);
end
