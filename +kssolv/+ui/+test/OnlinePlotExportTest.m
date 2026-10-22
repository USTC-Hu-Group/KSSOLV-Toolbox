classdef OnlinePlotExportTest < matlab.unittest.TestCase
    methods (Test)
        function dualAxisExportRetainsDataAndRemainsUsable(testCase)
            folder = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
            fig = uifigure('Visible','off'); testCase.addTeardown(@()delete(fig));
            ax = uiaxes(fig);
            yyaxis(ax,'left'); energy = plot(ax,1:4,[-30.7,-30.75,-30.76,-30.76],'-o');
            ylabel(ax,'Energy (Ha)');
            yyaxis(ax,'right'); errors = semilogy(ax,1:4,[1,.1,.01,.001],'--s');
            ylabel(ax,'Error'); xlabel(ax,'Iterations'); title(ax,'Energy Convergence');
            before = {energy.XData,energy.YData,errors.YData,ax.XLim};
            for extension = [".png",".jpg",".tif",".pdf",".svg"]
                path = fullfile(folder,"EnergyConvergence"+extension);
                kssolv.ui.browser.OnlinePlotExport.write(ax,path,150);
                info = dir(path); testCase.verifyGreaterThan(info.bytes,100);
                testCase.verifyEqual({energy.XData,energy.YData,errors.YData,ax.XLim},before);
            end
            pixels = imread(fullfile(folder,'EnergyConvergence.png'));
            testCase.verifyGreaterThan(std(double(pixels(:))),10,'Export must contain plot pixels.');
            testCase.verifyTrue(contains(fileread(fullfile(folder,'EnergyConvergence.svg')),'<svg'));
            errors.YData = [.5,.05,.005,.0005]; drawnow;
            kssolv.ui.browser.OnlinePlotExport.write(ax,fullfile(folder,'after.png'),150);
            testCase.verifyEqual(errors.YData,[.5,.05,.005,.0005]);
        end

        function invalidFormatCannotEnterTheNativeFileDialog(testCase)
            fig = uifigure('Visible','off'); testCase.addTeardown(@()delete(fig));
            ax = uiaxes(fig); plot(ax,1:3);
            testCase.verifyError(@()kssolv.ui.browser.OnlinePlotExport.write( ...
                ax, string(tempname)+'.fig',150),'KSSOLV:Online:PlotFormat');
        end
    end
end
