function tests = test_stage_a4_rns1_numerical_stability
%TEST_STAGE_A4_RNS1_NUMERICAL_STABILITY Fixed A4-RNS-1 evidence.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
projectRoot = string(fileparts(fileparts(fileparts(mfilename("fullpath")))));
addpath(projectRoot);
addpath(genpath(fullfile(projectRoot,"src")));
runsBefore = recursive_run_inventory(projectRoot);
protectedBefore = protected_hashes(projectRoot);
result = main_stage_A4_RNS_1();
authority = load_authority_fixture(projectRoot);
diagnostic = solve_stage_a_multiday_diagnostic_rhs_responses( ...
    authority.linearizationRound19,result.first);
defaultZero = solve_stage_a_multiday_recursive_direction( ...
    authority.linearizationRound19, ...
    AssemblyTolerance=1e-12,SymmetryTolerance=1e-10);
testCase.TestData.project_root = projectRoot;
testCase.TestData.result = result;
testCase.TestData.diagnostic = diagnostic;
testCase.TestData.authority = authority;
testCase.TestData.default_zero = defaultZero;
testCase.TestData.runs_before = runsBefore;
testCase.TestData.runs_after = recursive_run_inventory(projectRoot);
testCase.TestData.protected_before = protectedBefore;
testCase.TestData.protected_after = protected_hashes(projectRoot);
end

function testAuthorityFixtureManifestAndReplayProvenance(testCase)
fixture = testCase.TestData.result.fixture;
verifyTrue(testCase,fixture.source_commit_exact);
verifyTrue(testCase,fixture.state_fingerprint_exact);
verifyTrue(testCase,fixture.linearization_fingerprint_exact);
verifyTrue(testCase,fixture.artifact_hashes.all_pass);
verifyTrue(testCase,fixture.input_hashes.all_pass);
verifyTrue(testCase,fixture.authority_failure.all_pass);
verifyTrue(testCase,fixture.all_pass);
end

function testAuthorityFailureSignatureRemainsFrozen(testCase)
fixture = testCase.TestData.result.fixture;
failure = fixture.authority_failure;
verifyEqual(testCase, ...
    fixture.day17_authority_symmetry_relative, ...
    1.2272255924590032e-12,"AbsTol",0);
verifyEqual(testCase, ...
    fixture.authority_loose_direction_relative_error, ...
    6.4303876423081673e-9,"AbsTol",0);
verifyEqual(testCase, ...
    fixture.authority_loose_recursive_kkt_relative_residual, ...
    2.8387370718492251e-10,"AbsTol",0);
verifyEqual(testCase, ...
    testCase.TestData.authority.looseAudit. ...
        full_kkt_relative_residual, ...
    1.2503952621846266e-14,"AbsTol",0);
verifyEqual(testCase,failure.completed_round_count,18);
verifyEqual(testCase,failure.attempted_round,19);
verifyEqual(testCase,failure.failure_day_id,17);
verifyEqual(testCase,failure.failure_identifier, ...
    "stageAMultiday:solver:RecursiveLayerFailure");
verifyEqual(testCase,failure.failure_cause_identifier, ...
    "stageAMultiday:solver:DayResponseAsymmetry");
verifyTrue(testCase,contains(failure.failure_message, ...
    "day_17_response"));
verifyTrue(testCase,failure.mat_schema_exact);
verifyTrue(testCase,failure.round_prefix_exact);
verifyTrue(testCase,failure.round18_boundary_exact);
verifyTrue(testCase,failure.numeric_failure_signature_exact);
verifyTrue(testCase,failure.failure_logic_exact);
verifyTrue(testCase,failure.tooling_commit_anchor_exact);
verifyTrue(testCase,verify_tooling_git_objects( ...
    testCase.TestData.project_root));
verifyTrue(testCase,failure.stage_log_failure_record_exact);
verifyEqual(testCase, ...
    testCase.TestData.result.d2a_original_status_preserved, ...
    "FAIL_RETRYABLE");
end

function testRefinementUsesAtMostThreeRetainedFactorPasses(testCase)
tableValue = testCase.TestData.result.refinement;
verifyEqual(testCase,height(tableValue),8);
verifyLessThanOrEqual(testCase,max(tableValue.selected_pass),3);
verifyLessThanOrEqual(testCase,max(tableValue.passes_attempted),3);
verifyEqual(testCase, ...
    max(tableValue.additional_factorization_count),0);
verifyGreaterThan(testCase, ...
    max(tableValue.selected_pass),0);
end

function testOriginalOperatorResidualDecreasesDeterministically(testCase)
tableValue = testCase.TestData.result.refinement;
verifyLessThanOrEqual(testCase, ...
    tableValue.final_maximum_column_relative, ...
    tableValue.initial_maximum_column_relative);
triggered = tableValue.selected_pass>0;
verifyTrue(testCase,all( ...
    tableValue.final_maximum_column_relative(triggered)< ...
    tableValue.initial_maximum_column_relative(triggered)));
verifyTrue(testCase,all(ismember(tableValue.stop_reason, ...
    ["target_met_initial","target_met", ...
    "residual_no_longer_decreased","maximum_passes_reached"])));
end

function testAllFifteenRhsShareOneSelectedPass(testCase)
result = testCase.TestData.result.first;
for d = 1:numel(result.daily_thomas)
    refinement = result.daily_thomas(d).diagnostics.residual_refinement;
    verifyEqual(testCase,refinement.rhs_count,15);
    verifyTrue(testCase,refinement.all_rhs_share_selected_pass);
    verifyTrue(testCase,refinement.factor_context_unchanged);
    verifyTrue(testCase,refinement.residual_operator_exact_original);
    verifyFalse(testCase, ...
        refinement.correction_operator_claimed_equal_original);
end
end

function testDay17ResponseSymmetryPassesFrozenThreshold(testCase)
actual = testCase.TestData.result.actual;
verifyLessThanOrEqual(testCase, ...
    actual.day17_response_symmetry_relative,1e-12);
verifyLessThan(testCase, ...
    actual.day17_response_symmetry_relative, ...
    testCase.TestData.result.fixture. ...
        day17_authority_symmetry_relative);
end

function testOverallAndComponentDirectionsPass(testCase)
actual = testCase.TestData.result.actual;
verifyLessThanOrEqual(testCase,actual.direction_relative_error,1e-10);
verifyLessThanOrEqual(testCase,actual.xi_relative_error,1e-10);
verifyLessThanOrEqual(testCase,actual.y_relative_error,1e-10);
verifyLessThanOrEqual(testCase,actual.l_relative_error,1e-10);
verifyLessThanOrEqual(testCase,actual.z_relative_error,1e-10);
end

function testRecursiveAndDirectKktResidualsHaveMargin(testCase)
actual = testCase.TestData.result.actual;
verifyLessThanOrEqual(testCase, ...
    actual.recursive_full_kkt_relative_residual,1e-10);
verifyLessThanOrEqual(testCase, ...
    actual.direct_full_kkt_relative_residual,1e-10);
verifyLessThanOrEqual(testCase, ...
    actual.recursive_full_kkt_relative_residual, ...
    actual.engineering_target);
verifyEqual(testCase,actual.numerical_margin_status,"SUFFICIENT");
verifyTrue(testCase,actual.engineering_margin_is_nonblocking);
end

function testNoFullDirectionFallbackOrDirectChainSolve(testCase)
result = testCase.TestData.result;
verifyTrue(testCase,result.first.no_full_direction_fallback);
verifyFalse(testCase,result.first.full_direction_consumed);
verifyTrue(testCase,result.blocking.no_full_direction_fallback);
verifyFalse(testCase, ...
    result.execution.complete_kkt_direction_fallback_used);
verifyEqual(testCase,result.execution.full_kkt_direction_solve_count,0);
verifyEqual(testCase, ...
    result.execution.recursive_reinsertion_matvec_count,2);
verifyEqual(testCase, ...
    result.execution.equivalence_verifier_matvec_count,2);
verifyEqual(testCase,result.execution.full_kkt_audit_matvec_count,4);
for d = 1:numel(result.first.daily_thomas)
    refinement = result.first.daily_thomas(d).diagnostics. ...
        residual_refinement;
    verifyFalse(testCase,refinement.direct_chain_backslash_used);
    verifyFalse(testCase,refinement.full_kkt_direction_consumed);
end
end

function testInputStateRemainsStrictlyPositiveAndUnmodified(testCase)
result = testCase.TestData.result;
verifyGreaterThan(testCase,result.actual.minimum_l,0);
verifyGreaterThan(testCase,result.actual.minimum_z,0);
verifyTrue(testCase,result.blocking.positive_input_state);
verifyEqual(testCase,result.execution.state_update_count,0);
end

function testFactorizedOperatorAndResidualAuditIdentity(testCase)
audit = testCase.TestData.result.operator_audit;
result = testCase.TestData.result.first;
verifyEqual(testCase,audit.factor_count,169);
verifyTrue(testCase,audit.actual_operator_reconstruction_exact);
verifyTrue(testCase,audit.actual_operator_available_for_residual_audit);
verifyTrue(testCase,audit.retained_factor_context_exact);
verifyTrue(testCase,audit.raw_residual_operator_preserved);
verifyGreaterThan(testCase,audit.factorized_solve_audit_count,0);
verifyLessThanOrEqual(testCase, ...
    audit.maximum_factorized_operator_solve_relative_residual, ...
    audit.factorized_operator_solve_sanity_limit);
verifyTrue(testCase,audit.factorized_operator_solve_residuals_finite);
verifyFalse(testCase,audit.automatic_symmetrization_used);
verifyEqual(testCase,audit.additional_factorization_count,0);
verifyTrue(testCase,audit.all_pass);
for d = 1:numel(result.daily_thomas)
    rhs = [result.partition.day(d).r_v,result.partition.day(d).B];
    residual = rhs-result.partition.day(d).M* ...
        result.daily_thomas(d).stacked_solution;
    rebuilt = max(full(sqrt(sum(abs(residual).^2,1)))./ ...
        max(1,full(sqrt(sum(abs(rhs).^2,1)))));
    verifyEqual(testCase,rebuilt,result.daily_thomas(d).diagnostics. ...
        residual_refinement.final_maximum_column_relative, ...
        "AbsTol",0);
end
coreResidual = result.core.rhs- ...
    result.core.matrix*result.core.solution;
coreRebuilt = norm(coreResidual,2)/max(1,norm(result.core.rhs,2));
verifyEqual(testCase,coreRebuilt,result.core.diagnostics. ...
    residual_refinement.final_maximum_column_relative,"AbsTol",0);
end

function testTwoConsecutiveStressSolvesAreBitwiseDeterministic(testCase)
audit = testCase.TestData.result.determinism;
verifyTrue(testCase,audit.direction_exact);
verifyTrue(testCase,audit.refinement_diagnostics_exact);
verifyTrue(testCase,audit.daily_responses_exact);
verifyTrue(testCase,audit.core_solution_exact);
verifyTrue(testCase,audit.all_pass);
end

function testFourSourceResponsesUseRetainedFactorsWithinRnsTolerance(testCase)
result = testCase.TestData.result;
diagnostic = testCase.TestData.diagnostic;
verifyEqual(testCase, ...
    diagnostic.audit.additional_hourly_factorization_count,0);
verifyEqual(testCase, ...
    diagnostic.audit.additional_core_factorization_count,0);
verifyFalse(testCase,diagnostic.audit.complete_direction_consumed);
verifyFalse(testCase,diagnostic.audit.full_direction_fallback);
for d = 1:numel(diagnostic.day)
    verifyEqual(testCase, ...
        diagnostic.day(d).solve.selected_pass_inherited, ...
        result.first.daily_thomas(d).diagnostics. ...
            residual_refinement.selected_pass);
    verifyTrue(testCase,diagnostic.day(d).solve.fixed_pass_schedule);
end
verifyEqual(testCase, ...
    diagnostic.solve_diagnostics.core.selected_pass_inherited, ...
    result.first.core.diagnostics.residual_refinement.selected_pass);
verifyTrue(testCase, ...
    diagnostic.solve_diagnostics.core.fixed_pass_schedule);
verifyLessThanOrEqual(testCase, ...
    diagnostic.audit.maximum_source_complete_kkt_scaled_residual,1e-10);
verifyLessThanOrEqual(testCase, ...
    diagnostic.audit.direction_reconstruction_scaled_error,1e-10);
verifyLessThanOrEqual(testCase, ...
    max(diagnostic.audit.component_reconstruction_scaled_error),1e-10);
end

function testDefaultZeroPassPathReplaysAuthorityBitwise(testCase)
authority = testCase.TestData.authority;
defaultZero = testCase.TestData.default_zero;
verifyEqual(testCase, ...
    defaultZero.direction,authority.authorityLooseDirection);
verifyEqual(testCase,defaultZero.residual_refinement.maximum_passes,0);
for d = 1:numel(defaultZero.daily_thomas)
    refinement = defaultZero.daily_thomas(d).diagnostics. ...
        residual_refinement;
    verifyFalse(testCase,refinement.enabled);
    verifyEqual(testCase,refinement.selected_pass,0);
    verifyEqual(testCase,refinement.passes_attempted,0);
end
verifyFalse(testCase, ...
    defaultZero.core.diagnostics.residual_refinement.enabled);
verifyEqual(testCase, ...
    defaultZero.core.diagnostics.residual_refinement.selected_pass,0);
end

function testSharedPolicyHasNoDayRoundOrObjectiveSpecialCase(testCase)
root = testCase.TestData.project_root;
paths = [ ...
    fullfile(root,"src","solver","private", ...
        "refine_block_thomas_solution.m")
    fullfile(root,"src","solver","private", ...
        "refine_with_retained_ldl_factor.m")];
for pathValue = paths.'
    text = string(fileread(pathValue));
    verifyFalse(testCase,contains(text,"day_17"));
    verifyFalse(testCase,contains(text,"round19"));
    verifyFalse(testCase,contains(text,"A4-2D-2A"));
    verifyFalse(testCase,contains(text,"objective_scale"));
    verifyFalse(testCase,contains(text,"DiagnosticObjectiveChainId"));
end
verifyTrue(testCase, ...
    testCase.TestData.result.first.residual_refinement. ...
        uniform_shared_solver_path);
end

function testForbiddenCodeAnalyzerAndStageGovernance(testCase)
root = testCase.TestData.project_root;
config = load_stage_a4_configuration(root);
scan = scan_stage_a4_forbidden_code(root,config);
verifyTrue(testCase,all(scan.status=="PASS"));
requiredScanIds = [ ...
    "NO-RNS-DIRECT-RAW-OPERATOR-BACKSLASH"
    "NO-RNS-AUTOMATIC-SYMMETRIZATION"
    "NO-RNS-DIRECT-SOLVER-DEPENDENCY"
    "NO-RNS-STAGE-B-DEPENDENCY"];
verifyTrue(testCase,all(ismember(requiredScanIds,scan.check_id)));
for pathValue = rns_matlab_files(root).'
    verifyEmpty(testCase,checkcode(pathValue,"-struct"));
end
current = string(fileread(fullfile(root,"CURRENT_STAGE.md")));
verifyTrue(testCase,contains(current,"`stage_id`: `stage_A4`"));
verifyTrue(testCase,contains(current,"`status`: `READY`"));
verifyEqual(testCase, ...
    testCase.TestData.result.milestone_status,"PASS");
verifyTrue(testCase,testCase.TestData.result.all_blocking_pass);
verifyFalse(testCase,testCase.TestData.result.stage_a4_pass_claimed);
end

function testProtectedInputsAndHistoricalRunsRemainUnchanged(testCase)
verifyEqual(testCase,testCase.TestData.protected_after, ...
    testCase.TestData.protected_before);
verifyEqual(testCase,testCase.TestData.runs_after, ...
    testCase.TestData.runs_before);
execution = testCase.TestData.result.execution;
verifyFalse(testCase,execution.hundred_round_run_executed);
verifyFalse(testCase,execution.full_ipm_executed);
verifyFalse(testCase,execution.optimization_executed);
verifyFalse(testCase,execution.parallel_executed);
verifyFalse(testCase,execution.formal_a4_run_created);
verifyFalse(testCase,execution.d2a_rerun_executed);
verifyFalse(testCase,execution.stage_b_entered);
end

function fixture = load_authority_fixture(root)
pathValue = fullfile(root,"tests","fixtures", ...
    "stage_A4_RNS_1_authority_v1", ...
    "stage_A4_RNS_1_round19_authority_v1.mat");
fixture = load(pathValue);
end

function hashes = protected_hashes(root)
relative = [ ...
    "AGENTS.md"
    "CURRENT_STAGE.md"
    "config/solver.yaml"
    "config/stage_A4.yaml"
    "docs/00_用户确认的模型口径_v1.0.md"
    "docs/02_最终模型合同_v1.0.md"
    "inputs/raw/基础参数.xlsx"
    "inputs/raw/输入数据.xlsx"
    "stages/stage_A4/阶段A4_验收矩阵.csv"
    "stages/stage_A4/阶段A4_状态与决策日志.md"
    "main_stage_A4_2D_2A.m"
    "src/diagnostics/run_stage_a4_objective_unitization_diagnostic.m"
    "src/diagnostics/run_stage_a4_scaled_objective_chain.m"
    "tests/integration/test_stage_a4_objective_unitization_diagnostic.m"
    "tests/run_stage_A4_2D_2A_tests.m"
    "tests/stage_A4_2D_2A_expected_test_inventory.csv"
    "tests/fixtures/stage_A4_RNS_1_authority_v1/" + ...
        "stage_A4_RNS_1_round19_authority_v1.mat"
    "tests/fixtures/stage_A4_RNS_1_authority_v1/" + ...
        "stage_A4_RNS_1_round19_authority_v1.metadata.json"
    "tests/fixtures/stage_A4_RNS_1_authority_v1/" + ...
        "stage_A4_RNS_1_authority_round_prefix.csv"
    "tests/fixtures/stage_A4_RNS_1_authority_v1/" + ...
        "stage_A4_RNS_1_authority_input_hashes.csv"
    "tests/fixtures/stage_A4_RNS_1_authority_v1/" + ...
        "stage_A4_RNS_1_authority_generation_command.txt"
    "tests/fixtures/stage_A4_RNS_1_authority_v1/" + ...
        "stage_A4_RNS_1_authority_artifact_sha256.csv"];
hashes = strings(numel(relative),1);
for k = 1:numel(relative)
    hashes(k) = compute_sha256_file( ...
        fullfile(root,strrep(relative(k),"/",filesep)));
end
end

function inventory = recursive_run_inventory(root)
runRoot = fullfile(root,"runs");
entries = dir(fullfile(runRoot,"**","*"));
entries = entries(~ismember(string({entries.name}),[".",".."]));
relative = strings(numel(entries),1);
entryType = strings(numel(entries),1);
bytes = zeros(numel(entries),1);
modified = zeros(numel(entries),1);
sha256 = strings(numel(entries),1);
for k = 1:numel(entries)
    relative(k) = replace(string(fullfile(entries(k).folder, ...
        entries(k).name)),string(runRoot)+filesep,"");
    bytes(k) = entries(k).bytes;
    modified(k) = entries(k).datenum;
    if entries(k).isdir
        entryType(k) = "directory";
    else
        entryType(k) = "file";
        sha256(k) = compute_sha256_file_streaming(fullfile( ...
            entries(k).folder,entries(k).name));
    end
end
inventory = table(entryType,relative,bytes,modified,sha256);
inventory = sortrows(inventory,["entryType","relative"]);
end

function paths = rns_matlab_files(root)
relative = [ ...
    "main_stage_A4_RNS_1.m"
    "src/diagnostics/compute_stage_a4_rns1_fingerprint.m"
    "src/diagnostics/execute_stage_a4_iteration.m"
    "src/diagnostics/generate_stage_a4_rns1_stress_fixture.m"
    "src/diagnostics/run_stage_a4_rns1_stability_audit.m"
    "src/diagnostics/run_stage_a4_scaled_objective_chain.m"
    "src/diagnostics/scan_stage_a4_forbidden_code.m"
    "src/diagnostics/validate_stage_a4_rns1_test_inventory_contract.m"
    "src/solver/private/apply_retained_block_thomas_once.m"
    "src/solver/private/apply_retained_block_thomas_refinement_passes.m"
    "src/solver/private/apply_retained_ldl_refinement_passes.m"
    "src/solver/private/compute_retained_residual_metrics.m"
    "src/solver/private/factor_symmetric_ldl.m"
    "src/solver/private/refine_block_thomas_solution.m"
    "src/solver/private/refine_with_retained_ldl_factor.m"
    "src/solver/private/solve_with_ldl_factor.m"
    "src/solver/solve_block_thomas_ldl.m"
    "src/solver/solve_core16_ldl.m"
    "src/solver/solve_recursive_direction.m"
    "src/solver/solve_stage_a3_core16_ldl.m"
    "src/solver/solve_stage_a3_recursive_direction.m"
    "src/solver/solve_stage_a_multiday_core16_ldl.m"
    "src/solver/solve_stage_a_multiday_diagnostic_rhs_responses.m"
    "src/solver/solve_stage_a_multiday_recursive_direction.m"
    "tests/integration/test_stage_a4_rns1_numerical_stability.m"
    "tests/run_stage_A4_RNS_1_tests.m"];
paths = strings(numel(relative),1);
for k = 1:numel(relative)
    paths(k) = fullfile(root,strrep(relative(k),"/",filesep));
end
assert(all(isfile(paths)), ...
    "stageA4:rns1:ChangedCodeInventory", ...
    "The RNS MATLAB Code Analyzer inventory contains missing files.");
end

function exact = verify_tooling_git_objects(projectRoot)
commit = "8722eb86cbc10190b1d60afc60868de9ef35cde4";
paths = [ ...
    "scripts/generate_stage_A4_RNS_1_fixture.ps1"
    "src/diagnostics/generate_stage_a4_rns1_stress_fixture.m"
    "src/diagnostics/compute_stage_a4_rns1_fingerprint.m"];
expectedBlobs = [ ...
    "3fb92ebd3b005ad8dfe133bb92afaf0fc7091eee"
    "c44de265a4b94a0f6a9e4c9bdcb669b4b2868964"
    "e462e174fd3857540508c25e1a7bc91cf077cc48"];
actualBlobs = strings(numel(paths),1);
statuses = ones(numel(paths),1);
safeRoot = replace(projectRoot,"\","/");
for k = 1:numel(paths)
    command = sprintf( ...
        'git -c safe.directory="%s" -C "%s" rev-parse "%s:%s"', ...
        safeRoot,projectRoot,commit,paths(k));
    [statuses(k),output] = system(command);
    actualBlobs(k) = strip(string(output));
end
exact = all(statuses==0) && isequal(actualBlobs,expectedBlobs);
end

function sha256 = compute_sha256_file_streaming(pathValue)
fileId = fopen(pathValue,"rb");
assert(fileId>=0,"stageA4:rns1:RunInventoryFileOpen", ...
    "Unable to open historical run artifact for read-only hashing: %s", ...
    pathValue);
cleanup = onCleanup(@()fclose(fileId));
messageDigest = java.security.MessageDigest.getInstance("SHA-256");
while true
    bytes = fread(fileId,1024*1024,"*uint8");
    if isempty(bytes)
        break
    end
    messageDigest.update(typecast(bytes,"int8"));
end
digestBytes = mod(double(messageDigest.digest()),256);
sha256 = lower(join(compose("%02x",digestBytes),""));
sha256 = reshape(sha256,1,1);
clear cleanup
end
