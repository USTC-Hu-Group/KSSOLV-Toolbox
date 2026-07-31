classdef MoireBuilder
    %MOIREBUILDER Build a commensurate hexagonal twisted bilayer.
    %
    % Uses the coincidence-lattice integer construction employed by
    % Twister for hexagonal homobilayers. A bounded homogeneous in-plane
    % strain permits closely matched heterobilayers.

    methods (Static)
        function output = build(bottom, top, targetAngle, options)
            arguments
                bottom
                top
                targetAngle (1,1) double
                options.gap (1,1) double = 3.35
                options.vacuum (1,1) double = 15
                options.maximumStrain (1,1) double = 0.03
                options.maximumAtoms (1,1) double = 100000
                options.maximumIndex (1,1) double = 60
            end
            import kssolv.modeling.builders.BuilderUtils
            BuilderUtils.requireTwoDimensional(bottom);
            BuilderUtils.requireTwoDimensional(top);
            if ~isscalar(targetAngle) || ~isfinite(targetAngle) || ...
                    targetAngle < 0 || targetAngle > 60
                error("KSSOLV:Modeling:MoireAngle", ...
                    "Twist angle must be between 0 and 60 degrees.");
            end
            maximumAtoms = BuilderUtils.positiveInteger( ...
                options.maximumAtoms, "Maximum atom count");
            maximumIndex = BuilderUtils.positiveInteger( ...
                options.maximumIndex, "Maximum coincidence index");
            kssolv.modeling.builders.MoireBuilder. ...
                requireHexagonal(bottom);
            kssolv.modeling.builders.MoireBuilder. ...
                requireHexagonal(top);

            candidate = ...
                kssolv.modeling.builders.MoireBuilder. ...
                findCandidate(bottom, top, targetAngle, ...
                maximumAtoms, maximumIndex, options.maximumStrain);
            bottomTransform = eye(3);
            topTransform = eye(3);
            bottomTransform(1:2, 1:2) = candidate.bottomMatrix;
            topTransform(1:2, 1:2) = candidate.topMatrix;
            bottomSupercell = bottom * bottomTransform;
            topSupercell = top * topTransform;
            output = ...
                kssolv.modeling.builders.HeterostructureBuilder.build( ...
                bottomSupercell, topSupercell, ...
                gap = options.gap, vacuum = options.vacuum, ...
                maximumStrain = options.maximumStrain);
            output.properties.moire = struct( ...
                "target_angle_degrees", targetAngle, ...
                "achieved_angle_degrees", candidate.angle, ...
                "angle_error_degrees", candidate.angleError, ...
                "m", candidate.m, "n", candidate.n, ...
                "bottom_transform", candidate.bottomMatrix, ...
                "top_transform", candidate.topMatrix, ...
                "in_plane_strain", candidate.strain);
        end
    end

    methods (Static, Access = private)
        function requireHexagonal(structure)
            lengths = structure.lattice.lengths(1:2);
            gamma = structure.lattice.gamma;
            if abs(lengths(1) - lengths(2)) / max(lengths) > 1e-3 || ...
                    min(abs(gamma - [60, 120])) > 1e-3
                error("KSSOLV:Modeling:MoireHexagonalRequired", ...
                    "The moire coincidence builder requires a hexagonal " + ...
                    "in-plane primitive cell.");
            end
        end

        function best = findCandidate(bottom, top, target, ...
                maximumAtoms, maximumIndex, maximumStrain)
            best = [];
            bestScore = Inf;
            gamma = bottom.lattice.gamma;
            for m = 1:maximumIndex
                for n = 0:m
                    if gcd(m, n) > 1
                        continue
                    end
                    [bottomMatrix, topMatrix] = ...
                        kssolv.modeling.builders.MoireBuilder. ...
                        coincidenceMatrices(m, n, gamma);
                    determinant = abs(round(det(bottomMatrix)));
                    atomCount = determinant * ...
                        (bottom.num_sites + top.num_sites);
                    if atomCount > maximumAtoms
                        continue
                    end
                    bottomCell = bottomMatrix * ...
                        bottom.lattice.matrix(1:2, :);
                    topCell = topMatrix * ...
                        top.lattice.matrix(1:2, :);
                    angle = ...
                        kssolv.modeling.builders.MoireBuilder. ...
                        vectorAngle(topCell(1, :), bottomCell(1, :));
                    angle = min(angle, 60 - angle);
                    strain = ...
                        kssolv.modeling.builders.BuilderUtils. ...
                        inPlanePrincipalStrain(bottomCell, topCell);
                    if strain > maximumStrain
                        continue
                    end
                    angleError = abs(angle - target);
                    score = angleError + 1e-4 * atomCount + strain;
                    if score < bestScore
                        bestScore = score;
                        best = struct( ...
                            "m", m, "n", n, ...
                            "angle", angle, ...
                            "angleError", angleError, ...
                            "strain", strain, ...
                            "atomCount", atomCount, ...
                            "bottomMatrix", bottomMatrix, ...
                            "topMatrix", topMatrix);
                    end
                end
            end
            if isempty(best)
                error("KSSOLV:Modeling:MoireCandidateNotFound", ...
                    "No commensurate cell satisfies the atom and strain limits.");
            end
        end

        function [bottom, top] = coincidenceMatrices(m, n, gamma)
            if abs(gamma - 120) < abs(gamma - 60)
                bottom = [m, -n; -n, -(m + n)];
                top = [n, -m; -m, -(n + m)];
            else
                bottom = [m, n; -n, m + n];
                top = [n, m; -m, n + m];
            end
        end

        function angle = vectorAngle(first, second)
            first = reshape(first, 1, 3);
            second = reshape(second, 1, 3);
            angle = atan2d(norm(cross(first, second)), ...
                dot(first, second));
            angle = mod(abs(angle), 60);
        end
    end
end
