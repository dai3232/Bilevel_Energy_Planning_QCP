function evidence = run_package_closure_tests(options)
%RUN_PACKAGE_CLOSURE_TESTS Run the fixed package-closure evidence suite.

arguments
    options.EvidenceDirectory (1,1) string = ""
    options.CommandText (1,1) string = "run_package_closure_tests()"
end

root = string(fileparts(fileparts(mfilename("fullpath"))));
addpath(root);
addpath(fullfile(root,"tests"));
addpath(fullfile(root,"src"));
files = [ ...
    "tests/unit/test_package_hard_cut.m"
    "tests/unit/test_pkg1_package_contracts.m"
    "tests/unit/test_pkg9_workflow_facades.m"
    "tests/unit/test_pkg9_stage_b_module_facades.m"];
expected = fullfile(root,"tests", ...
    "package_closure_expected_test_inventory.csv");
evidence = rkkt.testing.run_fixed_test_inventory_with_evidence( ...
    root,files,expected, ...
    "EvidenceDirectory",options.EvidenceDirectory, ...
    "CommandText",options.CommandText, ...
    "SuiteLabel","package_closure");
assert(evidence.summary.test_total==37 && evidence.all_pass, ...
    "rkkt:closure:TestFailure", ...
    "The fixed 37-test package-closure suite must pass.");
end
