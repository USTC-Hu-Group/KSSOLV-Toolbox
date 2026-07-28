classdef ReactionTest < matlab.unittest.TestCase
    methods (Test)
        function automaticBalanceAndNormalization(testCase)
            import kssolv.analysis.matgenlab.core.Composition
            import kssolv.analysis.matgenlab.analysis.Reaction
            reaction=Reaction({Composition("Fe"),Composition("O2")}, ...
                {Composition("Fe2O3")});
            testCase.verifyEqual(string(reaction), ...
                "2 Fe + 1.5 O2 -> Fe2O3");
            testCase.verifyEqual(reaction.normalized_repr, ...
                "4 Fe + 3 O2 -> 2 Fe2O3");
            reaction.normalize_to(Composition("Fe"),3);
            testCase.verifyEqual(string(reaction), ...
                "3 Fe + 2.25 O2 -> 1.5 Fe2O3");
        end

        function balancedStringEnergyAndEntry(testCase)
            import kssolv.analysis.matgenlab.analysis.BalancedReaction
            reaction=BalancedReaction.from_str("4 Li + O2 -> 2 Li2O");
            testCase.verifyEqual(reaction.normalized_repr, ...
                "4 Li + O2 -> 2 Li2O");
            energies=containers.Map({'Li','O2','Li2O'},{0,0,-3});
            testCase.verifyEqual(reaction.calculate_energy(energies),-6);
            entry=reaction.as_entry(energies);
            testCase.verifyEqual(entry.energy,-6);
            restored=BalancedReaction.from_dict(reaction.as_dict());
            testCase.verifyTrue(restored==reaction);
        end

        function frozenOracle(testCase)
            testCase.assumeTrue( ...
                kssolv.analysis.matgenlab.test.support. ...
                PymatgenOracle.isAvailable());
            request=struct( ...
                "module","pymatgen.analysis.reaction_calculator", ...
                "symbol","Reaction", ...
                "construct",struct("args",{{ ...
                {struct("x_module","pymatgen.core.composition", ...
                    "x_class","Composition","Li",1), ...
                 struct("x_module","pymatgen.core.composition", ...
                    "x_class","Composition","O",2)}, ...
                {struct("x_module","pymatgen.core.composition", ...
                    "x_class","Composition","Li",2,"O",1)}}}), ...
                "operations",{{struct("kind","get","name","coeffs"), ...
                struct("kind","get","name","normalized_repr")}});
            reference=kssolv.analysis.matgenlab.test.support. ...
                PymatgenOracle.execute(request);
            actual=kssolv.analysis.matgenlab.analysis.Reaction( ...
                {kssolv.analysis.matgenlab.core.Composition("Li"), ...
                kssolv.analysis.matgenlab.core.Composition("O2")}, ...
                {kssolv.analysis.matgenlab.core.Composition("Li2O")});
            testCase.verifyEqual(actual.coeffs, ...
                reshape(reference.results{1},1,[]),AbsTol=1e-14);
            testCase.verifyEqual(actual.normalized_repr, ...
                string(reference.results{2}));
        end

        function thermoRoundTrip(testCase)
            data=kssolv.analysis.matgenlab.analysis.ThermoData( ...
                "fH","hematite","solid","Fe2O3",-824.2, ...
                "NIST","calorimetry",[298,1000],2.1);
            restored=kssolv.analysis.matgenlab.analysis. ...
                ThermoData.from_dict(data.as_dict());
            testCase.verifyEqual(restored.reduced_formula,"Fe2O3");
            testCase.verifyEqual(restored.value,-824.2);
        end

        function computedReactionEnergy(testCase)
            import kssolv.analysis.matgenlab.core.ComputedEntry
            import kssolv.analysis.matgenlab.analysis.ComputedReaction
            lithium=ComputedEntry("Li54",-108.56492362);
            oxygen=ComputedEntry("O2",-17.02844794);
            peroxide=ComputedEntry("Li72O72",-959.64693323);
            reaction=ComputedReaction({lithium,oxygen},{peroxide});
            testCase.verifyEqual(string(reaction), ...
                "2 Li + O2 -> Li2O2");
            testCase.verifyEqual(reaction.calculated_reaction_energy, ...
                -5.60748821935,AbsTol=1e-11);
            testCase.verifyTrue(isnan( ...
                reaction.calculated_reaction_energy_uncertainty));
            restored=ComputedReaction.from_dict(reaction.as_dict());
            testCase.verifyEqual(string(restored),string(reaction));
        end

        function computedReactionUsesLowestReducedEnergy(testCase)
            import kssolv.analysis.matgenlab.core.ComputedEntry
            import kssolv.analysis.matgenlab.analysis.ComputedReaction
            high=ComputedEntry("Li2",-1);
            low=ComputedEntry("Li4",-6);
            oxygen=ComputedEntry("O2",0);
            oxide=ComputedEntry("Li2O",-5);
            reaction=ComputedReaction({high,low,oxygen},{oxide});
            % Lowest lithium energy is -1.5 eV/Li, so
            % 2 Li + 1/2 O2 -> Li2O has energy -2 eV.
            testCase.verifyEqual( ...
                reaction.calculated_reaction_energy,-2,AbsTol=1e-14);
        end

        function completePublicSurface(testCase)
            import kssolv.analysis.matgenlab.core.Composition
            import kssolv.analysis.matgenlab.analysis.BalancedReaction
            reaction=BalancedReaction.from_str("4 Li + O2 -> 2 Li2O");
            symbols=cellfun(@(element)string(element), ...
                reaction.elements);
            testCase.verifyEqual(symbols,["Li","O"]);
            testCase.verifyEqual(reaction.coeffs,[-4,-1,2]);
            testCase.verifyEqual(numel(reaction.all_comp),3);
            testCase.verifyEqual(numel(reaction.reactants),2);
            testCase.verifyEqual(numel(reaction.products),1);
            testCase.verifyEqual(reaction.get_coeff(Composition("O2")),-1);
            testCase.verifyEqual(reaction.get_el_amount("Li"),4);
            [text,factor]=reaction.normalized_repr_and_factor();
            testCase.verifyEqual(text,"4 Li + O2 -> 2 Li2O");
            testCase.verifyEqual(factor,1);
            reaction.normalize_to_element("O",4);
            testCase.verifyEqual(reaction.get_el_amount("O"),4);

            automatic=kssolv.analysis.matgenlab.analysis.Reaction( ...
                {Composition("Li"),Composition("O2")}, ...
                {Composition("Li2O")});
            copied=automatic.copy();
            testCase.verifyTrue(copied==automatic);
            restored=kssolv.analysis.matgenlab.analysis.Reaction. ...
                from_dict(automatic.as_dict());
            testCase.verifyTrue(restored==automatic);
            testCase.verifyError(@()BalancedReaction( ...
                {Composition("H2"),1},{Composition("H2O"),1}), ...
                "KSSOLV:Matgenlab:Reaction:BalanceError");

            import kssolv.analysis.matgenlab.core.ComputedEntry
            computed=kssolv.analysis.matgenlab.analysis.ComputedReaction( ...
                {ComputedEntry("Li",0),ComputedEntry("O2",0)}, ...
                {ComputedEntry("Li2O",-3)});
            testCase.verifyNumElements(computed.all_entries,3);
            decoded=kssolv.analysis.matgenlab.analysis.ComputedReaction. ...
                from_dict(computed.as_dict());
            testCase.verifyEqual(decoded.calculated_reaction_energy,-3, ...
                AbsTol=1e-12);
        end
    end
end
