function tests = test_stage_a3_artifacts
%TEST_STAGE_A3_ARTIFACTS Verify strict, non-overwriting A3 evidence.
tests=functiontests(localfunctions);
end

function setupOnce(testCase)
root=string(fileparts(fileparts(fileparts(mfilename('fullpath')))));
originalPath=path; addpath(genpath(fullfile(root,"src")));
testCase.addTeardown(@()path(originalPath));
config=load_stage_a3_configuration(root); data=load_project_data(root);
index=build_stage_a3_index(data,"RunId","A3_ARTIFACT_TEST");
verification=run_stage_a3_direction_verification(data,index,config);
temporaryProject=string(tempname(tempdir)); mkdir(temporaryProject);
testCase.addTeardown(@()remove_tree(temporaryProject));
metadata=struct("a3_solver_executed",true,"newton_direction_count",1, ...
    "full_ipm_executed",false,"parallel_executed",false, ...
    "optimization_executed",false, ...
    "actual_test_command","NOT_EXECUTED_EXTERNAL_OR_PRETEST_BLOCK");
context=create_run_context(temporaryProject,"stage_A3", ...
    "RunId","stage_A3_artifact_integration","ManifestMetadata",metadata);
exported=export_stage_a3_artifacts(context,data,index,config, ...
    verification.linearization,verification.direct,verification.recursive, ...
    verification.audit,Physical=verification.physical);
testCase.TestData=struct("root",root,"config",config,"data",data, ...
    "index",index,"verification",verification,"project",temporaryProject, ...
    "context",context,"exported",exported);
end

function testRequiredSparseArtifactsAndDimensions(testCase)
p=testCase.TestData.exported.paths;
required=[string(p.linearization_mat);string(p.full_kkt_mat); ...
    string(p.daily_recursive_mat);string(p.daily_responses_mat); ...
    string(p.daily_aggregation_mat);string(p.directions_mat); ...
    string(p.reduced_system_mat); ...
    string(p.physical_recovery_mat);string(p.residuals_mat); ...
    string(p.index_mapping_mat);string(p.configuration_mat); ...
    string(p.matrix_manifest);string(p.block_dimensions); ...
    string(p.daily_chain_dimensions);string(p.daily_response_summary); ...
    string(p.daily_aggregation_audit);string(p.fixed_zero_map); ...
    string(p.permutation_map);string(p.canonical_index_map); ...
    string(p.fixed_zero_recovery_audit);string(p.soc_boundary_audit); ...
    string(p.direction_comparison);string(p.residual_summary); ...
    string(p.code_scan);string(p.linearization_identity); ...
    string(p.core_triplets);string(p.aggregated_response_triplets); ...
    string(p.day_response_triplets);string(p.artifact_hashes)];
verifyTrue(testCase,all(isfile(required)));
fullArtifact=load(p.full_kkt_mat); daily=load(p.daily_recursive_mat);
aggregate=load(p.daily_aggregation_mat);
reduced=load(p.reduced_system_mat);
verifyTrue(testCase,issparse(fullArtifact.kkt.matrix));
verifyEqual(testCase,size(fullArtifact.kkt.matrix),[18836 18836]);
verifyEqual(testCase,size(reduced.W),[3722 3722]);
verifyEqual(testCase,size(reduced.saddle),[4340 4340]);
verifyTrue(testCase,issparse(reduced.W)&&issparse(reduced.saddle));
verifyEqual(testCase,numel(daily.daily_partitions),7);
verifyEqual(testCase,reshape(arrayfun(@(x)size(x.M,1), ...
    daily.daily_partitions),1,[]), ...
    [589 590 589 590 590 590 590]);
verifyEqual(testCase,size(aggregate.aggregation.S_sum),[14 14]);
verifyEqual(testCase,size(aggregate.core.matrix),[16 16]);
verifyFalse(testCase,isfile(fullfile(testCase.TestData.context.matrices_dir, ...
    "full_kkt_triplets.csv")));
end

function testRecursivePermutationEvidenceIsPersisted(testCase)
p = testCase.TestData.exported.paths;
permutation = readtable(p.permutation_map,"TextType","string");
canonical = readtable(p.canonical_index_map,"TextType","string");
daily = load(p.daily_recursive_mat);
directions = load(p.directions_mat);
n = 4340;
identityOrder = (1:n).';

verifyEqual(testCase,height(permutation),n);
verifyEqual(testCase,sort(permutation.recursive_solver_index),identityOrder);
verifyEqual(testCase,sort(permutation.canonical_reduced_index),identityOrder);
verifyTrue(testCase,any(lower(string( ...
    permutation.is_identity_position))=="false"));
verifyEqual(testCase, ...
    permutation.inverse_canonical_to_recursive( ...
        permutation.forward_recursive_to_canonical),identityOrder);
verifyEqual(testCase, ...
    permutation.forward_recursive_to_canonical( ...
        permutation.inverse_canonical_to_recursive),identityOrder);
verifyEqual(testCase,height(canonical),height(testCase.TestData.index.permutation_map));
verifyEqual(testCase,height(canonical),11588);

verifyTrue(testCase,isfield(daily,"partition"));
verifyTrue(testCase,isfield(daily.partition,"permutation"));
verifyTrue(testCase,isfield(daily.partition,"assembly_audit"));
verifyEqual(testCase,daily.partition.permutation.dimension,n);
verifyTrue(testCase,daily.partition.permutation.is_nonidentity);
verifyTrue(testCase,daily.partition.permutation.is_bijection);
verifyEqual(testCase,height(daily.partition.permutation.map),n);
verifyEqual(testCase,height(daily.partition.permutation.assembly_map),8);
verifyEqual(testCase, ...
    daily.partition.assembly_audit.canonical_matrix_difference_nnz,0);
verifyEqual(testCase, ...
    daily.partition.assembly_audit.canonical_rhs_difference_nnz,0);

forward = daily.partition.permutation.forward_recursive_to_canonical;
inverse = daily.partition.permutation.inverse_canonical_to_recursive;
canonicalReduced = [directions.recursive_components.xi; ...
    directions.recursive_components.y];
restored = canonicalReduced(forward);
restored = restored(inverse);
verifyEqual(testCase,restored,canonicalReduced);
directReduced = [directions.full_components.xi;directions.full_components.y];
relativeError = norm(restored-directReduced,2)/max(1,norm(directReduced,2));
verifyLessThanOrEqual(testCase,relativeError, ...
    testCase.TestData.config.tolerances.direction_relative_2norm);
end

function testSevenResponsesAggregationAndBlocks(testCase)
p=testCase.TestData.exported.paths;
responses=readtable(p.daily_response_summary,"TextType","string");
chains=readtable(p.daily_chain_dimensions,"TextType","string");
blocks=readtable(p.block_dimensions,"TextType","string");
aggregation=readtable(p.daily_aggregation_audit,"TextType","string");
verifyEqual(testCase,responses.day,(14:20)');
verifyEqual(testCase,responses.S_rows,repmat(14,7,1));
verifyEqual(testCase,responses.S_columns,repmat(14,7,1));
verifyTrue(testCase,all(string(responses.status)=="PASS"));
verifyEqual(testCase,chains.chain_rows,[589;590;589;590;590;590;590]);
verifyEqual(testCase,height(blocks),168);
blockCounts=arrayfun(@(dayId)nnz(blocks.day==dayId),(14:20)');
verifyEqual(testCase,blockCounts,repmat(24,7,1));
verifyTrue(testCase,all(string(blocks.status)=="PASS"));
verifyEqual(testCase,string(aggregation.day_ids_sorted),"[14 15 16 17 18 19 20]");
verifyEqual(testCase,aggregation.S_order_invariance_relative_error,0);
verifyEqual(testCase,aggregation.gamma_order_invariance_relative_error,0);
verifyEqual(testCase,string(aggregation.status),"PASS");
end

function testPhysicalFixedZeroAndSocEvidence(testCase)
p=testCase.TestData.exported.paths;
fixed=readtable(p.fixed_zero_map,"TextType","string");
recovery=readtable(p.fixed_zero_recovery_audit,"TextType","string");
verifyEqual(testCase,height(fixed),422); verifyEqual(testCase,height(recovery),422);
verifyTrue(testCase,all(recovery.recovered_value==0));
verifyTrue(testCase,all(recovery.recovered_direction==0));
verifyTrue(testCase,all(startsWith(string(recovery.recovery_source),"physical.")));
verifyTrue(testCase,all(string(recovery.status)=="PASS"));
physical=load(p.physical_recovery_mat);
verifyEqual(testCase,physical.physical.fixed_zero_audit.count,422);
verifyTrue(testCase,physical.physical.fixed_zero_audit.values_exact_zero);
verifyTrue(testCase,physical.physical.fixed_zero_audit.directions_exact_zero);
soc=readtable(p.soc_boundary_audit,"TextType","string");
verifyEqual(testCase,height(soc),350);
verifyTrue(testCase,all(string(soc.status)=="PASS"));
verifyEqual(testCase,nnz(startsWith(string(soc.check_id),"SOC-END-")),14);
verifyEqual(testCase,nnz(contains(string(soc.boundary_role),"no_interday")),14);
end

function testComparisonResidualIdentityAndAcceptance(testCase)
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
verifyEqual(testCase,identity.full_kkt_dimension,18836);
verifyEqual(testCase,reshape(identity.daily_chain_dimensions,1,[]), ...
    [589 590 589 590 590 590 590]);
verifyEqual(testCase,identity.fixed_zero_count,422);
acceptance=evaluate_stage_a3_acceptance_facts(testCase.TestData.root, ...
    testCase.TestData.verification);
verifyEqual(testCase,height(acceptance),6);
verifyTrue(testCase,all(acceptance.status=="PASS"));
end

function testExecutionAndCommandMarkersAreOneWay(testCase)
metadata=struct("a3_solver_executed",false,"newton_direction_count",1, ...
    "full_ipm_executed",false,"parallel_executed",false, ...
    "optimization_executed",false, ...
    "actual_test_command","NOT_EXECUTED_EXTERNAL_OR_PRETEST_BLOCK");
context=create_run_context(testCase.TestData.project,"stage_A3", ...
    "RunId","stage_A3_execution_marker","ManifestMetadata",metadata);
manifest=mark_stage_a3_solver_execution(context);
verifyTrue(testCase,manifest.a3_solver_executed);
manifest=record_stage_a3_test_command(context,"run_stage_A3_tests()", ...
    "run_stage_A2_tests()","run_stage_A1_tests()");
verifyEqual(testCase,string(manifest.actual_test_command.stage_a3), ...
    "run_stage_A3_tests()");
verifyError(testCase,@()mark_stage_a3_solver_execution(context), ...
    "stageA3:artifacts:SolverExecutionAlreadyMarked");
verifyError(testCase,@()record_stage_a3_test_command(context,"x","y","z"), ...
    "stageA3:artifacts:TestCommandAlreadyRecorded");
end

function testNonOverwriteAndEvidenceHashes(testCase)
verifyError(testCase,@()export_again(testCase), ...
    "stageA3:artifacts:TargetExists");
reports=testCase.TestData.context.reports_dir;
write_bytes(fullfile(reports,"阶段A3_7日日响应汇总与方向等价报告.docx"));
write_bytes(fullfile(reports,"阶段A3_问题修复与验收报告.docx"));
write_bytes(fullfile(reports,"运行_stage_A3_artifact_integration_结果摘要.docx"));
evidence=write_stage_a3_evidence_hashes(testCase.TestData.context);
verifyTrue(testCase,all(evidence.status=="PASS"));
verifyEqual(testCase,nnz(evidence.scope=="reports"),3);
verifyError(testCase,@()write_stage_a3_evidence_hashes( ...
    testCase.TestData.context),"stageA3:artifacts:RefuseOverwrite");
end

function export_again(testCase)
v=testCase.TestData.verification;
export_stage_a3_artifacts(testCase.TestData.context,testCase.TestData.data, ...
    testCase.TestData.index,testCase.TestData.config,v.linearization, ...
    v.direct,v.recursive,v.audit,Physical=v.physical);
end
function write_bytes(pathValue)
fileId=fopen(pathValue,'wb'); assert(fileId>=0);
guard=onCleanup(@()close_if_open(fileId)); fwrite(fileId,uint8('test'),'uint8');
fclose(fileId); clear guard;
end
function close_if_open(fileId)
try
    if ischar(fopen(fileId))
        fclose(fileId);
    end
catch
end
end
function remove_tree(pathValue)
if isfolder(pathValue), rmdir(pathValue,'s'); end
end
