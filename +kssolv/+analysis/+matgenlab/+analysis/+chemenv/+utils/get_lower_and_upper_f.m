function value=get_lower_and_upper_f(options)
%GET_LOWER_AND_UPPER_F Build distance-angle surface boundary functions.
distance=fieldValue(options,"distance_bounds");
angle=fieldValue(options,"angle_bounds");
minimumDistance=fieldValue(distance,"lower");
maximumDistance=fieldValue(distance,"upper");
minimumAngle=fieldValue(angle,"lower");
maximumAngle=fieldValue(angle,"upper");
kind=string(fieldValue(options,"type"));
switch kind
    case "standard_elliptic"
        value=kssolv.analysis.matgenlab.analysis.chemenv.utils. ...
            quarter_ellipsis_functions([minimumDistance,maximumAngle], ...
            [maximumDistance,minimumAngle]);
    case "standard_diamond"
        value=kssolv.analysis.matgenlab.analysis.chemenv.utils. ...
            diamond_functions([minimumDistance,maximumAngle], ...
            [maximumDistance,minimumAngle],fieldValue(distance,"delta"), ...
            fieldValue(angle,"delta"));
    case "standard_spline"
        value=kssolv.analysis.matgenlab.analysis.chemenv.utils. ...
            spline_functions(fieldValue(options,"lower_points"), ...
            fieldValue(options,"upper_points"),fieldValue(options,"degree"));
    otherwise
        error("KSSOLV:Matgenlab:ChemEnv:Surface", ...
            "Surface calculation of type '%s' is not implemented.",kind);
end
end
function value=fieldValue(input,name)
if isa(input,"containers.Map"),value=input(char(name));
else,value=input.(char(name));end
end
