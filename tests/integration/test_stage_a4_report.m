function tests = test_stage_a4_report
%TEST_STAGE_A4_REPORT Verify artifact-only A4 report generation and gates.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
project = string(tempname); mkdir(project);
guard = onCleanup(@()remove_tree(project));
runRoot = fullfile(project,"runs","A4_REPORT_FIXTURE");
mkdir(runRoot);
for folder = ["acceptance","issues","iterations","results", ...
        "matrices","checkpoints","tests","reports"]
    mkdir(fullfile(runRoot,folder));
end
context = struct( ...
    "root",char(runRoot),"project_root",char(project), ...
    "run_id","A4_REPORT_FIXTURE","stage_id","stage_A4");
write_valid_evidence(runRoot);
testCase.TestData.project = project;
testCase.TestData.runRoot = runRoot;
testCase.TestData.context = context;
testCase.TestData.guard = guard;
end

function teardownOnce(testCase)
if isfield(testCase.TestData,"guard")
    clear testCase.TestData.guard;
end
if isfield(testCase.TestData,"project")
    remove_tree(testCase.TestData.project);
end
end

function testGeneratesThreeValidatedArtifactBackedReports(testCase)
output = fullfile(testCase.TestData.project,"generated_final");
[paths,audit] = rkkt.reporting.generate_stage_a4_reports( ...
    testCase.TestData.context,OutputDirectory=output, ...
    FinalStatusCandidate="PASS",ReportGateMode="final");
verifyEqual(testCase,sort(string(fieldnames(paths))), ...
    sort(["model_report";"issue_report";"run_summary"]));
verifyTrue(testCase,all(audit.status=="PASS"));
verifyEqual(testCase,string(audit.visual_qa_status), ...
    repmat("NOT_RUN_EXTERNAL_GATE",3,1));
verifyEqual(testCase,string(audit.relative_name),[ ...
    "阶段A4_模型与优化结果报告.docx"; ...
    "阶段A4_问题修复与验收报告.docx"; ...
    "运行_A4_REPORT_FIXTURE_结果摘要.docx"]);

names = fieldnames(paths);
for k = 1:numel(names)
    verifyTrue(testCase,isfile(paths.(names{k})));
    [valid,details] = rkkt.reporting.validate_docx_package(paths.(names{k}));
    verifyTrue(testCase,valid,strjoin(details.errors,"; "));
    verifyTrue(testCase,contains(details.document_text, ...
        "A4_REPORT_FIXTURE"));
    verifyTrue(testCase,contains(details.document_text,"STAGE A4"));
    rows = regexp(char(details.document_xml), ...
        '(?s)<w:tr>.*?</w:tr>','match');
    verifyNotEmpty(testCase,rows);
    verifyTrue(testCase,all(cellfun( ...
        @(value)contains(value,'<w:cantSplit/>'),rows)));
end

[~,model] = rkkt.reporting.validate_docx_package(paths.model_report);
verifyTrue(testCase,contains(model.document_text, ...
    "results/hourly_dispatch_results.csv"));
for name = ["QW1","QP5","QS2","ES2"]
    verifyTrue(testCase,contains(model.document_text,name));
end
verifyTrue(testCase,contains(model.styles_xml, ...
    'w:styleId="Heading1"'));
verifyTrue(testCase,contains(model.styles_xml, ...
    'w:before="320" w:after="160" w:line="264"'));
verifyTrue(testCase,contains(model.document_xml, ...
    'w:w="12240" w:h="15840"'));
verifyTrue(testCase,contains(model.document_xml, ...
    '<w:tblW w:w="9360" w:type="dxa"/>'));
end

function testSupportsReportGatePreflightButFinalRequiresPass(testCase)
pathValue = fullfile(testCase.TestData.runRoot, ...
    "acceptance","acceptance_results.csv");
original = fileread(pathValue);
guard = onCleanup(@()write_text(pathValue,original));
value = readtable(pathValue,"TextType","string");
value.status(value.test_id=="SA4-RPT-001") = "NOT_RUN";
rkkt.artifacts.write_table_csv_17g(pathValue,value);

verifyError(testCase,@()rkkt.reporting.generate_stage_a4_reports( ...
    testCase.TestData.context, ...
    OutputDirectory=fullfile(testCase.TestData.project,"final_rejected"), ...
    ReportGateMode="final"), ...
    "stageA4:report:ReportGateNotPassed");
[paths,audit] = rkkt.reporting.generate_stage_a4_reports( ...
    testCase.TestData.context, ...
    OutputDirectory=fullfile(testCase.TestData.project,"preflight"), ...
    ReportGateMode="preflight");
verifyTrue(testCase,all(audit.status=="PASS"));
[~,details] = rkkt.reporting.validate_docx_package(paths.run_summary);
verifyTrue(testCase,contains(details.document_text, ...
    "PENDING_REPORT_GATE"));
clear guard;
write_text(pathValue,original);
end

function testRejectsNoncanonicalCapacityEvidence(testCase)
pathValue = fullfile(testCase.TestData.runRoot, ...
    "results","capacity_results.csv");
original = fileread(pathValue);
guard = onCleanup(@()write_text(pathValue,original));
value = readtable(pathValue,"TextType","string");
value.capacity_name(14) = "WRONG";
rkkt.artifacts.write_table_csv_17g(pathValue,value);
verifyError(testCase,@()rkkt.reporting.generate_stage_a4_reports( ...
    testCase.TestData.context, ...
    OutputDirectory=fullfile(testCase.TestData.project,"bad_capacity")), ...
    "stageA4:report:CapacityEvidence");
clear guard;
write_text(pathValue,original);
end

function testRejectsIncompleteHourlyScope(testCase)
pathValue = fullfile(testCase.TestData.runRoot, ...
    "results","hourly_dispatch_results.csv");
original = fileread(pathValue);
guard = onCleanup(@()write_text(pathValue,original));
value = readtable(pathValue,"TextType","string");
value(end,:) = [];
rkkt.artifacts.write_table_csv_17g(pathValue,value);
verifyError(testCase,@()rkkt.reporting.generate_stage_a4_reports( ...
    testCase.TestData.context, ...
    OutputDirectory=fullfile(testCase.TestData.project,"bad_hourly")), ...
    "stageA4:report:HourlyEvidence");
clear guard;
write_text(pathValue,original);
end

function testRejectsFailedDirectionAndPhysicalEvidence(testCase)
directionPath = fullfile(testCase.TestData.runRoot, ...
    "iterations","direction_audit.csv");
originalDirection = fileread(directionPath);
guardDirection = onCleanup(@()write_text(directionPath,originalDirection));
direction = readtable(directionPath,"TextType","string");
direction.direction_relative_error(2) = 1e-5;
rkkt.artifacts.write_table_csv_17g(directionPath,direction);
verifyError(testCase,@()rkkt.reporting.generate_stage_a4_reports( ...
    testCase.TestData.context, ...
    OutputDirectory=fullfile(testCase.TestData.project,"bad_direction")), ...
    "stageA4:report:DirectionThreshold");
clear guardDirection;
write_text(directionPath,originalDirection);

physicalPath = fullfile(testCase.TestData.runRoot, ...
    "acceptance","physical_audit.csv");
originalPhysical = fileread(physicalPath);
guardPhysical = onCleanup(@()write_text(physicalPath,originalPhysical));
physical = readtable(physicalPath,"TextType","string");
physical.status(1) = "FAIL";
rkkt.artifacts.write_table_csv_17g(physicalPath,physical);
verifyError(testCase,@()rkkt.reporting.generate_stage_a4_reports( ...
    testCase.TestData.context, ...
    OutputDirectory=fullfile(testCase.TestData.project,"bad_physical")), ...
    "stageA4:report:PhysicalEvidence");
clear guardPhysical;
write_text(physicalPath,originalPhysical);
end

function testGeneratesTruthfulReportsForFailedRun(testCase)
root = testCase.TestData.runRoot;
acceptancePath = fullfile(root,"acceptance","acceptance_results.csv");
iterationPath = fullfile(root,"iterations","iteration_summary.csv");
directionPath = fullfile(root,"iterations","direction_audit.csv");
physicalPath = fullfile(root,"acceptance","physical_audit.csv");
testPath = fullfile(root,"tests","test_summary.json");
issuePath = fullfile(root,"issues","issue_log.csv");
paths = [acceptancePath;iterationPath;directionPath; ...
    physicalPath;testPath;issuePath];
original = arrayfun(@fileread,paths,'UniformOutput',false);
guard = onCleanup(@()restore_files(paths,original));

acceptance = readtable(acceptancePath,"TextType","string");
acceptance.status(1) = "FAIL";
acceptance.status(7) = "NOT_RUN";
rkkt.artifacts.write_table_csv_17g(acceptancePath,acceptance);
iterations = readtable(iterationPath,"TextType","string");
iterations.r_eq_inf(end) = 1e-4;
iterations.convergence_passed(end) = false;
rkkt.artifacts.write_table_csv_17g(iterationPath,iterations);
direction = readtable(directionPath,"TextType","string");
direction.direction_relative_error(end) = 1e-7;
rkkt.artifacts.write_table_csv_17g(directionPath,direction);
physical = readtable(physicalPath,"TextType","string");
physical.actual_value(1) = 1e-4;
physical.status(1) = "FAIL";
rkkt.artifacts.write_table_csv_17g(physicalPath,physical);
rkkt.artifacts.write_json_file(testPath,struct( ...
    "test_total",10,"test_passed",9,"test_failed",1, ...
    "test_incomplete",0));
issues = table("ISSUE-A4-FAIL","SA4-CONV-001", ...
    "未满足收敛阈值","达到最大迭代次数","未伪造修复", ...
    "待后续重跑","OPEN", ...
    'VariableNames',{'issue_id','test_id','symptom','root_cause', ...
    'implemented_change','regression_test','status'});
rkkt.artifacts.write_table_csv_17g(issuePath,issues);

[reportPaths,audit] = rkkt.reporting.generate_stage_a4_reports( ...
    testCase.TestData.context, ...
    OutputDirectory=fullfile(testCase.TestData.project,"failed_run"), ...
    FinalStatusCandidate="FAIL_RETRYABLE",ReportGateMode="final");
verifyTrue(testCase,all(audit.status=="PASS"));
verifyTrue(testCase,isfile(reportPaths.model_report));
verifyTrue(testCase,isfile(reportPaths.issue_report));
verifyTrue(testCase,isfile(reportPaths.run_summary));
[~,details] = rkkt.reporting.validate_docx_package(reportPaths.run_summary);
verifyTrue(testCase,contains(details.document_text,"FAIL_RETRYABLE"));
verifyTrue(testCase,contains(details.document_text,"未将未通过门禁改写为 PASS"));
clear guard;
restore_files(paths,original);
end

function testRefusesOverwriteAndIncompleteReportSet(testCase)
output = fullfile(testCase.TestData.project,"collision");
paths = rkkt.reporting.generate_stage_a4_reports( ...
    testCase.TestData.context,OutputDirectory=output);
verifyError(testCase,@()rkkt.reporting.generate_stage_a4_reports( ...
    testCase.TestData.context,OutputDirectory=output), ...
    "stageA4:report:ArtifactExists");
incomplete = rmfield(paths,"run_summary");
verifyError(testCase,@()rkkt.reporting.validate_stage_a4_report_set( ...
    incomplete,"A4_REPORT_FIXTURE"), ...
    "stageA4:report:ReportSetSchema");
end

function write_valid_evidence(root)
manifest = struct( ...
    "run_id","A4_REPORT_FIXTURE","stage_id","stage_A4", ...
    "status","RUNNING","git_commit","0123456789abcdef", ...
    "thermal_pass","pass_1","day_ids",14:20, ...
    "optimization_executed",true,"full_ipm_executed",true, ...
    "parallel_executed",false, ...
    "physical_dispatch_interpretation",true, ...
    "capacity_planning_interpretation",true, ...
    "newton_direction_count",3, ...
    "enabled_components",["OBJ_INVEST","CON_POWER_BAL", ...
        "CON_SOC_DYN","CON_SOC_CLOSE","CON_DURATION", ...
        "CON_WIND_SOLAR","CON_HYDRO_HOURLY","CON_FIRE_PASS1", ...
        "CON_STORAGE_BOUNDS"], ...
    "disabled_components",["CON_HYDRO_WATER","CON_FIRE_PASS2", ...
        "CON_MIN_UP_DOWN","OBJ_START_STOP","PARALLEL"]);
rkkt.artifacts.write_json_file(fullfile(root,"run_manifest.json"),manifest);

environment = table( ...
    ["MATLAB_VERSION";"SPARSE_SOLVE"],[true;true], ...
    ["PASS";"PASS"], ...
    'VariableNames',{'check_id','blocking','status'});
rkkt.artifacts.write_table_csv_17g(fullfile(root,"environment.csv"),environment);
sha = ["aebb35fa80e6ba2fb8d4534b09a141feaedcb2b9d027e9924e7a0091943c4277"; ...
    "10baac1dc5d0b07dbbb9d2fe8f9aac82f071e43d4fb9901ff7ba0b467d05c186"];
inputHashes = table(["基础参数.xlsx";"输入数据.xlsx"],sha,sha, ...
    ["PASS";"PASS"], ...
    'VariableNames',{'file_name','expectedSHA256','actualSHA256','status'});
rkkt.artifacts.write_table_csv_17g(fullfile(root,"input_hashes.csv"),inputHashes);

test_id = ["SA4-CONV-001";"SA4-CONV-002";"SA4-CONV-003"; ...
    "SA4-CONV-004";"SA4-EQ-001";"SA4-PHY-001";"SA4-RPT-001"];
requirement = ["原始等式残差";"不等式可行性";"对偶残差"; ...
    "归一化互补间隙";"逐轮方向审计";"物理验收";"报告验收"];
actual_value = ["1e-10";"0";"1e-10";"1e-10"; ...
    "max=1e-12";"max=1e-10";"three DOCX structurally valid"];
threshold = ["<=1e-6";"<=1e-6";"<=1e-6";"<=1e-6"; ...
    "<=1e-6";"<=1e-8";"PASS"];
status = repmat("PASS",7,1);
blocking = true(7,1);
evidence_path = ["iterations/iteration_summary.csv"; ...
    "iterations/iteration_summary.csv"; ...
    "iterations/iteration_summary.csv"; ...
    "iterations/iteration_summary.csv"; ...
    "iterations/direction_audit.csv"; ...
    "acceptance/physical_audit.csv";"reports"];
acceptance = table(test_id,requirement,actual_value,threshold,status, ...
    blocking,evidence_path);
rkkt.artifacts.write_table_csv_17g(fullfile(root,"acceptance", ...
    "acceptance_results.csv"),acceptance);

audit_id = ["POWER_BALANCE";"SOC_DYNAMICS";"SOC_INITIAL"; ...
    "SOC_TERMINAL";"CAPACITY_BOUNDS";"OUTPUT_BOUNDS"; ...
    "STORAGE_BOUNDS";"FIXED_ZERO"];
physicalRequirement = ["小时功率平衡";"SOC递推";"每日初端0.5E"; ...
    "每日末端0.5E";"容量界";"机组出力界";"储能界";"固定零"];
physicalActual = [1e-10;1e-10;1e-10;1e-10;0;0;0;0];
physicalThreshold = repmat(1e-8,8,1);
physicalStatus = repmat("PASS",8,1);
physicalEvidence = repmat("results/hourly_dispatch_results.csv",8,1);
physical = table(audit_id,physicalRequirement,physicalActual, ...
    physicalThreshold,physicalStatus,physicalEvidence, ...
    'VariableNames',{'audit_id','requirement','actual_value', ...
    'threshold','status','evidence_path'});
rkkt.artifacts.write_table_csv_17g(fullfile(root,"acceptance","physical_audit.csv"),physical);

issues = table(strings(0,1),strings(0,1),strings(0,1), ...
    strings(0,1),strings(0,1),strings(0,1),strings(0,1), ...
    'VariableNames',{'issue_id','test_id','symptom','root_cause', ...
    'implemented_change','regression_test','status'});
rkkt.artifacts.write_table_csv_17g(fullfile(root,"issues","issue_log.csv"),issues);

iteration = (1:3).';
state_revision = iteration;
objective_scaled = [900;850;800];
objective_original = [4.0e9;3.8e9;3.7e9];
r_eq_inf = [1e-4;1e-7;1e-10];
r_ineq_inf = [0;0;0];
physical_inequality_violation = [0;0;0];
r_dual_scaled_inf = [1e-4;1e-7;1e-10];
r_dual_original_mapped_inf = r_dual_scaled_inf*4.92e6;
r_comp_scaled_inf = [1e-4;1e-7;1e-10];
mean_lz_scaled = [1e-4;1e-7;1e-10];
ltz_scaled = 1000*mean_lz_scaled;
gap_original_mapped = ltz_scaled*4.92e6;
eta_eq = r_eq_inf;
eta_dual = r_dual_scaled_inf;
eta_gap = mean_lz_scaled;
candidate_alpha_primal = [0.5;0.8;1.0];
applied_alpha_primal = candidate_alpha_primal;
candidate_alpha_dual = [0.4;0.7;1.0];
applied_alpha_dual = candidate_alpha_dual;
min_l = [0.4;0.2;0.1];
min_z = [0.3;0.1;0.01];
convergence_passed = [false;false;true];
iterations = table(iteration,state_revision,objective_scaled, ...
    objective_original,r_eq_inf,r_ineq_inf, ...
    physical_inequality_violation,r_dual_scaled_inf, ...
    r_dual_original_mapped_inf,r_comp_scaled_inf,mean_lz_scaled, ...
    ltz_scaled,gap_original_mapped,eta_eq,eta_dual,eta_gap, ...
    candidate_alpha_primal,applied_alpha_primal, ...
    candidate_alpha_dual,applied_alpha_dual,min_l,min_z, ...
    convergence_passed);
rkkt.artifacts.write_table_csv_17g(fullfile(root,"iterations","iteration_summary.csv"), ...
    iterations);

small = [1e-12;2e-12;3e-12];
no_full_direction_fallback = true(3,1);
full_kkt_audit_only = true(3,1);
recursive_direction_is_official = true(3,1);
direction = table(iteration,small,small,small,small,small,small,small, ...
    no_full_direction_fallback,full_kkt_audit_only, ...
    recursive_direction_is_official, ...
    'VariableNames',{'iteration','direction_relative_error', ...
    'xi_relative_error','y_relative_error','l_relative_error', ...
    'z_relative_error','recursive_full_kkt_relative_residual', ...
    'full_kkt_relative_residual','no_full_direction_fallback', ...
    'full_kkt_audit_only','recursive_direction_is_official'});
rkkt.artifacts.write_table_csv_17g(fullfile(root,"iterations","direction_audit.csv"), ...
    direction);

capacityNames = ["QW1";"QW2";"QW3";"QW4";"QW5"; ...
    "QP1";"QP2";"QP3";"QP4";"QP5";"QS1";"QS2";"ES1";"ES2"];
capacityUnit = [repmat("MW",12,1);repmat("MWh",2,1)];
capacityValue = (101:114).';
capacityLower = (1:14).';
capacityUpper = capacityValue+100;
investment = capacityValue*1000;
capacityStatus = repmat("PASS",14,1);
capacity = table(capacityNames,capacityUnit,capacityValue, ...
    capacityLower,capacityUpper,investment,capacityStatus, ...
    'VariableNames',{'capacity_name','unit','value','lower_bound', ...
    'upper_bound','investment_cost_yuan','status'});
rkkt.artifacts.write_table_csv_17g(fullfile(root,"results","capacity_results.csv"),capacity);

hourly = synthetic_hourly();
rkkt.artifacts.write_table_csv_17g(fullfile(root,"results", ...
    "hourly_dispatch_results.csv"),hourly);
hashPath = ["results/capacity_results.csv"; ...
    "results/hourly_dispatch_results.csv"; ...
    "results/physical_results.mat";"acceptance/physical_audit.csv"];
hashStatus = repmat("PASS",4,1);
hashes = table(hashPath,hashStatus, ...
    'VariableNames',{'relative_path','status'});
rkkt.artifacts.write_table_csv_17g(fullfile(root,"results", ...
    "result_artifact_hashes.csv"),hashes);

matrix_name = ["full_kkt";"reduced_saddle";"global_core"];
rows = [18836;4340;16]; columns = rows; nnzValue = [1;1;1];
matrices = table(matrix_name,rows,columns,nnzValue, ...
    'VariableNames',{'matrix_name','rows','columns','nnz'});
rkkt.artifacts.write_table_csv_17g(fullfile(root,"matrices","matrix_manifest.csv"),matrices);
checkpoints = table("A4_REPORT_FIXTURE","stage_A4",3, ...
    "checkpoints/final.mat",string(repmat('a',1,64)), ...
    'VariableNames',{'run_id','stage_id','iteration','path','sha256'});
rkkt.artifacts.write_table_csv_17g(fullfile(root,"checkpoints", ...
    "checkpoint_manifest.csv"),checkpoints);
rkkt.artifacts.write_json_file(fullfile(root,"tests","test_summary.json"),struct( ...
    "test_total",10,"test_passed",10,"test_failed",0, ...
    "test_incomplete",0));
end

function value = synthetic_hourly()
variables = [repmat("PW",5,1);repmat("PP",5,1); ...
    repmat("PH",4,1);repmat("PF",4,1); ...
    repmat("Pch",2,1);repmat("Pdis",2,1);repmat("SOC",2,1)];
assets = [(1:5).';(1:5).';(1:4).';(1:4).'; ...
    (1:2).';(1:2).';(1:2).'];
n = 7*24*numel(variables);
day = zeros(n,1); hour = zeros(n,1); variable_name = strings(n,1);
asset_id = zeros(n,1); numericValue = ones(n,1);
energy_mwh = ones(n,1); fixed_zero = false(n,1);
fixed_zero_exact = true(n,1); status = repmat("PASS",n,1);
row = 0;
for dayId = 14:20
    for hourId = 1:24
        for k = 1:numel(variables)
            row = row+1; day(row)=dayId; hour(row)=hourId;
            variable_name(row)=variables(k); asset_id(row)=assets(k);
            if variables(k)=="SOC", energy_mwh(row)=0; end
            if variables(k)=="PW"&&assets(k)==1&&mod(hourId,2)==0
                fixed_zero(row)=true; numericValue(row)=0;
                energy_mwh(row)=0;
            end
        end
    end
end
value = table(day,hour,variable_name,asset_id,numericValue, ...
    energy_mwh,fixed_zero,fixed_zero_exact,status, ...
    'VariableNames',{'day','hour','variable_name','asset_id','value', ...
    'energy_mwh','fixed_zero','fixed_zero_exact','status'});
end

function write_text(pathValue,textValue)
[fileId,message] = fopen(pathValue,'wb','n','UTF-8');
assert(fileId>=0,"stageA4:test:WriteText","%s",message);
guard = onCleanup(@()close_if_open(fileId));
bytes = unicode2native(char(textValue),'UTF-8');
fwrite(fileId,bytes,'uint8');
fclose(fileId); clear guard;
end

function restore_files(paths,contents)
for k = 1:numel(paths)
    write_text(paths(k),contents{k});
end
end

function close_if_open(fileId)
try
    if ischar(fopen(fileId)), fclose(fileId); end
catch
end
end

function remove_tree(pathValue)
if isfolder(pathValue), rmdir(pathValue,'s'); end
end
