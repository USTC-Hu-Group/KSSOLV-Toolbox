classdef BatteryPlotterTest < matlab.unittest.TestCase
    methods (Test)
        function plotDataAndLabels(testCase)
            lithium=kssolv.analysis.matgenlab.core.ComputedEntry( ...
                "Li",-1.90753119);
            insertion=kssolv.analysis.matgenlab.apps.battery. ...
                InsertionElectrode.from_entries( ...
                loadFixture("LiTiO2_batt.json"),lithium);
            conversion=kssolv.analysis.matgenlab.apps.battery. ...
                ConversionElectrode.from_composition_and_entries( ...
                "FeF3",loadFixture("FeF3_batt.json"),"Li");
            plotter=kssolv.analysis.matgenlab.apps.battery. ...
                VoltageProfilePlotter("frac_x");
            plotter.add_electrode(insertion,"LTO insertion");
            plotter.add_electrode(conversion,"FeF3 conversion");
            [x,y]=plotter.get_plot_data(insertion);
            testCase.verifyEqual(numel(x),2*insertion.num_steps+1);
            testCase.verifyEqual(y(end),0);
            semantic=plotter.get_plotly_figure();
            testCase.verifyEqual(semantic.layout.xaxis.title, ...
                "Atomic Fraction of Li");
            testCase.verifyEqual(numel(semantic.data),2);
            ax=plotter.get_plot();
            testCase.verifyClass(ax,"matlab.graphics.axis.Axes");
            testCase.verifyEqual(string(ax.XLabel.String), ...
                "Atomic Fraction of Li");
            close(ancestor(ax,"figure"));
            filename=string(tempname)+".png";
            cleanup=onCleanup(@()deleteIfPresent(filename));
            plotter.save(filename,5,4);
            testCase.verifyTrue(isfile(filename));
            plotter.show(5,4);
            close all force;
            clear cleanup
        end

        function mixedFrameworkLabel(testCase)
            lithium=kssolv.analysis.matgenlab.core.ComputedEntry( ...
                "Li",-1.90753119);
            insertion=kssolv.analysis.matgenlab.apps.battery. ...
                InsertionElectrode.from_entries( ...
                loadFixture("LiTiO2_batt.json"),lithium);
            conversion=kssolv.analysis.matgenlab.apps.battery. ...
                ConversionElectrode.from_composition_and_entries( ...
                "FeF3",loadFixture("FeF3_batt.json"),"Li");
            plotter=kssolv.analysis.matgenlab.apps.battery. ...
                VoltageProfilePlotter("x_form");
            plotter.add_electrode(conversion,"conversion");
            semantic=plotter.get_plotly_figure();
            testCase.verifyEqual(semantic.layout.xaxis.title, ...
                "x in Li<sub>x</sub>FeF3");
            plotter.add_electrode(insertion,"insertion");
            semantic=plotter.get_plotly_figure();
            testCase.verifyEqual(semantic.layout.xaxis.title, ...
                "x Work Ion per Host F.U.");
        end
    end
end
function value=loadFixture(name)
path=fullfile(fileparts(mfilename("fullpath")),"+fixtures",name);
value=kssolv.analysis.matgenlab.util.decode(fileread(path));
end
function deleteIfPresent(filename)
if isfile(filename),delete(filename);end
end
