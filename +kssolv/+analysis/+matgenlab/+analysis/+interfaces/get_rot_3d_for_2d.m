function rotation=get_rot_3d_for_2d(filmMatrix,substrateMatrix)
%GET_ROT_3D_FOR_2D Proper polar rotation aligning two surface bases.
film=double(filmMatrix);
film=[film(1:2,:);cross(film(1,:),film(2,:))];
substrate=double(substrateMatrix);
substrate=substrate(1:2,:);
normal=cross(substrate(1,:),substrate(2,:));
normal=normal*kssolv.analysis.matgenlab.analysis.interfaces. ...
    fast_norm(film(3,:));
substrate=[substrate;normal];
transformation=(film\substrate).';
[left,~,right]=svd(transformation);
rotation=left*right.';
if det(rotation)<0
    left(:,end)=-left(:,end);
    rotation=left*right.';
end
end
