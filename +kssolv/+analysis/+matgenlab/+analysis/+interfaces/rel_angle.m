function value=rel_angle(vectors1,vectors2)
%REL_ANGLE Relative change in included angle.
angle1=kssolv.analysis.matgenlab.analysis.interfaces. ...
    vec_angle(vectors1(1,:),vectors1(2,:));
angle2=kssolv.analysis.matgenlab.analysis.interfaces. ...
    vec_angle(vectors2(1,:),vectors2(2,:));
value=angle2/angle1-1;
end
