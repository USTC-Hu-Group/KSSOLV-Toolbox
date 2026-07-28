classdef SpectroscopyTest < matlab.unittest.TestCase
    methods (Test)
        function dielectricOracle(testCase)
            value=kssolv.analysis.matgenlab.analysis. ...
                DielectricAnalysis([1,2],[4,5;6,7],[.2,.3;.4,.5]);
            testCase.verifyEqual(value.wavelengths, ...
                [1239.8419843320026,619.9209921660013], ...
                AbsTol=2e-12);
            testCase.verifyEqual(value.n, ...
                [2.000624512358598,2.237073078214844; ...
                2.4508486847772915,2.6474359693682015], ...
                AbsTol=5e-15);
            testCase.verifyEqual(value.R(1,1), ...
                0.11145019411248873,AbsTol=5e-15);
        end

        function officialXASFixtures(testCase)
            root=fixtureRoot(testCase);
            xanes=readXAS(fullfile(root,"LiCoO2_k_xanes.json"));
            exafs=readXAS(fullfile(root,"LiCoO2_k_exafs.json"));
            testCase.verifyEqual(xanes.e0,7728.565,AbsTol=1e-12);
            testCase.verifyEqual(xanes.get_interpolated_value(7720.422), ...
                0.27430232238806,AbsTol=2e-13);
            stitched=xanes.stitch(exafs);
            testCase.verifyEqual(numel(stitched.x),500);
            testCase.verifyEqual(min(stitched.x),7713.228,AbsTol=1e-9);
            testCase.verifyEqual(stitched.e0,7728.56689178109, ...
                AbsTol=3e-9);
        end

        function officialL23AndSiteWeighting(testCase)
            root=fixtureRoot(testCase);
            l2=readXAS(fullfile(root,"ZnO_l2_xanes.json"));
            l3=readXAS(fullfile(root,"ZnO_l3_xanes.json"));
            stitched=l2.stitch(l3,100,"L23");
            testCase.verifyEqual(stitched.edge,"L23");
            testCase.verifyEqual(numel(stitched.x),100);
            site1=readXAS(fullfile(root,"site1_k_xanes.json"));
            site2=readXAS(fullfile(root,"site2_k_xanes.json"));
            weighted=kssolv.analysis.matgenlab.analysis. ...
                site_weighted_spectrum({site1,site2});
            testCase.verifyEqual(numel(weighted.x),500);
            testCase.verifyEqual(weighted.y(1), ...
                0.028463941623578896,AbsTol=5e-15);
            testCase.verifyEqual(site1.absorbing_index,9);
            testCase.verifyEqual(site2.absorbing_index,13);
        end
    end
end

function root=fixtureRoot(testCase)
root="/tmp/matgenlab-plan.tMNeV8/pymatgen-2026.5.4/" + ...
    "test-files/analysis/spectrum_test";
testCase.assumeTrue(isfolder(root), ...
    "Frozen pymatgen XAS fixtures are unavailable.");
end

function value=readXAS(path)
value=kssolv.analysis.matgenlab.analysis.XAS. ...
    from_dict(jsondecode(fileread(path)));
end
