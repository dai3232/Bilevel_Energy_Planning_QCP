function evidence = run_PKG_3_tests()
%RUN_PKG_3_TESTS Execute only the fixed eight-test PKG-3 inventory.

repositoryRoot = string(fileparts(fileparts(mfilename("fullpath"))));
sourceRoot = fullfile(repositoryRoot, "src");
addpath(sourceRoot);
addpath(fullfile(sourceRoot, "artifacts"));
addpath(fullfile(sourceRoot, "data"));
addpath(fullfile(sourceRoot, "testing"));

relativeFiles = "tests/unit/test_pkg3_indexing_interface.m";
inventoryPath = fullfile(repositoryRoot, "tests", ...
    "PKG_3_expected_test_inventory.csv");
evidence = run_fixed_test_inventory_with_evidence( ...
    repositoryRoot, relativeFiles, inventoryPath, ...
    "SuiteLabel", "PKG-3 indexing facade and manual validation");
end
