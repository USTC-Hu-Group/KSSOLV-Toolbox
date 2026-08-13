classdef PeriodicGeometryTest < matlab.unittest.TestCase
    %PERIODICGEOMETRYTEST Minimum-image exact geometry editing.

    methods (Test)
        function sharedGeometryCapabilitiesExcludeMolecularClean(testCase)
            model = testCase.periodicFixture();
            for command = ["measure_geometry", "set_distance", ...
                    "set_angle", "set_dihedral", "align_geometry"]
                [supported, reason] = kssolv.modeling.CommandExecutor. ...
                    supportsForModel(command, model);
                testCase.verifyTrue(supported, reason);
            end
            for command = ["clean_geometry", "optimize_geometry"]
                [supported, reason] = kssolv.modeling.CommandExecutor. ...
                    supportsForModel(command, model);
                testCase.verifyFalse(supported);
                testCase.verifyNotEmpty(reason);
            end
        end

        function measuresAcrossPeriodicBoundaryWithMinimumImage(testCase)
            model = testCase.periodicFixture();
            distance = testCase.measure(model, [1, 4]);
            angle = testCase.measure(model, [1, 4, 7]);
            testCase.verifyEqual(distance, sqrt(3) * 5.43 / 4, ...
                "AbsTol", 1e-12);
            testCase.verifyEqual(angle, 109.4712206344907, ...
                "AbsTol", 1e-12);
        end

        function exactDistanceUsesMinimumImageAndPreservesInput(testCase)
            model = testCase.periodicFixture();
            original = model.frac_coords;
            result = kssolv.modeling.CommandExecutor.execute( ...
                model, "set_distance", struct("indices", [1, 4], ...
                "value", 2.4, "scope", "atom"));
            testCase.verifyEqual(testCase.measure(result.model, [1, 4]), ...
                2.4, "AbsTol", 1e-6);
            testCase.verifyEqual(model.frac_coords, original, ...
                "AbsTol", 1e-12);
            testCase.verifyGreaterThanOrEqual(result.model.frac_coords, 0);
            testCase.verifyLessThan(result.model.frac_coords, 1);
        end

        function exactAngleAndDihedralUseUnwrappedImages(testCase)
            model = testCase.periodicFixture();
            angled = kssolv.modeling.CommandExecutor.execute( ...
                model, "set_angle", struct("indices", [1, 4, 7], ...
                "value", 112.25, "scope", "atom")).model;
            testCase.verifyEqual(testCase.measure(angled, [1, 4, 7]), ...
                112.25, "AbsTol", 1e-5);

            twisted = kssolv.modeling.CommandExecutor.execute( ...
                model, "set_dihedral", struct( ...
                "indices", [1, 4, 7, 2], "value", 170.25, ...
                "scope", "atom")).model;
            testCase.verifyEqual(testCase.measure( ...
                twisted, [1, 4, 7, 2]), 170.25, "AbsTol", 1e-5);
        end

        function exactEditsHonorSelectedPeriodicInstances(testCase)
            model = testCase.periodicFixture();

            distanceIndices = [1, 4];
            [reference, offsets] = testCase.referencePath( ...
                model, distanceIndices);
            reference(2, :) = reference(2, :) + ...
                model.lattice.get_cartesian_coords([1, 0, 0]);
            offsets(2, :) = offsets(2, :) + [1, 0, 0];
            edited = kssolv.modeling.CommandExecutor.execute( ...
                model, "set_distance", struct( ...
                "indices", distanceIndices, "value", 2.42, ...
                "scope", "atom", ...
                "referenceCoordinates", reference)).model;
            actual = testCase.coordinatesAtOffsets( ...
                edited, distanceIndices, offsets);
            testCase.verifyEqual(norm(actual(2, :) - actual(1, :)), ...
                2.42, "AbsTol", 1e-6);

            angleIndices = [1, 4, 7];
            [reference, offsets] = testCase.referencePath( ...
                model, angleIndices);
            edited = kssolv.modeling.CommandExecutor.execute( ...
                model, "set_angle", struct( ...
                "indices", angleIndices, "value", 116.5, ...
                "scope", "atom", ...
                "referenceCoordinates", reference)).model;
            actual = testCase.coordinatesAtOffsets( ...
                edited, angleIndices, offsets);
            testCase.verifyEqual(testCase.angle(actual), 116.5, ...
                "AbsTol", 1e-5);

            dihedralIndices = [1, 4, 7, 2];
            [reference, ~] = testCase.referencePath( ...
                model, dihedralIndices);
            edited = kssolv.modeling.CommandExecutor.execute( ...
                model, "set_dihedral", struct( ...
                "indices", dihedralIndices, "value", -47.25, ...
                "scope", "atom", ...
                "referenceCoordinates", reference)).model;
            actual = testCase.bestDihedralImage( ...
                edited, dihedralIndices, reference, -47.25);
            testCase.verifyEqual(testCase.dihedral(actual), -47.25, ...
                "AbsTol", 1e-5);
        end
    end

    methods (Static, Access = private)
        function value = periodicFixture()
            value = kssolv.analysis.matgenlab.core.Structure. ...
                from_spacegroup("Fd-3m", eye(3) * 5.43, ...
                "Si", [0, 0, 0]);
        end

        function value = measure(model, indices)
            result = kssolv.modeling.CommandExecutor.execute( ...
                model, "measure_geometry", struct("indices", indices));
            value = result.analysis.value;
        end

        function [coordinates, offsets] = referencePath(model, indices)
            fractional = model.frac_coords(indices, :);
            unwrapped = zeros(size(fractional));
            unwrapped(1, :) = fractional(1, :) + [1, 0, 0];
            for position = 2:size(fractional, 1)
                delta = fractional(position, :) - ...
                    fractional(position - 1, :);
                delta(model.pbc) = delta(model.pbc) - ...
                    round(delta(model.pbc));
                unwrapped(position, :) = ...
                    unwrapped(position - 1, :) + delta;
            end
            offsets = round(unwrapped - fractional);
            coordinates = model.lattice.get_cartesian_coords(unwrapped);
        end

        function coordinates = coordinatesAtOffsets(model, indices, offsets)
            fractional = model.frac_coords(indices, :) + offsets;
            coordinates = model.lattice.get_cartesian_coords(fractional);
        end

        function value = angle(coordinates)
            first = coordinates(1, :) - coordinates(2, :);
            second = coordinates(3, :) - coordinates(2, :);
            value = acosd(dot(first, second) / norm(first) / norm(second));
        end

        function value = dihedral(coordinates)
            first = coordinates(2, :) - coordinates(1, :);
            central = coordinates(3, :) - coordinates(2, :);
            last = coordinates(4, :) - coordinates(3, :);
            normalA = cross(first, central);
            normalB = cross(central, last);
            normalA = normalA / norm(normalA);
            normalB = normalB / norm(normalB);
            central = central / norm(central);
            value = atan2d(dot(cross(normalA, normalB), central), ...
                dot(normalA, normalB));
        end

        function coordinates = bestDihedralImage( ...
                model, indices, reference, target)
            coordinates = reference;
            bestError = Inf;
            base = model(indices(4)).coords;
            for first = -2:2
                for second = -2:2
                    for third = -2:2
                        image = model.lattice.get_cartesian_coords( ...
                            [first, second, third]);
                        candidate = reference;
                        candidate(4, :) = base + image;
                        value = kssolv.modeling.test. ...
                            PeriodicGeometryTest.dihedral(candidate);
                        errorValue = abs(mod(value - target + 180, 360) - 180);
                        if errorValue < bestError
                            bestError = errorValue;
                            coordinates = candidate;
                        end
                    end
                end
            end
        end
    end
end
