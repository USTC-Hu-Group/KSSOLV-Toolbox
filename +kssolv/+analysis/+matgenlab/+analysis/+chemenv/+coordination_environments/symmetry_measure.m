function value=symmetry_measure(points_distorted,points_perfect)
%SYMMETRY_MEASURE Continuous symmetry measure between two point sets.
distorted=double(points_distorted);
perfect=double(points_perfect);
if size(distorted,1)==1
    value=struct(symmetry_measure=0,scaling_factor=[], ...
        rotation_matrix=[]);
    return
end
rotation=kssolv.analysis.matgenlab.analysis.chemenv. ...
    coordination_environments.find_rotation(distorted,perfect);
[factor,rotated,perfect]=kssolv.analysis.matgenlab.analysis.chemenv. ...
    coordination_environments.find_scaling_factor( ...
    distorted,perfect,rotation);
denominator=sum(perfect.^2,"all");
if abs(denominator)<eps,csm=0;
else,csm=100*sum((perfect-factor*rotated).^2,"all")/denominator;end
value=struct(symmetry_measure=csm,scaling_factor=factor, ...
    rotation_matrix=rotation);
end
