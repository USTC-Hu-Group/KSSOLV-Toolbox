function unitVector = get_uvec(vector)
%GET_UVEC Unit vector parallel to VECTOR; near-zero vectors are unchanged.
arguments
    vector {mustBeNumeric}
end
magnitude = norm(vector);
if magnitude < 1e-8
    unitVector = double(vector);
else
    unitVector = double(vector) / magnitude;
end
end
