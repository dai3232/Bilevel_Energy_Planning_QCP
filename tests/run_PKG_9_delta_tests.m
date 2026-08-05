function evidence = run_PKG_9_delta_tests()
%RUN_PKG_9_DELTA_TESTS Execute only the fixed PKG-9 delta inventory.

repositoryRoot = string(fileparts(fileparts(mfilename("fullpath"))));
sourceRoot = fullfile(repositoryRoot,"src");
addpath(genpath(sourceRoot));
addpath(fullfile(sourceRoot,"artifacts"));
addpath(fullfile(sourceRoot,"data"));
addpath(fullfile(sourceRoot,"testing"));

relativeFiles = [ ...
    "tests/unit/test_pkg9_delta_guards.m"
    "tests/unit/test_pkg9_workflow_facades.m"
    "tests/unit/test_pkg9_stage_b_module_facades.m"
    "tests/integration/test_pkg9_validation_entries.m"
    "tests/integration/test_pkg9_stage_b2b_delta.m"];
inventoryPath = fullfile(repositoryRoot,"tests", ...
    "PKG_9_expected_test_inventory.csv");
evidence = rkkt.testing.run_fixed_test_inventory_with_evidence( ...
    repositoryRoot,relativeFiles,inventoryPath, ...
    "SuiteLabel","PKG-9 stable B-2B interface delta");
end
