classdef TestPeriodicTable < matlab.unittest.TestCase
    methods (Test)
        function elementConstructionAndLookup(testCase)
            Element = @(s) kssolv.analysis.matgenlab.core.Element(s);
            fe = Element("Fe");
            testCase.verifyEqual(fe.symbol, "Fe");
            testCase.verifyEqual(fe.Z, 26);
            testCase.verifyEqual(fe.atomic_mass, 55.845, "AbsTol", 1e-12);
            testCase.verifyEqual(fe.X, 1.83, "AbsTol", 1e-12);
            testCase.verifyEqual(kssolv.analysis.matgenlab.core.Element.fromZ(26), fe);
            testCase.verifyEqual(kssolv.analysis.matgenlab.core.Element.fromName("Iron"), fe);
            testCase.verifyEqual(kssolv.analysis.matgenlab.core.Element.fromName("aluminium").symbol, "Al");
            testCase.verifyError(@() Element("Dolphin"), ...
                "KSSOLV:Matgenlab:Element:InvalidSymbol");
        end

        function completeElementSet(testCase)
            symbols = kssolv.analysis.matgenlab.core.PeriodicTableData.symbols(false);
            allSymbols = kssolv.analysis.matgenlab.core.PeriodicTableData.symbols(true);
            testCase.verifyNumElements(symbols, 118);
            testCase.verifyNumElements(allSymbols, 120);
            testCase.verifyEqual(symbols(1:10).', ...
                ["H","He","Li","Be","B","C","N","O","F","Ne"]);
            testCase.verifyEqual(symbols(end), "Og");
        end

        function rowsGroupsAndBlocks(testCase)
            cases = {
                "H", 1, 1, "s"
                "He", 1, 18, "p"
                "O", 2, 16, "p"
                "Fe", 4, 8, "d"
                "Ce", 6, 3, "f"
                "Lu", 6, 3, "d"
                "U", 7, 3, "f"
                "Lr", 7, 3, "d"
                "Og", 7, 18, "p"
            };
            for idx = 1:size(cases, 1)
                el = kssolv.analysis.matgenlab.core.Element(cases{idx, 1});
                testCase.verifyEqual(el.row, cases{idx, 2});
                testCase.verifyEqual(el.group, cases{idx, 3});
                testCase.verifyEqual(el.block, cases{idx, 4});
            end
            testCase.verifyEqual( ...
                kssolv.analysis.matgenlab.core.Element.fromRowAndGroup(8, 4).symbol, "Ce");
        end

        function electronicStructures(testCase)
            fe = kssolv.analysis.matgenlab.core.Element("Fe");
            expected = {
                1, "s", 2
                2, "s", 2
                2, "p", 6
                3, "s", 2
                3, "p", 6
                4, "s", 2
                3, "d", 6
            };
            testCase.verifyEqual(fe.full_electronic_structure, expected);
            testCase.verifyEqual(fe.n_electrons, 26);
            testCase.verifyEqual(fe.valence, [2, 6]);
            testCase.verifyEqual( ...
                kssolv.analysis.matgenlab.core.Element("O").valence, [1, 4]);
            testCase.verifyEqual( ...
                kssolv.analysis.matgenlab.core.Element("He").valence, [NaN, 0]);
        end

        function termSymbols(testCase)
            cases = {
                "Li", "2S0.5"
                "C", "3P0.0"
                "O", "3P2.0"
                "Ti", "3F2.0"
                "Pr", "4I4.5"
                "Ne", "1S0"
            };
            for idx = 1:size(cases, 1)
                actual = kssolv.analysis.matgenlab.core.Element( ...
                    cases{idx, 1}).ground_state_term_symbol;
                testCase.verifyEqual(actual, cases{idx, 2});
            end
        end

        function chemicalCategories(testCase)
            testCase.verifyTrue(kssolv.analysis.matgenlab.core.Element("Fe").is_metal);
            testCase.verifyTrue(kssolv.analysis.matgenlab.core.Element("Fe").is_transition_metal);
            testCase.verifyFalse(kssolv.analysis.matgenlab.core.Element("Si").is_metal);
            testCase.verifyTrue(kssolv.analysis.matgenlab.core.Element("Si").is_metalloid);
            testCase.verifyTrue(kssolv.analysis.matgenlab.core.Element("Xe").is_noble_gas);
            testCase.verifyTrue(kssolv.analysis.matgenlab.core.Element("Br").is_halogen);
            testCase.verifyTrue(kssolv.analysis.matgenlab.core.Element("U").is_actinoid);
            testCase.verifyTrue(kssolv.analysis.matgenlab.core.Element("U").is_radioactive);
        end

        function speciesAndDummySpecies(testCase)
            Species = @(varargin) kssolv.analysis.matgenlab.core.Species(varargin{:});
            fe2 = Species("Fe2+");
            testCase.verifyEqual(fe2.symbol, "Fe");
            testCase.verifyEqual(fe2.oxi_state, 2);
            testCase.verifyEqual(string(fe2), "Fe2+");
            testCase.verifyEqual(fe2.ionic_radius, 0.92, "AbsTol", 1e-12);
            testCase.verifyEqual(fe2.get_shannon_radius("VI", "High Spin"), ...
                0.78, "AbsTol", 1e-12);
            testCase.verifyEqual(fe2.get_crystal_field_spin("oct", "high"), 4);
            spin = kssolv.analysis.matgenlab.core.Species.fromStr("Fe,spin=5");
            testCase.verifyEqual(string(spin), "Fe0+,spin=5");
            testCase.verifyEqual(spin.spin, 5);

            dummy = kssolv.analysis.matgenlab.core.DummySpecies("X");
            testCase.verifyEqual(string(dummy), "X0+");
            testCase.verifyEqual(dummy.X, 0);
            testCase.verifyFalse(dummy.is_metal);
            testCase.verifyError( ...
                @() kssolv.analysis.matgenlab.core.DummySpecies("Vac"), ...
                "KSSOLV:Matgenlab:DummySpecies:InvalidSymbol");
        end

        function serializationRoundTrip(testCase)
            el = kssolv.analysis.matgenlab.core.Element("Fe");
            testCase.verifyEqual( ...
                kssolv.analysis.matgenlab.core.Element.fromDict(el.asDict()), el);
            sp = kssolv.analysis.matgenlab.core.Species("Mn", 3, "spin", 4);
            testCase.verifyEqual( ...
                kssolv.analysis.matgenlab.core.Species.fromDict(sp.asDict()), sp);
            ds = kssolv.analysis.matgenlab.core.DummySpecies("Xx", -1);
            testCase.verifyEqual( ...
                kssolv.analysis.matgenlab.core.DummySpecies.fromDict(ds.asDict()), ds);
        end
    end
end
