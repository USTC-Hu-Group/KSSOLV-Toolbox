function [a, b, c, cosAlpha, cosBeta, cosGamma] = getCellParameters(cell)
% GETCELLPARAMS Computes lattice parameters (a, b, c, cosAlpha, cosBeta, cosGamma)
% from a 3x3 cell matrix.
%
% Input:
%   cell - A 3x3 matrix where each row represents a lattice vector
%
% Output:
%   a, b, c - Magnitudes of the lattice vectors
%   cosAlpha, cosBeta, cosGamma - Cosines of the angles between the vectors
%
% Note: Rows are vectors: v1 = cell(1, :), v2 = cell(2, :), v3 = cell(3, :)

% Extract the lattice vectors
v1 = cell(1, :);
v2 = cell(2, :);
v3 = cell(3, :);

% Calculate the magnitudes of the lattice vectors
a = sqrt(sum(v1 .^ 2));
b = sqrt(sum(v2 .^ 2));
c = sqrt(sum(v3 .^ 2));

% Calculate the cosines of the angles between the vectors
cosAlpha = dot(v2, v3) / (b * c);
cosBeta = dot(v1, v3) / (a * c);
cosGamma = dot(v1, v2) / (a * b);
end
