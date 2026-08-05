function evidence = run_PKG_4_tests()
%RUN_PKG_4_TESTS Execute only the fixed ten-test PKG-4 inventory.

repositoryRoot = string(fileparts(fileparts(mfilename("fullpath"))));
sourceRoot = fullfile(repositoryRoot,"src");
addpath(sourceRoot);
addpath(fullfile(sourceRoot,"artifacts"));
addpath(fullfile(sourceRoot,"data"));
addpath(fullfile(sourceRoot,"testing"));

relativeFiles = "tests/unit/test_pkg4_model_interface.m";
inventoryPath = fullfile(repositoryRoot,"tests", ...
    "PKG_4_expected_test_inventory.csv");
evidence = rkkt.testing.run_fixed_test_inventory_with_evidence( ...
    repositoryRoot,relativeFiles,inventoryPath, ...
    "SuiteLabel","PKG-4 state and shared-linearization facades");
end
