function evidence = run_stage_A4_3_supporting_suite(suiteLabel,options)
%RUN_STAGE_A4_3_SUPPORTING_SUITE Persist one fixed post-convergence suite.

arguments
    suiteLabel (1,1) string
    options.EvidenceDirectory (1,1) string = ""
    options.CommandText (1,1) string = ""
end
root = string(fileparts(fileparts(mfilename("fullpath"))));
addpath(root);
addpath(fullfile(root,"tests"));
addpath(genpath(fullfile(root,"src")));
label = strip(suiteLabel);
switch label
    case "stage_A4_RNS_1"
        files = "tests/integration/" + ...
            "test_stage_a4_rns1_numerical_stability.m";
        inventoryName = "stage_A4_RNS_1_expected_test_inventory.csv";
        expectedCount = 17;
    case "stage_A4_2D_2A_R1"
        files = "tests/integration/" + ...
            "test_stage_a4_objective_unitization_stable_rerun.m";
        inventoryName = ...
            "stage_A4_2D_2A_R1_expected_test_inventory.csv";
        expectedCount = 18;
    case "stage_A4_3_finalizer"
        files = "tests/integration/testA43Finalizer.m";
        inventoryName = ...
            "stage_A4_3_finalizer_expected_test_inventory.csv";
        expectedCount = 5;
    otherwise
        error("stageA4:a43:tests:SupportingSuite", ...
            "Unsupported A4-3 supporting suite: %s",label);
end
commandText = strip(options.CommandText);
if strlength(commandText)==0
    commandText = "run_stage_A4_3_supporting_suite("""+label+""")";
end
evidence = run_fixed_test_inventory_with_evidence( ...
    root,files,fullfile(root,"tests",inventoryName), ...
    "EvidenceDirectory",options.EvidenceDirectory, ...
    "CommandText",commandText,"SuiteLabel",label);
assert(evidence.summary.test_total==expectedCount && ...
    evidence.all_pass, ...
    "stageA4:a43:tests:SupportingSuiteFailed", ...
    "The fixed %s suite must pass exactly %d tests.", ...
    label,expectedCount);
end
