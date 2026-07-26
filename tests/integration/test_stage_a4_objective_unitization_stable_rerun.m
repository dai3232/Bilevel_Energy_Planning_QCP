function tests = test_stage_a4_objective_unitization_stable_rerun
%TEST_STAGE_A4_OBJECTIVE_UNITIZATION_STABLE_RERUN Fixed R1 evidence.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
projectRoot = string(fileparts(fileparts(fileparts(mfilename("fullpath")))));
addpath(projectRoot);
addpath(fullfile(projectRoot,"tests"));
addpath(genpath(fullfile(projectRoot,"src")));
protectedBefore = protected_hashes(projectRoot);
runsBefore = recursive_run_inventory(projectRoot);
[cached,hasCached] = stage_a4_r1_test_cache("get");
if hasCached
    result = cached;
else
    result = main_stage_A4_2D_2A_R1();
end
testCase.TestData.project_root = projectRoot;
testCase.TestData.result = result;
testCase.TestData.used_precomputed_result = hasCached;
testCase.TestData.protected_before = protectedBefore;
testCase.TestData.protected_after = protected_hashes(projectRoot);
testCase.TestData.runs_before = runsBefore;
testCase.TestData.runs_after = recursive_run_inventory(projectRoot);
end

function testThreeChainsCompleteFiveFiveTwentyAndThirtyUpdates(testCase)
result = testCase.TestData.result;
verifyEqual(testCase,result.milestone_status,"PASS");
verifyTrue(testCase,result.all_blocking_pass);
verifyTrue(testCase,result.forbidden_execution_pass);
verifyTrue(testCase,result.execution.forbidden_execution_audit_pass);
verifyEqual(testCase,result.unscaled_five.iteration_count,5);
verifyEqual(testCase,result.scaled_five.iteration_count,5);
verifyEqual(testCase,result.scaled_twenty.iteration_count,20);
verifyFalse(testCase,result.scaled_twenty.failure.present);
verifyEqual(testCase,result.execution.total_newton_direction_count,30);
verifyEqual(testCase,result.execution.state_update_count,30);
verifyEqual(testCase,result.execution.full_kkt_audit_count,30);
verifyEqual(testCase,height(result.round_table),30);
end

function testScaledFiveAndTwentyPrefixDeterministicFieldsExact(testCase)
audit = testCase.TestData.result.scaled_prefix_audit;
verifyTrue(testCase,audit.fresh_initial_state_exact);
verifyTrue(testCase,all(audit.per_iteration_exact));
verifyTrue(testCase,all(audit.per_field_exact,"all"));
verifyTrue(testCase,audit.all_pass);
verifyGreaterThanOrEqual(testCase,numel(audit.compared_field_names),30);
verifyEqual(testCase,audit.excluded_chain_specific_fields, ...
    ["r1_chain_id","timing","timing_total_seconds"]);
end

function testThreeInitialCanonicalStatesBitwiseEqual(testCase)
result = testCase.TestData.result;
audit = result.initialization_audit;
verifyTrue(testCase,audit.unscaled_vs_scaled_five_exact);
verifyTrue(testCase,audit.unscaled_vs_scaled_twenty_exact);
verifyTrue(testCase,audit.scaled_five_vs_twenty_exact);
verifyTrue(testCase,audit.fingerprints_exact);
verifyEqual(testCase,numel(unique(audit.initial_fingerprints)),1);
verifyEqual(testCase,result.unscaled_five.initial_state_revision,0);
verifyEqual(testCase,result.scaled_five.initial_state.state_revision,0);
verifyEqual(testCase,result.scaled_twenty.initial_state.state_revision,0);
end

function testStableV2MaxPassesThreeOnAllThirtyRounds(testCase)
result = testCase.TestData.result;
verifyEqual(testCase,result.recursive_refinement_max_passes,3);
verifyTrue(testCase,result.execution.stable_v2_recursive_route);
verifyEqual(testCase,result.unscaled_five.recursive_refinement_max_passes,3);
verifyEqual(testCase,result.scaled_five.recursive_refinement_max_passes,3);
verifyEqual(testCase,result.scaled_twenty.recursive_refinement_max_passes,3);
verifyTrue(testCase,all( ...
    result.round_table.recursive_refinement_max_passes==3));
verifyTrue(testCase,all(result.refinement_table.maximum_passes==3));
verifyTrue(testCase,all(result.refinement_table.selected_pass<=3));
verifyTrue(testCase,all(result.refinement_table.passes_attempted<=3));
end

function testSevenDayAndCoreRefinementTraceComplete(testCase)
tableValue = testCase.TestData.result.refinement_table;
verifyEqual(testCase,height(tableValue),240);
chains = unique(tableValue.chain_id,'stable');
verifyEqual(testCase,chains, ...
    ["unscaled_stable_5";"scaled_stable_5";"scaled_stable_20"]);
for chain = chains.'
    iterationIds = unique(tableValue.iteration( ...
        tableValue.chain_id==chain));
    for iteration = iterationIds.'
        rows = tableValue(tableValue.chain_id==chain & ...
            tableValue.iteration==iteration,:);
        verifyEqual(testCase,height(rows),8);
        verifyEqual(testCase,rows.object_type(1:7), ...
            repmat("day_chain",7,1));
        verifyEqual(testCase,rows.day_id(1:7),(14:20).');
        verifyEqual(testCase,rows.object_type(8),"global_core");
        verifyTrue(testCase,isnan(rows.day_id(8)));
    end
end
verifyTrue(testCase,all(tableValue.additional_factorization_count==0));
verifyFalse(testCase,any(tableValue.full_kkt_direction_consumed));
verifyTrue(testCase,all(tableValue.residual_operator_exact_original));
verifyTrue(testCase,all(tableValue.factor_context_unchanged));
end

function testAllStatesFiniteAndStrictlyPositive(testCase)
tableValue = testCase.TestData.result.round_table;
verifyTrue(testCase,all(isfinite(tableValue{:,vartype("numeric")}),"all"));
verifyGreaterThan(testCase,min(tableValue.min_l_before),0);
verifyGreaterThan(testCase,min(tableValue.min_l_after),0);
verifyGreaterThan(testCase,min(tableValue.min_z_before),0);
verifyGreaterThan(testCase,min(tableValue.min_z_after),0);
verifyEqual(testCase,max(tableValue.physical_violation_before),0, ...
    "AbsTol",0);
verifyEqual(testCase,max(tableValue.physical_violation_after),0, ...
    "AbsTol",0);
end

function testOverallAndXiYlZDirectionErrorsPass(testCase)
tableValue = testCase.TestData.result.round_table;
verifyLessThanOrEqual(testCase, ...
    max(tableValue.direction_relative_error),1e-10);
verifyLessThanOrEqual(testCase,max(tableValue.xi_relative_error),1e-10);
verifyLessThanOrEqual(testCase,max(tableValue.y_relative_error),1e-10);
verifyLessThanOrEqual(testCase,max(tableValue.l_relative_error),1e-10);
verifyLessThanOrEqual(testCase,max(tableValue.z_relative_error),1e-10);
end

function testRecursiveAndDirectKktResidualsPass(testCase)
result = testCase.TestData.result;
tableValue = result.round_table;
verifyLessThanOrEqual(testCase, ...
    max(tableValue.recursive_full_kkt_relative_residual),1e-10);
verifyLessThanOrEqual(testCase, ...
    max(tableValue.full_kkt_relative_residual),1e-10);
verifyTrue(testCase,all(tableValue.no_full_direction_fallback));
verifyFalse(testCase,result.execution.full_kkt_direction_consumed);
verifyFalse(testCase, ...
    result.execution.complete_kkt_direction_fallback_used);
end

function testIndependentCandidateAppliedStepsAndStateUpdatesExact(testCase)
result = testCase.TestData.result;
chains = {result.unscaled_five,result.scaled_five,result.scaled_twenty};
for chainPosition = 1:numel(chains)
    chain = chains{chainPosition};
    for item = chain.iterations.'
        if chainPosition==1
            before = item.canonical_state_before;
            after = item.canonical_state_after;
            direction = item.recursive_direction_components;
        else
            before = item.state_before;
            after = item.state_after;
            direction = item.recursive_direction;
        end
        ap = item.applied_alpha_primal;
        ad = item.applied_alpha_dual;
        verifyEqual(testCase,item.candidate_alpha_primal,ap,'AbsTol',0);
        verifyEqual(testCase,item.candidate_alpha_dual,ad,'AbsTol',0);
        verifyLessThanOrEqual(testCase,relative_inf_error( ...
            after.xi,before.xi+ap*direction.xi),16*eps);
        verifyLessThanOrEqual(testCase,relative_inf_error( ...
            after.l,before.l+ap*direction.l),16*eps);
        verifyLessThanOrEqual(testCase,relative_inf_error( ...
            after.y,before.y+ad*direction.y),16*eps);
        verifyLessThanOrEqual(testCase,relative_inf_error( ...
            after.z,before.z+ad*direction.z),16*eps);
    end
end
verifyFalse(testCase,result.execution.common_step_used);
end

function testPerRoundMetricCapacityGapAndTimingSchemaComplete(testCase)
result = testCase.TestData.result;
tableValue = result.round_table;
required = ["chain_id","iteration","state_revision_before", ...
    "state_revision_after","r_eq_before","r_eq_after","r_ineq_before", ...
    "r_ineq_after","r_dual_before","r_dual_after","r_comp_before", ...
    "r_comp_after","gap_before","gap_after","candidate_alpha_primal", ...
    "candidate_alpha_dual","applied_alpha_primal", ...
    "applied_alpha_dual","primal_limiter","dual_limiter", ...
    "direction_relative_error","recursive_full_kkt_relative_residual", ...
    "full_kkt_relative_residual","state_fingerprint_before", ...
    "state_fingerprint_after","direction_fingerprint", ...
    "timing_total_seconds"];
verifyTrue(testCase,all(ismember(required, ...
    string(tableValue.Properties.VariableNames))));
capacityNames = ["QW1","QW2","QW3","QW4","QW5", ...
    "QP1","QP2","QP3","QP4","QP5","QS1","QS2","ES1","ES2"];
verifyTrue(testCase,all(ismember(capacityNames, ...
    string(tableValue.Properties.VariableNames))));
verifyTrue(testCase,all(tableValue.timing_total_seconds>0));
verifyTrue(testCase,all(strlength(tableValue.primal_limiter)>0));
verifyTrue(testCase,all(strlength(tableValue.dual_limiter)>0));
expectedGapNames = ["iteration","gap_before","gap_after", ...
    "gap_reduction","gap_reduction_ratio","r_dual_before", ...
    "r_dual_after","alpha_primal","alpha_dual","min_l_after", ...
    "min_z_after"];
for gapCell = {result.gap_tables.unscaled_five, ...
        result.gap_tables.scaled_five}
    gap = gapCell{1};
    verifyEqual(testCase,string(gap.Properties.VariableNames), ...
        expectedGapNames);
    verifyEqual(testCase,height(gap),5);
end
verifyEqual(testCase,string( ...
    result.gap_tables.scaled_twenty.Properties.VariableNames), ...
    expectedGapNames);
verifyEqual(testCase,height(result.gap_tables.scaled_twenty),20);
end

function testConvergenceIntervalsAndMonotonicityConclusionsRebuild(testCase)
result = testCase.TestData.result;
analysis = result.convergence_analysis;
tableValue = analysis.intervals;
verifyEqual(testCase,tableValue.interval_name, ...
    ["initial_to_5";"5_to_18";"18_to_19"; ...
    "19_to_20";"initial_to_20"]);
for row = 1:height(tableValue)
    verifyEqual(testCase,tableValue.gap_scaled_end_to_start_ratio(row), ...
        tableValue.gap_scaled_end(row)/ ...
        tableValue.gap_scaled_start(row),'AbsTol',0);
    verifyEqual(testCase, ...
        tableValue.r_dual_scaled_end_to_start_ratio(row), ...
        tableValue.r_dual_scaled_end(row)/ ...
        tableValue.r_dual_scaled_start(row),'AbsTol',0);
    verifyEqual(testCase,tableValue.r_eq_end_to_start_ratio(row), ...
        tableValue.r_eq_end(row)/tableValue.r_eq_start(row),'AbsTol',0);
end
final = result.scaled_twenty.final_metrics;
thresholds = analysis.thresholds;
expected = final.equality_inf<=thresholds.r_eq && ...
    final.slack_equality_inf<=thresholds.r_ineq && ...
    final.dual_scaled_inf<=thresholds.r_dual_scaled && ...
    final.mean_gap_scaled<=thresholds.gap_scaled;
verifyEqual(testCase,result.convergence_achieved,expected);
verifyFalse(testCase,analysis.formal_convergence_claimed);
verifyTrue(testCase,contains(analysis.projection_definition, ...
    "not a convergence claim"));
end

function testOriginalScaledMappedAndDimensionlessSemanticsTraceable(testCase)
result = testCase.TestData.result;
scale = result.scaled_twenty.objective_scale.factor;
verifyGreaterThan(testCase,scale,0);
for item = result.scaled_twenty.iterations.'
    metrics = {item.metrics_before,item.metrics_after};
    states = {item.state_before,item.state_after};
    for position = 1:2
        value = metrics{position};
        verifyEqual(testCase,value.mapped_mean_gap, ...
            scale*value.mean_gap_scaled,'AbsTol',0);
        verifyEqual(testCase,value.mapped_raw_gap, ...
            scale*value.raw_gap_scaled,'AbsTol',0);
        verifyLessThanOrEqual(testCase, ...
            value.mapping_r_dual_scaled_error,2048*eps);
        mappedY = scale*states{position}.y;
        mappedZ = scale*states{position}.z;
        base = result.scaled_twenty.initial_scaled_linearization;
        rebuilt = base.objective.original_gradient+ ...
            base.A.'*mappedY+base.G.'*mappedZ;
        componentScale = max(1, ...
            norm(base.objective.original_gradient,inf)+ ...
            norm(base.A.'*mappedY,inf)+norm(base.G.'*mappedZ,inf));
        verifyEqual(testCase,value.mapping_r_dual_component_scale, ...
            componentScale,'AbsTol',0);
        verifyEqual(testCase,value.mapping_r_dual_scaled_error, ...
            norm(value.r_dual_original_mapped-rebuilt,inf)/ ...
                componentScale,'AbsTol',0);
        verifyTrue(testCase,isfinite( ...
            value.mapping_r_dual_residual_relative_error));
        verifyLessThanOrEqual(testCase, ...
            value.mapping_r_comp_scaled_error,2048*eps);
        verifyTrue(testCase,isfinite(value.eta_dual_mapped));
        verifyTrue(testCase,isfinite(value.eta_gap_mapped));
    end
end
verifyFalse(testCase,result.convergence_analysis.mean_lz_is_dimensionless);
verifyEqual(testCase,result.convergence_analysis.dimensionless_metrics, ...
    ["eta_eq","eta_dual_mapped","eta_gap_mapped"]);
end

function testInputsModelMatricesIndexAndThresholdsFrozen(testCase)
result = testCase.TestData.result;
verifyEqual(testCase,testCase.TestData.protected_after, ...
    testCase.TestData.protected_before);
hashes = testCase.TestData.protected_after;
verify_hash(testCase,hashes,"AGENTS.md", ...
    "3ce86f80daacc5eb00286c10cf18e2aad2d03c4b9f5f34d6eeaa73ed38b4b319");
verify_hash(testCase,hashes,"CURRENT_STAGE.md", ...
    "c94ca7ad66341830b306c8c0be5aacda561735f457b7c6b898ea0dda82e9522b");
verify_hash(testCase,hashes,"config/solver.yaml", ...
    "596e944c633899f3268eda34683e5684e4034bf110b970ef1e9b59684289b395");
verify_hash(testCase,hashes,"inputs/raw/基础参数.xlsx", ...
    "aebb35fa80e6ba2fb8d4534b09a141feaedcb2b9d027e9924e7a0091943c4277");
verify_hash(testCase,hashes,"inputs/raw/输入数据.xlsx", ...
    "10baac1dc5d0b07dbbb9d2fe8f9aac82f071e43d4fb9901ff7ba0b467d05c186");
verifyTrue(testCase,result.structure_audit.all_pass);
verifyEqual(testCase,result.structure_audit.complete_kkt_dimension,18836);
verifyEqual(testCase,result.structure_audit.fixed_zero_count,422);
verifyEqual(testCase,result.structure_audit.day_ids,(14:20).');
end

function testRound18MinZCorrectionRebuiltFromAuthorityMat(testCase)
root = testCase.TestData.project_root;
pathValue = fullfile(root,"tests","fixtures", ...
    "stage_A4_RNS_1_authority_v1", ...
    "stage_A4_RNS_1_round19_authority_v1.mat");
verifyEqual(testCase,compute_sha256_file(pathValue), ...
    "14c5501a17fc317a5653b8d55ac29f6b103ddcfb3004aef807acff6bde4e62b3");
loaded = load(pathValue,"stateAfterRound18", ...
    "linearizationRound19","sourceEvidence");
state = loaded.stateAfterRound18;
rebuiltMinZ = min(state.z);
rebuiltGap = mean(state.l.*state.z);
verifyEqual(testCase,rebuiltMinZ, ...
    1.5822518332365282e-06,'AbsTol',0);
verifyEqual(testCase,rebuiltGap,0.16366994392519446,'AbsTol',0);
verifyEqual(testCase,state.l,loaded.linearizationRound19.l,'AbsTol',0);
verifyEqual(testCase,state.z,loaded.linearizationRound19.z,'AbsTol',0);
verifyEqual(testCase,loaded.linearizationRound19.complementarity_gap, ...
    rebuiltGap,'AbsTol',0);
verifyEqual(testCase,loaded.sourceEvidence.round18_min_z, ...
    rebuiltMinZ,'AbsTol',0);
verifyNotEqual(testCase,rebuiltMinZ,0.51589348514731437);
end

function testOldD2AFailureAndRnsStableV2EvidencePreserved(testCase)
root = testCase.TestData.project_root;
paths = [ ...
    "main_stage_A4_2D_2A.m"
    "src/diagnostics/run_stage_a4_objective_unitization_diagnostic.m"
    "tests/fixtures/stage_A4_2A_five_round_baseline.csv"
    "tests/fixtures/stage_A4_RNS_1_stable_v2/" + ...
        "stage_A4_RNS_1_stable_v2.mat"
    "tests/fixtures/stage_A4_RNS_1_authority_v1/" + ...
        "stage_A4_RNS_1_round19_authority_v1.mat"];
expected = [ ...
    "940ac90ef5079a9993c0651ec42c4de4e3c58e0609dd00feda67b2d0804b8f34"
    "f8b6ff9d51c6a47d0db88713b3ddee5640e00bb750b998a3d6814815d204575c"
    "f4c17af3506ba57f96104b2ef8abe80c79ba8089a59a4ad608970f8ec8fe36c0"
    "90faccc0f5192b45656b665f6401dfaf05d47c8ee3dfaa5e7fb1b2932002b64b"
    "14c5501a17fc317a5653b8d55ac29f6b103ddcfb3004aef807acff6bde4e62b3"];
for k = 1:numel(paths)
    verifyEqual(testCase,compute_sha256_file(fullfile(root, ...
        strrep(paths(k),"/",filesep))),expected(k));
end
verifyFalse(testCase, ...
    testCase.TestData.result.formal_algorithm_replaced);
end

function testEvidenceCommandHashesSchemaAndNoOverwriteContract(testCase)
root = testCase.TestData.project_root;
result = testCase.TestData.result;
exporter = fullfile(root,"src","diagnostics", ...
    "export_stage_a4_2d_2a_r1_stable_v2_evidence.m");
script = fullfile(root,"scripts", ...
    "export_stage_A4_2D_2A_R1_stable_v2.ps1");
verifyTrue(testCase,isfile(exporter));
verifyTrue(testCase,isfile(script));
code = string(fileread(exporter));
verifyTrue(testCase,contains(code,".building"));
verifyTrue(testCase,contains(code,"Refusing to overwrite"));
verifyTrue(testCase,contains(code,"artifact_sha256"));
verifyTrue(testCase,contains(code,"test_results"));
verifyTrue(testCase,contains(code,"generation_command"));
verifyTrue(testCase,contains(code,"forbidden_execution_audit"));
verifyTrue(testCase,contains(code,"forbidden_code_audit"));
verifyTrue(testCase,contains(code,"dependency_closure_sha256"));
verifyTrue(testCase,result.forbidden_execution_pass);
verifyTrue(testCase,all(result.forbidden_execution_audit.status=="PASS"));
verifyTrue(testCase,all(result.r1_forbidden_code_audit.status=="PASS"));
verifyGreaterThan(testCase,height(result.r1_dependency_closure),2);
verifyEqual(testCase,height(testCase.TestData.result.round_table),30);
verifyEqual(testCase,height( ...
    testCase.TestData.result.residual_trajectory),30);
verifyEqual(testCase,height( ...
    testCase.TestData.result.refinement_table),240);
end

function testIndependentForbiddenExecutionAuditAndR1DependencyClosure(testCase)
root = testCase.TestData.project_root;
result = testCase.TestData.result;
[r1Scan,dependencyClosure] = scan_stage_a4_r1_forbidden_code(root);
verifyEqual(testCase,height(r1Scan),15);
verifyTrue(testCase,all(r1Scan.status=="PASS"), ...
    evalc('disp(r1Scan(r1Scan.status~="PASS",:))'));
verifyGreaterThan(testCase,height(dependencyClosure),2);
requiredDependencies = [ ...
    "main_stage_A4_2D_2A_R1.m"
    "src/diagnostics/run_stage_a4_objective_unitization_r1_diagnostic.m"
    "src/diagnostics/audit_stage_a4_r1_forbidden_execution.m"
    "src/diagnostics/make_stage_a4_r1_blocking_audit.m"
    "src/diagnostics/scan_stage_a4_r1_forbidden_code.m"
    "src/diagnostics/run_stage_a4_five_iteration_diagnostic.m"
    "src/diagnostics/run_stage_a4_scaled_objective_chain.m"
    "src/diagnostics/execute_stage_a4_iteration.m"
    "src/solver/solve_stage_a_multiday_recursive_direction.m"
    "src/solver/solve_stage_a_multiday_full_kkt_direction.m"
    "src/solver/update_primal_dual_state.m"];
verifyTrue(testCase,all(ismember(requiredDependencies, ...
    string(dependencyClosure.relative_path))));
verifyTrue(testCase,all(strlength(string(dependencyClosure.sha256))==64));
verifyEqual(testCase,result.r1_forbidden_code_audit,r1Scan);
verifyEqual(testCase,result.r1_dependency_closure,dependencyClosure);
verifyEqual(testCase,result.execution.r1_dependency_file_count, ...
    height(dependencyClosure));
verifyTrue(testCase,result.execution.r1_dependency_closure_all_hashed);
verifyEqual(testCase,result.execution.r1_dependency_root, ...
    "main_stage_A4_2D_2A_R1.m");
verifyEqual(testCase,result.execution.r1_dependency_analysis_method, ...
    "matlab.codetools.requiredFilesAndProducts");
verifyEqual(testCase,result.execution.r1_forbidden_code_check_count,15);

config = load_stage_a4_configuration(root);
[recomputedAudit,recomputedExecution] = ...
    audit_stage_a4_r1_forbidden_execution( ...
        result.unscaled_five,result.scaled_five,result.scaled_twenty, ...
        result.execution_sequence,result.round_table, ...
        result.refinement_table,config,r1Scan,dependencyClosure);
verifyEqual(testCase,result.forbidden_execution_audit,recomputedAudit);
verifyTrue(testCase,all(recomputedAudit.status=="PASS"));
verifyTrue(testCase,recomputedExecution.forbidden_execution_audit_pass);

noFallbackOnly = result.round_table;
noFallbackOnly.no_full_direction_fallback(:) = false;
[noFallbackAudit,noFallbackExecution] = ...
    audit_stage_a4_r1_forbidden_execution( ...
        result.unscaled_five,result.scaled_five,result.scaled_twenty, ...
        result.execution_sequence,noFallbackOnly,result.refinement_table, ...
        config,r1Scan,dependencyClosure);
verifyTrue(testCase,all(noFallbackAudit.status=="PASS"), ...
    "The forbidden-execution gate must not reuse the no-fallback value.");
verifyTrue(testCase, ...
    noFallbackExecution.complete_kkt_direction_fallback_used);
verifyTrue(testCase,noFallbackExecution.forbidden_execution_audit_pass);
noFallbackBlocking = make_stage_a4_r1_blocking_audit( ...
    result.unscaled_five,result.scaled_five,result.scaled_twenty, ...
    result.scaled_prefix_audit,result.initialization_audit, ...
    result.structure_audit,noFallbackOnly,result.refinement_table, ...
    noFallbackAudit);
noFallbackRow = noFallbackBlocking.test_id=="R1-NO-FALLBACK";
forbiddenRow = ...
    noFallbackBlocking.test_id=="R1-FORBIDDEN-EXECUTION";
verifyEqual(testCase,noFallbackBlocking.status(noFallbackRow),"FAIL");
verifyEqual(testCase,noFallbackBlocking.status(forbiddenRow),"PASS");

commonStepChain = result.unscaled_five;
commonStepChain.step_strategy = "common_min";
[commonStepAudit,commonStepExecution] = ...
    audit_stage_a4_r1_forbidden_execution( ...
        commonStepChain,result.scaled_five,result.scaled_twenty, ...
        result.execution_sequence,result.round_table, ...
        result.refinement_table,config,r1Scan,dependencyClosure);
commonStepRow = commonStepAudit.test_id=="R1-RUN-INDEPENDENT-STEPS";
verifyEqual(testCase,nnz(commonStepRow),1);
verifyEqual(testCase,commonStepAudit.status(commonStepRow),"FAIL");
verifyTrue(testCase,commonStepExecution.common_step_used);
verifyFalse(testCase,commonStepExecution.forbidden_execution_audit_pass);

missingDependency = dependencyClosure( ...
    dependencyClosure.relative_path~= ...
        "src/diagnostics/execute_stage_a4_iteration.m",:);
[missingDependencyAudit,missingDependencyExecution] = ...
    audit_stage_a4_r1_forbidden_execution( ...
        result.unscaled_five,result.scaled_five,result.scaled_twenty, ...
        result.execution_sequence,result.round_table, ...
        result.refinement_table,config,r1Scan,missingDependency);
closureRow = missingDependencyAudit.test_id== ...
    "R1-RUN-ROOTED-DEPENDENCY-CLOSURE";
verifyEqual(testCase,nnz(closureRow),1);
verifyEqual(testCase,missingDependencyAudit.status(closureRow),"FAIL");
verifyFalse(testCase, ...
    missingDependencyExecution.r1_dependency_closure_all_hashed);
verifyFalse(testCase, ...
    missingDependencyExecution.forbidden_execution_audit_pass);

sharedScan = scan_stage_a4_forbidden_code(root,config);
verifyEqual(testCase,height(sharedScan),30);
verifyTrue(testCase,all(sharedScan.status=="PASS"), ...
    evalc('disp(sharedScan(sharedScan.status~="PASS",:))'));
verifyEqual(testCase,result.stage_status,"READY");
verifyFalse(testCase,result.execution.hundred_round_run_executed);
verifyFalse(testCase,result.execution.full_ipm_executed);
verifyFalse(testCase,result.execution.optimization_executed);
verifyFalse(testCase,result.execution.parallel_executed);
verifyFalse(testCase,result.execution.formal_a4_run_created);
verifyFalse(testCase,result.execution.stage_b_entered);
verifyFalse(testCase,result.execution.common_step_used);
verifyFalse(testCase,result.execution.dynamic_sigma_used);
verifyFalse(testCase,result.execution.predictor_corrector_used);
verifyFalse(testCase,result.execution.line_search_used);
verifyFalse(testCase,result.execution.regularization_used);
verifyFalse(testCase,result.execution.automatic_symmetrization_used);
verifyFalse(testCase, ...
    result.execution.forbidden_execution_reuses_no_fallback);
verifyFalse(testCase,result.stage_a4_pass_claimed);
end

function testHistoricalRunsContentUnchanged(testCase)
verifyEqual(testCase,testCase.TestData.runs_after, ...
    testCase.TestData.runs_before);
end

function hashes = protected_hashes(projectRoot)
relative = [ ...
    "AGENTS.md"
    "CURRENT_STAGE.md"
    "config/solver.yaml"
    "config/stage_A4.yaml"
    "src/model/initialize_stage_a4_state.m"
    "src/model/initialize_stage_a_multiday_state.m"
    "src/model/build_stage_a4_linearization.m"
    "src/model/build_stage_a_multiday_linearization.m"
    "inputs/raw/基础参数.xlsx"
    "inputs/raw/输入数据.xlsx"
    "stages/stage_A4/阶段A4_验收矩阵.csv"];
sha256 = strings(numel(relative),1);
for k = 1:numel(relative)
    sha256(k) = compute_sha256_file(fullfile(projectRoot, ...
        strrep(relative(k),"/",filesep)));
end
hashes = table(relative,sha256, ...
    'VariableNames',{'relative_path','sha256'});
end

function verify_hash(testCase,hashes,pathValue,expected)
row = hashes.relative_path==pathValue;
verifyEqual(testCase,nnz(row),1);
verifyEqual(testCase,hashes.sha256(row),expected);
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

function sha256 = compute_sha256_file_streaming(pathValue)
fileId = fopen(pathValue,"rb");
assert(fileId>=0,"stageA4:r1:RunInventoryFileOpen", ...
    "Unable to hash historical run artifact read-only: %s",pathValue);
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

function value = relative_inf_error(actual,expected)
value = norm(actual-expected,inf)/ ...
    max([1,norm(actual,inf),norm(expected,inf)]);
end
