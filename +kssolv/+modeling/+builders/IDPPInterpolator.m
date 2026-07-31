classdef IDPPInterpolator
    %IDPPINTERPOLATOR Native image-dependent pair-potential interpolation.
    %
    % Implements the ASE IDPP pair energy and force expression, optimized
    % with a deterministic FIRE integrator while keeping endpoints fixed.

    methods (Static)
        function [images, diagnostics] = interpolate( ...
                initial, ending, intermediateCount, options)
            arguments
                initial
                ending
                intermediateCount (1,1) double = 5
                options.maximumSteps (1,1) double = 200
                options.forceTolerance (1,1) double = 0.1
                options.springConstant (1,1) double = 0.05
                options.initialTimeStep (1,1) double = 0.005
            end
            import kssolv.modeling.builders.BuilderUtils
            BuilderUtils.requireStructure(initial);
            BuilderUtils.requireStructure(ending);
            intermediateCount = BuilderUtils.positiveInteger( ...
                intermediateCount, "Intermediate image count");
            maximumSteps = BuilderUtils.positiveInteger( ...
                options.maximumSteps, "Maximum IDPP steps");
            forceTolerance = BuilderUtils.positiveScalar( ...
                options.forceTolerance, "Force tolerance");
            springConstant = double(options.springConstant);
            if ~isscalar(springConstant) || ~isfinite(springConstant) || ...
                    springConstant < 0
                error("KSSOLV:Modeling:IDPPSpring", ...
                    "Spring constant must be a finite nonnegative scalar.");
            end
            if initial.num_sites ~= ending.num_sites || ...
                    ~all(cellfun(@(first, second) first == second, ...
                    initial.species_and_occu, ending.species_and_occu))
                error("KSSOLV:Modeling:IDPPEndpoints", ...
                    "IDPP endpoints must have identical site count, " + ...
                    "species and ordering.");
            end
            if initial.lattice ~= ending.lattice
                error("KSSOLV:Modeling:IDPPLattice", ...
                    "Variable-cell IDPP interpolation is not supported.");
            end

            images = ...
                kssolv.modeling.builders.IDPPInterpolator. ...
                linearImages(initial, ending, intermediateCount);
            positions = zeros( ...
                numel(images), initial.num_sites, 3);
            for imageIndex = 1:numel(images)
                positions(imageIndex, :, :) = ...
                    images{imageIndex}.cart_coords;
            end
            linearPositions = positions;
            positions = ...
                kssolv.modeling.builders.IDPPInterpolator. ...
                separateCoincidentSites(positions);
            startDistances = ...
                kssolv.modeling.builders.IDPPInterpolator. ...
                distanceMatrix(initial.cart_coords, ...
                initial.lattice, initial.pbc);
            endDistances = ...
                kssolv.modeling.builders.IDPPInterpolator. ...
                distanceMatrix(ending.cart_coords, ...
                ending.lattice, ending.pbc);
            targets = zeros( ...
                numel(images), initial.num_sites, initial.num_sites);
            for imageIndex = 1:numel(images)
                fraction = (imageIndex - 1) / (numel(images) - 1);
                targets(imageIndex, :, :) = ...
                    (1 - fraction) * startDistances + ...
                    fraction * endDistances;
            end
            [~, linearEnergy] = ...
                kssolv.modeling.builders.IDPPInterpolator.bandForces( ...
                linearPositions, targets, initial.lattice, ...
                initial.pbc, options.springConstant);
            [positions, diagnostics] = ...
                kssolv.modeling.builders.IDPPInterpolator.optimize( ...
                positions, targets, initial.lattice, initial.pbc, ...
                maximumSteps, forceTolerance, springConstant, ...
                options.initialTimeStep);
            diagnostics.linear_path_energy = linearEnergy;
            for imageIndex = 2:numel(images) - 1
                model = images{imageIndex};
                coordinates = squeeze(positions(imageIndex, :, :));
                for siteIndex = 1:model.num_sites
                    model = model.replace(siteIndex, [], ...
                        coordinates(siteIndex, :), ...
                        coords_are_cartesian = true);
                end
                model.properties.neb_image = struct( ...
                    "method", "IDPP", ...
                    "index", imageIndex - 1, ...
                    "fraction", (imageIndex - 1) / ...
                    (numel(images) - 1));
                images{imageIndex} = model;
            end
        end
    end

    methods (Static, Access = private)
        function images = linearImages(initial, ending, intermediateCount)
            fractions = linspace(0, 1, intermediateCount + 2);
            start = initial.frac_coords;
            delta = ending.frac_coords - start;
            delta(:, initial.pbc) = ...
                delta(:, initial.pbc) - round(delta(:, initial.pbc));
            images = cell(1, numel(fractions));
            for index = 1:numel(fractions)
                images{index} = ...
                    kssolv.analysis.matgenlab.core.Structure( ...
                    initial.lattice, initial.species_and_occu, ...
                    start + fractions(index) * delta, ...
                    site_properties = initial.site_properties, ...
                    labels = initial.labels, ...
                    properties = initial.structure_properties, ...
                    skip_checks = true);
            end
            % Preserve both user endpoints exactly, including their
            % representative coordinates inside/outside the periodic cell.
            images{1} = initial.copy();
            images{end} = ending.copy();
        end

        function [positions, diagnostics] = optimize( ...
                positions, targets, lattice, pbc, maximumSteps, ...
                tolerance, springConstant, initialTimeStep)
            velocity = zeros(size(positions));
            timeStep = initialTimeStep;
            maximumTimeStep = initialTimeStep * 10;
            alpha = 0.1;
            positiveSteps = 0;
            initialEnergy = NaN;
            converged = false;
            maximumForce = Inf;
            for iteration = 1:maximumSteps
                [forces, energy] = ...
                    kssolv.modeling.builders.IDPPInterpolator. ...
                    bandForces(positions, targets, lattice, pbc, ...
                    springConstant);
                if iteration == 1
                    initialEnergy = energy;
                end
                interior = forces(2:end-1, :, :);
                maximumForce = max(vecnorm( ...
                    reshape(interior, [], 3), 2, 2));
                if maximumForce <= tolerance
                    converged = true;
                    break
                end
                integrationForces = ...
                    kssolv.modeling.builders.IDPPInterpolator. ...
                    limitForces(forces, 50);
                velocity = velocity + timeStep * integrationForces;
                power = sum(velocity(:) .* integrationForces(:));
                if power > 0
                    positiveSteps = positiveSteps + 1;
                    if positiveSteps > 5
                        timeStep = min(timeStep * 1.1, maximumTimeStep);
                        alpha = alpha * 0.99;
                    end
                else
                    positiveSteps = 0;
                    timeStep = timeStep * 0.5;
                    velocity(:) = 0;
                    alpha = 0.1;
                end
                forceNorm = norm(integrationForces(:));
                velocityNorm = norm(velocity(:));
                if forceNorm > 0 && velocityNorm > 0
                    velocity = (1 - alpha) * velocity + ...
                        alpha * velocityNorm / forceNorm * ...
                        integrationForces;
                end
                positions(2:end-1, :, :) = ...
                    positions(2:end-1, :, :) + ...
                    timeStep * velocity(2:end-1, :, :);
                velocity([1, end], :, :) = 0;
                if timeStep < 1e-8 || any(~isfinite(positions), "all")
                    error("KSSOLV:Modeling:IDPPDiverged", ...
                        "IDPP optimization diverged or exhausted its time step.");
                end
            end
            [~, finalEnergy] = ...
                kssolv.modeling.builders.IDPPInterpolator.bandForces( ...
                positions, targets, lattice, pbc, springConstant);
            diagnostics = struct( ...
                "iterations", iteration, ...
                "converged", converged, ...
                "maximum_force", maximumForce, ...
                "initial_energy", initialEnergy, ...
                "final_energy", finalEnergy);
        end

        function [forces, energy] = bandForces( ...
                positions, targets, lattice, pbc, springConstant)
            forces = zeros(size(positions));
            energy = 0;
            for imageIndex = 2:size(positions, 1) - 1
                coordinates = squeeze(positions(imageIndex, :, :));
                target = squeeze(targets(imageIndex, :, :));
                [imageForce, imageEnergy] = ...
                    kssolv.modeling.builders.IDPPInterpolator. ...
                    pairForces(coordinates, target, lattice, pbc);
                spring = springConstant * ( ...
                    squeeze(positions(imageIndex - 1, :, :)) + ...
                    squeeze(positions(imageIndex + 1, :, :)) - ...
                    2 * coordinates);
                forces(imageIndex, :, :) = imageForce + spring;
                energy = energy + imageEnergy;
            end
            if springConstant > 0
                displacement = ...
                    positions(2:end, :, :) - positions(1:end-1, :, :);
                energy = energy + ...
                    0.5 * springConstant * sum(displacement(:).^2);
            end
        end

        function [forces, energy] = pairForces( ...
                coordinates, target, lattice, pbc)
            siteCount = size(coordinates, 1);
            forces = zeros(siteCount, 3);
            energy = 0;
            for first = 1:siteCount - 1
                for second = first + 1:siteCount
                    delta = coordinates(second, :) - ...
                        coordinates(first, :);
                    delta = ...
                        kssolv.modeling.builders.IDPPInterpolator. ...
                        minimumImage(delta, lattice, pbc);
                    distance = max(norm(delta), 1e-8);
                    difference = distance - target(first, second);
                    energy = energy + difference^2 / distance^4;
                    coefficient = 2 * difference * ...
                        (1 - 2 * difference / distance) / distance^5;
                    pairForce = coefficient * delta;
                    forces(first, :) = forces(first, :) + pairForce;
                    forces(second, :) = forces(second, :) - pairForce;
                end
            end
        end

        function matrix = distanceMatrix(coordinates, lattice, pbc)
            count = size(coordinates, 1);
            matrix = zeros(count);
            for first = 1:count - 1
                for second = first + 1:count
                    delta = coordinates(second, :) - ...
                        coordinates(first, :);
                    delta = ...
                        kssolv.modeling.builders.IDPPInterpolator. ...
                        minimumImage(delta, lattice, pbc);
                    matrix(first, second) = norm(delta);
                    matrix(second, first) = matrix(first, second);
                end
            end
        end

        function delta = minimumImage(delta, lattice, pbc)
            fractional = delta / lattice.matrix;
            fractional(pbc) = ...
                fractional(pbc) - round(fractional(pbc));
            delta = fractional * lattice.matrix;
        end

        function positions = separateCoincidentSites(positions)
            for imageIndex = 2:size(positions, 1) - 1
                coordinates = squeeze(positions(imageIndex, :, :));
                for first = 1:size(coordinates, 1) - 1
                    for second = first + 1:size(coordinates, 1)
                        if norm(coordinates(first, :) - ...
                                coordinates(second, :)) < 1e-7
                            direction = [0, 0, 1];
                            if mod(first + second, 2) == 0
                                direction = [0, 1, 0];
                            end
                            coordinates(first, :) = ...
                                coordinates(first, :) + 0.05 * direction;
                            coordinates(second, :) = ...
                                coordinates(second, :) - 0.05 * direction;
                        end
                    end
                end
                positions(imageIndex, :, :) = coordinates;
            end
        end

        function limited = limitForces(forces, maximumNorm)
            limited = forces;
            reshaped = reshape(limited, [], 3);
            norms = vecnorm(reshaped, 2, 2);
            scale = min(1, maximumNorm ./ max(norms, eps));
            reshaped = reshaped .* scale;
            limited = reshape(reshaped, size(forces));
            limited([1, end], :, :) = 0;
        end
    end
end
