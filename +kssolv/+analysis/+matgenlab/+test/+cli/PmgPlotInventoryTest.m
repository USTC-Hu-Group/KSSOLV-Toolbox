classdef PmgPlotInventoryTest < matlab.unittest.TestCase
    properties
        Fixture
        Oracle
    end

    methods (TestMethodSetup)
        function prepare(testCase)
            testCase.Fixture = fullfile(pwd, "+kssolv", "+analysis", ...
                "+matgenlab", "+test", "+cli", "+fixtures", "+pmg_plot");
            testCase.Oracle = jsondecode(fileread(fullfile(pwd, "dev", ...
                "matgenlab", "oracles", "pmg_plot_2026.5.4.json")));
        end
    end

    methods (TestMethodTeardown)
        function closeFigures(~)
            close(findall(groot, "Type", "figure"));
        end
    end

    methods (Test)
        function xrdPlotMatchesFrozenPattern(testCase)
            args = struct("xrd_structure_file", ...
                fullfile(testCase.Fixture, "POSCAR_Fe3O4"));
            ax = kssolv.analysis.matgenlab.cli.pmg_plot.get_xrd_plot(args);
            testCase.verifyTrue(isgraphics(ax, "axes"));
            testCase.verifyEqual(string(ax.Parent.Visible), "off");
            pattern = ax.UserData.pattern;
            testCase.verifyEqual(numel(pattern.x), ...
                double(testCase.Oracle.xrd.count));
            testCase.verifyEqual(pattern.x(:), ...
                double(testCase.Oracle.xrd.x(:)), "AbsTol", 2e-8);
            testCase.verifyEqual(pattern.y(:), ...
                double(testCase.Oracle.xrd.y(:)), "AbsTol", 2e-7);
            testCase.verifyEqual(string(ax.XLabel.String), ...
                "2\theta (degrees)");
        end

        function dosModesMatchFrozenOracle(testCase)
            filename = fullfile(testCase.Fixture, ...
                "vasprun_Li_no_projected.xml.gz");
            args = struct("dos_file", filename, "site", false, ...
                "element", [], "orbital", false);
            ax = kssolv.analysis.matgenlab.cli.pmg_plot.get_dos_plot(args);
            dos = ax.UserData.dos("Total");
            testCase.verifyEqual(numel(dos.energies), ...
                double(testCase.Oracle.dos.count));
            testCase.verifyEqual(dos.energies(:), ...
                double(testCase.Oracle.dos.energies(:)), "AbsTol", 1e-10);
            testCase.verifyEqual(dos.efermi, ...
                double(testCase.Oracle.dos.efermi), "AbsTol", 1e-10);
            testCase.verifyEqual(dos.densities.up(:), ...
                double(testCase.Oracle.dos.densities.up(:)), ...
                "AbsTol", 1e-10);
            testCase.verifyEqual(dos.densities.down(:), ...
                double(testCase.Oracle.dos.densities.down(:)), ...
                "AbsTol", 1e-10);
            close(ax.Parent);

            projected = fullfile(testCase.Fixture, "vasprun.Al.xml.gz");
            siteArgs = struct("dos_file", projected, "site", true, ...
                "element", [], "orbital", false);
            ax = kssolv.analysis.matgenlab.cli.pmg_plot.get_dos_plot( ...
                siteArgs);
            testCase.verifyEqual(sort(ax.UserData.labels), ...
                sort(["Total", "Site 0 Al"]));
            close(ax.Parent);

            elementArgs = siteArgs;
            elementArgs.site = false;
            elementArgs.element = "Al";
            ax = kssolv.analysis.matgenlab.cli.pmg_plot.get_dos_plot( ...
                elementArgs);
            testCase.verifyEqual(sort(ax.UserData.labels), ...
                sort(reshape(string(testCase.Oracle.projected_dos. ...
                element_labels), 1, [])));
            close(ax.Parent);

            orbitalArgs = siteArgs;
            orbitalArgs.site = false;
            orbitalArgs.orbital = true;
            ax = kssolv.analysis.matgenlab.cli.pmg_plot.get_dos_plot( ...
                orbitalArgs);
            testCase.verifyEqual(sort(ax.UserData.labels), ...
                sort(reshape(string(testCase.Oracle.projected_dos. ...
                orbital_labels), 1, [])));
        end

        function integratedChargeMatchesFrozenOracle(testCase)
            args = struct("chgcar_file", fullfile(testCase.Fixture, ...
                "CHGCAR.Fe3O4.gz"), "inds", [], "radius", 3);
            ax = kssolv.analysis.matgenlab.cli.pmg_plot. ...
                get_chgint_plot(args);
            expectedIndices = reshape( ...
                double(testCase.Oracle.chgint.indices), 1, []);
            testCase.verifyEqual(ax.UserData.atom_indices, expectedIndices);
            testCase.verifyEqual(ax.UserData.labels, ...
                reshape(string(testCase.Oracle.chgint.labels), 1, []));
            for index = 1:numel(expectedIndices)
                expected = squeeze( ...
                    double(testCase.Oracle.chgint.curves(index, :, :)));
                testCase.verifyEqual(ax.UserData.curves{index}, expected, ...
                    "AbsTol", 2e-10);
            end
            testCase.verifyEqual(string(ax.XLabel.String), "Radius (A)");
            testCase.verifyEqual(string(ax.YLabel.String), ...
                "Integrated charge (e)");
        end

        function masterDispatcherExportsHeadlessly(testCase)
            output = string(tempname) + ".png";
            cleanup = onCleanup(@() deleteIfPresent(output));
            args = struct("chgcar_file", "", "xrd_structure_file", ...
                fullfile(testCase.Fixture, "POSCAR_Fe3O4"), ...
                "dos_file", "", "out_file", output);
            ax = kssolv.analysis.matgenlab.cli.pmg_plot.plot(args);
            testCase.verifyTrue(isgraphics(ax, "axes"));
            testCase.verifyTrue(isfile(output));
            info = dir(output);
            testCase.verifyGreaterThan(info.bytes, 1024);
            testCase.verifyEmpty( ...
                kssolv.analysis.matgenlab.cli.pmg_plot.plot(struct()));
            clear cleanup
        end

    end
end

function deleteIfPresent(filename)
if isfile(filename), delete(filename); end
end
