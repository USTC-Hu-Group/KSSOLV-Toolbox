classdef Wannier90InventoryTest < matlab.unittest.TestCase
    properties
        fixture
        oracle
    end

    methods (TestMethodSetup)
        function prepare(testCase)
            testCase.fixture = fullfile(pwd, "+kssolv", "+analysis", ...
                "+matgenlab", "+test", "+io", "+fixtures", "+wannier90");
            testCase.oracle = jsondecode(fileread(fullfile(pwd, "dev", ...
                "matgenlab", "oracles", "wannier90_2026.7.24.json")));
        end
    end

    methods (Test)
        function regularOfficialFilesMatchFrozenOracle(testCase)
            testCase.verifyOfficialFile("UNK.std", "UNK_std");
            testCase.verifyOfficialFile("UNK.N2.std", "UNK_N2_std");
        end

        function noncollinearOfficialFilesMatchFrozenOracle(testCase)
            testCase.verifyOfficialFile("UNK.ncl", "UNK_ncl");
            testCase.verifyOfficialFile("UNK.H2.ncl", "UNK_H2_ncl");
        end

        function officialFilesRoundTrip(testCase)
            names = ["UNK.std", "UNK.ncl", "UNK.N2.std", "UNK.H2.ncl"];
            for name = names
                original = kssolv.analysis.matgenlab.io.wannier90.Unk. ...
                    from_file(fullfile(testCase.fixture, name));
                output = string(tempname);
                cleanup = onCleanup(@() deleteIfExists(output));
                original.write_file(output);
                restored = kssolv.analysis.matgenlab.io.wannier90.Unk. ...
                    from_file(output);
                testCase.verifyTrue(original == restored, name);
                clear cleanup
            end
        end

        function constructionAndMutationMatchUpstream(testCase)
            regular = reshape(complex(1:48, 49:96), [2, 2, 3, 4]);
            unk = kssolv.analysis.matgenlab.io.wannier90.Unk(7, regular);
            testCase.verifyEqual(unk.ik, 7);
            testCase.verifyEqual(unk.nbnd, 2);
            testCase.verifyEqual(unk.ng, [2, 3, 4]);
            testCase.verifyFalse(unk.is_noncollinear);
            testCase.verifyEqual(unk.data, regular);
            spinor = reshape(complex(1:96, 97:192), [2, 2, 2, 3, 4]);
            unk.data = spinor;
            testCase.verifyTrue(unk.is_noncollinear);
            testCase.verifyEqual(unk.data, spinor);
            testCase.verifyNotEmpty(char(unk));
            testCase.verifyTrue(unk == ...
                kssolv.analysis.matgenlab.io.wannier90.Unk(7, spinor));
            testCase.verifyTrue(unk ~= "not an Unk");
        end

        function invalidShapesAreRejected(testCase)
            testCase.verifyError(@() ...
                kssolv.analysis.matgenlab.io.wannier90.Unk(1, ...
                zeros(2, 2, 2)), ...
                "KSSOLV:Matgenlab:Wannier90:InvalidDataShape");
            testCase.verifyError(@() ...
                kssolv.analysis.matgenlab.io.wannier90.Unk(1, ...
                zeros(2, 3, 2, 2, 2)), ...
                "KSSOLV:Matgenlab:Wannier90:InvalidSpinorShape");
        end
    end

    methods
        function verifyOfficialFile(testCase, filename, field)
            expected = testCase.oracle.(field);
            unk = kssolv.analysis.matgenlab.io.wannier90.Unk.from_file( ...
                fullfile(testCase.fixture, filename));
            testCase.verifyEqual(unk.ik, expected.ik);
            testCase.verifyEqual(unk.nbnd, expected.nbnd);
            testCase.verifyEqual(unk.ng, reshape(expected.ng, 1, []));
            testCase.verifyEqual(unk.is_noncollinear, ...
                expected.is_noncollinear);
            testCase.verifyEqual(size(unk.data), ...
                reshape(expected.shape, 1, []));
            for index = 1:numel(expected.samples)
                sample = expected.samples(index);
                location = num2cell(reshape(sample.index, 1, []) + 1);
                value = unk.data(location{:});
                testCase.verifyEqual(real(value), sample.real, ...
                    AbsTol = 1e-13);
                testCase.verifyEqual(imag(value), sample.imag, ...
                    AbsTol = 1e-13);
            end
        end
    end
end

function deleteIfExists(filename)
if isfile(filename), delete(filename); end
end
