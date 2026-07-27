classdef PathCreationTest < matlab.unittest.TestCase
    % PATHCREATIONTEST A unittest for testing the band path creation.

    properties (Constant)
        verbose_tests = true;
    end

    methods (Test)
        function test_aP2Y(testCase)
            testCase.baseTest('aP2', true);
        end

        function test_aP2N(testCase)
            testCase.baseTest('aP2', false);
        end

        function test_aP3Y(testCase)
            testCase.baseTest('aP3', true);
        end

        function test_aP3N(testCase)
            testCase.baseTest('aP3', false);
        end

        function test_cF1Y(testCase)
            testCase.baseTest('cF1', true);
        end

        function test_cF1N(testCase)
            testCase.baseTest('cF1', false);
        end

        function test_cF2Y(testCase)
            testCase.baseTest('cF2', true);
        end

        function test_cF2N(testCase)
            testCase.baseTest('cF2', false);
        end

        function test_cI1Y(testCase)
            testCase.baseTest('cI1', true);
        end

        function test_cI1N(testCase)
            testCase.baseTest('cI1', false);
        end

        function test_cP1Y(testCase)
            testCase.baseTest('cP1', true);
        end

        function test_cP1N(testCase)
            testCase.baseTest('cP1', false);
        end

        function test_cP2Y(testCase)
            testCase.baseTest('cP2', true);
        end

        function test_cP2N(testCase)
            testCase.baseTest('cP2', false);
        end

        function test_hP1Y(testCase)
            testCase.baseTest('hP1', true);
        end

        function test_hP1N(testCase)
            testCase.baseTest('hP1', false);
        end

        function test_hP2Y(testCase)
            testCase.baseTest('hP2', true);
        end

        function test_hP2N(testCase)
            testCase.baseTest('hP2', false);
        end

        function test_hR1Y(testCase)
            testCase.baseTest('hR1', true);
        end

        function test_hR1N(testCase)
            testCase.baseTest('hR1', false);
        end

        function test_hR2Y(testCase)
            testCase.baseTest('hR2', true);
        end

        function test_hR2N(testCase)
            testCase.baseTest('hR2', false);
        end

        function test_mC1Y(testCase)
            testCase.baseTest('mC1', true);
        end

        function test_mC1N(testCase)
            testCase.baseTest('mC1', false);
        end

        function test_mC2Y(testCase)
            testCase.baseTest('mC2', true);
        end

        function test_mC2N(testCase)
            testCase.baseTest('mC2', false);
        end

        function test_mC3Y(testCase)
            testCase.baseTest('mC3', true);
        end

        function test_mC3N(testCase)
            testCase.baseTest('mC3', false);
        end

        function test_mP1Y(testCase)
            testCase.baseTest('mP1', true);
        end

        function test_mP1N(testCase)
            testCase.baseTest('mP1', false);
        end

        function test_oA1N(testCase)
            testCase.baseTest('oA1', false);
        end

        function test_oA2N(testCase)
            testCase.baseTest('oA2', false);
        end

        function test_oC1Y(testCase)
            testCase.baseTest('oC1', true);
        end

        function test_oC1N(testCase)
            testCase.baseTest('oC1', false);
        end

        function test_oC2Y(testCase)
            testCase.baseTest('oC2', true);
        end

        function test_oC2N(testCase)
            testCase.baseTest('oC2', false);
        end

        function test_oF1Y(testCase)
            testCase.baseTest('oF1', true);
        end

        function test_oF1N(testCase)
            testCase.baseTest('oF1', false);
        end

        function test_oF2N(testCase)
            testCase.baseTest('oF2', false);
        end

        function test_oF3Y(testCase)
            testCase.baseTest('oF3', true);
        end

        function test_oF3N(testCase)
            testCase.baseTest('oF3', false);
        end

        function test_oI1Y(testCase)
            testCase.baseTest('oI1', true);
        end

        function test_oI1N(testCase)
            testCase.baseTest('oI1', false);
        end

        function test_oI2N(testCase)
            testCase.baseTest('oI2', false);
        end

        function test_oI3Y(testCase)
            testCase.baseTest('oI3', true);
        end

        function test_oI3N(testCase)
            testCase.baseTest('oI3', false);
        end

        function test_oP1Y(testCase)
            testCase.baseTest('oP1', true);
        end

        function test_oP1N(testCase)
            testCase.baseTest('oP1', false);
        end

        function test_tI1Y(testCase)
            testCase.baseTest('tI1', true);
        end

        function test_tI1N(testCase)
            testCase.baseTest('tI1', false);
        end

        function test_tI2Y(testCase)
            testCase.baseTest('tI2', true);
        end

        function test_tI2N(testCase)
            testCase.baseTest('tI2', false);
        end

        function test_tP1Y(testCase)
            testCase.baseTest('tP1', true);
        end

        function test_tP1N(testCase)
            testCase.baseTest('tP1', false);
        end
    end

    methods(Access = private)
        function baseTest(testCase, extBravais, withInv)
            % Base method to run test for a specific bravais lattice

            % Get the structure data from BandPathData.mat
            [POSCAR_inversion, POSCAR_noinversion] = kssolv.analysis.seekpath.hpkot.internal.getStructureData(extBravais);
            if withInv
                [cell, positions, atomicNumbers] = kssolv.analysis.seekpath.utils.simpleReadPoscar(POSCAR_inversion);
            else
                [cell, positions, atomicNumbers] = kssolv.analysis.seekpath.utils.simpleReadPoscar(POSCAR_noinversion);
            end
            structure = {cell, positions, atomicNumbers};

            % Run the getPath function
            result = kssolv.analysis.seekpath.hpkot.getPath(structure, false);

            % Verify the results
            testCase.assertEqual(result.bravais_lattice_extended, extBravais);
            testCase.assertEqual(result.has_inversion_symmetry, withInv);

            if testCase.verbose_tests
                fprintf('*** %s (inv=%d)\n', extBravais, withInv);
                for i = 1:size(result.path, 1)
                    p1 = result.path{i, 1};
                    p2 = result.path{i, 2};
                    fprintf('   %s -- %s: %s -- %s\n', p1, p2, ...
                        mat2str(result.point_coords(p1), 3), mat2str(result.point_coords(p2), 3));
                end
            end
        end
    end
end
