function [factor,rotated,perfect]=find_scaling_factor( ...
        points_distorted,points_perfect,rotation)
%FIND_SCALING_FACTOR Least-squares scale after rotation.
distorted=double(points_distorted);
perfect=double(points_perfect);
rotated=(rotation*distorted.').';
denominator=sum(rotated.^2,"all");
if denominator==0,factor=0;
else,factor=sum(rotated.*perfect,"all")/denominator;end
end
