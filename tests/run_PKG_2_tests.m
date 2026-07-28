function evidence = run_PKG_2_tests(options)
%RUN_PKG_2_TESTS Execute the fixed PKG-2 data-interface test inventory.

arguments
    options.EvidenceDirectory (1,1) string = ""
    options.CommandText (1,1) string = "run_PKG_2_tests()"
end

repositoryRoot = string(fileparts(fileparts(mfilename("fullpath"))));
sourceRoot = fullfile(repositoryRoot, "src");
addpath(sourceRoot);
addpath(fullfile(sourceRoot, "artifacts"));
addpath(fullfile(sourceRoot, "data"));
addpath(fullfile(sourceRoot, "testing"));

relativeFiles = [
    "tests/unit/test_pkg1_package_contracts.m"
    "tests/unit/test_stage0_data_reader.m"
    "tests/unit/test_pkg2_data_interface.m"];
inventoryPath = fullfile(repositoryRoot, "tests", ...
    "PKG_2_expected_test_inventory.csv");
evidence = run_fixed_test_inventory_with_evidence( ...
    repositoryRoot, relativeFiles, inventoryPath, ...
    "EvidenceDirectory", options.EvidenceDirectory, ...
    "CommandText", options.CommandText, ...
    "SuiteLabel", "PKG-2 data facade and manual validation");
end
