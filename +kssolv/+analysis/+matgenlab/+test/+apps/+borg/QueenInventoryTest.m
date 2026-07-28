classdef QueenInventoryTest < matlab.unittest.TestCase
    properties
        fixtures
        oracle
    end

    methods (TestMethodSetup)
        function prepare(testCase)
            testCase.fixtures = fullfile(pwd, "+kssolv", "+analysis", ...
                "+matgenlab", "+test", "+apps", "+borg", ...
                "+fixtures", "+queen");
            testCase.oracle = jsondecode(fileread(fullfile(pwd, "dev", ...
                "matgenlab", "oracles", ...
                "apps_borg_queen_2026.5.4.json")));
        end
    end

    methods (Test)
        function serialOfficialFixtureMatches(testCase)
            drone = kssolv.analysis.matgenlab.apps.borg. ...
                VaspToComputedEntryDrone();
            queen = kssolv.analysis.matgenlab.apps.borg. ...
                BorgQueen(drone, testCase.fixtures, 1);
            data = queen.get_data();
            testCase.verifyEqual(numel(data), ...
                testCase.oracle.serial.count);
            testCase.verifyClass(data{1}, ...
                "kssolv.analysis.matgenlab.core.ComputedEntry");
            testCase.verifyEqual(data{1}.energy, ...
                testCase.oracle.serial.energy, AbsTol = 1e-10);
            testCase.verifyEqual(data{1}.reduced_formula, ...
                string(testCase.oracle.serial.formula));
        end

        function delayedAndParallelAssimilationMatch(testCase)
            drone = kssolv.analysis.matgenlab.apps.borg. ...
                VaspToComputedEntryDrone();
            queen = kssolv.analysis.matgenlab.apps.borg. ...
                BorgQueen(drone);
            testCase.verifyEmpty(queen.get_data());
            queen.parallel_assimilate(testCase.fixtures);
            data = queen.get_data();
            testCase.verifyEqual(numel(data), 1);
            testCase.verifyEqual(data{1}.energy, ...
                testCase.oracle.serial.energy, AbsTol = 1e-10);
        end

        function officialPlainDataLoads(testCase)
            drone = kssolv.analysis.matgenlab.apps.borg. ...
                VaspToComputedEntryDrone();
            queen = kssolv.analysis.matgenlab.apps.borg.BorgQueen(drone);
            queen.load_data(fullfile(testCase.fixtures, ...
                "assimilated.json"));
            data = queen.get_data();
            testCase.verifyEqual(numel(data), ...
                testCase.oracle.loaded_count);
            testCase.verifyEqual(data{1}.energy, ...
                testCase.oracle.loaded_energy, AbsTol = 1e-12);
            testCase.verifyEqual(data{1}.composition.Li, 1);
        end

        function saveAndLoadCompressedMsonRoundTrip(testCase)
            drone = kssolv.analysis.matgenlab.apps.borg. ...
                VaspToComputedEntryDrone();
            source = kssolv.analysis.matgenlab.apps.borg. ...
                BorgQueen(drone, testCase.fixtures, 1);
            for extension = [".json", ".json.gz", ".json.bz2"]
                filename = string(tempname) + extension;
                cleanup = onCleanup(@() deleteIfExists(filename));
                source.save_data(filename);
                target = kssolv.analysis.matgenlab.apps.borg. ...
                    BorgQueen(drone);
                target.load_data(filename);
                data = target.get_data();
                testCase.verifyEqual(numel(data), 1);
                testCase.verifyClass(data{1}, ...
                    "kssolv.analysis.matgenlab.core.ComputedEntry");
                testCase.verifyEqual(data{1}.energy, ...
                    testCase.oracle.serial.energy, AbsTol = 1e-10);
                clear cleanup
            end
        end

        function orderHelperAdvancesStatus(testCase)
            drone = kssolv.analysis.matgenlab.apps.borg. ...
                VaspToComputedEntryDrone();
            [entry, status] = kssolv.analysis.matgenlab.apps.borg. ...
                order_assimilation({testCase.fixtures, drone, {}, ...
                struct("count", 3, "total", 4)});
            testCase.verifyEqual(entry.energy, ...
                testCase.oracle.serial.energy, AbsTol = 1e-10);
            testCase.verifyEqual(status.count, 4);
            testCase.verifyEqual(status.total, 4);
        end

        function invalidInputsAreRejected(testCase)
            drone = kssolv.analysis.matgenlab.apps.borg. ...
                VaspToComputedEntryDrone();
            testCase.verifyError(@() ...
                kssolv.analysis.matgenlab.apps.borg. ...
                BorgQueen(drone, [], 0), ...
                "KSSOLV:Matgenlab:BorgQueen:DroneCount");
            queen = kssolv.analysis.matgenlab.apps.borg.BorgQueen(drone);
            testCase.verifyError(@() queen.serial_assimilate( ...
                fullfile(testCase.fixtures, "missing")), ...
                "KSSOLV:Matgenlab:BorgQueen:Root");
        end
    end
end

function deleteIfExists(filename)
if isfile(filename), delete(filename); end
end
