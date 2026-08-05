function evidence = run_PKG_6_tests()
%RUN_PKG_6_TESTS Execute only the fixed fourteen-test PKG-6 inventory.

repositoryRoot = string(fileparts(fileparts(mfilename("fullpath"))));
sourceRoot = fullfile(repositoryRoot,"src");
addpath(sourceRoot);
addpath(fullfile(sourceRoot,"artifacts"));
addpath(fullfile(sourceRoot,"data"));
addpath(fullfile(sourceRoot,"testing"));

relativeFiles = [ ...
    "tests/unit/test_pkg6_solver_interface.m"
    "tests/equivalence/test_stage_a3_nonzero_binding_residual.m"];
inventoryPath = fullfile(repositoryRoot,"tests", ...
    "PKG_6_expected_test_inventory.csv");
evidence = rkkt.testing.run_fixed_test_inventory_with_evidence( ...
    repositoryRoot,relativeFiles,inventoryPath, ...
    "SuiteLabel","PKG-6 recursive direction facades");
end
