function angle = get_angle(v1, v2, units)
%GET_ANGLE Angle between two vectors in degrees or radians.
if nargin < 3, units = "degrees"; end
v1 = double(v1(:)); v2 = double(v2(:));
cosine = dot(v1, v2) / norm(v1) / norm(v2);
cosine = max(-1, min(1, cosine));
angle = acos(cosine);
switch string(units)
    case "degrees"
        angle = rad2deg(angle);
    case "radians"
        % already radians
    otherwise
        error("KSSOLV:Matgenlab:Coord:InvalidAngleUnits", ...
            "Invalid units='%s'", string(units));
end
end
