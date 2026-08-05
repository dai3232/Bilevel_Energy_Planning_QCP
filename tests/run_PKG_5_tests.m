function evidence = run_PKG_5_tests()
%RUN_PKG_5_TESTS Execute only the fixed ten-test PKG-5 inventory.

repositoryRoot = string(fileparts(fileparts(mfilename("fullpath"))));
sourceRoot = fullfile(repositoryRoot,"src");
addpath(sourceRoot);
addpath(fullfile(sourceRoot,"artifacts"));
addpath(fullfile(sourceRoot,"data"));
addpath(fullfile(sourceRoot,"testing"));

relativeFiles = "tests/unit/test_pkg5_solver_interface.m";
inventoryPath = fullfile(repositoryRoot,"tests", ...
    "PKG_5_expected_test_inventory.csv");
evidence = rkkt.testing.run_fixed_test_inventory_with_evidence( ...
    repositoryRoot,relativeFiles,inventoryPath, ...
    "SuiteLabel","PKG-5 full and reduced KKT facades");
end
