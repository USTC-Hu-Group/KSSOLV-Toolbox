classdef SpectrumPlotterInventoryTest < matlab.unittest.TestCase
    % Frozen pymatgen.vis.plotters SpectrumPlotter behavior and inventory.

    methods (Test)
        function shiftedAndStackedRendering(testCase)
            import kssolv.analysis.matgenlab.core.Spectrum
            import kssolv.analysis.matgenlab.vis.SpectrumPlotter
            first=Spectrum([0,1],[1,2]);
            second=Spectrum([0,1],[2,4]);
            plotter=SpectrumPlotter(3,.2,false);
            plotter.add_spectrum("first",first,"k");
            plotter.add_spectra(containers.Map( ...
                {'second'},{second}),@(key)key);
            ax=plotter.get_plot();
            testCase.verifyEqual(numel(ax.Children),2);
            line=findobj(ax,"DisplayName","second");
            testCase.verifyEqual(line.YData,[2.2,4.2],AbsTol=1e-14);
            close(ax.Parent);

            stacked=SpectrumPlotter(0,.2,true);
            stacked.add_spectrum("first",first,"b");
            stacked.add_spectrum("second",second,"r");
            ax=stacked.get_plot();
            testCase.verifyEqual(numel(findobj(ax,"Type","patch")),2);
            testCase.verifyEmpty(findobj(ax,"Type","line"));
            close(ax.Parent);
        end

        function saveShowAndFrozenInventory(testCase)
            import kssolv.analysis.matgenlab.core.Spectrum
            import kssolv.analysis.matgenlab.vis.SpectrumPlotter
            plotter=SpectrumPlotter();
            plotter.add_spectrum("sample",Spectrum([0,1],[1,2]));
            filename=string(tempname)+".png";
            cleanup=onCleanup(@()deleteIfPresent(filename));
            plotter.save_plot(filename,"png");
            testCase.verifyTrue(isfile(filename));
            plotter.show();
            close all force;

            inventory=fullfile(KSSOLV_Toolbox.RootDirectory, ...
                "dev","matgenlab","inventory","api.csv");
            options=detectImportOptions(inventory,"TextType","string");
            rows=readtable(inventory,options);
            rows=rows(rows.module=="pymatgen.vis.plotters",:);
            testCase.verifyEqual(height(rows),6);
            available=string(methods( ...
                "kssolv.analysis.matgenlab.vis.SpectrumPlotter"));
            for index=1:height(rows)
                if rows.kind(index)=="class",continue,end
                qualified=split(rows.qualname(index),".");
                testCase.verifyTrue(any(available==qualified(2)));
            end
            clear cleanup
        end
    end
end

function deleteIfPresent(filename)
if isfile(filename),delete(filename);end
end
