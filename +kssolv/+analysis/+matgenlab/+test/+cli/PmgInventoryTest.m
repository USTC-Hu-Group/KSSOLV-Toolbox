classdef PmgInventoryTest < matlab.unittest.TestCase
    methods (Test)
        function frozenIncarDifference(testCase)
            [fixture, oracle] = testCase.fixtureAndOracle();
            args = struct("incars", {{fullfile(fixture, "INCAR"), ...
                fullfile(fixture, "INCAR_2")}}, "Print", false);
            [status, text] = ...
                kssolv.analysis.matgenlab.cli.pmg.diff_incar(args);
            body = "SAME PARAMS" + extractAfter(text, "SAME PARAMS");
            expected = string(oracle.diff_body);
            testCase.verifyEqual(status, oracle.diff_status);
            testCase.verifyEqual(testCase.normalizedLines(body), ...
                testCase.normalizedLines(expected));
        end

        function masterDispatchAndErrors(testCase)
            [~, oracle] = testCase.fixtureAndOracle();
            testCase.verifyError(@() ...
                kssolv.analysis.matgenlab.cli.pmg.main([]), ...
                "KSSOLV:Matgenlab:Pmg:CommandRequired");
            handler = struct("plot", @(args)args);
            result = kssolv.analysis.matgenlab.cli.pmg.main( ...
                ["plot", "-d", "vasprun.xml", "-o"], handler);
            testCase.verifyEqual(string(result.dos_file), "vasprun.xml");
            testCase.verifyTrue(result.orbital);
            testCase.verifyEqual(result.radius, 3);
            testCase.verifyEqual(string(oracle.empty_error), ...
                "Please specify a command.");
            testCase.verifyError(@() ...
                kssolv.analysis.matgenlab.cli.pmg.main(["unknown"]), ...
                "KSSOLV:Matgenlab:Pmg:UnknownCommand");
        end

        function nativeStructureView(testCase)
            fixture = testCase.fixtureAndOracle();
            args = struct("filename", {{fullfile(fixture, "POSCAR")}}, ...
                "exclude_bonding", {{"Li,Na"}}, "show", false);
            [status, viewer] = ...
                kssolv.analysis.matgenlab.cli.pmg.parse_view(args);
            cleanup = onCleanup(@()close(viewer.figure_handle));
            testCase.verifyEqual(status, 0);
            testCase.verifyEqual(viewer.excluded_bonding_elements, ...
                ["Li", "Na"]);
            testCase.verifyEqual(viewer.structure.num_sites, 24);
            clear cleanup
        end
    end
    methods (Static, Access = private)
        function varargout = fixtureAndOracle()
            fixture = fullfile(fileparts(mfilename("fullpath")), ...
                "+fixtures", "+pmg");
            root = fileparts(fileparts(fileparts(fileparts(fileparts( ...
                fileparts(mfilename("fullpath")))))));
            oracle = jsondecode(fileread(fullfile(root, "dev", ...
                "matgenlab", "oracles", "pmg_2026.5.4.json")));
            if nargout <= 1
                if nargout == 0, return; end
                varargout{1} = fixture;
            else
                varargout{1} = fixture;
                varargout{2} = oracle;
            end
        end

        function value = normalizedLines(text)
            lines = splitlines(strip(string(text)));
            value = regexprep(strip(lines), "\s+", " ");
        end
    end
end
