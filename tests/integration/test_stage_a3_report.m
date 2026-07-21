function tests = test_stage_a3_report
%TEST_STAGE_A3_REPORT Verify artifact-only A3 reporting and failure closure.
tests=functiontests(localfunctions);
end

function setupOnce(testCase)
root=string(fileparts(fileparts(fileparts(mfilename('fullpath')))));
originalPath=path; addpath(genpath(fullfile(root,"src")));
testCase.addTeardown(@()path(originalPath));
config=load_stage_a3_configuration(root); data=load_project_data(root);
index=build_stage_a3_index(data,"RunId","A3_REPORT_TEST");
verification=run_stage_a3_direction_verification(data,index,config);
project=string(tempname(tempdir)); mkdir(project);
testCase.addTeardown(@()remove_tree(project));
metadata=struct("day_ids",config.days,"hours",config.hours, ...
    "soc_boundary_mode",char(config.soc_boundary_mode), ...
    "newton_direction_count",1,"optimization_executed",false, ...
    "full_ipm_executed",false,"parallel_executed",false, ...
    "a3_solver_executed",true,"physical_dispatch_interpretation",false, ...
    "enabled_components",["OBJ_INVEST","FORMAL_DAILY_SOC"]);
context=create_run_context(project,"stage_A3","RunId","A3_REPORT_RUN", ...
    "ManifestMetadata",metadata);
context.project_root=char(root);
environment=table("ENV",true,"PASS", ...
    'VariableNames',{'check_id','blocking','status'});
hashes=table(["基础参数.xlsx";"输入数据.xlsx"], ...
    repmat("abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789",2,1), ...
    repmat("abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789",2,1), ...
    repmat("PASS",2,1),'VariableNames', ...
    {'file_name','expectedSHA256','actualSHA256','status'});
write_table_csv_17g(context.environment_csv_path,environment);
write_table_csv_17g(context.input_hashes_csv_path,hashes);
scan=table("A3-SYNTHETIC-SCAN","test fixture",0,"PASS","no match", ...
    'VariableNames',{'check_id','requirement','actual','status','evidence'});
export_stage_a3_artifacts(context,data,index,config,verification.linearization, ...
    verification.direct,verification.recursive,verification.audit, ...
    CodeScan=scan,Physical=verification.physical);
acceptance=evaluate_stage_a3_acceptance_facts(root,verification);
write_table_csv_17g(context.acceptance_results_path,acceptance);
write_table_csv_17g(context.issue_log_path,new_stage_a3_issue_log());
write_test_evidence(context.tests_dir,"A3",6);
a2Directory=fullfile(context.tests_dir,"a2_regression"); mkdir(a2Directory);
write_test_evidence(a2Directory,"A2",32);
a1Directory=fullfile(context.tests_dir,"a1_regression"); mkdir(a1Directory);
write_test_evidence(a1Directory,"A1",37);
testCase.TestData=struct("root",root,"project",project, ...
    "context",context,"acceptance",acceptance);
end

function testGeneratesThreeValidatedArtifactBackedReports(testCase)
output=fullfile(testCase.TestData.project,"reports_success");
paths=generate_stage_a3_reports(testCase.TestData.context, ...
    'OutputDirectory',output,'FinalStatusCandidate','PASS');
names=fieldnames(paths); verifyEqual(testCase,numel(names),3);
for k=1:numel(names)
    verifyTrue(testCase,isfile(paths.(names{k})));
    [valid,details]=validate_docx_package(paths.(names{k}));
    verifyTrue(testCase,valid,strjoin(details.errors,"; "));
    verifyTrue(testCase,contains(details.document_text,"A3"));
    verifyTrue(testCase,contains(details.document_text,"A3_REPORT_RUN"));
end
[~,details]=validate_docx_package(paths.model_report);
verifyTrue(testCase,contains(details.document_text,"18836"));
verifyTrue(testCase,contains(details.document_text,"4340"));
verifyTrue(testCase,contains(details.document_text,"422"));
verifyTrue(testCase,contains(details.document_text,"14—20"));
verifyTrue(testCase,contains(details.document_text,"输入数据.xlsx"));
verifyTrue(testCase,contains(details.document_text, ...
    "count=7; day_ids=[14 15 16 17 18 19 20]; S=14x14; c,beta,gamma=14x1"));
verifyTrue(testCase,contains(details.document_text, ...
    "sorted_days=[14 15 16 17 18 19 20]; S_relative_error=0; gamma_relative_error=0"));
verifyFalse(testCase,contains(details.document_text,"NaN"));
[~,issueDetails]=validate_docx_package(paths.issue_report);
verifyTrue(testCase,contains(issueDetails.document_text,"启用：全局q/rho"));
verifyTrue(testCase,contains(issueDetails.document_text,"未启用：A4、完整IPM"));
verifyTrue(testCase,contains(issueDetails.document_text, ...
    "7组；日14—20；S=14x14；c/beta/gamma=14x1"));
verifyTrue(testCase,contains(issueDetails.document_text, ...
    "日14—20；S顺序误差=0；gamma顺序误差=0"));
end

function testRejectsFalsePassAndFinalManifest(testCase)
pathValue=testCase.TestData.context.acceptance_results_path;
backup=pathValue+".test_backup"; [moved,message]=movefile(pathValue,backup);
assert(moved,message); guard=onCleanup(@()restore_file(pathValue,backup));
bad=testCase.TestData.acceptance;
bad=set_stage_a3_acceptance_result(bad,"SA3-EQ-001","FAIL", ...
    "1","forced test failure","iterations/direction_comparison.csv");
write_table_csv_17g(pathValue,bad);
verifyError(testCase,@()generate_stage_a3_reports(testCase.TestData.context, ...
    'OutputDirectory',fullfile(testCase.TestData.project,"false_pass"), ...
    'FinalStatusCandidate','PASS'),"stageA3:report:AcceptanceMismatch");
clear guard;

manifestPath=testCase.TestData.context.run_manifest_path;
manifestBackup=manifestPath+".test_backup";
manifest=jsondecode(fileread(manifestPath));
[moved,message]=movefile(manifestPath,manifestBackup); assert(moved,message);
manifestGuard=onCleanup(@()restore_file(manifestPath,manifestBackup));
manifest.status='FAIL_RETRYABLE'; write_json_file(manifestPath,manifest);
verifyError(testCase,@()generate_stage_a3_reports(testCase.TestData.context, ...
    'OutputDirectory',fullfile(testCase.TestData.project,"finalized"), ...
    'FinalStatusCandidate','PASS'),"stageA3:report:ManifestIdentity");
clear manifestGuard;
end

function testRejectsNonemptyIssueLog(testCase)
pathValue=testCase.TestData.context.issue_log_path;
backup=pathValue+".test_backup"; [moved,message]=movefile(pathValue,backup);
assert(moved,message); guard=onCleanup(@()restore_file(pathValue,backup));
issues=new_stage_a3_issue_log();
issues=append_stage_a3_issue(issues,testCase.TestData.context,"SA3-RUN", ...
    "test","object","symptom","message","cause","solution", ...
    "OPEN","run_manifest.json");
write_table_csv_17g(pathValue,issues);
verifyError(testCase,@()generate_stage_a3_reports(testCase.TestData.context, ...
    'OutputDirectory',fullfile(testCase.TestData.project,"nonempty_issues"), ...
    'FinalStatusCandidate','PASS'),"stageA3:report:UnresolvedIssues");
clear guard;
end

function testExistingReportsAndFailureStatus(testCase)
output=fullfile(testCase.TestData.project,"reports_collision");
generate_stage_a3_reports(testCase.TestData.context, ...
    'OutputDirectory',output,'FinalStatusCandidate','PASS');
verifyError(testCase,@()generate_stage_a3_reports(testCase.TestData.context, ...
    'OutputDirectory',output,'FinalStatusCandidate','PASS'), ...
    "stageA3:report:ArtifactExists");
context=create_synthetic_context(testCase,"A3_FAILURE_REPORT_RUN");
acceptance=initialize_stage_a3_acceptance(testCase.TestData.root);
for row=1:height(acceptance)
    acceptance=set_stage_a3_acceptance_result(acceptance, ...
        acceptance.test_id(row),"BLOCKED","not run","dependency blocked", ...
        "run_manifest.json");
end
exception=MException("stageA3:external:Blocked","synthetic external block");
pathValue=generate_stage_a3_failure_report(context,exception, ...
    new_stage_a3_issue_log(),acceptance);
verifyTrue(testCase,isfile(pathValue));
[valid,details]=validate_docx_package(pathValue);
verifyTrue(testCase,valid,strjoin(details.errors,"; "));
verifyTrue(testCase,contains(details.document_text,"BLOCKED_EXTERNAL"));
verifyTrue(testCase,contains(details.document_text,"不宣告 Stage A3 通过"));
end

function context=create_synthetic_context(testCase,runId)
metadata=struct("newton_direction_count",1,"optimization_executed",false, ...
    "full_ipm_executed",false,"parallel_executed",false, ...
    "a3_solver_executed",false);
context=create_run_context(testCase.TestData.project,"stage_A3", ...
    "RunId",runId,"ManifestMetadata",metadata);
context.project_root=char(testCase.TestData.root);
end
function write_test_evidence(directory,prefix,count)
names=compose(prefix+"_test_%02d",(1:count)');
inventory=table(uint32((1:count)'),names,repmat("tests/"+lower(prefix),count,1), ...
    'VariableNames',{'test_order','test_name','source_file'});
results=table(names,true(count,1),false(count,1),false(count,1), ...
    zeros(count,1),repmat("",count,1), ...
    'VariableNames',{'test_name','passed','failed','incomplete', ...
    'duration_seconds','details'});
write_table_csv_17g(fullfile(directory,"test_inventory.csv"),inventory);
write_table_csv_17g(fullfile(directory,"test_results.csv"),results);
write_json_file(fullfile(directory,"test_summary.json"),struct( ...
    "test_total",count,"test_passed",count,"test_failed",0, ...
    "test_incomplete",0,"duration_seconds",0));
end
function restore_file(pathValue,backup)
if isfile(pathValue), delete(pathValue); end
if isfile(backup), movefile(backup,pathValue); end
end
function remove_tree(pathValue)
if isfolder(pathValue), rmdir(pathValue,'s'); end
end
