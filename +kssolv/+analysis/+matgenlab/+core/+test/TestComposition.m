classdef TestComposition < matlab.unittest.TestCase
    methods (Test)
        function compositionErrorType(testCase)
            typed = kssolv.analysis.matgenlab.core. ...
                CompositionError("invalid formula");
            testCase.verifyEqual(typed.message, "invalid formula");
            testCase.verifyError(@() typed.throw(), ...
                "KSSOLV:Matgenlab:Composition:CompositionError");
        end

        function formulaParsingParity(testCase)
            input = [
                "Li3Fe2(PO4)3"
                "Li3Fe(PO4)O"
                "LiMn2O4"
                "Li4O4"
                "Li3Fe2Mo3O12"
                "Li3Fe2((PO4)3(CO3)5)2"
                "Li1.5Si0.5"
                "ZnOH"
            ];
            formulas = [
                "Li3 Fe2 P3 O12"
                "Li3 Fe1 P1 O5"
                "Li1 Mn2 O4"
                "Li4 O4"
                "Li3 Fe2 Mo3 O12"
                "Li3 Fe2 P6 C10 O54"
                "Li1.5 Si0.5"
                "Zn1 H1 O1"
            ];
            reduced = [
                "Li3Fe2(PO4)3"
                "Li3FePO5"
                "LiMn2O4"
                "Li2O2"
                "Li3Fe2(MoO4)3"
                "Li3Fe2P6(C5O27)2"
                "Li1.5Si0.5"
                "ZnHO"
            ];
            for idx = 1:numel(input)
                comp = kssolv.analysis.matgenlab.core.Composition(input(idx));
                testCase.verifyEqual(comp.formula, formulas(idx));
                testCase.verifyEqual(comp.reduced_formula, reduced(idx));
            end
        end

        function nestedAndWhitespaceParsing(testCase)
            comp = kssolv.analysis.matgenlab.core.Composition("Na 3 Zr (PO 4) 3");
            testCase.verifyEqual(comp.reduced_formula, "Na3Zr(PO4)3");
            nested = kssolv.analysis.matgenlab.core.Composition( ...
                "(Bi2(Mg0.667Nb1.333)O7)((Bi2(Mg0.667Nb1.333)O7)0.9(SrCO3)0.1)" + ...
                "((Bi2(Mg0.667Nb1.333)O7)0.7(SrCO3)0.3)");
            testCase.verifyEqual(nested.formula, ...
                "Sr0.4 Mg1.7342 Nb3.4658 Bi5.2 C0.4 O19.4");
            testCase.verifyError( ...
                @() kssolv.analysis.matgenlab.core.Composition("(co2)(po4)2"), ...
                "KSSOLV:Matgenlab:Composition:InvalidFormula");
        end

        function mixedValenceLookup(testCase)
            pairs = {
                kssolv.analysis.matgenlab.core.Species("Fe2+"), 2
                kssolv.analysis.matgenlab.core.Species("Fe3+"), 4
                kssolv.analysis.matgenlab.core.Species("Li+"), 8
            };
            comp = kssolv.analysis.matgenlab.core.Composition(pairs);
            testCase.verifyEqual(comp.amountOf("Fe"), 6);
            testCase.verifyEqual(comp.amountOf("Fe2+"), 2);
            testCase.verifyEqual(comp.amountOf("Fe3+"), 4);
            testCase.verifyEqual(comp.formula, "Li8 Fe6");
            testCase.verifyEqual(comp.alphabetical_formula, "Fe6 Li8");
            testCase.verifyEqual(comp.reduced_formula, "Li4Fe3");
            testCase.verifyTrue(comp.contains("Fe"));
            testCase.verifyFalse(comp.contains("O"));
        end

        function compositionProperties(testCase)
            comp = kssolv.analysis.matgenlab.core.Composition("Li3Fe2(PO4)3");
            testCase.verifyEqual(comp.num_atoms, 20);
            testCase.verifyEqual(comp.average_electroneg, ...
                2.7225, "AbsTol", 1e-12);
            testCase.verifyEqual(comp.total_electrons, 202);
            testCase.verifyEqual(comp.get_atomic_fraction("Li"), 3 / 20, "AbsTol", 1e-12);
            testCase.verifyEqual(comp.chemical_system, "Fe-Li-O-P");
            testCase.verifyTrue(comp.contains_element_type("transition_metal"));
            testCase.verifyTrue(comp.contains_element_type("p-block"));
        end

        function formulaConventions(testCase)
            testCase.verifyEqual( ...
                kssolv.analysis.matgenlab.core.Composition("CaCO3").hill_formula, ...
                "C Ca O3");
            testCase.verifyEqual( ...
                kssolv.analysis.matgenlab.core.Composition("C2H5OH").hill_formula, ...
                "C2 H6 O");
            testCase.verifyEqual( ...
                kssolv.analysis.matgenlab.core.Composition("Li4O4").anonymized_formula, ...
                "AB");
            testCase.verifyEqual( ...
                kssolv.analysis.matgenlab.core.Composition("Li3Fe2(PO4)3").anonymized_formula, ...
                "A2B3C3D12");
        end

        function arithmetic(testCase)
            a = kssolv.analysis.matgenlab.core.Composition("Fe2O3");
            b = kssolv.analysis.matgenlab.core.Composition("FeO");
            sum_ = a + b;
            difference = a - b;
            product = b * 4;
            quotient = a / 2;
            testCase.verifyEqual(sum_.formula, "Fe3 O4");
            testCase.verifyEqual(difference.formula, "Fe1 O2");
            testCase.verifyEqual(product.formula, "Fe4 O4");
            testCase.verifyEqual(quotient.formula, "Fe1 O1.5");
            testCase.verifyTrue(a == kssolv.analysis.matgenlab.core.Composition("Fe2O3"));
            testCase.verifyTrue(a.almost_equals( ...
                kssolv.analysis.matgenlab.core.Composition("Fe2.01O3")));
        end

        function mappingsAndWeights(testCase)
            comp = kssolv.analysis.matgenlab.core.Composition("Fe2O3");
            map = comp.asDict();
            testCase.verifyEqual(map("Fe"), 2);
            testCase.verifyEqual(map("O"), 3);
            testCase.verifyEqual( ...
                kssolv.analysis.matgenlab.core.Composition.fromDict(map), comp);
            alloy = kssolv.analysis.matgenlab.core.Composition.from_weights( ...
                {"Fe", 0.5; "Ni", 0.5});
            testCase.verifyEqual(alloy.num_atoms, 1, "AbsTol", 1e-12);
            testCase.verifyEqual(alloy.get_wt_fraction("Fe"), 0.5, "AbsTol", 1e-12);
        end

        function oxidationStateGuess(testCase)
            ionComp = kssolv.analysis.matgenlab.core.Composition("SO4");
            guesses = ionComp.oxi_state_guesses([], -2);
            testCase.verifyNotEmpty(guesses);
            testCase.verifyEqual(guesses{1}.S, 6);
            testCase.verifyEqual(guesses{1}.O, -2);
            charged = ionComp.add_charges_from_oxi_state_guesses([], -2);
            testCase.verifyEqual(charged.charge, -2);
            testCase.verifyEqual(charged.remove_charges(), ionComp);

            overrides = struct("S", 6, "O", -2);
            overridden = ionComp.oxi_state_guesses(overrides, -2);
            testCase.verifyEqual(overridden{1}.S, 6);
            testCase.verifyEqual(overridden{1}.O, -2);
            testCase.verifyError(@() ...
                kssolv.analysis.matgenlab.core.Composition( ...
                    "Li4Fe4P4O16").oxi_state_guesses([], 0, false, 3), ...
                "KSSOLV:Matgenlab:Composition:MaxSites");

            mixed = kssolv.analysis.matgenlab.core.Composition("Fe3O4");
            mixedGuesses = mixed.oxi_state_guesses();
            testCase.verifyEqual(mixedGuesses{1}.Fe, 8 / 3, ...
                "AbsTol", 1e-12);
            testCase.verifyEqual( ...
                string(mixed.add_charges_from_oxi_state_guesses()), ...
                "Fe2+1 Fe3+2 O2-4");

            ranked = kssolv.analysis.matgenlab.core.Composition( ...
                "Li4Fe4P4O16").oxi_state_guesses();
            testCase.verifyEqual([ranked{1}.Fe, ranked{1}.P], [2, 5]);
            testCase.verifyEqual([ranked{2}.Fe, ranked{2}.P], [2.5, 4.5]);
            reduced = kssolv.analysis.matgenlab.core.Composition( ...
                "Li4Fe4P4O16").add_charges_from_oxi_state_guesses( ...
                    [], 0, false, 10);
            testCase.verifyEqual(string(reduced), "Li+1 Fe2+1 P5+1 O2-4");
        end

        function invalidAmounts(testCase)
            testCase.verifyError(@() kssolv.analysis.matgenlab.core.Composition( ...
                {"H", -0.1}), "KSSOLV:Matgenlab:Composition:NegativeAmount");
            tiny = kssolv.analysis.matgenlab.core.Composition( ...
                {"S", kssolv.analysis.matgenlab.core.Composition.amount_tolerance / 2});
            testCase.verifyEqual(length(tiny), 0);
        end
    end
end
