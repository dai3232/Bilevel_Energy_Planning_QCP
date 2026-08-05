function tests = test_stage_b1_report
%TEST_STAGE_B1_REPORT Verify artifact-only Chinese report generation.
tests = functiontests(localfunctions);
end

function testReportIsGeneratedOnlyFromPersistedB1Facts(testCase)
root = string(fileparts(fileparts(fileparts(mfilename("fullpath")))));
addpath(genpath(fullfile(root,"src")));
runRoot = string(tempname(tempdir));
mkdir(runRoot);
guard = onCleanup(@()remove_tree(runRoot));
mkdir(fullfile(runRoot,"diagnostics"));
mkdir(fullfile(runRoot,"acceptance"));
mkdir(fullfile(runRoot,"tests"));
mkdir(fullfile(runRoot,"issues"));
mkdir(fullfile(runRoot,"reports"));

data = rkkt.data.load_project_data(root);
runId = "B1_REPORT_TEST";
water = rkkt.diagnostics.build_stage_b1_water_input_audit(data,runId);
[derivatives,~] = rkkt.diagnostics.run_stage_b1_derivative_checks(data);
rkkt.artifacts.write_table_csv_17g(fullfile(runRoot,"diagnostics", ...
    "water_input_audit.csv"),water);
rkkt.artifacts.write_table_csv_17g(fullfile(runRoot,"diagnostics", ...
    "derivative_check.csv"),derivatives);

testId = ["SB-DATA-001";"SB-DER-001";"SB-EQ-001";"SB-PHY-001"];
requirement = ["28 day-plant rows";"relative error <= 1e-7"; ...
    "extended direction equivalence";"physical water feasibility"];
status = ["PASS";"PASS";"NOT_RUN";"NOT_RUN"];
actualValue = ["28"; ...
    compose("gradient=%.17g; hessian=%.17g", ...
        max(derivatives.gradient_relative_error), ...
        max(derivatives.hessian_relative_error)); ...
    "not executed";"not executed"];
acceptance = table(testId,requirement,status,actualValue, ...
    'VariableNames',{'test_id','requirement','status','actual_value'});
rkkt.artifacts.write_table_csv_17g(fullfile(runRoot,"acceptance", ...
    "acceptance_results.csv"),acceptance);

[hashes,hashPass] = rkkt.data.verify_input_hashes(root);
verifyTrue(testCase,hashPass);
inputHashes = table(string(hashes.fileName), ...
    string(hashes.actualSHA256),string(hashes.status), ...
    'VariableNames',{'file_name','actualSHA256','status'});
rkkt.artifacts.write_table_csv_17g(fullfile(runRoot,"input_hashes.csv"),inputHashes);

environment = rkkt.diagnostics.inspect_stage_b1_environment();
environment = addvars(environment, ...
    repmat(runId,height(environment),1), ...
    'Before',1,'NewVariableNames','run_id');
rkkt.artifacts.write_table_csv_17g(fullfile(runRoot,"environment.csv"),environment);
issues = table(strings(0,1),'VariableNames',{'issue_id'});
rkkt.artifacts.write_table_csv_17g(fullfile(runRoot,"issues","issue_log.csv"),issues);
rkkt.artifacts.write_json_file(fullfile(runRoot,"tests","test_summary.json"), ...
    struct("test_total",14,"test_passed",14, ...
    "test_failed",0,"test_incomplete",0));
rkkt.artifacts.write_json_file(fullfile(runRoot,"run_manifest.json"), ...
    struct("run_id",runId,"stage_id","stage_B","status","RUNNING", ...
    "git_commit","B1_REPORT_TEST_COMMIT"));

report = rkkt.reporting.generate_stage_b1_report(runRoot);
verifyTrue(testCase,isfile(report.path));
[valid,details] = rkkt.reporting.validate_stage_b1_report(runRoot);
verifyTrue(testCase,valid,details.message);
verifyNotEmpty(testCase,details.package.document_text);
verifyTrue(testCase,contains(details.package.document_text, ...
    "SB-EQ-001"));
verifyTrue(testCase,contains(details.package.document_text, ...
    "NOT_RUN"));
verifyFalse(testCase,contains(details.package.document_text, ...
    "stage_A4"));
clear guard
end

function remove_tree(pathValue)
try
    if isfolder(pathValue)
        rmdir(pathValue,"s");
    end
catch
end
end
