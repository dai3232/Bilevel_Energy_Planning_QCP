function evidence = run_PKG_7_tests()
%RUN_PKG_7_TESTS Execute only the fixed fourteen-test PKG-7 inventory.

repositoryRoot = string(fileparts(fileparts(mfilename("fullpath"))));
sourceRoot = fullfile(repositoryRoot,"src");
addpath(genpath(sourceRoot));
addpath(fullfile(sourceRoot,"artifacts"));
addpath(fullfile(sourceRoot,"data"));
addpath(fullfile(sourceRoot,"testing"));

relativeFiles = "tests/unit/test_pkg7_ipm_interface.m";
inventoryPath = fullfile(repositoryRoot,"tests", ...
    "PKG_7_expected_test_inventory.csv");
evidence = rkkt.testing.run_fixed_test_inventory_with_evidence( ...
    repositoryRoot,relativeFiles,inventoryPath, ...
    "SuiteLabel","PKG-7 IPM step and deferred-solve facades");
end
