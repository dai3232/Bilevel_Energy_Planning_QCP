function evidence = run_stage_B_2C_A4_3_affected_regressions(options)
%RUN_STAGE_B_2C_A4_3_AFFECTED_REGRESSIONS Run the legal affected closure.
%
% The six formal-candidate and four result-export A4-3 tests intentionally
% require CURRENT_STAGE stage_A4 / READY and are not in the affected
% closure.  B-2C does not bypass that historical stage gate.  This fixed
% suite covers all A4 checkpoint/report tests affected by the shared CSV,
% evidence, checkpoint, and DOCX infrastructure touched in B-2C.

arguments
    options.EvidenceDirectory (1,1) string = ""
    options.CommandText (1,1) string = ...
        "run_stage_B_2C_A4_3_affected_regressions()"
end
root = string(fileparts(fileparts(mfilename("fullpath"))));
addpath(root); addpath(fullfile(root,"tests"));
addpath(genpath(fullfile(root,"src")));
files = ["tests/unit/test_stage_a4_checkpoint.m"; ...
    "tests/integration/test_stage_a4_report.m"];
expected = fullfile(root,"tests", ...
    "stage_B_2C_A4_3_affected_inventory.csv");
evidence = rkkt.testing.run_fixed_test_inventory_with_evidence(root,files,expected, ...
    "EvidenceDirectory",options.EvidenceDirectory, ...
    "CommandText",options.CommandText, ...
    "SuiteLabel","stage_B_2C_A4_3_affected");
assert(evidence.summary.test_total==17 && evidence.all_pass, ...
    "stageB2C:tests:A43Affected", ...
    "The exact seventeen affected A4-3 checkpoint/report tests must pass.");
end
