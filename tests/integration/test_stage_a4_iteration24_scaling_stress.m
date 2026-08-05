function tests = test_stage_a4_iteration24_scaling_stress
%TEST_STAGE_A4_ITERATION24_SCALING_STRESS Fixed independent stress gates.
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
hashBefore = string(rkkt.data.compute_sha256_file(failurePath));
result = rkkt.diagnostics.run_stage_a4_iteration24_scaling_stress(root);
hashAfter = string(rkkt.data.compute_sha256_file(failurePath));
testCase.TestData.root = root;
testCase.TestData.failure_path = failurePath;
testCase.TestData.failure_hash_before = hashBefore;
testCase.TestData.failure_hash_after = hashAfter;
testCase.TestData.result = result;
end

function testAuthorityStateAndLinearizationRebuildExactly(testCase)
r = testCase.TestData.result;
verifyEqual(testCase,r.state_revision,23);
verifyEqual(testCase,r.state_fingerprint_before, ...
    "6937649075448b70b6535eed5c64b8ca9ee169c4c1e1cb38721ac01ccceedeb1");
verifyEqual(testCase,r.state_fingerprint_after, ...
    r.state_fingerprint_before);
verifyEqual(testCase,r.linearization_fingerprint, ...
    "bcc8af26275ad735dc5e9d8e2881541aff23e9010a97dc7f618e632e9db1d157");
verifyEqual(testCase,r.failure_evidence_sha256, ...
    "5771a31b4add2d3d9ab6458865e5d2b8b9d8505e6bdd50bccca1149ecee92657");
verifyEqual(testCase,r.authority_commit, ...
    "1f3836ca629f5fc8a1de1f5ea5b783d114e1586b");
verifyEqual(testCase,r.authority_manifest_sha256, ...
    rkkt.data.compute_sha256_file(fullfile(testCase.TestData.root,"runs", ...
    "20260728_112548_stage_A4_1f3836ca","run_manifest.json")));
verifyTrue(testCase,r.input_hashes_pass);
verifyEqual(testCase,r.effective_config.equilibration_passes,8);
verifyEqual(testCase,r.effective_config. ...
    recursive_refinement_max_passes,3);
verifyEqual(testCase,r.effective_config.sigma,0.1);
verifyEqual(testCase,r.effective_config.tau,0.9995);
verifyEqual(testCase,r.effective_config.initialization_id, ...
    "stageA4-deterministic-interior-v1.0");
verifyEqual(testCase,r.effective_config.step_rule, ...
    "independent_alpha_primal_alpha_dual");
verifyEqual(testCase,r.effective_config.sha256, ...
    rkkt.data.compute_sha256_file(fullfile(testCase.TestData.root,"config", ...
    "stage_A4_iteration24_scaling_stress.yaml")));
end

function testUnscaledFailureStillReproducesAtDay14Hour3(testCase)
failure = testCase.TestData.result.unscaled_failure;
verifyTrue(testCase,failure.present);
verifyEqual(testCase,failure.identifier, ...
    "stageAMultiday:solver:RecursiveLayerFailure");
verifyTrue(testCase,contains(failure.message, ...
    "day_14_block_ldl_thomas"));
verifyTrue(testCase,contains(failure.message, ...
    "Hour 3 failed at schur_pivot_factorization"));
verifyTrue(testCase,contains(failure.message,"rank=17"));
end

function testSharedScaledRouteCoversEveryHourAndCore(testCase)
r = testCase.TestData.result;
rows = r.hourly_factor_audit;
verifyEqual(testCase,height(rows),168);
verifyTrue(testCase,all(rows.scaling_used));
verifyEqual(testCase,unique(rows.equilibration_passes),8);
verifyEqual(testCase,r.factor_operator_audit.factor_count,169);
verifyTrue(testCase,r.core_audit.scaling_used);
verifyEqual(testCase,r.core_audit.equilibration_passes,8);
verifyEqual(testCase,r.core_audit.dimension,16);
end

function testDay14Hour3RankAndConditionRecover(testCase)
rows = testCase.TestData.result.hourly_factor_audit;
row = rows(rows.day==14 & rows.hour==3,:);
verifyEqual(testCase,height(row),1);
verifyEqual(testCase,row.dimension,22);
verifyEqual(testCase,row.original_numeric_rank,17);
verifyEqual(testCase,row.scaled_numeric_rank,22);
verifyGreaterThan(testCase,row.original_condition_2,4e14);
verifyLessThan(testCase,row.scaled_condition_2,1e8);
verifyGreaterThan(testCase,row.condition_reduction_factor,4e6);
end

function testEveryScaledPivotIsNumericallyFullRank(testCase)
rows = testCase.TestData.result.hourly_factor_audit;
verifyEqual(testCase,rows.scaled_numeric_rank,rows.dimension);
verifyTrue(testCase,all(isfinite(rows.scaled_condition_2)));
verifyEqual(testCase,testCase.TestData.result.core_audit. ...
    scaled_numeric_rank,16);
end

function testDirectionAndAllComponentsMeetEngineeringThreshold(testCase)
audit = testCase.TestData.result.equivalence;
verifyLessThanOrEqual(testCase,audit.direction_relative_error,1e-10);
verifyLessThanOrEqual(testCase,audit.component_relative_errors.xi,1e-10);
verifyLessThanOrEqual(testCase,audit.component_relative_errors.y,1e-10);
verifyLessThanOrEqual(testCase,audit.component_relative_errors.l,1e-10);
verifyLessThanOrEqual(testCase,audit.component_relative_errors.z,1e-10);
verifyTrue(testCase,audit.passed.direction);
end

function testRecursiveAndCompleteKktResidualsMeetThreshold(testCase)
r = testCase.TestData.result;
verifyLessThanOrEqual(testCase, ...
    r.equivalence.recursive_kkt_relative_residual,1e-10);
verifyLessThanOrEqual(testCase, ...
    r.equivalence.full_kkt_relative_residual,1e-10);
verifyEqual(testCase,r.full_audit.kkt.dimension,18836);
verifyTrue(testCase,r.equivalence.passed.recursive_residual);
verifyTrue(testCase,r.equivalence.passed.full_residual_hard);
end

function testOriginalOperatorAndCongruenceContractClose(testCase)
audit = testCase.TestData.result.factor_operator_audit;
verifyTrue(testCase,audit.all_scaled);
verifyTrue(testCase,audit.all_original_operators_retained);
verifyLessThanOrEqual(testCase, ...
    audit.maximum_congruence_reconstruction_relative,64*eps);
verifyLessThanOrEqual(testCase, ...
    audit.maximum_factor_reconstruction_relative,1e-12);
verifyLessThanOrEqual(testCase, ...
    audit.maximum_original_factorized_operator_relative,1e-12);
verifyTrue(testCase,audit.all_pass);
end

function testSymmetryAndDayResponseRemainWithinContract(testCase)
r = testCase.TestData.result;
verifyLessThanOrEqual(testCase, ...
    max(r.hourly_factor_audit.symmetry_relative_original),1e-12);
verifyLessThanOrEqual(testCase, ...
    max(r.hourly_factor_audit.symmetry_relative_scaled),1e-12);
verifyLessThanOrEqual(testCase, ...
    r.maximum_day_response_symmetry_relative,1e-12);
verifyLessThanOrEqual(testCase, ...
    r.core_audit.symmetry_relative_scaled,1e-12);
verifyFalse(testCase,r.automatic_symmetrization_used);
end

function testRetainedFactorRefinementIsBounded(testCase)
r = testCase.TestData.result;
rows = r.refinement_audit;
verifyEqual(testCase,height(rows),8);
verifyEqual(testCase,rows.maximum_passes,3*ones(8,1));
verifyLessThanOrEqual(testCase,max(rows.passes_attempted),3);
verifyLessThanOrEqual(testCase,max(rows.correction_count),3);
verifyTrue(testCase,all(rows.final_maximum_column_relative<= ...
    rows.initial_maximum_column_relative));
verifyTrue(testCase,all(ismember(rows.stop_reason, ...
    ["target_met_initial","target_met", ...
    "residual_no_longer_decreased","maximum_passes_reached"])));
end

function testRepeatedStressDirectionIsBitwiseDeterministic(testCase)
d = testCase.TestData.result.determinism;
verifyTrue(testCase,d.direction_exact);
verifyEqual(testCase,d.maximum_absolute_difference,0);
verifyEqual(testCase,d.first_direction_fingerprint, ...
    d.second_direction_fingerprint);
verifyEqual(testCase,d.first_direction_fingerprint, ...
    "9ce8c92a103a6a4c83b294d2dca02d9a42c33378b6687c58cd4a0476c1a59356");
end

function testNoFullDirectionFallbackOrForbiddenExecution(testCase)
r = testCase.TestData.result;
verifyTrue(testCase,r.no_full_direction_fallback);
verifyTrue(testCase,r.recursive.no_full_direction_fallback);
verifyFalse(testCase,r.recursive.full_direction_consumed);
verifyEqual(testCase,r.full_kkt_role,"independent_audit_only");
verifyFalse(testCase,r.regularization_used);
verifyFalse(testCase,r.automatic_symmetrization_used);
verifyFalse(testCase,r.parallel_executed);
verifyFalse(testCase,r.full_ipm_executed);
verifyFalse(testCase,r.optimization_executed);
verifyTrue(testCase,isfield(r,"forbidden_execution"));
verifyTrue(testCase,r.forbidden_execution.independent_checks);
verifyTrue(testCase,r.forbidden_execution.all_pass);
verifyEqual(testCase,r.forbidden_execution.check_count,23);
verifyGreaterThan(testCase,r.forbidden_execution.dependency_file_count,0);
verifyTrue(testCase,all(r.forbidden_execution.results.status=="PASS"));
verifyTrue(testCase,all(strlength( ...
    r.forbidden_execution.results.evidence_type)>0));
verifyEqual(testCase,r.execution_ledger.state_update_calls,0);
verifyEqual(testCase,r.execution_ledger.full_direction_fallback_calls,0);
verifyEqual(testCase,r.execution_ledger.recursive_direction_solves,2);
verifyEqual(testCase,r.execution_ledger.full_kkt_audit_direction_solves,1);
end

function testStatePositivityAndNoUpdateAreExact(testCase)
r = testCase.TestData.result;
verifyTrue(testCase,r.positive_state);
verifyTrue(testCase,r.state_unchanged);
verifyEqual(testCase,r.state_update_count,0);
verifyEqual(testCase,r.state_fingerprint_before, ...
    r.state_fingerprint_after);
verifyEqual(testCase,testCase.TestData.failure_hash_before, ...
    testCase.TestData.failure_hash_after);
end

function testForbiddenSourcePatternsAndDefaultRouteBoundary(testCase)
root = testCase.TestData.root;
relative = [ ...
    "src/+rkkt/+solver/equilibrate_symmetric_congruence.m"; ...
    "src/+rkkt/+solver/factor_symmetric_ldl.m"; ...
    "src/+rkkt/+solver/solve_with_ldl_factor.m"; ...
    "src/+rkkt/+solver/solve_block_thomas_ldl.m"; ...
    "src/+rkkt/+solver/solve_stage_a_multiday_recursive_direction.m"];
allText = "";
for k=1:numel(relative)
    allText = allText+newline+ ...
        string(fileread(fullfile(root,relative(k))));
end
verifyEmpty(testCase,regexp(allText, ...
    "(?<![A-Za-z0-9_])(inv|pinv|lsqminnorm)\s*\(", ...
    "once"));
verifyFalse(testCase,contains(allText,"(matrix+matrix.')/2"));
verifyFalse(testCase,contains(allText,"(matrix + matrix.') / 2"));
verifyFalse(testCase,contains(allText,"parfor"));
verifyTrue(testCase,contains(string(fileread(fullfile(root, ...
    "src/+rkkt/+solver/solve_stage_a_multiday_recursive_direction.m"))), ...
    "options.UseCongruenceScaling (1,1) logical = false"));
verifyTrue(testCase,contains(string(fileread(fullfile(root, ...
    "src/+rkkt/+solver/solve_recursive_direction.m"))), ...
    "options.UseCongruenceScaling (1,1) logical = false"));
defaultRouteFiles = [ ...
    "src/+rkkt/+solver/solve_block_thomas_ldl.m"; ...
    "src/+rkkt/+solver/solve_core16_ldl.m"; ...
    "src/+rkkt/+solver/solve_stage_a3_core16_ldl.m"; ...
    "src/+rkkt/+solver/solve_stage_a_multiday_core16_ldl.m"];
for k=1:numel(defaultRouteFiles)
    text = string(fileread(fullfile(root,defaultRouteFiles(k))));
    verifyTrue(testCase,contains(text, ...
        "options.UseCongruenceScaling (1,1) logical = false"));
end
verifyTrue(testCase,contains(string(fileread(fullfile(root, ...
    "src/+rkkt/+diagnostics/scan_stage_a4_iteration24_scaling_stress_forbidden_execution.m"))), ...
    "requiredFilesAndProducts"));
end

function testGovernanceAndArtifactRoundTrip(testCase)
r = testCase.TestData.result;
root = testCase.TestData.root;
current = string(fileread(fullfile(root,"CURRENT_STAGE.md")));
verifyTrue(testCase,contains(current,"`stage_id`: `stage_A4`"));
verifyTrue(testCase,contains(current,"`status`: `READY`"));
verifyFalse(testCase,r.stage_a4_pass_claimed);
verifyFalse(testCase,r.formal_a4_run_created);
verifyEqual(testCase,r.status,"PASS");

temporaryRoot = string(tempname);
[created,message] = mkdir(temporaryRoot);
assert(created,"stageA4:scaleStress:TestDirectory", ...
    "Could not create temporary directory: %s",message);
cleanup = onCleanup(@()remove_test_directory(temporaryRoot));
directories = ["matrices";"acceptance";"issues";"reports";"tests"];
for k=1:numel(directories)
    mkdir(fullfile(temporaryRoot,directories(k)));
end
context = struct( ...
    "root",temporaryRoot, ...
    "run_id","unit_test_A4_ITER24_SCALE_STRESS", ...
    "matrices_dir",fullfile(temporaryRoot,"matrices"), ...
    "matrix_manifest_path", ...
        fullfile(temporaryRoot,"matrices","matrix_manifest.csv"), ...
    "acceptance_results_path", ...
        fullfile(temporaryRoot,"acceptance","acceptance_results.csv"), ...
    "issue_log_path", ...
        fullfile(temporaryRoot,"issues","issue_log.csv"), ...
    "decision_log_path", ...
        fullfile(temporaryRoot,"issues","decision_log.csv"));
rkkt.artifacts.export_stage_a4_iteration24_scaling_stress(context,r, ...
    CommandText="unit_test_scale_stress");
rkkt.artifacts.write_json_file(fullfile(temporaryRoot,"run_manifest.json"),struct( ...
    "status","RUNNING","stage_id","stage_A4", ...
    "git_commit",r.git.commit));
rkkt.artifacts.write_table_csv_17g_atomic(fullfile(temporaryRoot,"input_hashes.csv"), ...
    r.input_hashes);
rkkt.artifacts.write_json_file(fullfile(temporaryRoot,"tests","test_summary.json"), ...
    struct("test_total",15,"test_passed",15, ...
    "test_failed",0,"test_incomplete",0));
rkkt.artifacts.write_json_file(fullfile(temporaryRoot,"historical_runs_audit.json"), ...
    struct("passed",true,"before_count",0, ...
    "after_historical_count",0,"missing_paths",strings(0,1), ...
    "unexpected_historical_paths",strings(0,1), ...
    "changed_paths",strings(0,1)));
[reportPath,validation] = ...
    rkkt.reporting.generate_stage_a4_iteration24_scaling_stress_report(context);
verifyTrue(testCase,isfile(reportPath));
verifyEmpty(testCase,validation.errors);
options = detectImportOptions(context.acceptance_results_path, ...
    "Delimiter",",","TextType","string", ...
    "VariableNamingRule","preserve");
options.Delimiter=",";
options.DataLines=[2 Inf];
options=setvartype(options,"string");
acceptance = readtable(context.acceptance_results_path,options);
verifyEqual(testCase,height(acceptance),13);
verifyEqual(testCase,nnz(acceptance.status=="PASS"),13);
verifyTrue(testCase,isfile(fullfile(temporaryRoot,"diagnostics", ...
    "forbidden_execution_audit.csv")));
verifyTrue(testCase,isfile(fullfile(temporaryRoot,"diagnostics", ...
    "dependency_closure.csv")));
verifyTrue(testCase,isfile(fullfile(temporaryRoot,"diagnostics", ...
    "model_scope_audit.csv")));
clear cleanup
end

function remove_test_directory(pathValue)
if isfolder(pathValue)
    rmdir(pathValue,"s");
end
end
