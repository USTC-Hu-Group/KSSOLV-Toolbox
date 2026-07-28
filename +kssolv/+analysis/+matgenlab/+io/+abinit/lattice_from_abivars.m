function lattice = lattice_from_abivars(varargin)
%LATTICE_FROM_ABIVARS Build a lattice from ABINIT acell/rprim or angdeg.
options = parse_options(varargin{:});
if ~isfield(options, "acell"), error("KSSOLV:Matgenlab:Abinit:Acell", "acell is required."); end
acell = reshape(double(options.acell), 1, 3);
hasRprim = isfield(options, "rprim"); hasAngles = isfield(options, "angdeg");
if hasRprim && hasAngles
    error("KSSOLV:Matgenlab:Abinit:Lattice", "angdeg and rprim are mutually exclusive.");
end
if hasRprim
    matrix = reshape(double(options.rprim), 3, 3);
elseif hasAngles
    angles = reshape(double(options.angdeg), 1, 3);
    if any(angles <= 0) || sum(angles) >= 360
        error("KSSOLV:Matgenlab:Abinit:Angles", "Invalid ABINIT angdeg values.");
    end
    if max(abs(angles - angles(1))) < 1e-12 && abs(angles(1) - 90) > 1e-12
        cosine = cosd(angles(1)); aa = sqrt(2 / 3 * (1 - cosine));
        cc = sqrt(1 - aa ^ 2);
        matrix = [aa 0 cc; -.5*aa sqrt(3)/2*aa cc; -.5*aa -sqrt(3)/2*aa cc];
    else
        matrix = zeros(3); matrix(1,1) = 1;
        matrix(2,1) = cosd(angles(3)); matrix(2,2) = sind(angles(3));
        matrix(3,1) = cosd(angles(2));
        matrix(3,2) = (cosd(angles(1))-matrix(2,1)*matrix(3,1))/matrix(2,2);
        matrix(3,3) = sqrt(1-matrix(3,1)^2-matrix(3,2)^2);
    end
else
    error("KSSOLV:Matgenlab:Abinit:Lattice", "rprim or angdeg is required.");
end
matrix = matrix .* acell.';
lattice = kssolv.analysis.matgenlab.core.Lattice(matrix * 0.529177210903);
end

function output = parse_options(varargin)
if numel(varargin)==1 && isstruct(varargin{1}), output=varargin{1}; return; end %#ok<ISCL>
output=struct();
for index=1:2:numel(varargin)
    output.(matlab.lang.makeValidName(char(varargin{index})))=varargin{index+1};
end
end
