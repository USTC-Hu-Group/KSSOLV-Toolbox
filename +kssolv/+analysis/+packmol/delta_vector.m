function delta = delta_vector(first, second, pbcLength)
%DELTA_VECTOR Minimum-image displacement used by Packmol.
delta = first - second;
if nargin >= 3 && ~isempty(pbcLength)
    delta = delta - pbcLength .* round(delta ./ pbcLength);
end
end
