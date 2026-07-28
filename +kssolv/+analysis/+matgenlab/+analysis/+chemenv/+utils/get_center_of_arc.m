function value=get_center_of_arc(p1,p2,radius)
%GET_CENTER_OF_ARC Center of the signed-radius arc joining two points.
delta=p2-p1;distance=hypot(delta(1),delta(2));
radical=(radius/distance)^2-.25;
if radical<0
    error("KSSOLV:Matgenlab:ChemEnv:Arc", ...
        "Impossible to find center of arc because the arc is ill-defined.");
end
parameter=sqrt(radical);
if radius>0,parameter=-parameter;end
value=[(p1(1)+p2(1))/2-parameter*delta(2), ...
    (p1(2)+p2(2))/2+parameter*delta(1)];
end
