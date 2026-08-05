function evidence = run_stage_B_1_affected_regressions(options)
%RUN_STAGE_B_1_AFFECTED_REGRESSIONS Run the five data/index regressions.
%
% The inventory intentionally excludes the Stage-0 environment test because
% that test opens a parallel pool, which is outside the B-1 execution scope.

arguments
    options.EvidenceDirectory (1,1) string = ""
    options.CommandText (1,1) string = ...
        "run_stage_B_1_affected_regressions()"
end

root = string(fileparts(fileparts(mfilename("fullpath"))));
addpath(root);
addpath(fullfile(root,"tests"));
addpath(genpath(fullfile(root,"src")));
files = [ ...
    "tests/unit/test_stage0_data_reader.m"
    "tests/unit/test_canonical_index_framework.m"];
expected = fullfile(root,"tests", ...
    "stage_B_1_affected_regression_inventory.csv");
evidence = rkkt.testing.run_fixed_test_inventory_with_evidence( ...
    root,files,expected, ...
    "EvidenceDirectory",options.EvidenceDirectory, ...
    "CommandText",options.CommandText, ...
    "SuiteLabel","stage_B_1_affected_regressions");
assert(evidence.summary.test_total==5 && evidence.all_pass, ...
    "stageB1:tests:AffectedRegressionFailed", ...
    "The exact five affected data/index regressions must pass.");
end
