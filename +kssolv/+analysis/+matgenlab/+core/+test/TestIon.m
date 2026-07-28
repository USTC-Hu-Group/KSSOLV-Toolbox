classdef TestIon < matlab.unittest.TestCase
    methods (Test)
        function chargeParsing(testCase)
            cases = {
                "Li+", 1
                "Li[+]", 1
                "Ca[2+]", 2
                "Ca[+2]", 2
                "Ca++", 2
                "Ca[++]", 2
                "Ca2+", 1
                "C2O4-2", -2
                "CO2", 0
                "Cl-", -1
                "SO4[-2]", -2
                "SO4-2", -2
                "SO42-", -1
                "SO4--", -2
                "N3-", -1
                "Na[+-+]", 1
            };
            for idx = 1:size(cases, 1)
                ion = kssolv.analysis.matgenlab.core.Ion.fromFormula(cases{idx, 1});
                testCase.verifyEqual(ion.charge, cases{idx, 2}, ...
                    sprintf("Charge mismatch for %s.", cases{idx, 1}));
            end
        end

        function formulaParity(testCase)
            input = [
                "Li+"
                "MnO4-"
                "Mn++"
                "PO3-2"
                "Fe(CN)6-3"
                "Fe(CN)6----"
                "Fe2((PO4)3(CO3)5)2-3"
                "Ca[2+]"
                "NaOH(aq)"
            ];
            formulas = [
                "Li1 +1"
                "Mn1 O4 -1"
                "Mn1 +2"
                "P1 O3 -2"
                "Fe1 C6 N6 -3"
                "Fe1 C6 N6 -4"
                "Fe2 P6 C10 O54 -3"
                "Ca1 +2"
                "Na1 H1 O1 (aq)"
            ];
            reduced = [
                "Li[+1]"
                "MnO4[-1]"
                "Mn[+2]"
                "PO3[-2]"
                "Fe(CN)6[-3]"
                "Fe(CN)6[-4]"
                "FeP3C5O27[-1.5]"
                "Ca[+2]"
                "NaOH(aq)"
            ];
            anonymized = [
                "A+1"
                "AB4-1"
                "A+2"
                "AB3-2"
                "AB6C6-3"
                "AB6C6-4"
                "AB3C5D27-3"
                "A+2"
                "ABC(aq)"
            ];
            for idx = 1:numel(input)
                ion = kssolv.analysis.matgenlab.core.Ion.fromFormula(input(idx));
                testCase.verifyEqual(ion.formula, formulas(idx));
                testCase.verifyEqual(ion.reduced_formula, reduced(idx));
                testCase.verifyEqual(ion.anonymized_formula, anonymized(idx));
            end
        end

        function aqueousSpecialFormulas(testCase)
            cases = {
                "Cl-", "Cl[-1]"
                "H+", "H[+1]"
                "F2", "F2(aq)"
                "H2", "H2(aq)"
                "O3", "O3(aq)"
                "NaOH", "NaOH(aq)"
                "H4O4", "H2O2(aq)"
                "OH-", "OH[-1]"
                "H2PO4-", "H2PO4[-1]"
                "CH3COO-", "CH3COO[-1]"
                "CH3COOH", "CH3COOH(aq)"
                "CH3OH", "CH3OH(aq)"
                "C2O4--", "C2O4[-2]"
                "CO2", "CO2(aq)"
                "NH4+", "NH4[+1]"
                "NH3", "NH3(aq)"
                "HCOO-", "HCO2[-1]"
                "C2H6O", "C2H5OH(aq)"
                "C3H8O", "C3H7OH(aq)"
                "C4H10O", "C4H9OH(aq)"
            };
            for idx = 1:size(cases, 1)
                actual = kssolv.analysis.matgenlab.core.Ion. ...
                    fromFormula(cases{idx, 1}).reduced_formula;
                testCase.verifyEqual(actual, cases{idx, 2}, ...
                    sprintf("Reduced formula mismatch for %s.", cases{idx, 1}));
            end
        end

        function arithmeticAndSerialization(testCase)
            na = kssolv.analysis.matgenlab.core.Ion.fromDict( ...
                struct(Na=1, charge=1));
            cl = kssolv.analysis.matgenlab.core.Ion.fromDict( ...
                struct(Cl=1, charge=-1));
            result = na + cl;
            testCase.verifyEqual(result.composition, ...
                kssolv.analysis.matgenlab.core.Composition("NaCl"));
            testCase.verifyEqual(result.charge, 0);
            scaled = na * 4;
            testCase.verifyEqual(scaled.formula, "Na4 +4");

            source = kssolv.analysis.matgenlab.core.Ion.fromFormula("MnO4-");
            map = source.asDict();
            roundTrip = kssolv.analysis.matgenlab.core.Ion.fromDict(map);
            testCase.verifyEqual(roundTrip, ...
                kssolv.analysis.matgenlab.core.Ion.fromFormula("MnO4-"));
        end

        function oxidationStateGuess(testCase)
            guesses = kssolv.analysis.matgenlab.core.Ion. ...
                fromFormula("SO4-2").oxi_state_guesses();
            testCase.verifyNotEmpty(guesses);
            testCase.verifyEqual(guesses{1}.S, 6);
            testCase.verifyEqual(guesses{1}.O, -2);
        end
    end
end
