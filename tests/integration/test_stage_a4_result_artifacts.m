function tests = test_stage_a4_result_artifacts
%TEST_STAGE_A4_RESULT_ARTIFACTS Verify final A4 physical-result export.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
projectRoot = string(fileparts(fileparts(fileparts( ...
    mfilename('fullpath')))));
originalPath = path;
addpath(genpath(fullfile(projectRoot,"src")));
testCase.addTeardown(@()path(originalPath));

data = load_project_data(projectRoot);
config = load_stage_a4_configuration(projectRoot);
index = build_stage_a4_index(data,"RunId","A4_RESULT_ARTIFACT_TEST");
state = initialize_stage_a4_state(data,index,config);

temporaryProject = string(tempname(tempdir));
mkdir(temporaryProject);
testCase.addTeardown(@()remove_tree(temporaryProject));
runRoot = fullfile(temporaryProject,"runs","A4_RESULT_ARTIFACT_TEST");
acceptanceDirectory = fullfile(runRoot,"acceptance");
mkdir(acceptanceDirectory);
manifestPath = fullfile(runRoot,"run_manifest.json");
write_json_file(manifestPath,struct( ...
    "run_id","A4_RESULT_ARTIFACT_TEST", ...
    "stage_id","stage_A4","status","RUNNING"));
context = struct( ...
    "root",char(runRoot), ...
    "run_id","A4_RESULT_ARTIFACT_TEST", ...
    "stage_id","stage_A4", ...
    "acceptance_dir",char(acceptanceDirectory), ...
    "run_manifest_path",char(manifestPath));
audit = physical_audit_fixture();
exported = export_stage_a4_result_artifacts( ...
    context,data,index,state,audit,SolvePass="pass_1");

testCase.TestData = struct( ...
    "project_root",projectRoot, ...
    "temporary_project",temporaryProject, ...
    "data",data,"index",index,"state",state, ...
    "context",context,"audit",audit,"exported",exported);
end

function testWritesCanonicalCapacityAndHourlyResultTables(testCase)
exported = testCase.TestData.exported;
paths = exported.paths;
required = [string(paths.capacity_results); ...
    string(paths.hourly_dispatch_results); ...
    string(paths.physical_results_mat); ...
    string(paths.physical_audit); ...
    string(paths.result_artifact_hashes)];
verifyTrue(testCase,all(isfile(required)));

capacity = readtable(paths.capacity_results,"TextType","string");
verifyEqual(testCase,height(capacity),14);
verifyEqual(testCase,string(capacity.capacity_name), ...
    ["QW1";"QW2";"QW3";"QW4";"QW5"; ...
    "QP1";"QP2";"QP3";"QP4";"QP5"; ...
    "QS1";"QS2";"ES1";"ES2"]);
verifyEqual(testCase,string(capacity.unit), ...
    [repmat("MW",12,1);repmat("MWh",2,1)]);
verifyTrue(testCase,all(string(capacity.status)=="PASS"));
verifyTrue(testCase,all(capacity.value>=capacity.lower_bound));
verifyTrue(testCase,all(capacity.value<=capacity.upper_bound));
verifyLessThanOrEqual(testCase, ...
    max(capacity.maximum_daily_copy_absolute_difference),1.0e-8);

hourly = readtable(paths.hourly_dispatch_results,"TextType","string");
verifyEqual(testCase,height(hourly),4032);
verifyEqual(testCase,unique(hourly.day),(14:20).');
verifyEqual(testCase,unique(hourly.hour),(1:24).');
verifyEqual(testCase,group_count(hourly,"PW"),840);
verifyEqual(testCase,group_count(hourly,"PP"),840);
verifyEqual(testCase,group_count(hourly,"PH"),672);
verifyEqual(testCase,group_count(hourly,"PF"),672);
verifyEqual(testCase,group_count(hourly,"Pch"),336);
verifyEqual(testCase,group_count(hourly,"Pdis"),336);
verifyEqual(testCase,group_count(hourly,"SOC"),336);
verifyTrue(testCase,all(string(hourly.status)=="PASS"));
end

function testFixedZeroAndStorageSignConventionsAreExplicit(testCase)
hourly = testCase.TestData.exported.hourly_dispatch_results;
fixed = hourly.fixed_zero;
verifyEqual(testCase,nnz(fixed),422);
verifyTrue(testCase,all(hourly.value(fixed)==0));
verifyTrue(testCase,all(hourly.fixed_zero_exact(fixed)));
verifyTrue(testCase,all(hourly.bound_violation(fixed)==0));

charge = hourly.variable_name=="Pch";
discharge = hourly.variable_name=="Pdis";
soc = hourly.variable_name=="SOC";
verifyTrue(testCase,all(hourly.power_balance_coefficient(charge)==-1));
verifyTrue(testCase,all(hourly.power_balance_coefficient(discharge)==1));
verifyTrue(testCase,all(hourly.power_balance_coefficient(soc)==0));
verifyTrue(testCase,all(hourly.energy_mwh(soc)==0));
end

function testMatAuditAndHashesTraceThePersistedArtifacts(testCase)
exported = testCase.TestData.exported;
payload = load(exported.paths.physical_results_mat);
verifyTrue(testCase,all(isfield(payload,cellstr([ ...
    "final_state","physical","capacity_results", ...
    "hourly_dispatch_results","physical_audit"]))));
verifyEqual(testCase,payload.physical.fixed_zero_audit.count,422);
verifyTrue(testCase,payload.physical.fixed_zero_audit.values_exact_zero);

audit = readtable(exported.paths.physical_audit,"TextType","string");
verifyEqual(testCase,string(audit.run_id), ...
    repmat("A4_RESULT_ARTIFACT_TEST",height(audit),1));
verifyEqual(testCase,string(audit.stage_id), ...
    repmat("stage_A4",height(audit),1));
verifyEqual(testCase,string(audit.solve_pass), ...
    repmat("pass_1",height(audit),1));

hashes = readtable(exported.paths.result_artifact_hashes, ...
    "TextType","string");
verifyEqual(testCase,height(hashes),4);
verifyTrue(testCase,all(strlength(string(hashes.sha256))==64));
verifyTrue(testCase,all(string(hashes.status)=="PASS"));
for row = 1:height(hashes)
    target = fullfile(testCase.TestData.context.root, ...
        replace(string(hashes.relative_path(row)),"/",filesep));
    verifyTrue(testCase,isfile(target));
    verifyEqual(testCase,compute_sha256_file(target), ...
        string(hashes.sha256(row)));
end
end

function testRefusesOverwriteAndInvalidFinalState(testCase)
verifyError(testCase,@()export_again(testCase), ...
    "stageA4:artifacts:TargetExists");
invalidState = testCase.TestData.state;
invalidState.xi(end) = [];
verifyError(testCase,@()export_stage_a4_result_artifacts( ...
    testCase.TestData.context,testCase.TestData.data, ...
    testCase.TestData.index,invalidState,testCase.TestData.audit), ...
    "stageA4:artifacts:FinalState");
end

function exported = export_again(testCase)
exported = export_stage_a4_result_artifacts( ...
    testCase.TestData.context,testCase.TestData.data, ...
    testCase.TestData.index,testCase.TestData.state, ...
    testCase.TestData.audit,SolvePass="pass_1");
end

function count = group_count(tableValue,variableName)
count = nnz(string(tableValue.variable_name)==variableName);
end

function audit = physical_audit_fixture()
audit_id = ["POWER_BALANCE";"SOC_DYNAMICS";"SOC_BOUNDARIES"; ...
    "CAPACITY_BOUNDS";"OUTPUT_BOUNDS";"FIXED_ZERO"];
requirement = ["小时功率平衡";"SOC逐小时递推";"每日初末0.5E"; ...
    "容量上下界";"物理出力上下界";"固定零精确恢复"];
actual_value = zeros(6,1);
threshold = repmat(1.0e-8,6,1);
status = repmat("PASS",6,1);
evidence_path = repmat("results/hourly_dispatch_results.csv",6,1);
audit = table(audit_id,requirement,actual_value,threshold,status, ...
    evidence_path);
end

function remove_tree(pathValue)
if isfolder(pathValue), rmdir(pathValue,'s'); end
end
