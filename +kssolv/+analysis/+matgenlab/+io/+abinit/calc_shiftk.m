function shiftk = calc_shiftk(structure, varargin)
%CALC_SHIFTK Select symmetry-compatible ABINIT k-point shifts.
structure = kssolv.analysis.matgenlab.io.abinit.as_structure(structure);
m = structure.lattice.matrix;
lengths = vecnorm(m, 2, 2);
angles = structure.lattice.angles;
isCubic = max(abs(lengths - mean(lengths))) < 1e-5 && max(abs(angles - 60)) < 1e-3;
if isCubic
    % Primitive FCC basis has equal 60-degree angles.
    shiftk = [.5 .5 .5; .5 0 0; 0 .5 0; 0 0 .5];
elseif max(abs(angles - 109.471220634)) < 1e-3
    shiftk = [.25 .25 .25; -.25 -.25 -.25];
elseif any(abs(angles - 120) < 1)
    [~, axisIndex] = max(lengths); shiftk = [0 0 0]; shiftk(axisIndex) = .5;
else
    shiftk = [.5 .5 .5];
end
end
