classdef ChemicalPotentialTest < matlab.unittest.TestCase
    methods (Test)
        function energyAndArithmetic(testCase)
            potential = ...
                kssolv.analysis.matgenlab.core.ChemicalPotential( ...
                    struct("Li", -1.5, "O", -4));
            testCase.verifyEqual(potential.get_energy("Li2O"), -7);
            scaled = 2 * potential;
            testCase.verifyEqual(scaled.get_energy("Li2O"), -14);
            correction = ...
                kssolv.analysis.matgenlab.core.ChemicalPotential( ...
                    struct("Li", 0.5));
            combined = potential + correction;
            testCase.verifyEqual(combined.get_energy("Li2O"), -6);
            testCase.verifyError(@() potential.get_energy("LiFeO2"), ...
                "KSSOLV:Matgenlab:ChemicalPotential:Missing");
            testCase.verifyEqual( ...
                potential.get_energy("LiFeO2", false), -9.5);
        end

        function formulaReduction(testCase)
            [formula, factor] = ...
                kssolv.analysis.matgenlab.core.reduce_formula( ...
                    struct("Li", 4, "O", 2));
            testCase.verifyEqual(formula, "Li2O");
            testCase.verifyEqual(factor, 2);
        end
    end
end
