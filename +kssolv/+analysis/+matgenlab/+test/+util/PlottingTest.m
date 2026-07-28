classdef PlottingTest < matlab.unittest.TestCase
    methods (TestMethodTeardown)
        function closeFigures(~)
            close all force
        end
    end
    methods (Test)
        function formulaFormattingMatchesOfficial(testCase)
            inputs=["Li2O","Fe","LiFePO4","H2O","Li3V2(PO4)3"];
            expected=["$Li_{2}O$","$Fe$","$LiFePO_{4}$", ...
                "$H_{2}O$","$Li_{3}V_{2}(PO_{4})_{3}$"];
            for index=1:numel(inputs)
                testCase.verifyEqual( ...
                    kssolv.analysis.matgenlab.util. ...
                    format_formula(inputs(index)),expected(index));
            end
        end

        function prettyPlotSizingAndPolyfit(testCase)
            axesHandle=kssolv.analysis.matgenlab.util.pretty_plot(10);
            testCase.verifyClass(axesHandle, ...
                "matlab.graphics.axis.Axes");
            figureHandle=axesHandle.Parent;
            testCase.verifyEqual(figureHandle.Position(3:4),[10,6], ...
                AbsTol=1e-12);
            existing=axes(figure("Visible","off"));
            output=kssolv.analysis.matgenlab.util. ...
                pretty_plot(6,4,existing);
            testCase.verifyTrue(output==existing);
            testCase.verifyEqual(existing.Parent.Position(3:4),[6,4], ...
                AbsTol=1e-12);

            x=1:4;y=2*x+1;
            fitted=kssolv.analysis.matgenlab.util. ...
                pretty_polyfit_plot(x,y,1,"xlabel","x","ylabel","y");
            testCase.verifyEqual(fitted.XLabel.String,'x');
            testCase.verifyEqual(fitted.YLabel.String,'y');
            testCase.verifyEqual(numel(fitted.Children),2);
        end

        function twoAxisAndAxesHelpers(testCase)
            axesHandle=kssolv.analysis.matgenlab.util. ...
                pretty_plot_two_axis(0:3,1:4,4:-1:1, ...
                "xlabel","x","y1label","y1","y2label","y2", ...
                "dpi",[]);
            testCase.verifyEqual(axesHandle.XLabel.String,'x');
            yyaxis(axesHandle,"left");
            testCase.verifyEqual(axesHandle.YLabel.String,'y1');
            yyaxis(axesHandle,"right");
            testCase.verifyEqual(axesHandle.YLabel.String,'y2');

            [created,figureHandle]= ...
                kssolv.analysis.matgenlab.util.get_ax_fig();
            testCase.verifyTrue(created.Parent==figureHandle);
            [same,sameFigure]= ...
                kssolv.analysis.matgenlab.util.get_ax_fig(created);
            testCase.verifyTrue(same==created);
            testCase.verifyTrue(sameFigure==figureHandle);
            [axes3d,figure3d]= ...
                kssolv.analysis.matgenlab.util.get_ax3d_fig();
            testCase.verifyTrue(axes3d.Parent==figure3d);
            testCase.verifyEqual(axes3d.View,[-37.5,30],AbsTol=1e-12);
            [array,arrayFigure,module]= ...
                kssolv.analysis.matgenlab.util. ...
                get_axarray_fig_plt([],2,2);
            testCase.verifySize(array,[2,2]);
            testCase.verifyTrue(all(arrayfun( ...
                @(value)value.Parent==arrayFigure,array),"all"));
            testCase.verifyEqual(module,"MATLAB graphics");
        end

        function periodicHeatmapAndVanArkelCreateLabeledAxes(testCase)
            data=struct("Te",.11083,"Au",.75756, ...
                "Th",1.24758,"Ni",-2.0354);
            heatmap=kssolv.analysis.matgenlab.util. ...
                periodic_table_heatmap(data,"cmap","plasma", ...
                "max_row",10,"cbar_label","Hello World", ...
                "cmap_range",[0,1],"blank_color","white", ...
                "value_format","%.4f","edge_color","black", ...
                "value_fontsize",12,"symbol_fontsize",18, ...
                "readable_fontcolor",true);
            testCase.verifyClass(heatmap,"matlab.graphics.axis.Axes");
            labels=findall(heatmap,"Type","text");
            testCase.verifyTrue(any(string({labels.String})=="Te"));
            triangle=kssolv.analysis.matgenlab.util. ...
                van_arkel_triangle({{"Fe","C"},{"Ni","F"}},true);
            testCase.verifyClass(triangle,"matlab.graphics.axis.Axes");
            testCase.verifyEqual(triangle.XLabel.String, ...
                '$\frac{\chi_{A}+\chi_{B}}{2}$');
            testCase.verifyEqual(triangle.YLabel.String, ...
                '$|\chi_{A}-\chi_{B}|$');
        end

        function figureDecoratorAppliesAndSavesOptions(testCase)
            wrapped=kssolv.analysis.matgenlab.util. ...
                add_fig_kwargs(@makeFigure);
            temporary=tempname+".png";
            cleanup=onCleanup(@()deleteIfPresent(temporary));
            figureHandle=wrapped("title","hello", ...
                "size_kwargs",struct("w",6,"h",4), ...
                "show",false,"ax_grid",true, ...
                "ax_annotate",true,"tight_layout",true, ...
                "savefig",temporary);
            testCase.verifyClass(figureHandle, ...
                "matlab.ui.Figure");
            testCase.verifyEqual(figureHandle.Position(3:4),[6,4], ...
                AbsTol=1e-12);
            testCase.verifyTrue(isfile(temporary));
            labels=findall(figureHandle,"-property","String");
            titleFound=false;
            for index=1:numel(labels)
                titleFound=titleFound|| ...
                    any(string(labels(index).String)=="hello");
            end
            testCase.verifyTrue(titleFound);
            clear cleanup
        end
    end
end

function figureHandle=makeFigure()
figureHandle=figure("Visible","off");
axesHandle=axes(figureHandle);
plot(axesHandle,[0,1],[0,1]);
end

function deleteIfPresent(path)
if isfile(path),delete(path);end
end
