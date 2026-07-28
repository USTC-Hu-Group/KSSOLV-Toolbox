classdef PhononPlotterTest < matlab.unittest.TestCase
    methods (Test)
        function frequencyUnitsMatchFrozenOracle(testCase)
            testCase.assumeTrue( ...
                kssolv.analysis.matgenlab.test.support. ...
                PymatgenOracle.isAvailable());
            units=["thz","ev","mev","ha","cm-1","cm^-1"];
            for unit=units
                request=struct( ...
                    "module","pymatgen.phonon.plotter", ...
                    "symbol","freq_units", ...
                    "operations",{{struct( ...
                        "kind","call","args",{{unit}})}});
                reference=kssolv.analysis.matgenlab.test.support. ...
                    PymatgenOracle.execute(request);
                actual=kssolv.analysis.matgenlab.phonon.freq_units(unit);
                testCase.verifyEqual(actual.factor, ...
                    reference.results{1}{1},AbsTol=1e-15);
                testCase.verifyEqual(actual.label, ...
                    string(reference.results{1}{2}));
            end
            testCase.verifyError(@() ...
                kssolv.analysis.matgenlab.phonon.freq_units("bad"), ...
                "KSSOLV:Matgenlab:PhononPlotter:Units");
        end

        function dosAndThermoPlottersProduceDataAndFiles(testCase)
            import kssolv.analysis.matgenlab.phonon.PhononDos
            import kssolv.analysis.matgenlab.phonon.PhononDosPlotter
            import kssolv.analysis.matgenlab.phonon.ThermoPlotter
            frequencies=linspace(0.1,4,100);
            first=PhononDos(frequencies, ...
                exp(-((frequencies-1.5)/0.4).^2));
            second=PhononDos(frequencies, ...
                0.5*exp(-((frequencies-2.5)/0.5).^2));
            plotter=PhononDosPlotter(false,0.05);
            plotter.add_dos("first",first,"color","red");
            plotter.add_dos_dict( ...
                containers.Map({'second'},{second}));
            data=plotter.get_dos_dict();
            testCase.verifyEqual(sort(string(data.keys)), ...
                ["first","second"]);
            ax=plotter.get_plot([],[],false,"mev");
            testCase.verifyEqual(numel(ax.Children)>=3,true);
            close(ax.Parent);
            filename=string(tempname)+".pdf";
            cleanup=onCleanup(@()deleteIfPresent(filename));
            plotter.save_plot(filename,"pdf");
            testCase.verifyTrue(isfile(filename));
            thermo=ThermoPlotter(first);
            figures=[ ...
                thermo.plot_cv(10,300,8), ...
                thermo.plot_entropy(10,300,8), ...
                thermo.plot_internal_energy(10,300,8), ...
                thermo.plot_helmholtz_free_energy(10,300,8), ...
                thermo.plot_thermodynamic_properties(10,300,8)];
            testCase.verifyEqual(numel(figures),5);
            finalAxes=findobj(figures(end),"Type","axes");
            testCase.verifyEqual(numel(finalAxes.Children),4);
            close(figures);
            clear cleanup
        end

        function bandPlotterDataAndProjection(testCase)
            import kssolv.analysis.matgenlab.core.Lattice
            import kssolv.analysis.matgenlab.core.Structure
            import kssolv.analysis.matgenlab.phonon.PhononBandStructureSymmLine
            import kssolv.analysis.matgenlab.phonon.PhononBSPlotter
            qpoints=[0,0,0;0.25,0,0;0.5,0,0];
            frequencies=[1,2,3;2,3,4;3,4,5];
            labels=containers.Map( ...
                {'GAMMA','X'},{[0,0,0],[0.5,0,0]});
            structure=Structure(Lattice.cubic(4),{"Si"},[0,0,0]);
            eigen=complex(zeros(3,3,1,3));
            eigen(:)=1/sqrt(3);
            bands=PhononBandStructureSymmLine( ...
                qpoints,frequencies,Lattice.cubic(1), ...
                false,eigen,labels,false,structure);
            plotter=PhononBSPlotter(bands,"sample");
            data=plotter.bs_plot_data();
            testCase.verifyEqual(plotter.n_bands,3);
            testCase.verifyEqual(data.distances{1},[0,0.25,0.5]);
            testCase.verifyEqual(data.frequency{1},frequencies);
            ticks=plotter.get_ticks();
            testCase.verifyEqual(ticks.label,["Γ","X"]);
            ax=plotter.get_plot([], "cm-1");close(ax.Parent);
            ax=plotter.get_proj_plot("element");close(ax.Parent);
            plotter.show();close all force;
            plotter.show_proj("element");close all force;
            comparison=PhononBSPlotter(bands,"copy");
            ax=plotter.plot_compare(comparison);close(ax.Parent);
            ax=plotter.plot_brillouin();close(ax.Parent);
            filename=string(tempname)+".png";
            cleanup=onCleanup(@()deleteIfPresent(filename));
            plotter.save_plot(filename);
            testCase.verifyTrue(isfile(filename));
            clear cleanup
        end

        function gruneisenPlottersCoverMeshAndBands(testCase)
            import kssolv.analysis.matgenlab.core.Lattice
            import kssolv.analysis.matgenlab.core.Structure
            import kssolv.analysis.matgenlab.phonon.GruneisenParameter
            import kssolv.analysis.matgenlab.phonon.GruneisenPlotter
            import kssolv.analysis.matgenlab.phonon.GruneisenPhononBandStructureSymmLine
            import kssolv.analysis.matgenlab.phonon.GruneisenPhononBSPlotter
            qpoints=[0,0,0;0.25,0,0;0.5,0,0];
            frequencies=[1,2,3;2,3,4;3,4,5];
            gamma=[-2,-1,0;0.5,1,1.5;2,2.5,3];
            structure=Structure(Lattice.cubic(4),{"Si"},[0,0,0]);
            parameter=GruneisenParameter(qpoints,gamma, ...
                frequencies,[1,1,1],structure,[]);
            meshPlotter=GruneisenPlotter(parameter);
            ax=meshPlotter.get_plot("o",4,"mev");close(ax.Parent);
            meshPlotter.show("mev");close all force;
            meshFile=string(tempname)+".pdf";
            cleanup1=onCleanup(@()deleteIfPresent(meshFile));
            meshPlotter.save_plot(meshFile);
            testCase.verifyTrue(isfile(meshFile));
            labels=containers.Map( ...
                {'G','X'},{[0,0,0],[0.5,0,0]});
            bands=GruneisenPhononBandStructureSymmLine( ...
                qpoints,frequencies,gamma,Lattice.cubic(1),[],labels);
            plotter=GruneisenPhononBSPlotter(bands);
            data=plotter.bs_plot_data();
            testCase.verifyEqual(data.gruneisen{1},gamma);
            ax=plotter.get_plot_gs();close(ax.Parent);
            ax=plotter.get_plot_gs([],true,"units","mev");
            close(ax.Parent);
            plotter.show_gs();close all force;
            other=GruneisenPhononBSPlotter(bands);
            ax=plotter.plot_compare_gs(other);close(ax.Parent);
            filename=string(tempname)+".pdf";
            cleanup2=onCleanup(@()deleteIfPresent(filename));
            plotter.save_plot_gs(filename,"pdf");
            testCase.verifyTrue(isfile(filename));
            clear cleanup1 cleanup2
        end
    end
end

function deleteIfPresent(filename)
if isfile(filename),delete(filename);end
end
