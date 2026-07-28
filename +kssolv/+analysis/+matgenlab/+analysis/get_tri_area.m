function area=get_tri_area(points)
%GET_TRI_AREA Area of a triangle embedded in three dimensions.
points=double(points);
if ~isequal(size(points),[3,3])
    error("KSSOLV:Matgenlab:Wulff:TriangleSize", ...
        "Triangle points must be a 3-by-3 coordinate array.");
end
area=norm(cross(points(2,:)-points(1,:), ...
    points(3,:)-points(1,:)))/2;
end
