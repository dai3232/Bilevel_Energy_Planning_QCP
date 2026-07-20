function tests = test_stage_a2_artifacts
%TEST_STAGE_A2_ARTIFACTS Verify strict, non-overwriting A2 evidence.
tests=functiontests(localfunctions);
end

function setupOnce(testCase)
root=string(fileparts(fileparts(fileparts(mfilename('fullpath')))));
originalPath=path; addpath(genpath(fullfile(root,"src")));
testCase.addTeardown(@()path(originalPath));
config=load_stage_a2_configuration(root); data=load_project_data(root);
index=build_stage_a2_index(data,"RunId","A2_ARTIFACT_TEST");
verification=run_stage_a2_direction_verification(data,index,config);
temporaryProject=string(tempname(tempdir)); mkdir(temporaryProject);
testCase.addTeardown(@()remove_tree(temporaryProject));
context=create_run_context(temporaryProject,"stage_A2", ...
    "RunId","stage_A2_artifact_integration");
exported=export_stage_a2_artifacts(context,data,index,config, ...
    verification.linearization,verification.direct,verification.recursive, ...
    verification.audit);
testCase.TestData=struct("root",root,"config",config,"data",data, ...
    "index",index,"verification",verification,"project",temporaryProject, ...
    "context",context,"exported",exported);
end

function testRequiredSparseArtifactsAndDimensions(testCase)
p=testCase.TestData.exported.paths;
required=[string(p.linearization_mat);string(p.full_kkt_mat); ...
    string(p.recursive_blocks_mat);string(p.directions_mat); ...
    string(p.residuals_mat);string(p.index_mapping_mat); ...
    string(p.configuration_mat);string(p.matrix_manifest); ...
    string(p.block_dimensions);string(p.block_diagnostics); ...
    string(p.fixed_zero_map);string(p.fixed_zero_recovery_audit); ...
    string(p.renewable_activity);string(p.soc_boundary_audit); ...
    string(p.direction_comparison);string(p.residual_summary); ...
    string(p.code_scan);string(p.linearization_identity); ...
    string(p.artifact_hashes);p.hour_D_triplets];
verifyTrue(testCase,all(isfile(required)));
fullArtifact=load(p.full_kkt_mat); recursive=load(p.recursive_blocks_mat);
verifyTrue(testCase,issparse(fullArtifact.kkt.matrix));
verifyEqual(testCase,size(fullArtifact.kkt.matrix),[2749 2749]);
verifyTrue(testCase,issparse(recursive.partition.M));
verifyEqual(testCase,size(recursive.partition.M),[589 589]);
verifyEqual(testCase,size(recursive.day_response.S),[14 14]);
verifyEqual(testCase,size(recursive.core.matrix),[16 16]);
verifyFalse(testCase,isfile(fullfile(testCase.TestData.context.matrices_dir, ...
    "full_kkt_triplets.csv")));
verifyFalse(testCase,isfile(fullfile(testCase.TestData.context.matrices_dir, ...
    "hour_chain_M_triplets.csv")));
end

function testNaturalBlocksAndDiagnostics(testCase)
p=testCase.TestData.exported.paths;
dimensions=readtable(p.block_dimensions,"TextType","string");
expected=[repmat(22,7,1);repmat(27,11,1);26;repmat(22,4,1);24];
verifyEqual(testCase,dimensions.hour,(1:24)');
verifyEqual(testCase,dimensions.kkt_dimension,expected);
verifyEqual(testCase,sum(dimensions.kkt_dimension),589);
verifyTrue(testCase,all(string(dimensions.status)=="PASS"));
diagnostics=readtable(p.block_diagnostics,"TextType","string");
verifyEqual(testCase,height(diagnostics),24);
verifyEqual(testCase,diagnostics.rhs_count,repmat(15,24,1));
verifyTrue(testCase,all(string(diagnostics.status)=="PASS"));
manifest=readtable(p.matrix_manifest,"TextType","string");
fullRow=manifest(string(manifest.matrix_name)=="full_kkt",:);
chainRow=manifest(string(manifest.matrix_name)=="hour_chain_M",:);
verifyEqual(testCase,[fullRow.rows fullRow.columns],[2749 2749]);
verifyEqual(testCase,[chainRow.rows chainRow.columns],[589 589]);
verifyEqual(testCase,nnz(startsWith(string(manifest.matrix_name),"hour_") & ...
    endsWith(string(manifest.matrix_name),"_D")),24);
end

function testFixedZeroActivityAndSocEvidence(testCase)
p=testCase.TestData.exported.paths;
fixed=readtable(p.fixed_zero_map,"TextType","string");
verifyEqual(testCase,height(fixed),61);
verifyEqual(testCase,nnz(string(fixed.asset_type)=="solar"),60);
wind=fixed(string(fixed.asset_type)=="wind",:);
verifyEqual(testCase,height(wind),1); verifyEqual(testCase,wind.hour,19);
verifyEqual(testCase,wind.asset_id,3);
verifyTrue(testCase,all(fixed.fixed_value==0));
verifyTrue(testCase,all(fixed.fixed_direction_value==0));
recovery=readtable(p.fixed_zero_recovery_audit,"TextType","string");
verifyEqual(testCase,height(recovery),61);
verifyTrue(testCase,all(recovery.recovered_value==0));
verifyTrue(testCase,all(recovery.recovered_direction==0));
verifyTrue(testCase,all(string(recovery.status)=="PASS"));
activity=readtable(p.renewable_activity,"TextType","string");
verifyEqual(testCase,height(activity),240);
verifyEqual(testCase,nnz(to_logical(activity.exact_zero)),61);
verifyTrue(testCase,all(string(activity.status)=="PASS"));
soc=readtable(p.soc_boundary_audit,"TextType","string");
verifyEqual(testCase,height(soc),50);
verifyTrue(testCase,all(string(soc.status)=="PASS"));
verifyEqual(testCase,nnz(startsWith(string(soc.check_id),"SOC-END-H24")),2);
verifyEqual(testCase,nnz(contains(string(soc.check_id),"H10") & ...
    startsWith(string(soc.check_id),"SOC-END")),0);
end

function testComparisonResidualIdentityAndScan(testCase)
p=testCase.TestData.exported.paths;
comparison=readtable(p.direction_comparison,"TextType","string");
residual=readtable(p.residual_summary,"TextType","string");
scan=readtable(p.code_scan,"TextType","string");
verifyTrue(testCase,all(string(comparison.status)=="PASS"));
verifyTrue(testCase,all(string(residual.status)=="PASS"));
verifyTrue(testCase,all(string(scan.status)=="PASS"));
identity=jsondecode(fileread(p.linearization_identity));
verifyTrue(testCase,identity.all_identities_equal);
verifyEqual(testCase,identity.shared_linearization_object_count,1);
verifyEqual(testCase,identity.full_kkt_dimension,2749);
verifyEqual(testCase,identity.hourly_chain_dimension,589);
verifyEqual(testCase,identity.fixed_zero_count,61);
end

function testExecutionAndCommandMarkersAreOneWay(testCase)
metadata=struct("a2_solver_executed",false,"newton_direction_count",1, ...
    "full_ipm_executed",false,"parallel_executed",false, ...
    "optimization_executed",false, ...
    "actual_test_command","NOT_EXECUTED_EXTERNAL_OR_PRETEST_BLOCK");
context=create_run_context(testCase.TestData.project,"stage_A2", ...
    "RunId","stage_A2_execution_marker","ManifestMetadata",metadata);
manifest=mark_stage_a2_solver_execution(context);
verifyTrue(testCase,manifest.a2_solver_executed);
manifest=record_stage_a2_test_command(context,"run_stage_A2_tests()", ...
    "run_stage_A1_tests()");
verifyEqual(testCase,string(manifest.actual_test_command.stage_a2), ...
    "run_stage_A2_tests()");
verifyEqual(testCase,string(manifest.actual_test_command.stage_a1_regression), ...
    "run_stage_A1_tests()");
verifyError(testCase,@()mark_stage_a2_solver_execution(context), ...
    "stageA2:artifacts:SolverExecutionAlreadyMarked");
verifyError(testCase,@()record_stage_a2_test_command(context,"x","y"), ...
    "stageA2:artifacts:TestCommandAlreadyRecorded");
end

function testNonOverwriteAndEvidenceHashes(testCase)
verifyError(testCase,@()export_again(testCase), ...
    "stageA2:artifacts:TargetExists");
reports=testCase.TestData.context.reports_dir;
write_bytes(fullfile(reports,"阶段A2_完整24小时方向等价与变维结构报告.docx"));
write_bytes(fullfile(reports,"阶段A2_问题修复与验收报告.docx"));
write_bytes(fullfile(reports,"运行_stage_A2_artifact_integration_结果摘要.docx"));
evidence=write_stage_a2_evidence_hashes(testCase.TestData.context);
verifyTrue(testCase,all(evidence.status=="PASS"));
verifyEqual(testCase,nnz(evidence.scope=="reports"),3);
verifyError(testCase,@()write_stage_a2_evidence_hashes( ...
    testCase.TestData.context),"stageA2:artifacts:RefuseOverwrite");
end

function export_again(testCase)
v=testCase.TestData.verification;
export_stage_a2_artifacts(testCase.TestData.context,testCase.TestData.data, ...
    testCase.TestData.index,testCase.TestData.config,v.linearization, ...
    v.direct,v.recursive,v.audit);
end

function write_bytes(pathValue)
fileId=fopen(pathValue,'wb'); assert(fileId>=0);
guard=onCleanup(@()close_if_open(fileId)); fwrite(fileId,uint8('test'),'uint8');
fclose(fileId); clear guard;
end
function close_if_open(fileId)
try, if ischar(fopen(fileId)), fclose(fileId); end, catch, end
end
function remove_tree(pathValue)
if isfolder(pathValue), rmdir(pathValue,'s'); end
end

function values = to_logical(raw)
if islogical(raw), values=raw; return; end
if isnumeric(raw), values=raw~=0; return; end
values=lower(strip(string(raw)))=="true" | strip(string(raw))=="1";
end
