function evidence = run_stage_B_2C_tests(options)
%RUN_STAGE_B_2C_TESTS Run the exact frozen eighteen-test B-2C suite.

arguments
    options.EvidenceDirectory (1,1) string = ""
    options.CommandText (1,1) string = "run_stage_B_2C_tests()"
end
root = string(fileparts(fileparts(mfilename("fullpath"))));
addpath(root); addpath(fullfile(root,"tests"));
addpath(genpath(fullfile(root,"src")));
files = "tests/integration/test_stage_b2c_formal_ipm.m";
expected = fullfile(root,"tests", ...
    "stage_B_2C_expected_test_inventory.csv");
evidence = rkkt.testing.run_fixed_test_inventory_with_evidence(root,files,expected, ...
    "EvidenceDirectory",options.EvidenceDirectory, ...
    "CommandText",options.CommandText,"SuiteLabel","stage_B_2C");
assert(evidence.summary.test_total==18 && evidence.all_pass, ...
    "stageB2C:tests:Inventory", ...
    "The exact eighteen B-2C tests must pass.");
end
