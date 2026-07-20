function tests = test_stage_a2_report
%TEST_STAGE_A2_REPORT Verify artifact-only A2 reporting and failure closure.
tests=functiontests(localfunctions);
end

function setupOnce(testCase)
root=string(fileparts(fileparts(fileparts(mfilename('fullpath')))));
originalPath=path; addpath(genpath(fullfile(root,"src")));
testCase.addTeardown(@()path(originalPath));
config=load_stage_a2_configuration(root); data=load_project_data(root);
index=build_stage_a2_index(data,"RunId","A2_REPORT_TEST");
verification=run_stage_a2_direction_verification(data,index,config);
project=string(tempname(tempdir)); mkdir(project);
testCase.addTeardown(@()remove_tree(project));
metadata=struct("time_scope_type",char(config.time_scope_type), ...
    "input_day",14,"start_hour",1,"terminal_hour",24, ...
    "soc_boundary_mode",char(config.soc_boundary_mode), ...
    "newton_direction_count",1,"optimization_executed",false, ...
    "full_ipm_executed",false,"parallel_executed",false, ...
    "a2_solver_executed",true,"physical_dispatch_interpretation",false);
context=create_run_context(project,"stage_A2","RunId","A2_REPORT_RUN", ...
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
export_stage_a2_artifacts(context,data,index,config,verification.linearization, ...
    verification.direct,verification.recursive,verification.audit);
acceptance=evaluate_stage_a2_acceptance_facts(root,data,index,verification);
write_table_csv_17g(context.acceptance_results_path,acceptance);
write_table_csv_17g(context.issue_log_path,new_stage_a2_issue_log());
write_test_evidence(context.tests_dir,"A2",5);
a1Directory=fullfile(context.tests_dir,"a1_regression"); mkdir(a1Directory);
write_test_evidence(a1Directory,"A1",37);
testCase.TestData.root=root; testCase.TestData.project=project;
testCase.TestData.context=context; testCase.TestData.acceptance=acceptance;
end

function testGeneratesThreeValidatedArtifactBackedReports(testCase)
output=fullfile(testCase.TestData.project,"reports_success");
paths=generate_stage_a2_reports(testCase.TestData.context, ...
    'OutputDirectory',output,'FinalStatusCandidate','PASS');
names=fieldnames(paths); verifyEqual(testCase,numel(names),3);
for k=1:numel(names)
    verifyTrue(testCase,isfile(paths.(names{k})));
    [valid,details]=validate_docx_package(paths.(names{k}));
    verifyTrue(testCase,valid,strjoin(details.errors,"; "));
    verifyTrue(testCase,contains(details.document_text,"A2"));
    verifyTrue(testCase,contains(details.document_text,"A2_REPORT_RUN"));
end
model=paths.model_report; [~,details]=validate_docx_package(model);
verifyTrue(testCase,contains(details.document_text,"2749"));
verifyTrue(testCase,contains(details.document_text,"589"));
verifyTrue(testCase,contains(details.document_text,"fixed_zero_map"));
verifyTrue(testCase,contains(details.document_text,"输入数据.xlsx"));
end

function testRejectsFalsePassAndFinalManifest(testCase)
pathValue=testCase.TestData.context.acceptance_results_path;
backup=pathValue+".test_backup";
[moved,message]=movefile(pathValue,backup); assert(moved,message);
guard=onCleanup(@()restore_file(pathValue,backup));
bad=testCase.TestData.acceptance;
bad=set_stage_a2_acceptance_result(bad,"SA2-EQ-001","FAIL", ...
    "1","forced test failure","iterations/direction_comparison.csv");
write_table_csv_17g(pathValue,bad);
verifyError(testCase,@()generate_stage_a2_reports(testCase.TestData.context, ...
    'OutputDirectory',fullfile(testCase.TestData.project,"false_pass"), ...
    'FinalStatusCandidate','PASS'),"stageA2:report:AcceptanceMismatch");
clear guard;

manifestPath=testCase.TestData.context.run_manifest_path;
manifestBackup=manifestPath+".test_backup";
manifest=jsondecode(fileread(manifestPath));
[moved,message]=movefile(manifestPath,manifestBackup); assert(moved,message);
manifestGuard=onCleanup(@()restore_file(manifestPath,manifestBackup));
manifest.status='FAIL_RETRYABLE'; write_json_file(manifestPath,manifest);
verifyError(testCase,@()generate_stage_a2_reports(testCase.TestData.context, ...
    'OutputDirectory',fullfile(testCase.TestData.project,"finalized"), ...
    'FinalStatusCandidate','PASS'),"stageA2:report:ManifestIdentity");
clear manifestGuard;
end

function testExistingReportsAreNeverOverwritten(testCase)
output=fullfile(testCase.TestData.project,"reports_collision");
generate_stage_a2_reports(testCase.TestData.context, ...
    'OutputDirectory',output,'FinalStatusCandidate','PASS');
verifyError(testCase,@()generate_stage_a2_reports(testCase.TestData.context, ...
    'OutputDirectory',output,'FinalStatusCandidate','PASS'), ...
    "stageA2:report:ArtifactExists");
end

function testMinimalFailureReportRequiresNoNumericalArtifacts(testCase)
context=create_synthetic_context(testCase,"A2_FAILURE_REPORT_RUN");
acceptance=initialize_stage_a2_acceptance(testCase.TestData.root);
for row=1:height(acceptance)
    acceptance=set_stage_a2_acceptance_result(acceptance, ...
        acceptance.test_id(row),"BLOCKED","not run","dependency blocked", ...
        "run_manifest.json");
end
exception=MException("stageA2:test:Failure","synthetic catch-path failure");
pathValue=generate_stage_a2_failure_report(context,exception, ...
    new_stage_a2_issue_log(),acceptance);
verifyTrue(testCase,isfile(pathValue));
[valid,details]=validate_docx_package(pathValue);
verifyTrue(testCase,valid,strjoin(details.errors,"; "));
verifyTrue(testCase,contains(details.document_text,"synthetic catch-path failure"));
verifyTrue(testCase,contains(details.document_text,"不宣告 Stage A2 通过"));
end

function context = create_synthetic_context(testCase,runId)
metadata=struct("newton_direction_count",1,"optimization_executed",false, ...
    "full_ipm_executed",false,"parallel_executed",false, ...
    "a2_solver_executed",false);
context=create_run_context(testCase.TestData.project,"stage_A2", ...
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
function close_if_open(fileId)
try, if ischar(fopen(fileId)), fclose(fileId); end, catch, end
end
function remove_tree(pathValue)
if isfolder(pathValue), rmdir(pathValue,'s'); end
end
