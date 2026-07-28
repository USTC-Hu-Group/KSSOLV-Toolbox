function value = formula_double_format(afloat, ignore_ones, tol)
%FORMULA_DOUBLE_FORMAT Normalize a numeric formula coefficient.
if nargin < 2, ignore_ones = true; end
if nargin < 3, tol = 1e-8; end
afloat = double(afloat);
if ignore_ones && abs(afloat - 1) <= tol + eps
    value = "";
elseif abs(afloat - round(afloat)) <= tol
    value = round(afloat);
else
    value = round(afloat, 8);
end
end
