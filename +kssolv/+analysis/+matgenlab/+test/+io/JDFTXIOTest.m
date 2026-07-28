classdef JDFTXIOTest < matlab.unittest.TestCase
    %JDFTXIOTEST Native MATLAB regression tests on frozen official fixtures.
    methods (Test)
        function outputUtilities(testCase)
            import kssolv.analysis.matgenlab.io.jdftx.*
            lines = {"header"; "*************** JDFTx one"; "a: 2.5"; ...
                "*************** JDFTx two"; "tail"};
            testCase.verifyEqual(get_start_lines(lines), [1, 3]);
            testCase.verifyEqual(find_key_first("JDFTx", lines), 1);
            testCase.verifyEqual(find_key("JDFTx", lines), 3);
            testCase.verifyEqual(find_all_key("JDFTx", lines), [1, 3]);
            testCase.verifyTrue(key_exists("tail", lines));
            testCase.verifyEqual(get_colon_val("x mu: -2.5 end", "mu:"), -2.5);
            testCase.verifyEqual(correct_geom_opt_type("ionic dynamics"), ...
                "IonicDynamics");
        end

        function genericTags(testCase)
            import kssolv.analysis.matgenlab.io.jdftx.*
            bool = BoolTag();
            testCase.verifyTrue(bool.read("flag", "yes"));
            testCase.verifyEqual(strtrim(bool.write("flag", false)), ...
                "flag no");
            integer = IntTag("lb", 0, "ub", 4);
            [valid, ~] = integer.validate_value_bounds("n", 4);
            testCase.verifyTrue(valid);
            [valid, ~] = integer.validate_value_bounds("n", 5);
            testCase.verifyFalse(valid);
            dump = get_dump_tag_container();
            parsed = dump.read("dump", "End State BandEigs");
            testCase.verifyTrue(parsed.End.State);
            testCase.verifyTrue(parsed.End.BandEigs);
        end

        function infileRoundTripAndStructure(testCase)
            import kssolv.analysis.matgenlab.io.jdftx.*
            path = fullfile(jdftxFixtureRoot(), "test_jdftx_in_files", ...
                "input-simple1.in");
            input = JDFTXInfile.from_file(path);
            testCase.verifyEqual(input.get("elec-n-bands"), 34);
            testCase.verifyEqual(input.get("elec-cutoff"), [30, 100]);
            testCase.verifyEqual(numel(input.get("ion")), 5);
            structure = input.structure;
            testCase.verifyEqual(structure.natoms, 5);
            testCase.verifyEqual(structure.structure.lattice(1, 1), ...
                5.29177210544, AbsTol=1e-10);
            restored = JDFTXInfile.from_str(string(input));
            testCase.verifyTrue(input.is_comparable_to(restored));
            mson = input.as_dict();
            testCase.verifyTrue(JDFTXInfile.from_dict(mson). ...
                is_comparable_to(input));
        end

        function outputFixtures(testCase)
            import kssolv.analysis.matgenlab.io.jdftx.*
            root = fullfile(jdftxFixtureRoot(), "test_jdftx_out_files");
            single = JDFTXOutfile.from_file( ...
                fullfile(root, "example_sp.out"));
            testCase.verifyEqual(numel(single.slices), 1);
            testCase.verifyEqual(single.nat, 16);
            testCase.verifyEqual(single.nspin, 1);
            testCase.verifyEqual(single.efermi, -5.7010303210091475, ...
                AbsTol=1e-9);
            testCase.verifyEqual(single.pwcut, 816.3415873794178, ...
                AbsTol=1e-8);
            testCase.verifyEqual(single.fftgrid, [54, 54, 224]);
            testCase.verifyEqual(single.geom_opt_type, "single point");
            testCase.verifyTrue(single.converged);
            lattice = JDFTXOutfile.from_file( ...
                fullfile(root, "example_latmin.out"));
            testCase.verifyEqual(numel(lattice.slices), 7);
            testCase.verifyEqual(lattice.geom_opt_type, "lattice");
            testCase.verifyTrue(lattice.is_metal);
            ionic = JDFTXOutfile.from_file( ...
                fullfile(root, "example_ionmin.out"));
            testCase.verifyEqual(ionic.nat, 41);
            testCase.verifyEqual(ionic.geom_opt_type, "ionic");
            testCase.verifyFalse(ionic.is_metal);
        end

        function bandProjectionAndEigenvalueFixtures(testCase)
            import kssolv.analysis.matgenlab.io.jdftx.*
            root = fullfile(jdftxFixtureRoot(), ...
                "test_jdftx_calc_dirs", "N2");
            output = JDFTXOutputs.from_calc_dir(root, ...
                store_vars = {"bandProjections", "eigenvals", "kpts", ...
                "bandstructure"});
            testCase.verifySize(output.bandProjections, [54, 15, 8]);
            testCase.verifyEqual(output.bandProjections(1), ...
                complex(single(-0.1331527), single(0.5655596)), ...
                AbsTol=1e-7);
            testCase.verifySize(output.eigenvals, [54, 15]);
            testCase.verifyEqual(output.eigenvals(1), ...
                -28.252696199119907, AbsTol=1e-9);
            testCase.verifySize(output.kpts, [54, 3]);
            testCase.verifyEqual(output.orb_label_list(1), "N#1(s)");
            testCase.verifyNotEmpty(output.bandstructure);
        end

        function dataModelsAndSerialization(testCase)
            import kssolv.analysis.matgenlab.io.jdftx.*
            lines = ["FillingsUpdate: mu: 0.5 nElectrons: 4", ...
                "ElecMinimize: Iter: 3 F: -2 |grad|_K: 1e-4 " + ...
                "alpha: 0.1 linmin: -0.2 t[s]: 4"];
            step = JElStep.from_lines_collect(lines, ...
                "ElecMinimize", "F");
            testCase.verifyEqual(step.nstep, 3);
            testCase.verifyEqual(step.e, -54.42277249196118, AbsTol=1e-12);
            testCase.verifyEqual(step.to_dict(), step.as_dict());
            structure = JOutStructure(eye(3), ["H"; "H"], ...
                [0, 0, 0; 0, 0, 1]);
            structure.charges = [-0.1; 0.1];
            testCase.verifyEqual(structure.charges, [-0.1; 0.1]);
            testCase.verifyEqual(structure.to_dict(), structure.as_dict());
        end

        function explicitRunnerBoundaryAndPlotting(testCase)
            import kssolv.analysis.matgenlab.io.jdftx.*
            testCase.verifyError(@() JDFTXRunner.run("/usr/bin/true"), ...
                "KSSOLV:Matgenlab:JDFTX:ExternalBoundary");
            result = JDFTXRunner.run("/usr/bin/true", ...
                allow_external = true);
            testCase.verifyEqual(result.status, 0);
            path = fullfile(jdftxFixtureRoot(), ...
                "test_jdftx_out_files", "example_sp.out");
            output = JDFTXOutfile.from_file(path);
            figure_value = figure("Visible", "off");
            cleanup = onCleanup(@() close(figure_value));
            handles = JDFTXPlotter.plot_scf(output, ...
                axes = axes(figure_value));
            testCase.verifyNotEmpty(handles);
        end
    end
end

function root = jdftxFixtureRoot()
root = fullfile(KSSOLV_Toolbox.RootDirectory, "+kssolv", "+analysis", ...
    "+matgenlab", "+test", "+io", "+fixtures", "+jdftx");
end
