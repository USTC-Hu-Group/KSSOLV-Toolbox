function qpoints=phonopy_mesh_qpoints(structure,meshDensity)
%PHONOPY_MESH_QPOINTS Gamma-centered full mesh in phonopy ordering.
inverse=inv(structure.lattice.matrix);
lengths=vecnorm(inverse.',2,2).';
mesh=max(1,round(lengths*meshDensity));
coordinates=cell(1,3);
for axis=1:3
    count=mesh(axis);
    indices=0:count-1;
    values=indices/count;
    values(values>=0.5)=values(values>=0.5)-1;
    coordinates{axis}=values;
end
qpoints=zeros(prod(mesh),3);output=0;
for third=coordinates{3}
    for second=coordinates{2}
        for first=coordinates{1}
            output=output+1;
            qpoints(output,:)=[first,second,third];
        end
    end
end
end
