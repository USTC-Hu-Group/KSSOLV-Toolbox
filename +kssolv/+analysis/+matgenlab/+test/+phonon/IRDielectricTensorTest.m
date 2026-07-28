classdef IRDielectricTensorTest < matlab.unittest.TestCase
    methods (Test)
        function spectraMatchFrozenOracle(testCase)
            testCase.assumeTrue( ...
                kssolv.analysis.matgenlab.test.support. ...
                PymatgenOracle.isAvailable());
            import kssolv.analysis.matgenlab.core.Lattice
            import kssolv.analysis.matgenlab.core.Structure
            import kssolv.analysis.matgenlab.phonon.IRDielectricTensor
            structure=Structure(Lattice.cubic(4),{"Si"},[0,0,0]);
            frequencies=[0.01,0.02,0.03,1.2,2.3,3.1];
            oscillator=zeros(6,3,3);
            for index=1:6
                oscillator(index,:,:)= ...
                    diag([index,index+1,index+2])*0.01;
            end
            epsilon=diag([10,11,12]);
            tensor=IRDielectricTensor( ...
                oscillator,frequencies,epsilon,structure);
            request=struct( ...
                "module","pymatgen.phonon.ir_spectra", ...
                "symbol","IRDielectricTensor", ...
                "construct",struct("args",{{oscillator,frequencies, ...
                    epsilon,structure.as_dict()}}), ...
                "operations",{{ ...
                struct("kind","get","name","max_phfreq"), ...
                struct("kind","get","name","nph_freqs"), ...
                struct("kind","call","name","get_ir_spectra", ...
                    "args",{{0.002,0,4,101}})}});
            reference=kssolv.analysis.matgenlab.test.support. ...
                PymatgenOracle.execute(request);
            testCase.verifyEqual(tensor.max_phfreq,reference.results{1});
            testCase.verifyEqual(tensor.nph_freqs,reference.results{2});
            [grid,actual]=tensor.get_ir_spectra(0.002,0,4,101);
            expected=reference.results{3};
            testCase.verifyEqual(grid,expected{1},AbsTol=1e-15);
            complexData=expected{2}.matgenlab_complex;
            testCase.verifyEqual(real(actual),complexData.real,AbsTol=2e-14);
            testCase.verifyEqual(imag(actual),complexData.imag,AbsTol=2e-14);
            realSpectrum=tensor.get_spectrum("xx","re",0.002,0,4,101);
            testCase.verifyEqual(realSpectrum.x,grid*1000);
            testCase.verifyEqual(realSpectrum.y,squeeze(real(actual(:,1,1))));
        end

        function serializationAndPlotter(testCase)
            import kssolv.analysis.matgenlab.core.Lattice
            import kssolv.analysis.matgenlab.core.Structure
            import kssolv.analysis.matgenlab.phonon.IRDielectricTensor
            structure=Structure(Lattice.cubic(4),{"Na"},[0,0,0]);
            tensor=IRDielectricTensor(zeros(4,3,3), ...
                [0,0,0,1],eye(3),structure);
            restored=IRDielectricTensor.from_dict(tensor.as_dict());
            testCase.verifyEqual(restored.ph_freqs_gamma, ...
                tensor.ph_freqs_gamma);
            plotter=tensor.get_plotter({"xx","yz"},"reim", ...
                0.001,0,2,20);
            testCase.verifyEqual(numel(plotter.spectra.keys),4);
            ax=tensor.plot({"xx"},"reim",true,[],[], ...
                0.001,0,2,20);
            testCase.verifyGreaterThanOrEqual(numel(ax.Children),3);
            close(ax.Parent);
            filename=string(tempname)+".json";
            cleanup=onCleanup(@()deleteIfPresent(filename));
            tensor.write_json(filename);
            testCase.verifyTrue(isfile(filename));
            wire=jsondecode(fileread(filename));
            testCase.verifyEqual(wire.x_class,'IRDielectricTensor');
            clear cleanup
        end
    end
end

function deleteIfPresent(filename)
if isfile(filename),delete(filename);end
end
