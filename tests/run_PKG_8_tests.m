function evidence = run_PKG_8_tests()
%RUN_PKG_8_TESTS Execute only the fixed twenty-two-test PKG-8 inventory.

repositoryRoot = string(fileparts(fileparts(mfilename("fullpath"))));
sourceRoot = fullfile(repositoryRoot,"src");
addpath(genpath(sourceRoot));
addpath(fullfile(sourceRoot,"artifacts"));
addpath(fullfile(sourceRoot,"data"));
addpath(fullfile(sourceRoot,"testing"));

relativeFiles = "tests/unit/test_pkg8_call_migration.m";
inventoryPath = fullfile(repositoryRoot,"tests", ...
    "PKG_8_expected_test_inventory.csv");
evidence = run_fixed_test_inventory_with_evidence( ...
    repositoryRoot,relativeFiles,inventoryPath, ...
    "SuiteLabel","PKG-8 caller migration and package closure");
end
