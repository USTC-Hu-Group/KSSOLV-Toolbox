function [box, symmOp] = lattice_2_lmpbox(lattice, origin)
%LATTICE_2_LMPBOX Convert a Lattice to LAMMPS restricted-triclinic form.
if nargin < 2, origin=[0 0 0]; end
abc=lattice.abc; a=abc(1); b=abc(2); c=abc(3);
xlo=origin(1); ylo=origin(2); zlo=origin(3); xhi=a+xlo;
m=lattice.matrix; xy=dot(m(2,:),m(1,:)/a);
yhi=sqrt(max(0,b*b-xy*xy))+ylo;
xz=dot(m(3,:),m(1,:)/a);
yz=(dot(m(2,:),m(3,:))-xy*xz)/(yhi-ylo);
zhi=sqrt(max(0,c*c-xz*xz-yz*yz))+zlo;
if lattice.is_orthogonal, tilt=[]; else, tilt=[xy xz yz]; end
restricted=[xhi-xlo 0 0;xy yhi-ylo 0;xz yz zhi-zlo];
rot=restricted\m;
box=kssolv.analysis.matgenlab.io.lammps.LammpsBox( ...
    [xlo xhi;ylo yhi;zlo zhi],tilt);
symmOp=kssolv.analysis.matgenlab.core.SymmOp. ...
    from_rotation_and_translation(rot,origin);
end
