function evidence = run_stage_B_2A_stage_A_regressions(options)
%RUN_STAGE_B_2A_STAGE_A_REGRESSIONS Run five read-only Stage-A regressions.

arguments
    options.EvidenceDirectory (1,1) string = ""
    options.CommandText (1,1) string = "run_stage_B_2A_stage_A_regressions()"
end

root = string(fileparts(fileparts(mfilename("fullpath"))));
addpath(root);
addpath(fullfile(root,"tests"));
addpath(genpath(fullfile(root,"src")));
files = "tests/integration/test_stage_b2a_stage_a_regression.m";
expected = fullfile(root,"tests", ...
    "stage_B_2A_stage_A_regression_inventory.csv");
evidence = rkkt.testing.run_fixed_test_inventory_with_evidence( ...
    root,files,expected, ...
    "EvidenceDirectory",options.EvidenceDirectory, ...
    "CommandText",options.CommandText, ...
    "SuiteLabel","stage_B_2A_stage_A_regression");
assert(evidence.summary.test_total==5 && evidence.all_pass, ...
    "stageB2A:tests:StageARegression", ...
    "The five frozen Stage-A prefix regressions must pass.");
end
