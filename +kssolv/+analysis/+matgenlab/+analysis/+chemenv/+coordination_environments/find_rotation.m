function value=find_rotation(points_distorted,points_perfect)
%FIND_ROTATION Orthogonal least-squares alignment matrix.
h=double(points_distorted).'*double(points_perfect);
[u,~,v]=svd(h);
value=v*u.';
end
