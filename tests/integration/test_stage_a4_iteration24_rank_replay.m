function tests = test_stage_a4_iteration24_rank_replay
%TEST_STAGE_A4_ITERATION24_RANK_REPLAY Fixed root-cause replay gates.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
root = string(fileparts(fileparts(fileparts(mfilename("fullpath")))));
originalPath = path;
addpath(root);
addpath(genpath(fullfile(root,"src")));
testCase.addTeardown(@()path(originalPath));
failurePath = fullfile(root,"runs", ...
    "20260728_112548_stage_A4_1f3836ca","checkpoints", ...
    "numerical_failure_inv001_iter024_rev023_20260728_113512_963.mat");
hashBefore = string(compute_sha256_file(failurePath));
result = diagnose_stage_a4_iteration24_rank_failure(root);
hashAfter = string(compute_sha256_file(failurePath));
testCase.TestData.root = root;
testCase.TestData.failure_path = failurePath;
testCase.TestData.failure_hash_before = hashBefore;
testCase.TestData.failure_hash_after = hashAfter;
testCase.TestData.result = result;
end

function testAuthorityStateAndLinearizationRebuildExactly(testCase)
r = testCase.TestData.result;
verifyEqual(testCase,r.state_revision,23);
verifyEqual(testCase,r.state_fingerprint, ...
    "6937649075448b70b6535eed5c64b8ca9ee169c4c1e1cb38721ac01ccceedeb1");
verifyEqual(testCase,r.linearization_fingerprint, ...
    "bcc8af26275ad735dc5e9d8e2881541aff23e9010a97dc7f618e632e9db1d157");
verifyEqual(testCase,r.failure_evidence_sha256, ...
    "5771a31b4add2d3d9ab6458865e5d2b8b9d8505e6bdd50bccca1149ecee92657");
verifyTrue(testCase,r.input_hashes_pass);
end

function testProductionFailureReproducesAtDay14Hour3(testCase)
r = testCase.TestData.result;
failure = r.replay_failure;
verifyTrue(testCase,failure.present);
verifyEqual(testCase,failure.identifier, ...
    "stageAMultiday:solver:RecursiveLayerFailure");
verifyEqual(testCase,failure.layer,"day_14_block_ldl_thomas");
verifyEqual(testCase,failure.rank,17);
verifyLessThanOrEqual(testCase,relative_difference( ...
    failure.condition_2,406960873079081.69),1e-15);
verifyTrue(testCase,contains(failure.message, ...
    "Hour 3 failed at schur_pivot_factorization"));
end

function testRawHourBlocksRemainFullRank(testCase)
rows = testCase.TestData.result.block_summary;
verifyEqual(testCase,double(rows.hour),(1:3).');
verifyEqual(testCase,double(rows.dimension),22*ones(3,1));
verifyEqual(testCase,double(rows.raw_rank),22*ones(3,1));
verifyTrue(testCase,all(rows.raw_condition_2<1.2e8));
verifyEqual(testCase,double(rows.n_primal),19*ones(3,1));
verifyEqual(testCase,double(rows.n_equalities),3*ones(3,1));
end

function testThomasSchurScaleCrossesDefaultRankGate(testCase)
rows = testCase.TestData.result.block_summary;
verifyEqual(testCase,double(rows.schur_rank),[22;22;17]);
verifyEqual(testCase, ...
    double(rows.singular_values_below_rank_tolerance),[0;0;5]);
verifyGreaterThan(testCase,rows.schur_smin(2)/rows.rank_tolerance(2),1);
verifyLessThan(testCase,rows.schur_smin(3)/rows.rank_tolerance(3),1);
verifyGreaterThan(testCase,rows.schur_condition_2(3),4e14);
verifyLessThanOrEqual(testCase,max(rows.schur_symmetry_relative),1e-12);
end

function testHighPrecisionReplayRejectsStructuralSingularity(testCase)
hp = testCase.TestData.result.high_precision;
verifyTrue(testCase,hp.available);
verifyEqual(testCase,hp.digits,80);
verifyTrue(testCase,hp.s3_high_precision_full_rank);
verifyGreaterThan(testCase,hp.s3_smin,4e-8);
verifyLessThan(testCase,hp.s3_smin,5e-8);
verifyGreaterThan(testCase,hp.s3_condition_2,4e14);
verifyLessThan(testCase,hp.schur_double_reconstruction_relative,1e-15);
verifyTrue(testCase,contains(string(hp.solution_reference_residual_text), ...
    "e-"));
end

function testNearNullModesArePrimalPhysicalDirections(testCase)
r = testCase.TestData.result;
components = r.near_null_components;
verifyEqual(testCase,numel(unique(components.mode)),5);
perMode = groupsummary(components,"mode","max","equality_energy");
verifyLessThan(testCase,max(perMode.max_equality_energy),1e-12);
leaders = components(components.loading_order<=2,:);
verifyTrue(testCase,all(leaders.coordinate_kind=="primal"));
lastMode = components(components.mode==22 & ...
    components.loading_order<=2,:);
verifyEqual(testCase,sort(lastMode.identifier),["PF";"PF"]);
verifyEqual(testCase,sort(double(lastMode.asset_id)),[1;2]);
end

function testCurvatureAndSocEliminationExplainScaleSeparation(testCase)
r = testCase.TestData.result;
curvature = r.curvature_sources;
verifyEqual(testCase,height(curvature),19);
verifyEqual(testCase,max(abs(curvature.hessian_diagonal)),0);
verifyGreaterThan(testCase,min(curvature.w_diagonal),3e-8);
verifyLessThan(testCase,max(curvature.w_diagonal),4e-7);
S3 = r.matrix_data.S3;
verifyGreaterThan(testCase,max(abs(diag(S3(21:22,21:22)))),1e7);
verifyEqual(testCase,r.root_cause.classification, ...
    "numerically_full_rank_scale_imbalanced_thomas_gate");
end

function testDiagnosticCongruenceRestoresRankWithoutStateUse(testCase)
r = testCase.TestData.result;
trace = r.scaling_trace;
verifyEqual(testCase,double(trace.pass),(0:8).');
verifyEqual(testCase,trace.numeric_rank(1),17);
verifyEqual(testCase,trace.numeric_rank(end),22);
verifyGreaterThan(testCase, ...
    trace.condition_2(1)/trace.condition_2(end),4e6);
verifyLessThan(testCase,trace.condition_2(end),1e8);
verifyLessThanOrEqual(testCase,max(trace.symmetry_relative),1e-12);
verifyTrue(testCase,r.root_cause.repair_not_applied);
end

function testUnguardedAndScaledSolvesAreDiagnosticOnly(testCase)
r = testCase.TestData.result;
comparison = r.factor_solve_comparison;
verifyEqual(testCase,height(comparison),3);
verifyLessThan(testCase, ...
    max(comparison.original_operator_relative_residual(1:2)),1e-14);
verifyLessThan(testCase, ...
    max(comparison.relative_error_to_high_precision(1:2)),1e-14);
verifyFalse(testCase,any(comparison.used_for_formal_direction));
verifyEqual(testCase,comparison.inertia_zero_by_diagnostic_gate(1),3);
verifyEqual(testCase,comparison.inertia_zero_by_diagnostic_gate(2),0);
end

function testCompleteKktIsIndependentAuditOnly(testCase)
r = testCase.TestData.result;
audit = r.full_kkt_audit;
verifyTrue(testCase,audit.performed);
verifyEqual(testCase,audit.dimension,18836);
verifyLessThanOrEqual(testCase,audit.relative_residual,1e-10);
verifyFalse(testCase,audit.warning_present);
verifyFalse(testCase,audit.direction_consumed);
verifyFalse(testCase,r.options.full_kkt_direction_consumed);
verifyFalse(testCase,r.options.full_direction_fallback_used);
end

function testGovernanceAndHistoricalEvidenceRemainFrozen(testCase)
r = testCase.TestData.result;
verifyTrue(testCase,r.protected_file_audit.all_pass);
verifyEqual(testCase,testCase.TestData.failure_hash_before, ...
    testCase.TestData.failure_hash_after);
verifyTrue(testCase,r.no_state_update);
verifyEqual(testCase,r.options.state_update_count,0);
verifyEqual(testCase,r.options.newton_direction_count_completed,0);
verifyFalse(testCase,r.options.formal_a4_run_created);
verifyFalse(testCase,r.options.full_ipm_executed);
verifyFalse(testCase,r.options.optimization_executed);
verifyFalse(testCase,r.options.parallel_executed);
verifyFalse(testCase,r.options.automatic_symmetrization_used);
verifyFalse(testCase,r.options.regularization_used);
verifyTrue(testCase,r.no_stage_a4_pass_claim);
current = string(fileread(fullfile(testCase.TestData.root,"CURRENT_STAGE.md")));
verifyTrue(testCase,contains(current,"`stage_id`: `stage_A4`"));
verifyTrue(testCase,contains(current,"`status`: `READY`"));
end

function testArtifactCsvAndDiagnosticReportRoundTrip(testCase)
r = testCase.TestData.result;
temporaryRoot = string(tempname);
[created,message] = mkdir(temporaryRoot);
assert(created,"stageA4:iter24:TestDirectory", ...
    "Could not create temporary report test directory: %s",message);
cleanup = onCleanup(@()remove_test_directory(temporaryRoot));
directories = ["matrices";"acceptance";"issues";"reports";"tests"];
for k=1:numel(directories)
    mkdir(fullfile(temporaryRoot,directories(k)));
end
context = struct( ...
    "root",temporaryRoot, ...
    "run_id","unit_test_stage_A4_ITER24_REPLAY_with_underscores", ...
    "matrices_dir",fullfile(temporaryRoot,"matrices"), ...
    "matrix_manifest_path", ...
        fullfile(temporaryRoot,"matrices","matrix_manifest.csv"), ...
    "acceptance_results_path", ...
        fullfile(temporaryRoot,"acceptance","acceptance_results.csv"), ...
    "issue_log_path", ...
        fullfile(temporaryRoot,"issues","issue_log.csv"));
export_stage_a4_iteration24_rank_replay(context,r, ...
    CommandText="unit_test_command_with_underscores");
write_json_file(fullfile(temporaryRoot,"run_manifest.json"),struct( ...
    "status","RUNNING", ...
    "stage_id","stage_A4", ...
    "git_commit",r.current_commit));
inputHashes = table( ...
    ["基础参数.xlsx";"输入数据.xlsx"], ...
    ["fixture_hash_1";"fixture_hash_2"], ...
    ["PASS";"PASS"], ...
    'VariableNames',{'fileName','actualSHA256','status'});
write_table_csv_17g_atomic( ...
    fullfile(temporaryRoot,"input_hashes.csv"),inputHashes);
write_json_file(fullfile(temporaryRoot,"tests","test_summary.json"), ...
    struct("test_total",12,"test_passed",12, ...
    "test_failed",0,"test_incomplete",0));

[reportPath,validation] = ...
    generate_stage_a4_iteration24_rank_report(context);
verifyTrue(testCase,isfile(reportPath));
verifyEmpty(testCase,validation.errors);

opts = detectImportOptions(context.acceptance_results_path, ...
    "Delimiter",",","TextType","string", ...
    "VariableNamingRule","preserve");
opts.Delimiter=",";
acceptance = readtable(context.acceptance_results_path,opts);
verifyEqual(testCase,height(acceptance),5);
verifyEqual(testCase,string(acceptance.run_id(1)), ...
    string(context.run_id));
verifyEqual(testCase,string(acceptance.contract(2)), ...
    "layer=day_14_block_ldl_thomas, rank=17");
clear cleanup
end

function value = relative_difference(actual,expected)
value = abs(actual-expected)/max(1,abs(expected));
end

function remove_test_directory(pathValue)
if isfolder(pathValue)
    rmdir(pathValue,"s");
end
end
