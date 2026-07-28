function result=magnetic_deformation(structureA,structureB)
%MAGNETIC_DEFORMATION Compute the lattice deformation between magnetic states.
first=kssolv.analysis.matgenlab.analysis.magnetism. ...
    CollinearMagneticStructureAnalyzer(structureA);
second=kssolv.analysis.matgenlab.analysis.magnetism. ...
    CollinearMagneticStructureAnalyzer(structureB);
orderA=string(first.ordering);orderB=string(second.ordering);
A=structureA.lattice.matrix.';B=structureB.lattice.matrix.';
gradient=A\B;
eta=.5*(gradient.'*gradient-eye(3));
principal=eig(eta);
value=100/3*sqrt(sum(principal.^2));
result=kssolv.analysis.matgenlab.analysis.magnetism. ...
    MagneticDeformation(value,orderA+"-"+orderB);
end
