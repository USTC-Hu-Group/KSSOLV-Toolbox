function matrix = make_symmetric_matrix_from_upper_tri(val)
%MAKE_SYMMETRIC_MATRIX_FROM_UPPER_TRI Form a 3-by-3 symmetric matrix.
% val order is [A_xx, A_yy, A_zz, A_xy, A_xz, A_yz].
if ~isnumeric(val) || ~isvector(val) || numel(val) ~= 6
    error("KSSOLV:Matgenlab:Num:InvalidUpperTriangle", ...
        "Expect val of length 6, got %s", mat2str(size(val)));
end
value = reshape(val, 1, 6);
matrix = [value(1), value(4), value(5); ...
          value(4), value(2), value(6); ...
          value(5), value(6), value(3)];
end
