function evidence = run_PKG_1_tests(options)
%RUN_PKG_1_TESTS Execute the fixed PKG-1 package/contract test inventory.

arguments
    options.EvidenceDirectory (1,1) string = ""
    options.CommandText (1,1) string = "run_PKG_1_tests()"
end

repositoryRoot = string(fileparts(fileparts(mfilename("fullpath"))));
sourceRoot = fullfile(repositoryRoot,"src");
addpath(sourceRoot);
addpath(fullfile(sourceRoot,"artifacts"));
addpath(fullfile(sourceRoot,"data"));
addpath(fullfile(sourceRoot,"testing"));

relativeFiles = "tests/unit/test_pkg1_package_contracts.m";
inventoryPath = fullfile(repositoryRoot,"tests", ...
    "PKG_1_expected_test_inventory.csv");
evidence = rkkt.testing.run_fixed_test_inventory_with_evidence( ...
    repositoryRoot,relativeFiles,inventoryPath, ...
    "EvidenceDirectory",options.EvidenceDirectory, ...
    "CommandText",options.CommandText, ...
    "SuiteLabel","PKG-1 package and contract infrastructure");
end
