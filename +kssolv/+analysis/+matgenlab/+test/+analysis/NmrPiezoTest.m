classdef NmrPiezoTest < matlab.unittest.TestCase
    methods (Test)
        function shieldingNotations(testCase)
            import kssolv.analysis.matgenlab.analysis.ChemicalShielding
            shielding = ChemicalShielding.from_maryland_notation( ...
                195.0788, 68.1733, 0.8337);
            haeberlen = shielding.haeberlen_values;
            testCase.verifyEqual(haeberlen.sigma_iso, 195.0788, ...
                AbsTol=1e-10);
            testCase.verifyEqual(haeberlen.delta_sigma_iso, ...
                -65.33899505250002, AbsTol=1e-10);
            testCase.verifyEqual(haeberlen.zeta, ...
                -43.559330035000016, AbsTol=1e-10);
            maryland = shielding.maryland_values;
            testCase.verifyEqual(maryland.omega, 68.1733, AbsTol=1e-10);
            testCase.verifyEqual(maryland.kappa, 0.8337, AbsTol=1e-10);
        end

        function electricFieldGradientOracle(testCase)
            import kssolv.analysis.matgenlab.analysis.ElectricFieldGradient
            matrix = [11.11,1.371,2.652;1.371,3.635,-3.572; ...
                2.652,-3.572,-14.746];
            gradient = ElectricFieldGradient(matrix);
            testCase.verifyEqual(gradient.V_yy, 11.516, AbsTol=1e-3);
            testCase.verifyEqual(gradient.V_xx, 4.204, AbsTol=1e-3);
            testCase.verifyEqual(gradient.V_zz, -15.721, AbsTol=1e-3);
            testCase.verifyEqual(gradient.asymmetry, 0.465, AbsTol=1e-3);
            testCase.verifyEqual(double(gradient.coupling_constant("Al")), ...
                5.573, AbsTol=1e-3);
        end

        function piezoVaspOrdering(testCase)
            import kssolv.analysis.matgenlab.analysis.PiezoTensor
            vasp = [0,0,0,0,0,0.03839; ...
                0,0,0,0,0.03839,0; ...
                6.89822,6.89822,27.4628,0,0,0];
            tensor = PiezoTensor.from_vasp_voigt(vasp);
            testCase.verifyEqual(double(tensor(1,1,3)), 0.03839, ...
                AbsTol=1e-14);
            testCase.verifyEqual(double(tensor(2,2,3)), 0.03839, ...
                AbsTol=1e-14);
            testCase.verifyEqual(double(tensor(3,3,3)), 27.4628, ...
                AbsTol=1e-14);
        end
    end
end
