function point=fold_point(point,lattice,coordsAreCartesian)
%FOLD_POINT Fold a reciprocal-space point into the first Brillouin zone.
if nargin<3||isempty(coordsAreCartesian),coordsAreCartesian=false;end
if coordsAreCartesian,fractional=lattice.get_fractional_coords(point);
else,fractional=reshape(double(point),1,3);end
fractional=mod(fractional+.5-1e-10,1)-.5+1e-10;
point=lattice.get_cartesian_coords(fractional);
best=zeros(1,3);distance=inf;
for ii=-1:1
    for jj=-1:1
        for kk=-1:1
            candidate=[ii,jj,kk]*lattice.matrix;
            current=norm(point-candidate);
            if current<distance,distance=current;best=candidate;end
        end
    end
end
point=point-best;
end
