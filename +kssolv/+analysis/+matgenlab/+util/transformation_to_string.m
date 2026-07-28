function text = transformation_to_string( ...
        matrix, translation_vec, components, c, delim)
%TRANSFORMATION_TO_STRING Render an affine transformation as xyz notation.
if nargin < 2, translation_vec = [0, 0, 0]; end
if nargin < 3, components = ["x", "y", "z"]; end
if nargin < 4, c = ""; end
if nargin < 5, delim = ","; end
matrix = double(matrix);
translation_vec = reshape(double(translation_vec), 1, []);
components = reshape(string(components), 1, []);
if ~isequal(size(matrix), [3, 3]) || numel(translation_vec) ~= 3 || ...
        numel(components) ~= 3
    error("KSSOLV:Matgenlab:String:InvalidTransformation", ...
        "matrix must be 3-by-3 and vectors must have three elements.");
end
parts = strings(1, 3);
for row = 1:3
    result = "";
    for column = 1:3
        coefficient = matrix(row, column);
        if coefficient == 0, continue; end
        [numerator, denominator] = limitedFraction(coefficient);
        if strlength(result) > 0 && numerator >= 0, result = result + "+"; end
        if abs(numerator) ~= 1
            result = result + string(numerator);
        elseif numerator < 0
            result = result + "-";
        end
        result = result + string(c) + components(column);
        if denominator ~= 1, result = result + "/" + string(denominator); end
    end
    offset = translation_vec(row);
    if offset ~= 0
        [numerator, denominator] = limitedFraction(offset);
        fractionText = string(numerator);
        if denominator ~= 1, fractionText = fractionText + "/" + string(denominator); end
        if offset > 0 && strlength(result) > 0, result = result + "+"; end
        result = result + fractionText;
    end
    if strlength(result) == 0, result = "0"; end
    parts(row) = result;
end
text = strjoin(parts, string(delim));
end

function [numerator, denominator] = limitedFraction(value)
% Continued-fraction implementation of Fraction.limit_denominator(1e6).
maxDenominator = 1e6;
signValue = sign(value);
target = abs(value);
p0 = 0; q0 = 1; p1 = 1; q1 = 0;
x = target;
while true
    coefficient = floor(x);
    q2 = q0 + coefficient * q1;
    if q2 > maxDenominator, break; end
    p2 = p0 + coefficient * p1;
    p0 = p1; q0 = q1; p1 = p2; q1 = q2;
    remainder = x - coefficient;
    if remainder == 0
        numerator = signValue * p1;
        denominator = q1;
        return
    end
    x = 1 / remainder;
end
k = floor((maxDenominator - q0) / q1);
n1 = p0 + k * p1; d1 = q0 + k * q1;
n2 = p1; d2 = q1;
error1 = abs(n1 / d1 - target);
error2 = abs(n2 / d2 - target);
tieTol = eps(max([1, target, error1, error2]));
if error2 < error1 - tieTol || ...
        (abs(error2 - error1) <= tieTol && d2 < d1)
    numerator = signValue * n2; denominator = d2;
else
    numerator = signValue * n1; denominator = d1;
end
end
