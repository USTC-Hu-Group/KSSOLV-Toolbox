function [extendedBravais, conventionalLattice, conventionalPositions] = getExtendedBravaisLattice( ...
    bravaisLatticeType, spaceGroupNumber, a, b, c, ...
    ~, cosineBeta, ~, comparisonThreshold, conventionalLattice, conventionalPositions)
%GETEXTENDEDBRAVAISLATTICE Determine the extended Bravais lattice type.
%
% This function determines the extended Bravais lattice type based on the
% input Bravais lattice type, space group number, lattice parameters,
% and atomic positions. It updates the conventional lattice and atomic
% positions if the Bravais lattice is 'aP'.
%
% Input:
%   bravaisLatticeType     - A string representing the Bravais lattice type (e.g., 'cP', 'tI', etc.).
%   spaceGroupNumber       - Space group number associated with the lattice.
%   a, b, c                - Lattice parameters (lengths of the lattice vectors).
%   cosineAlpha, cosineBeta, cosineGamma - Cosines of the lattice angles.
%   comparisonThreshold    - Threshold value for numerical comparisons in lattice type determination.
%   conventionalLattice     - A 3x3 matrix representing the conventional lattice vectors.
%   conventionalPositions  - An Nx3 matrix of atomic positions in fractional coordinates.
%
% Output:
%   extendedBravais        - A string representing the extended Bravais lattice type (e.g., 'cP', 'tI', etc.).
%   conventionalLattice     - The updated conventional lattice vectors (for 'aP' lattice, if applicable).
%   conventionalPositions  - The updated atomic positions (for 'aP' lattice, if applicable).

if strcmp(bravaisLatticeType, 'cP')
    if spaceGroupNumber >= 195 && spaceGroupNumber <= 206
        extendedBravais = 'cP1';
    elseif spaceGroupNumber >= 207 && spaceGroupNumber <= 230
        extendedBravais = 'cP2';
    else
        error('Internal error! Should be cP, but the space group number is not in the correct range.');
    end
elseif strcmp(bravaisLatticeType, 'cF')
    if spaceGroupNumber >= 195 && spaceGroupNumber <= 206
        extendedBravais = 'cF1';
    elseif spaceGroupNumber >= 207 && spaceGroupNumber <= 230
        extendedBravais = 'cF2';
    else
        error('Internal error! Should be cF, but the space group number is not in the correct range.');
    end
elseif strcmp(bravaisLatticeType, 'cI')
    extendedBravais = 'cI1';
elseif strcmp(bravaisLatticeType, 'tP')
    extendedBravais = 'tP1';
elseif strcmp(bravaisLatticeType, 'tI')
    if abs(c - a) < comparisonThreshold
        warning('tI lattice, but a almost equal to c.');
    end
    if c <= a
        extendedBravais = 'tI1';
    else
        extendedBravais = 'tI2';
    end
elseif strcmp(bravaisLatticeType, 'oP')
    extendedBravais = 'oP1';
elseif strcmp(bravaisLatticeType, 'oF')
    if abs(1.0 / (a^2) - (1.0 / (b^2) + 1.0 / (c^2))) < comparisonThreshold
        warning('oF lattice, but 1/a^2 almost equal to 1/b^2 + 1/c^2.');
    end
    if abs(1.0 / (c^2) - (1.0 / (a^2) + 1.0 / (b^2))) < comparisonThreshold
        warning('oF lattice, but 1/c^2 almost equal to 1/a^2 + 1/b^2.');
    end
    if 1.0 / (a^2) > 1.0 / (b^2) + 1.0 / (c^2)
        extendedBravais = 'oF1';
    elseif 1.0 / (c^2) > 1.0 / (a^2) + 1.0 / (b^2)
        extendedBravais = 'oF2';
    else
        extendedBravais = 'oF3';
    end
elseif strcmp(bravaisLatticeType, 'oI')
    % Sort a, b, c, first is the largest
    latticeVectors = {c, 1, 'c'; ...
        b, 3, 'b'; ...
        a, 2, 'a'};
    [~, sortedIndices] = sort(cell2mat(latticeVectors(:,1)), 'descend');
    sortedLatticeVectors = latticeVectors(sortedIndices, :);
    if abs(sortedLatticeVectors{1,1} - sortedLatticeVectors{2,1}) < comparisonThreshold
        warning('oI lattice, but the two longest vectors %s and %s have almost the same length.', ...
            sortedLatticeVectors{1,3}, sortedLatticeVectors{2,3});
    end
    extendedBravais = sprintf('%s%d', bravaisLatticeType, sortedLatticeVectors{1,2});
elseif strcmp(bravaisLatticeType, 'oC')
    if abs(b - a) < comparisonThreshold
        warning('oC lattice, but a almost equal to b.');
    end
    if a <= b
        extendedBravais = 'oC1';
    else
        extendedBravais = 'oC2';
    end
elseif strcmp(bravaisLatticeType, 'oA')
    if abs(b - c) < comparisonThreshold
        warning('oA lattice, but b almost equal to c.');
    end
    if b <= c
        extendedBravais = 'oA1';
    else
        extendedBravais = 'oA2';
    end
elseif strcmp(bravaisLatticeType, 'hP')
    specialGroups = [143, 144, 145, 146, 147, 148, 149, 151, 153, 157, 159, 160, 161, 162, 163];
    if ismember(spaceGroupNumber, specialGroups)
        extendedBravais = 'hP1';
    else
        extendedBravais = 'hP2';
    end
elseif strcmp(bravaisLatticeType, 'hR')
    if abs(sqrt(3.0) * a - sqrt(2.0) * c) < comparisonThreshold
        warning('hR lattice, but sqrt(3)a almost equal to sqrt(2)c.');
    end
    if sqrt(3.0) * a <= sqrt(2.0) * c
        extendedBravais = 'hR1';
    else
        extendedBravais = 'hR2';
    end
elseif strcmp(bravaisLatticeType, 'mP')
    extendedBravais = 'mP1';
elseif strcmp(bravaisLatticeType, 'mC')
    if abs(b - a * sqrt(1.0 - cosineBeta^2)) < comparisonThreshold
        warning('mC lattice, but b almost equal to a*sin(beta).');
    end
    if b < a * sqrt(1.0 - cosineBeta^2)
        extendedBravais = 'mC1';
    else
        if abs(-a * cosineBeta / c + a^2 * (1.0 - cosineBeta^2) / b^2 - 1.0) < comparisonThreshold
            warning('mC lattice, but -a*cos(beta)/c + a^2*sin(beta)^2/b^2 almost equal to 1.');
        end
        if -a * cosineBeta / c + a^2 * (1.0 - cosineBeta^2) / b^2 <= 1.0
            extendedBravais = 'mC2';
        else
            extendedBravais = 'mC3';
        end
    end
elseif strcmp(bravaisLatticeType, 'aP')
    % Handle triclinic lattice (complex calculations involving Niggli reduction)

    % Get the reciprocal lattice of the conventional lattice
    reciprocalLattice = kssolv.analysis.seekpath.utils.getReciprocalCellRows(conventionalLattice);

    % Perform Niggli reduction on the reciprocal lattice
    [reducedReciprocalLattice, ~] = kssolv.analysis.spglib.Spglib.niggliReduce(reciprocalLattice, 1e-6);

    % Get the real lattice from the reduced reciprocal lattice
    reducedLattice = kssolv.analysis.seekpath.utils.getRealCellFromReciprocalRows(reducedReciprocalLattice);

    % Get the cell parameters of the reduced reciprocal lattice
    [ka2, kb2, kc2, cosKalpha2, cosKbeta2, cosKgamma2] = kssolv.analysis.seekpath.utils.getCellParameters(reducedReciprocalLattice);

    % Compute the conditions
    conditions = [abs(kb2 * kc2 * cosKalpha2), abs(kc2 * ka2 * cosKbeta2), abs(ka2 * kb2 * cosKgamma2)];

    % M2 matrices
    M2Matrices(:,:,1) = [0, 0, 1; 1, 0, 0; 0, 1, 0];
    M2Matrices(:,:,2) = [0, 1, 0; 0, 0, 1; 1, 0, 0];
    M2Matrices(:,:,3) = eye(3);

    [~, smallestConditionIndex] = min(conditions);
    M2 = M2Matrices(:,:,smallestConditionIndex);

    % Apply M2 to the real lattice
    realCell3 = (reducedLattice' * M2)';

    % Get reciprocal of realCell3
    reciprocalCell3 = kssolv.analysis.seekpath.utils.getReciprocalCellRows(realCell3);

    % Get cell parameters
    [~, ~, ~, cosKalpha3, cosKbeta3, cosKgamma3] = kssolv.analysis.seekpath.utils.getCellParameters(reciprocalCell3);

    % Warnings if angles close to 90 degrees
    if abs(cosKalpha3) < comparisonThreshold
        warning('aP lattice, but the k_alpha3 angle is almost equal to 90 degrees.');
    end
    if abs(cosKbeta3) < comparisonThreshold
        warning('aP lattice, but the k_beta3 angle is almost equal to 90 degrees.');
    end
    if abs(cosKgamma3) < comparisonThreshold
        warning('aP lattice, but the k_gamma3 angle is almost equal to 90 degrees.');
    end

    % Determine M3
    if cosKalpha3 > 0 && cosKbeta3 > 0 && cosKgamma3 > 0
        % All acute angles
        M3 = eye(3);
    elseif cosKalpha3 <= 0 && cosKbeta3 <= 0 && cosKgamma3 <= 0
        % All obtuse angles
        M3 = eye(3);
    elseif cosKalpha3 > 0 && cosKbeta3 <= 0 && cosKgamma3 <= 0
        M3 = diag([1, -1, -1]);
    elseif cosKalpha3 <= 0 && cosKbeta3 > 0 && cosKgamma3 > 0
        M3 = diag([1, -1, -1]);
    elseif cosKalpha3 <= 0 && cosKbeta3 > 0 && cosKgamma3 <= 0
        M3 = diag([-1, 1, -1]);
    elseif cosKalpha3 > 0 && cosKbeta3 <= 0 && cosKgamma3 > 0
        M3 = diag([-1, 1, -1]);
    elseif cosKalpha3 <= 0 && cosKbeta3 <= 0 && cosKgamma3 > 0
        M3 = diag([-1, -1, 1]);
    elseif cosKalpha3 > 0 && cosKbeta3 > 0 && cosKgamma3 <= 0
        M3 = diag([-1, -1, 1]);
    else
        error('Problem identifying M3 matrix in aP lattice!');
    end

    % Apply M3 to realCell3
    realCellFinal = (realCell3' * M3)';

    % Get reciprocal of realCellFinal
    reciprocalCellFinal = kssolv.analysis.seekpath.utils.getReciprocalCellRows(realCellFinal);

    % Get cell parameters
    [~, ~, ~, cosKalpha, cosKbeta, cosKgamma] = kssolv.analysis.seekpath.utils.getCellParameters(reciprocalCellFinal);

    if cosKalpha <= 0 && cosKbeta <= 0 && cosKgamma <= 0
        % All obtuse
        extendedBravais = 'aP2';
    elseif cosKalpha >= 0 && cosKbeta >= 0 && cosKgamma >= 0
        % All acute
        extendedBravais = 'aP3';
    else
        error('Unexpected aP triclinic lattice, it is neither all-obtuse nor all-acute!');
    end

    % Update conventional lattice and positions
    % Get absolute positions
    convPosAbs = conventionalPositions * conventionalLattice;
    % Update conventional lattice
    conventionalLattice = realCellFinal;
    % Update positions
    conventionalPositions = convPosAbs / conventionalLattice;

else
    error('Unknown Bravais lattice type "%s" for space group %d.', bravaisLatticeType, spaceGroupNumber);
end
end
