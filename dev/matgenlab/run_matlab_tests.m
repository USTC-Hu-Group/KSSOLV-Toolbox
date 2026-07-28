function results = run_matlab_tests(options)
%RUN_MATLAB_TESTS Run every Matgenlab matlab.unittest test file.

arguments
    options.IncludeOracle (1,1) logical = true
end

root = KSSOLV_Toolbox.RootDirectory;
testRoot = fullfile(root, "+kssolv", "+analysis", "+matgenlab", "+test");
suite = testsuite(testRoot, IncludeSubfolders = true);
legacyCoreTestRoot = fullfile(root, "+kssolv", "+analysis", ...
    "+matgenlab", "+core", "+test");
if isfolder(legacyCoreTestRoot)
    suite = [suite, testsuite( ...
        legacyCoreTestRoot, IncludeSubfolders = true)];
end
if ~options.IncludeOracle
    suite = suite(~contains({suite.Name}, "OracleSmokeTest"));
end

results = run(suite);
disp(results);
results.assertSuccess();
end
