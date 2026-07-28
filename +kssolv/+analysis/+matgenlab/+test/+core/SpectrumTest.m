classdef SpectrumTest < matlab.unittest.TestCase
    % Port of pymatgen-core v2026.7.24 tests/core/test_spectrum.py.

    methods (Test)
        function constructorAndOperators(testCase)
            x = (0:0.1:9.9).';
            first = kssolv.analysis.matgenlab.core.Spectrum(x,sin(x));
            second = kssolv.analysis.matgenlab.core.Spectrum(x,cos(x));
            combined = 3*first + second;
            testCase.verifyEqual(combined.y,3*sin(x)+cos(x),AbsTol=1e-14);
            difference = first-second;
            quotient = first/3;
            testCase.verifyEqual(difference.y,sin(x)-cos(x), ...
                AbsTol=1e-14);
            testCase.verifyEqual(quotient.y,sin(x)/3,AbsTol=1e-14);
            testCase.verifyEqual(first.get_interpolated_value(0.05), ...
                (first.y(1)+first.y(2))/2,AbsTol=1e-14);
            bad = kssolv.analysis.matgenlab.core.Spectrum(x+1,sin(x));
            testCase.verifyError(@() first+bad, ...
                "KSSOLV:Matgenlab:Spectrum:IncompatibleXAxis");
        end

        function multiChannelAndNormalize(testCase)
            x = (0:0.1:9.9).';
            spectrum = kssolv.analysis.matgenlab.core.Spectrum( ...
                x,[sin(x)+2,cos(x)+2]);
            spectrum.normalize("sum");
            testCase.verifyEqual(sum(spectrum.y,1),[1,1],AbsTol=1e-14);
            spectrum.normalize("max",100);
            testCase.verifyEqual(max(spectrum.y,[],1),[100,100], ...
                AbsTol=1e-12);
            expected = (spectrum.y(1,:)+spectrum.y(2,:))/2;
            testCase.verifyEqual(spectrum.get_interpolated_value(0.05), ...
                expected,AbsTol=1e-12);
            testCase.verifyError(@() spectrum.normalize("invalid"), ...
                "KSSOLV:Matgenlab:Spectrum:InvalidNormalization");
        end

        function gaussianAndLorentzianSmearing(testCase)
            x = linspace(-10,10,100).';
            y = zeros(100,1);
            y([26,51,76]) = 1;
            gaussian = kssolv.analysis.matgenlab.core.Spectrum(x,y);
            gaussian.smear(0.3);
            testCase.verifyNotEqual(gaussian.y,y);
            testCase.verifyEqual(sum(gaussian.y),sum(y),AbsTol=1e-13);
            callable = kssolv.analysis.matgenlab.core.Spectrum(x,y);
            callable.smear(0,@(points) ...
                exp(-0.5*(points/0.3).^2)/(sqrt(2*pi)*0.3));
            testCase.verifyEqual(callable.y,gaussian.y,AbsTol=1e-14);
            lorentz = kssolv.analysis.matgenlab.core.Spectrum(x,y);
            lorentz.smear(0.3,"lorentzian");
            testCase.verifyEqual(sum(lorentz.y),sum(y),AbsTol=1e-13);
            testCase.verifyNotEqual(lorentz.y,y);
            testCase.verifyEqual( ...
                kssolv.analysis.matgenlab.core.lorentzian(0,0,1), ...
                2/pi,AbsTol=1e-15);
        end

        function copyAndSerialization(testCase)
            original = kssolv.analysis.matgenlab.core.Spectrum( ...
                (0:4).',(1:5).');
            copied = original.copy();
            copied.y(1) = 99;
            testCase.verifyEqual(original.y(1),1);
            roundTrip = ...
                kssolv.analysis.matgenlab.core.Spectrum. ...
                from_dict(original.as_dict());
            testCase.verifyEqual(roundTrip.x,original.x);
            testCase.verifyEqual(roundTrip.y,original.y);
            testCase.verifyTrue(startsWith(string(original),"Spectrum"));
        end
    end
end
