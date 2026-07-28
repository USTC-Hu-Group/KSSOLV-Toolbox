classdef CifTest < matlab.unittest.TestCase
    methods (Test)
        function moduleStr2floatMatchesUpstream(testCase)
            convert = @kssolv.analysis.matgenlab.io.cif.str2float;
            testCase.verifyEqual(convert("1.234(5)"), 1.234);
            testCase.verifyEqual(convert("-2.5(10"), -2.5);
            testCase.verifyEqual(convert("."), 0);
            testCase.verifyEqual(convert({"3.5(2)"}), 3.5);
            testCase.verifyError(@() convert("not-a-number"), ...
                "KSSOLV:Matgenlab:CifParser:InvalidNumber");
        end
        function blockParsesCif11TokensAndLoops(testCase)
            contents = strjoin([
                "# non-ASCII is ignored: " + string(char(233))
                "data_example"
                "_scalar 'value with spaces'"
                "_quoted_reserved '_starts_with_underscore'"
                "_description"
                ";"
                "first line"
                "second line"
                ";"
                "loop_"
                "_key"
                "_value"
                "a 1"
                "b 2 # comment"
                ], newline);
            block = kssolv.analysis.matgenlab.io.cif.CifBlock.from_str(contents);
            testCase.verifyEqual(block.header, "example");
            testCase.verifyEqual(string(block("_scalar")), "value with spaces");
            testCase.verifyEqual(string(block("_quoted_reserved")), ...
                "_starts_with_underscore");
            testCase.verifyEqual(string(block("_description")), ...
                " first line second line");
            testCase.verifyEqual(string(block("_key")), ["a", "b"]);
            testCase.verifyEqual(string(block("_value")), ["1", "2"]);
            restored = kssolv.analysis.matgenlab.io.cif.CifBlock.from_str(char(block));
            testCase.verifyEqual(string(restored("_scalar")), ...
                string(block("_scalar")));
            testCase.verifyEqual(string(restored("_quoted_reserved")), ...
                string(block("_quoted_reserved")));
            testCase.verifyEqual(string(restored("_description")), ...
                strtrim(string(block("_description"))));
            testCase.verifyEqual(restored.loops, block.loops);
        end

        function invalidLoopCardinalityIsRejected(testCase)
            contents = sprintf("data_x\nloop_\n_a\n_b\n1 2 3");
            testCase.verifyError(@() ...
                kssolv.analysis.matgenlab.io.cif.CifBlock.from_str(contents), ...
                "KSSOLV:Matgenlab:CifBlock:LoopCardinality");
        end

        function fileSupportsMultipleBlocksAndSkipsPowder(testCase)
            contents = strjoin([
                "data_first"
                "_a 1"
                "data_powder_pattern"
                "_b 2"
                "data_second"
                "_c 3"
                ], newline);
            file = kssolv.analysis.matgenlab.io.cif.CifFile.from_str(contents);
            testCase.verifyEqual(file.headers, ["first", "second"]);
            first = file.data("first");
            second = file.data("second");
            testCase.verifyEqual(string(first("_a")), "1");
            testCase.verifyEqual(string(second("_c")), "3");
        end

        function parserExpandsSymmetryAndPreservesLabels(testCase)
            cif = testCase.naclCif();
            parser = kssolv.analysis.matgenlab.io.cif.CifParser.from_str( ...
                cif, check_cif = false);
            structures = parser.parse_structures( ...
                primitive = false, on_error = "raise");
            structure = structures{1};
            testCase.verifyEqual(structure.num_sites, 4);
            testCase.verifyEqual(structure.lattice.parameters, ...
                [5.64, 5.64, 5.64, 90, 90, 90], AbsTol = 1e-10);
            testCase.verifyEqual(sort(structure.composition.chemical_system_set), ...
                ["Cl", "Na"]);
            testCase.verifyEqual(sort(structure.frac_coords, 1), ...
                sort([0,0,0; .5,.5,.5; .5,0,0; 0,.5,.5], 1), ...
                AbsTol = 1e-12);
        end

        function parserReturnsRealSymmetrizedStructure(testCase)
            parser = kssolv.analysis.matgenlab.io.cif.CifParser.from_str( ...
                testCase.naclCif(), check_cif = false);
            structures = parser.parse_structures( ...
                primitive = false, symmetrized = true, on_error = "raise");
            structure = structures{1};
            testCase.verifyClass(structure, ...
                "kssolv.analysis.matgenlab.symmetry.structure.SymmetrizedStructure");
            testCase.verifyEqual(numel(structure.equivalent_indices), 2);
            testCase.verifyEqual(sort(cellfun(@numel, ...
                structure.equivalent_indices)), [2,2]);
            testCase.verifyEqual(structure.spacegroup.int_symbol, "Not Parsed");
            testCase.verifyEqual(structure.spacegroup.int_number, -1);
        end

        function parserFindsPrimitiveCell(testCase)
            testCase.assumeTrue(testCase.spglibAvailable());
            parser = kssolv.analysis.matgenlab.io.cif.CifParser.from_str( ...
                testCase.naclCif(), check_cif = false);
            structures = parser.parse_structures( ...
                primitive = true, on_error = "raise");
            structure = structures{1};
            testCase.verifyEqual(structure.num_sites, 2);
            testCase.verifyEqual(structure.formula, "Na1 Cl1");
            testCase.verifyEqual(structure.volume, 5.64 ^ 3 / 2, ...
                RelTol = 1e-10);
        end

        function parserCombinesDisorderAndReadsOxidation(testCase)
            cif = strjoin([
                "data_disorder"
                "_cell_length_a 4"
                "_cell_length_b 4"
                "_cell_length_c 4"
                "_cell_angle_alpha 90"
                "_cell_angle_beta 90"
                "_cell_angle_gamma 90"
                "_symmetry_equiv_pos_as_xyz 'x,y,z'"
                "loop_"
                "_atom_type_symbol"
                "_atom_type_oxidation_number"
                "Fe2+ 2"
                "Mn2+ 2"
                "loop_"
                "_atom_site_type_symbol"
                "_atom_site_label"
                "_atom_site_fract_x"
                "_atom_site_fract_y"
                "_atom_site_fract_z"
                "_atom_site_occupancy"
                "Fe2+ Fe1 0 0 0 0.6"
                "Mn2+ Mn1 0 0 0 0.4"
                ], newline);
            parser = kssolv.analysis.matgenlab.io.cif.CifParser.from_str( ...
                cif, check_cif = false);
            structures = parser.parse_structures( ...
                primitive = false, on_error = "raise");
            site = structures{1}.get_site(1);
            testCase.verifyFalse(site.is_ordered);
            testCase.verifyEqual(site.species("Fe2+"), 0.6, AbsTol = 1e-12);
            testCase.verifyEqual(site.species("Mn2+"), 0.4, AbsTol = 1e-12);
        end

        function occupancyToleranceMatchesPymatgenBehavior(testCase)
            cif = replace(testCase.naclCif(), ...
                "Na Na1 0 0 0 1", "Na Na1 0 0 0 1.05");
            strict = kssolv.analysis.matgenlab.io.cif.CifParser.from_str( ...
                cif, occupancy_tolerance = 1.0, check_cif = false);
            testCase.verifyError(@() strict.parse_structures( ...
                primitive = false, on_error = "raise"), ...
                "KSSOLV:Matgenlab:CifParser:Section");
            tolerant = kssolv.analysis.matgenlab.io.cif.CifParser.from_str( ...
                cif, occupancy_tolerance = 1.1, check_cif = false);
            structures = tolerant.parse_structures( ...
                primitive = false, on_error = "raise");
            testCase.verifyEqual(structures{1}.get_site(1).species.num_atoms, ...
                1, AbsTol = 1e-12);
            raw = tolerant.parse_structures( ...
                primitive = false, check_occu = false, on_error = "raise");
            naSites = find(arrayfun(@(index) ...
                raw{1}.get_site(index).species.contains("Na"), ...
                1:raw{1}.num_sites));
            testCase.verifyEqual( ...
                raw{1}.get_site(naSites(1)).species.num_atoms, ...
                1.05, AbsTol = 1e-12);
        end

        function parserReadsMagneticMomentFields(testCase)
            cif = strjoin([
                "data_mag"
                "_cell_length_a 3"
                "_cell_length_b 4"
                "_cell_length_c 5"
                "_cell_angle_alpha 90"
                "_cell_angle_beta 90"
                "_cell_angle_gamma 90"
                "loop_"
                "_space_group_symop_magn_operation.xyz"
                "'x,y,z,1'"
                "loop_"
                "_atom_site_type_symbol"
                "_atom_site_label"
                "_atom_site_fract_x"
                "_atom_site_fract_y"
                "_atom_site_fract_z"
                "_atom_site_occupancy"
                "Fe Fe1 0 0 0 1"
                "loop_"
                "_atom_site_moment_label"
                "_atom_site_moment_crystalaxis_x"
                "_atom_site_moment_crystalaxis_y"
                "_atom_site_moment_crystalaxis_z"
                "Fe1 1 2 3"
                ], newline);
            parser = kssolv.analysis.matgenlab.io.cif.CifParser.from_str( ...
                cif, check_cif = false);
            structures = parser.parse_structures( ...
                primitive = false, on_error = "raise");
            testCase.verifyEqual( ...
                structures{1}.get_site(1).site_properties.magmom, ...
                [1,2,3], AbsTol = 1e-12);
        end

        function parserGeneratesMagneticOperationsFromBns(testCase)
            testCase.assumeTrue(testCase.spglibAvailable());
            cif = strjoin([
                "data_bns"
                "_space_group.magn_name_BNS ""P 4/m' b' m'"""
                "_cell_length_a 7.1316"
                "_cell_length_b 7.1316"
                "_cell_length_c 4.0505"
                "_cell_angle_alpha 90"
                "_cell_angle_beta 90"
                "_cell_angle_gamma 90"
                "loop_"
                "_atom_site_label"
                "_atom_site_type_symbol"
                "_atom_site_fract_x"
                "_atom_site_fract_y"
                "_atom_site_fract_z"
                "_atom_site_occupancy"
                "Gd1 Gd 0.31746 0.81746 0 1"
                "B1 B 0 0 0.20290 1"
                "B2 B 0.17590 0.03800 0.5 1"
                "B3 B 0.08670 0.58670 0.5 1"
                "loop_"
                "_atom_site_moment_label"
                "_atom_site_moment_crystalaxis_x"
                "_atom_site_moment_crystalaxis_y"
                "_atom_site_moment_crystalaxis_z"
                "Gd1 5.05 5.05 0"
                ], newline);
            parser = kssolv.analysis.matgenlab.io.cif.CifParser.from_str( ...
                cif, check_cif = false);
            structures = parser.parse_structures( ...
                primitive = false, on_error = "raise");
            testCase.verifyEqual(structures{1}.formula, "Gd4 B16");
            testCase.verifyEqual(numel(parser.symmetry_operations), 16);
        end

        function writerMatchesPymatgenP1SchemaAndRoundTrips(testCase)
            lattice = kssolv.analysis.matgenlab.core.Lattice. ...
                from_parameters(4.1, 5.2, 6.3, 82, 91, 104);
            disordered = kssolv.analysis.matgenlab.core.Composition( ...
                {"Fe", 0.75; "Mn", 0.25});
            structure = kssolv.analysis.matgenlab.core.Structure( ...
                lattice, {disordered, "O"}, [0,0,0; .2,.3,.4], ...
                site_properties = struct("charge", [1.25, -0.5]));
            writer = kssolv.analysis.matgenlab.io.cif.CifWriter( ...
                structure, significant_figures = 6, ...
                write_site_properties = true);
            text = string(writer);
            testCase.verifySubstring(text, ...
                "_symmetry_space_group_name_H-M   'P 1'");
            testCase.verifySubstring(text, "_atom_site_charge");
            parser = kssolv.analysis.matgenlab.io.cif.CifParser.from_str( ...
                text, check_cif = false);
            restored = parser.parse_structures( ...
                primitive = false, on_error = "raise");
            testCase.verifyEqual(restored{1}.num_sites, 2);
            testCase.verifyEqual(restored{1}.composition.element_composition, ...
                structure.composition.element_composition);
            testCase.verifyEqual(restored{1}.lattice.parameters, ...
                structure.lattice.parameters, AbsTol = 5e-6);
        end

        function magneticWriterRoundTripsMoment(testCase)
            structure = kssolv.analysis.matgenlab.core.Structure( ...
                kssolv.analysis.matgenlab.core.Lattice.cubic(3), ...
                "Fe", [0,0,0], ...
                site_properties = struct("magmom", {{[0,0,4.5]}}));
            writer = kssolv.analysis.matgenlab.io.cif.CifWriter( ...
                structure, write_magmoms = true);
            parser = kssolv.analysis.matgenlab.io.cif.CifParser.from_str( ...
                string(writer), check_cif = false);
            restored = parser.parse_structures( ...
                primitive = false, on_error = "raise");
            testCase.verifyEqual( ...
                restored{1}.get_site(1).site_properties.magmom, ...
                [0,0,4.5], AbsTol = 1e-8);
        end

        function blockSerializationAgreesWithFrozenOracle(testCase)
            testCase.assumeTrue( ...
                kssolv.analysis.matgenlab.test.support.PymatgenOracle.isAvailable());
            cif = strjoin([
                "data_demo"
                "_a 'hello world'"
                "loop_"
                "_b"
                "_c"
                "x 1"
                "y 2"
                ], newline);
            request = struct( ...
                "module", "pymatgen.io.cif", ...
                "symbol", "CifBlock", ...
                "construct", struct("method", "from_str", ...
                    "args", {{cif}}), ...
                "operations", {{struct( ...
                    "kind", "call", "name", "__str__")}});
            reference = ...
                kssolv.analysis.matgenlab.test.support.PymatgenOracle. ...
                execute(request);
            block = kssolv.analysis.matgenlab.io.cif.CifBlock.from_str(cif);
            testCase.verifyEqual(string(block), string(reference.results{1}));
        end

        function structureParsingAgreesWithFrozenOracle(testCase)
            testCase.assumeTrue( ...
                kssolv.analysis.matgenlab.test.support.PymatgenOracle.isAvailable());
            filename = fullfile(KSSOLV_Toolbox.RootDirectory, ...
                "+kssolv", "+services", "+fileparser", "+test", ...
                "CIF", "Al2O3.cif");
            cif = fileread(filename);
            request = struct( ...
                "module", "pymatgen.io.cif", ...
                "symbol", "CifParser", ...
                "construct", struct("method", "from_str", ...
                    "args", {{cif}}, "kwargs", struct("check_cif", false)), ...
                "operations", {{struct("kind", "call", ...
                    "name", "parse_structures", ...
                    "kwargs", struct("primitive", false))}});
            reference = ...
                kssolv.analysis.matgenlab.test.support.PymatgenOracle. ...
                execute(request);
            parser = kssolv.analysis.matgenlab.io.cif.CifParser.from_str( ...
                cif, check_cif = false);
            structures = parser.parse_structures( ...
                primitive = false, on_error = "raise");
            actual = structures{1};
            referenceSites = reference.results.sites;
            referenceFracCoords = reshape( ...
                vertcat(referenceSites.abc), 3, []).';
            testCase.verifyEqual(actual.num_sites, numel(referenceSites));
            testCase.verifyEqual(actual.lattice.matrix, ...
                reference.results.lattice.matrix, AbsTol = 1e-10);
            testCase.verifyEqual(actual.frac_coords, ...
                referenceFracCoords, AbsTol = 1e-10);
        end

        function p1WriterExactlyAgreesWithFrozenOracle(testCase)
            testCase.assumeTrue( ...
                kssolv.analysis.matgenlab.test.support.PymatgenOracle.isAvailable());
            structure = kssolv.analysis.matgenlab.core.Structure( ...
                kssolv.analysis.matgenlab.core.Lattice.cubic(5.43), ...
                {"Si", "Si"}, [0,0,0; .25,.25,.25]);
            request = struct( ...
                "module", "pymatgen.io.cif", ...
                "symbol", "CifWriter", ...
                "construct", struct("args", {{structure.as_dict()}}, ...
                    "kwargs", struct("significant_figures", 6)), ...
                "operations", {{struct( ...
                    "kind", "call", "name", "__str__")}});
            reference = ...
                kssolv.analysis.matgenlab.test.support.PymatgenOracle. ...
                execute(request);
            writer = kssolv.analysis.matgenlab.io.cif.CifWriter( ...
                structure, significant_figures = 6);
            testCase.verifyEqual(string(writer), string(reference.results));
        end

        function symmetryWriterExactlyAgreesWithFrozenOracle(testCase)
            testCase.assumeTrue(testCase.spglibAvailable());
            testCase.assumeTrue( ...
                kssolv.analysis.matgenlab.test.support.PymatgenOracle.isAvailable());
            structure = kssolv.analysis.matgenlab.core.Structure( ...
                kssolv.analysis.matgenlab.core.Lattice.cubic(5.64), ...
                {"Na", "Cl"}, [0,0,0; .5,.5,.5]);
            request = struct( ...
                "module", "pymatgen.io.cif", ...
                "symbol", "CifWriter", ...
                "construct", struct("args", {{structure.as_dict()}}, ...
                    "kwargs", struct("symprec", 0.01)), ...
                "operations", {{struct( ...
                    "kind", "call", "name", "__str__")}});
            reference = ...
                kssolv.analysis.matgenlab.test.support.PymatgenOracle. ...
                execute(request);
            writer = kssolv.analysis.matgenlab.io.cif.CifWriter( ...
                structure, symprec = 0.01);
            testCase.verifyEqual(string(writer), string(reference.results));
        end
    end

    methods (Static, Access = private)
        function available = spglibAvailable()
            try
                value = kssolv.analysis.spglib.Spglib.getSpacegroupType(int32(1));
                available = value.number == 1;
            catch
                available = false;
            end
        end

        function cif = naclCif()
            cif = strjoin([
                "data_NaCl"
                "_chemical_formula_sum 'Na2 Cl2'"
                "_cell_length_a 5.64"
                "_cell_length_b 5.64"
                "_cell_length_c 5.64"
                "_cell_angle_alpha 90"
                "_cell_angle_beta 90"
                "_cell_angle_gamma 90"
                "loop_"
                "_symmetry_equiv_pos_as_xyz"
                "'x,y,z'"
                "'x+1/2,y+1/2,z+1/2'"
                "loop_"
                "_atom_site_type_symbol"
                "_atom_site_label"
                "_atom_site_fract_x"
                "_atom_site_fract_y"
                "_atom_site_fract_z"
                "_atom_site_occupancy"
                "Na Na1 0 0 0 1"
                "Cl Cl1 0.5 0 0 1"
                ], newline);
        end
    end
end
