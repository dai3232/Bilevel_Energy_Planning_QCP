function tests = test_stage_a1_artifacts
%TEST_STAGE_A1_ARTIFACTS Verify strict, readable A1 numerical evidence.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
repositoryRoot = string(fileparts(fileparts(fileparts(mfilename('fullpath')))));
originalPath = path;
addpath(genpath(fullfile(repositoryRoot,"src")));
testCase.addTeardown(@() path(originalPath));

config = load_stage_a1_configuration(repositoryRoot);
data = load_project_data(repositoryRoot);
index = build_stage_a1_index(data,"RunId","A1_ARTIFACT_TEST");
state = initialize_stage_a1_state(data,index,config);
linearization = build_stage_a1_linearization(state,data,index,config);
direct = solve_full_kkt_direction(linearization);
recursive = solve_recursive_direction(linearization, ...
    AssemblyTolerance=config.tolerances.symmetry_relative, ...
    SymmetryTolerance=config.tolerances.symmetry_relative);
audit = verify_direction_equivalence(direct,recursive,linearization, ...
    DirectionRelative=config.tolerances.direction_relative_2norm, ...
    RecursiveResidual=config.tolerances.recursive_full_kkt_relative_residual, ...
    FullResidualPreferred=config.tolerances.direct_preferred, ...
    FullResidualMaximum=config.tolerances.direct_maximum);

temporaryProject = string(tempname(tempdir));
[created,message] = mkdir(temporaryProject);
testCase.assertTrue(created,message);
testCase.addTeardown(@() remove_test_project(temporaryProject));
context = create_run_context(temporaryProject,"stage_A1", ...
    "RunId","stage_A1_artifact_integration");
initialTargetsAbsent = ~isfile(context.matrix_manifest_path) && ...
    ~isfile(fullfile(context.indices_dir,"variable_index.csv"));
exported = export_stage_a1_artifacts(context,data,index,config, ...
    linearization,direct,recursive,audit);

testCase.TestData.repositoryRoot = repositoryRoot;
testCase.TestData.temporaryProject = temporaryProject;
testCase.TestData.context = context;
testCase.TestData.initialTargetsAbsent = initialTargetsAbsent;
testCase.TestData.data = data;
testCase.TestData.index = index;
testCase.TestData.config = config;
testCase.TestData.linearization = linearization;
testCase.TestData.direct = direct;
testCase.TestData.recursive = recursive;
testCase.TestData.audit = audit;
testCase.TestData.exported = exported;
end

function testA1ContextDoesNotPrecreateExporterTargets(testCase)
verifyTrue(testCase,testCase.TestData.initialTargetsAbsent);

stage0 = create_run_context(testCase.TestData.temporaryProject,"stage_0", ...
    "RunId","stage_0_placeholder_regression");
verifyTrue(testCase,isfile(stage0.matrix_manifest_path));
verifyTrue(testCase,isfile(fullfile(stage0.indices_dir,"variable_index.csv")));
end

function testStageA1ExecutionMarkerIsOneWay(testCase)
metadata = struct("a1_solver_executed",false, ...
    "newton_direction_count",1,"full_ipm_executed",false, ...
    "parallel_executed",false, ...
    "actual_test_command","NOT_EXECUTED_EXTERNAL_OR_PRETEST_BLOCK");
context = create_run_context(testCase.TestData.temporaryProject,"stage_A1", ...
    "RunId","stage_A1_execution_marker","ManifestMetadata",metadata);
manifest = mark_stage_a1_solver_execution(context);
verifyTrue(testCase,logical(manifest.a1_solver_executed));
verifyTrue(testCase,isfield(manifest,"solver_execution_started_at"));
manifest = record_stage_a1_test_command(context, ...
    "run_stage_A1_tests('EvidenceDirectory','temporary/tests')");
verifyEqual(testCase,string(manifest.actual_test_command), ...
    "run_stage_A1_tests('EvidenceDirectory','temporary/tests')");
verifyError(testCase,@() record_stage_a1_test_command(context,"duplicate"), ...
    "stageA1:artifacts:TestCommandAlreadyRecorded");
verifyError(testCase,@() mark_stage_a1_solver_execution(context), ...
    "stageA1:artifacts:SolverExecutionAlreadyMarked");
end

function testRequiredArtifactsAreReadableAndDimensioned(testCase)
paths = testCase.TestData.exported.paths;
required = [string(paths.linearization_mat);string(paths.full_kkt_mat); ...
    string(paths.recursive_blocks_mat);string(paths.directions_mat); ...
    string(paths.residuals_mat);string(paths.index_mapping_mat); ...
    string(paths.configuration_mat);string(paths.matrix_manifest); ...
    string(paths.block_dimensions);string(paths.direction_comparison); ...
    string(paths.residual_summary);string(paths.soc_boundary_audit); ...
    string(paths.fixed_zero_audit);string(paths.code_scan); ...
    string(paths.linearization_identity);string(paths.artifact_hashes)];
verifyTrue(testCase,all(isfile(required)));

fullArtifact = load(paths.full_kkt_mat);
recursiveArtifact = load(paths.recursive_blocks_mat);
directionArtifact = load(paths.directions_mat);
verifyTrue(testCase,issparse(fullArtifact.kkt.matrix));
verifyEqual(testCase,size(fullArtifact.kkt.matrix),[471 471]);
verifyEqual(testCase,[recursiveArtifact.partition.hour.dimension],[27 27 29]);
verifyEqual(testCase,size(recursiveArtifact.core.matrix),[16 16]);
verifyEqual(testCase,numel(directionArtifact.full_direction),471);
verifyEqual(testCase,numel(directionArtifact.recursive_direction),471);

blocks = readtable(paths.block_dimensions,"TextType","string");
verifyEqual(testCase,blocks.Properties.VariableNames, ...
    {'hour','n_primal','n_equalities','kkt_dimension', ...
    'expected_dimension','status'});
verifyEqual(testCase,blocks.hour,[8;9;10]);
verifyEqual(testCase,blocks.kkt_dimension,[27;27;29]);
verifyEqual(testCase,string(blocks.status),repmat("PASS",3,1));

manifest = readtable(paths.matrix_manifest,"TextType","string");
verifyEqual(testCase,manifest.Properties.VariableNames, ...
    {'matrix_name','rows','columns','nnz','is_sparse','sha256','path'});
fullRow = manifest(string(manifest.matrix_name)=="full_kkt",:);
coreRow = manifest(string(manifest.matrix_name)=="global_core",:);
verifyEqual(testCase,height(fullRow),1);
verifyEqual(testCase,[fullRow.rows fullRow.columns],[471 471]);
verifyEqual(testCase,lower(string(fullRow.is_sparse)),"true");
verifyEqual(testCase,height(coreRow),1);
verifyEqual(testCase,[coreRow.rows coreRow.columns],[16 16]);
end

function testCsvContractsAndBoundaryEvidence(testCase)
paths = testCase.TestData.exported.paths;
comparison = readtable(paths.direction_comparison,"TextType","string");
verifyEqual(testCase,comparison.Properties.VariableNames, ...
    {'metric_id','actual_value','threshold','status'});
verifyTrue(testCase,all(string(comparison.status)=="PASS"));

residuals = readtable(paths.residual_summary,"TextType","string");
verifyEqual(testCase,residuals.Properties.VariableNames, ...
    {'route','absolute_residual_2norm','rhs_2norm', ...
    'relative_residual_2norm','threshold','status'});
verifyTrue(testCase,all(string(residuals.status)=="PASS"));

soc = readtable(paths.soc_boundary_audit,"TextType","string");
verifyEqual(testCase,height(soc),8);
verifyTrue(testCase,all(string(soc.status)=="PASS"));
startRows = soc(soc.hour==8,:);
verifyEqual(testCase,height(startRows),2);
verifyTrue(testCase,all(contains(startRows.actual,"predecessor=NA")));

fixed = readtable(paths.fixed_zero_audit,"TextType","string");
verifyEqual(testCase,fixed.count,0);
verifyEqual(testCase,lower(string(fixed.vacuous)),"true");
verifyEqual(testCase,string(fixed.status),"PASS");

scan = readtable(paths.code_scan,"TextType","string");
verifyTrue(testCase,all(string(scan.status)=="PASS"));
identity = jsondecode(fileread(paths.linearization_identity));
verifyTrue(testCase,identity.all_identities_equal);
verifyEqual(testCase,identity.shared_linearization_object_count,1);
verifyEqual(testCase,identity.full_kkt_dimension,471);
verifyEqual(testCase,identity.hourly_block_dimensions,[27;27;29]);
verifyEqual(testCase,identity.global_core_dimension,16);
end

function testNumericalArtifactHashesMatchBytes(testCase)
paths = testCase.TestData.exported.paths;
hashes = readtable(paths.artifact_hashes,"TextType","string");
verifyEqual(testCase,hashes.Properties.VariableNames, ...
    {'relative_path','sha256','bytes','artifact_type','scope','status'});
verifyGreaterThan(testCase,height(hashes),20);
verifyTrue(testCase,all(string(hashes.scope)=="numerical_export"));
verifyTrue(testCase,all(string(hashes.status)=="PASS"));
verifyFalse(testCase,any(string(hashes.relative_path)== ...
    "matrices/numerical_artifact_hashes.csv"));
for row = 1:height(hashes)
    filePath = fullfile(testCase.TestData.context.root, ...
        replace(hashes.relative_path(row),"/",filesep));
    verifyTrue(testCase,isfile(filePath));
    verifyEqual(testCase,lower(string(hashes.sha256(row))), ...
        compute_sha256_file(string(filePath)));
    info = dir(filePath);
    verifyEqual(testCase,hashes.bytes(row),info.bytes);
end

verifyFalse(testCase,isfile(fullfile(testCase.TestData.context.matrices_dir, ...
    "full_kkt_triplets.csv")));
verifyFalse(testCase,isfile(fullfile(testCase.TestData.context.matrices_dir, ...
    "hour_chain_M_triplets.csv")));
end

function testCompleteEvidenceHashInventoryIncludesStagedReports(testCase)
staging = string(tempname(tempdir));
mkdir(staging);
cleanup = onCleanup(@() remove_test_project(staging)); %#ok<NASGU>
reports = struct( ...
    "model_report",fullfile(staging,"阶段A1_完整KKT与递推方向等价验收报告.docx"), ...
    "issue_report",fullfile(staging,"阶段A1_问题修复与验收报告.docx"), ...
    "run_summary",fullfile(staging,"运行_stage_A1_artifact_integration_结果摘要.docx"));
names = fieldnames(reports);
for k = 1:numel(names)
    write_bytes(reports.(names{k}),uint8(char("staged-report-"+string(k))));
end
evidence = write_stage_a1_evidence_hashes(testCase.TestData.context,reports);
verifyTrue(testCase,all(evidence.status=="PASS"));
verifyEqual(testCase,sum(evidence.scope=="report"),3);
verifyTrue(testCase,all(ismember( ...
    "reports/"+["阶段A1_完整KKT与递推方向等价验收报告.docx"; ...
    "阶段A1_问题修复与验收报告.docx"; ...
    "运行_stage_A1_artifact_integration_结果摘要.docx"], ...
    evidence.relative_path)));
verifyError(testCase,@() write_stage_a1_evidence_hashes( ...
    testCase.TestData.context,reports),"stageA1:artifacts:RefuseOverwrite");
end

function testExistingArtifactsAreNeverOverwritten(testCase)
verifyError(testCase,@() export_again(testCase), ...
    "stageA1:artifacts:TargetExists");

fresh = create_run_context(testCase.TestData.temporaryProject,"stage_A1", ...
    "RunId","stage_A1_preflight_collision");
sentinel = fullfile(fresh.matrices_dir,"directions.mat");
write_bytes(sentinel,uint8(char("preserve-existing-evidence")));
verifyError(testCase,@() export_to_context(testCase,fresh), ...
    "stageA1:artifacts:TargetExists");
verifyEqual(testCase,string(native2unicode(read_bytes(sentinel),"UTF-8")), ...
    "preserve-existing-evidence");
verifyFalse(testCase,isfile(fullfile(fresh.matrices_dir,"linearization.mat")));
verifyFalse(testCase,isfile(fullfile(fresh.indices_dir,"variable_index.csv")));
end

function export_again(testCase)
export_to_context(testCase,testCase.TestData.context);
end

function export_to_context(testCase,context)
export_stage_a1_artifacts(context,testCase.TestData.data, ...
    testCase.TestData.index,testCase.TestData.config, ...
    testCase.TestData.linearization,testCase.TestData.direct, ...
    testCase.TestData.recursive,testCase.TestData.audit);
end

function write_bytes(filePath,bytes)
fileId = fopen(filePath,"wb");
assert(fileId>=0,"Could not open test sentinel.");
cleanup = onCleanup(@() close_if_open(fileId));
fwrite(fileId,bytes,"uint8");
fclose(fileId);
clear cleanup;
end

function bytes = read_bytes(filePath)
fileId = fopen(filePath,"rb");
assert(fileId>=0,"Could not read test sentinel.");
cleanup = onCleanup(@() fclose(fileId));
bytes = fread(fileId,Inf,"*uint8").';
end

function close_if_open(fileId)
try
    if ischar(fopen(fileId)), fclose(fileId); end
catch
end
end

function remove_test_project(projectRoot)
if isfolder(projectRoot)
    rmdir(projectRoot,"s");
end
end
