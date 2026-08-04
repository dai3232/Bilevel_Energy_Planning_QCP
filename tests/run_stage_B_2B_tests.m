function evidence = run_stage_B_2B_tests(options)
%RUN_STAGE_B_2B_TESTS Run the exact frozen B-2B direction suite.

arguments
    options.EvidenceDirectory (1,1) string = ""
    options.CommandText (1,1) string = "run_stage_B_2B_tests()"
end

root = string(fileparts(fileparts(mfilename("fullpath"))));
addpath(root);
addpath(fullfile(root,"tests"));
addpath(genpath(fullfile(root,"src")));
files = "tests/equivalence/test_stage_b2b_direction_equivalence.m";
expected = fullfile(root,"tests", ...
    "stage_B_2B_expected_test_inventory.csv");
evidence = run_fixed_test_inventory_with_evidence( ...
    root,files,expected, ...
    "EvidenceDirectory",options.EvidenceDirectory, ...
    "CommandText",options.CommandText, ...
    "SuiteLabel","stage_B_2B");
assert(evidence.summary.test_total==12 && evidence.all_pass, ...
    "stageB2B:tests:Inventory", ...
    "The exact twelve B-2B direction tests must pass.");
end
