classdef CodInventoryTest < matlab.unittest.TestCase
    properties
        oracle
    end

    methods (TestMethodSetup)
        function prepare(testCase)
            testCase.oracle = jsondecode(fileread(fullfile(pwd, "dev", ...
                "matgenlab", "oracles", "cod_2026.5.4.json")));
        end
    end

    methods (Test)
        function formulaQueryUsesHillFormulaAndReturnsIds(testCase)
            client = kssolv.analysis.matgenlab.ext.cod.COD(12, @transport);
            ids = client.get_cod_ids("Li2O");
            testCase.verifyEqual(ids, reshape(testCase.oracle.ids, 1, []));
        end

        function structureByIdParsesCif(testCase)
            client = kssolv.analysis.matgenlab.ext.cod.COD(12, @transport);
            structure = client.get_structure_by_id( ...
                testCase.oracle.cod_id);
            testCase.verifyEqual(structure.formula, ...
                string(testCase.oracle.parsed_formula));
        end

        function formulaResultsPreserveMetadata(testCase)
            client = kssolv.analysis.matgenlab.ext.cod.COD(12, @transport);
            results = client.get_structure_by_formula("Li2O");
            testCase.verifyEqual(numel(results), 2);
            testCase.verifyEqual(results{1}.cod_id, testCase.oracle.ids(1));
            testCase.verifyEqual(string(results{1}.sg), ...
                string(testCase.oracle.space_group));
            testCase.verifyEqual(results{1}.structure.formula, "Be1");
        end

        function explicitTransportAndHttpErrorsAreStable(testCase)
            client = kssolv.analysis.matgenlab.ext.cod.COD();
            testCase.verifyError(@() client.get_cod_ids("Li2O"), ...
                "KSSOLV:Matgenlab:COD:TransportRequired");
            failed = kssolv.analysis.matgenlab.ext.cod.COD(60, ...
                @(~) struct("status", 503, "text", ""));
            testCase.verifyError(@() failed.get_cod_ids("Li2O"), ...
                "KSSOLV:Matgenlab:COD:HTTP");
        end
    end
end

function response = transport(request)
if contains(request.url, "/result")
    assert(request.params.formula == "Li2 O");
    response = struct("status", 200, "json", struct( ...
        "file", {"1010064", "1011372"}, "sg", {"P 1", "P 1"}));
else
    response = struct("status", 200, "text", cifText());
end
end

function text = cifText()
text = strjoin([
    "data_be"
    "_cell_length_a 5"
    "_cell_length_b 5"
    "_cell_length_c 5"
    "_cell_angle_alpha 90"
    "_cell_angle_beta 90"
    "_cell_angle_gamma 90"
    "_symmetry_space_group_name_H-M 'P 1'"
    "loop_"
    "_atom_site_type_symbol"
    "_atom_site_label"
    "_atom_site_fract_x"
    "_atom_site_fract_y"
    "_atom_site_fract_z"
    "_atom_site_occupancy"
    "Be Be1 0 0 0 1"
    ], newline);
end
