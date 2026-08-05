function tests = test_stage_a4_3_test_evidence_orchestration
%TEST_STAGE_A4_3_TEST_EVIDENCE_ORCHESTRATION Fixed infrastructure tests.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
root = string(fileparts(fileparts(fileparts(mfilename("fullpath")))));
addpath(root);
addpath(fullfile(root,"tests"));
addpath(genpath(fullfile(root,"src")));
testCase.TestData.root = root;
end

function testConvergedPlanIsExactly257WithFixedLabels(testCase)
plan = rkkt.testing.plan_stage_a4_3_test_campaign("CONVERGED");
verifyEqual(testCase,plan.suites.suite_label,[ ...
    "stage_A4_3";"stage_A4_RNS_1"; ...
    "stage_A4_2D_2A_R1";"stage_A4_regression_195"]);
verifyEqual(testCase,plan.suites.expected_count,[27;17;18;195]);
verifyEqual(testCase,plan.expected_total,257);
verifyTrue(testCase,plan.stage_pass_eligible);
verifyTrue(testCase,plan.existing_195_authorized);
end

function testNonconvergedPlanCannotExecute195OrPassStage(testCase)
for terminal = ["MAX_ITERATIONS","NUMERICAL_FAILURE"]
    plan = rkkt.testing.plan_stage_a4_3_test_campaign(terminal);
    verifyFalse(testCase,plan.stage_pass_eligible);
    verifyFalse(testCase,plan.existing_195_authorized);
    verifyFalse(testCase,any( ...
        plan.suites.suite_label=="stage_A4_regression_195"));
    verifyEqual(testCase,plan.expected_total,32);
end
verifyError(testCase,@()run_stage_A4_3_existing_195_regression( ...
    NumericalTerminalState="MAX_ITERATIONS"), ...
    "stageA4:a43:tests:Regression195NotAuthorized");
end

function testFrozenExistingRegressionInventoryIs195Once(testCase)
[files,inventory,components] = ...
    rkkt.testing.build_stage_a4_3_regression_195_inventory( ...
    testCase.TestData.root);
verifyEqual(testCase,components.expected_count,[8;8;8;11;24;67;32;37]);
verifyEqual(testCase,height(inventory),195);
verifyEqual(testCase,numel(unique(inventory.test_name)),195);
verifyEqual(testCase,numel(unique(files)),numel(files));
end

function testConvergedAggregateHasFourExactGroupsAnd257(testCase)
[project,runId,cleanup] = synthetic_run(testCase); %#ok<ASGLU>
plan = rkkt.testing.plan_stage_a4_3_test_campaign("CONVERGED");
write_synthetic_suites(project,runId,plan);
observed = rkkt.testing.aggregate_stage_a4_3_test_evidence( ...
    project,runId,"CONVERGED");
verifyTrue(testCase,observed.all_pass);
verifyEqual(testCase,height(observed.results),257);
verifyEqual(testCase,string(observed.summary.campaign_mode), ...
    "converged_full_validation");
verifyTrue(testCase,observed.summary.stage_pass_eligible);
counts = observed.summary.suite_counts;
verifyEqual(testCase,[counts.test_total].',[27;17;18;195]);
verifyEqual(testCase,unique(observed.results.suite_label,"stable"), ...
    plan.suites.suite_label);
end

function testNonconvergedAggregateCannotBecomeStagePass(testCase)
[project,runId,cleanup] = synthetic_run(testCase); %#ok<ASGLU>
plan = rkkt.testing.plan_stage_a4_3_test_campaign("MAX_ITERATIONS");
write_synthetic_suites(project,runId,plan);
observed = rkkt.testing.aggregate_stage_a4_3_test_evidence( ...
    project,runId,"MAX_ITERATIONS");
verifyTrue(testCase,observed.all_pass);
verifyEqual(testCase,height(observed.results),32);
verifyFalse(testCase,observed.summary.stage_pass_eligible);
verifyFalse(testCase,observed.summary.existing_195_executed);
verifyFalse(testCase,any( ...
    observed.results.suite_label=="stage_A4_regression_195"));
end

function [project,runId,cleanup] = synthetic_run(testCase)
project = string(tempname);
mkdir(project);
runId = "synthetic_a43";
mkdir(fullfile(project,"runs",runId,"tests"));
cleanup = onCleanup(@()rmdir(project,"s"));
verifyTrue(testCase,isfolder(fullfile(project,"runs",runId,"tests")));
end

function write_synthetic_suites(project,runId,plan)
testsRoot = fullfile(project,"runs",runId,"tests");
for suiteIndex = 1:height(plan.suites)
    row = plan.suites(suiteIndex,:);
    directory = fullfile(testsRoot,row.relative_directory);
    mkdir(directory);
    n = row.expected_count;
    test_order = uint32((1:n).');
    test_name = row.suite_label+"/test_"+compose("%03d",(1:n).');
    source_file = repmat("tests/synthetic.m",n,1);
    inventory = table(test_order,test_name,source_file);
    passed = true(n,1);
    failed = false(n,1);
    incomplete = false(n,1);
    duration_seconds = zeros(n,1);
    details = repmat("",n,1);
    results = table(test_name,passed,failed,incomplete, ...
        duration_seconds,details);
    rkkt.artifacts.write_table_csv_17g(fullfile(directory,"test_inventory.csv"), ...
        inventory);
    rkkt.artifacts.write_table_csv_17g(fullfile(directory,"test_results.csv"),results);
    write_synthetic_junit(fullfile(directory,"test_results.xml"), ...
        row.suite_label,test_name);
    write_text(fullfile(directory,"matlab_test_console.log"), ...
        "synthetic complete"+newline);
    write_text(fullfile(directory,"test_command.txt"), ...
        "synthetic "+row.suite_label+newline);
    summary = struct("execution_status","COMPLETE", ...
        "suite_label",char(row.suite_label),"test_total",n, ...
        "test_passed",n,"test_failed",0,"test_incomplete",0);
    rkkt.artifacts.write_json_file(fullfile(directory,"test_summary.json"),summary);
    write_synthetic_hashes(directory);
    if row.suite_label=="stage_A4_3"
        rkkt.artifacts.write_json_file(fullfile(directory,"suite_identity.json"), ...
            struct("run_id",char(runId),"suite_label","stage_A4_3", ...
            "test_total",27));
    end
end
end

function write_synthetic_hashes(directory)
names = ["test_inventory.csv";"test_results.csv";"test_results.xml"; ...
    "matlab_test_console.log";"test_command.txt";"test_summary.json"];
sha256 = strings(6,1);
bytes = zeros(6,1);
for k = 1:6
    target = fullfile(directory,names(k));
    sha256(k) = rkkt.data.compute_sha256_file(target);
    info = dir(target);
    bytes(k) = info.bytes;
end
status = repmat("PASS",6,1);
rkkt.artifacts.write_table_csv_17g(fullfile(directory,"test_evidence_sha256.csv"), ...
    table(names,sha256,bytes,status));
end

function write_synthetic_junit(pathValue,label,names)
lines = ["<?xml version=""1.0"" encoding=""UTF-8""?>"; ...
    "<testsuites tests="""+string(numel(names))+""">"; ...
    "<testsuite name="""+label+""" tests="""+ ...
    string(numel(names))+""">"];
for name = names.'
    lines(end+1,1) = "<testcase name="""+name+"""></testcase>"; %#ok<AGROW>
end
lines = [lines;"</testsuite>";"</testsuites>"];
write_text(pathValue,strjoin(lines,newline)+newline);
end

function write_text(pathValue,value)
[fileId,message] = fopen(pathValue,"wb","n","UTF-8");
assert(fileId>=0,"%s",message);
guard = onCleanup(@()close_file(fileId));
bytes = unicode2native(char(value),"UTF-8");
assert(fwrite(fileId,bytes,"uint8")==numel(bytes));
status = fclose(fileId);
clear guard
assert(status==0);
end

function close_file(fileId)
try
    if ischar(fopen(fileId))
        fclose(fileId);
    end
catch
end
end
