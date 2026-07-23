function tests = test_stage_a4_common_step_ab_comparison
%TEST_STAGE_A4_COMMON_STEP_AB_COMPARISON Verify the fixed A4-2C A/B audit.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
projectRoot = string(fileparts(fileparts(fileparts(mfilename("fullpath")))));
addpath(projectRoot);
addpath(genpath(fullfile(projectRoot,"src")));
runsBefore = recursive_run_inventory(projectRoot);
currentStagePath = fullfile(projectRoot,"CURRENT_STAGE.md");
solverPath = fullfile(projectRoot,"config","solver.yaml");
stageConfigPath = fullfile(projectRoot,"config","stage_A4.yaml");
currentStageHashBefore = string(compute_sha256_file(currentStagePath));
solverHashBefore = string(compute_sha256_file(solverPath));
stageConfigHashBefore = string(compute_sha256_file(stageConfigPath));
result = main_stage_A4_2C();
fixturePath = fullfile(projectRoot,"tests","fixtures", ...
    "stage_A4_2A_five_round_baseline.csv");
baseline = readtable(fixturePath,'Delimiter',',', ...
    'ReadVariableNames',true,'TextType','string', ...
    'VariableNamingRule','preserve');
testCase.TestData.project_root = projectRoot;
testCase.TestData.result = result;
testCase.TestData.baseline = baseline;
testCase.TestData.runs_before = runsBefore;
testCase.TestData.runs_after = recursive_run_inventory(projectRoot);
testCase.TestData.current_stage_hash_before = currentStageHashBefore;
testCase.TestData.current_stage_hash_after = ...
    string(compute_sha256_file(currentStagePath));
testCase.TestData.solver_hash_before = solverHashBefore;
testCase.TestData.solver_hash_after = ...
    string(compute_sha256_file(solverPath));
testCase.TestData.stage_config_hash_before = stageConfigHashBefore;
testCase.TestData.stage_config_hash_after = ...
    string(compute_sha256_file(stageConfigPath));
end

function testBaselineChainReproducesFrozenA42AFieldByField(testCase)
result = testCase.TestData.result;
expected = testCase.TestData.baseline;
actual = result.baseline_table;
verifyEqual(testCase,height(actual),5);
verifyEqual(testCase,string(actual.Properties.VariableNames), ...
    string(expected.Properties.VariableNames));
verifyEqual(testCase,actual.primal_limiter,string(expected.primal_limiter));
verifyEqual(testCase,actual.dual_limiter,string(expected.dual_limiter));
numericNames = setdiff(string(actual.Properties.VariableNames), ...
    ["primal_limiter","dual_limiter"],'stable');
for name = numericNames
    verifyEqual(testCase,actual.(name),double(expected.(name)), ...
        'AbsTol',0,sprintf('Frozen A4-2A mismatch in %s.',name));
end
chainA = result.chain_a;
verifyEqual(testCase,chainA.step_strategy,"independent");
verifyTrue(testCase,all([chainA.complementarity_audits.all_pass]));
verifyFalse(testCase,any( ...
    [chainA.complementarity_audits.contribution_analysis_evaluated]));
verifyEqual(testCase,[chainA.iterations.candidate_alpha_primal], ...
    [chainA.iterations.applied_alpha_primal],'AbsTol',0);
verifyEqual(testCase,[chainA.iterations.candidate_alpha_dual], ...
    [chainA.iterations.applied_alpha_dual],'AbsTol',0);
end

function testChainsStartEqualAndRemainStateIdentityIsolated(testCase)
result = testCase.TestData.result;
audit = result.isolation;
verifyTrue(testCase,audit.initial_canonical_states_exact);
verifyTrue(testCase,audit.chain_ids_distinct);
verifyTrue(testCase,audit.index_run_ids_distinct);
verifyTrue(testCase,audit.linearization_identity_sets_disjoint);
verifyTrue(testCase,audit.chain_states_diverge_after_first_update);
verifyTrue(testCase,audit.chain_a_unchanged_after_chain_b);
verifyTrue(testCase,audit.state_contains_no_mutable_handle);
verifyTrue(testCase,audit.passed);
verifyEqual(testCase,result.chain_a.initial_state.xi, ...
    result.chain_b.initial_state.xi,'AbsTol',0);
verifyEqual(testCase,result.chain_a.initial_state.y, ...
    result.chain_b.initial_state.y,'AbsTol',0);
verifyEqual(testCase,result.chain_a.initial_state.l, ...
    result.chain_b.initial_state.l,'AbsTol',0);
verifyEqual(testCase,result.chain_a.initial_state.z, ...
    result.chain_b.initial_state.z,'AbsTol',0);
verifyNotEqual(testCase,result.chain_a.diagnostic_chain_id, ...
    result.chain_b.diagnostic_chain_id);
aIdentities = [string({result.chain_a.iterations.linearization_identity_before}), ...
    string({result.chain_a.iterations.linearization_identity_after})];
bIdentities = [string({result.chain_b.iterations.linearization_identity_before}), ...
    string({result.chain_b.iterations.linearization_identity_after})];
verifyEmpty(testCase,intersect(unique(aIdentities),unique(bIdentities)));
aStates = string({result.chain_a.iterations.state_fingerprint_after});
bStates = string({result.chain_b.iterations.state_fingerprint_after});
verifyTrue(testCase,all(aStates~=bStates));
end

function testCommonStepUpdatesAllFourCanonicalStateGroups(testCase)
result = testCase.TestData.result;
audit = result.common_step_audit;
verifyTrue(testCase,audit.passed);
verifyTrue(testCase,all(audit.all_four_groups_common));
verifyLessThanOrEqual(testCase, ...
    audit.maximum_state_update_relative_error,16*eps);
for k = 1:5
    item = result.chain_b.iterations(k);
    before = item.canonical_state_before;
    after = item.canonical_state_after;
    direction = item.recursive_direction_components;
    alpha = min(item.candidate_alpha_primal,item.candidate_alpha_dual);
    verifyEqual(testCase,item.applied_alpha_primal,alpha,'AbsTol',0);
    verifyEqual(testCase,item.applied_alpha_dual,alpha,'AbsTol',0);
    verifyEqual(testCase,after.xi,before.xi+alpha*direction.xi, ...
        'AbsTol',0);
    verifyEqual(testCase,after.l,before.l+alpha*direction.l, ...
        'AbsTol',0);
    verifyEqual(testCase,after.y,before.y+alpha*direction.y, ...
        'AbsTol',0);
    verifyEqual(testCase,after.z,before.z+alpha*direction.z, ...
        'AbsTol',0);
    verifyTrue(testCase,item.applied_step.all_four_groups_use_common_step);
    verifyTrue(testCase,item.applied_step.policy_contract_passed);
end
end

function testExperimentalChainRebuildsAndResolvesEveryRound(testCase)
result = testCase.TestData.result;
audit = result.direction_provenance;
verifyTrue(testCase,audit.passed);
verifyTrue(testCase,all(audit.source_identity_bound_to_chain_b));
verifyTrue(testCase,audit.chain_b_consumes_only_previous_chain_b_state);
verifyTrue(testCase,audit.solve_invocation_ids_unique);
verifyTrue(testCase,audit.round_one_direction_equal_from_same_initial_state);
verifyTrue(testCase, ...
    audit.rounds_two_to_five_direction_fingerprints_diverge);
verifyEqual(testCase,audit.recursive_solve_count,5);
verifyEqual(testCase,audit.full_kkt_audit_count,5);
chainA = result.chain_a.iterations;
chainB = result.chain_b.iterations;
chainBAudits = result.chain_b.complementarity_audits;
verifyTrue(testCase,all([chainBAudits.all_pass]));
verifyFalse(testCase,any( ...
    [chainBAudits.contribution_analysis_evaluated]));
for name = ["xi","y","l","z"]
    verifyEqual(testCase, ...
        chainA(1).recursive_direction_components.(name), ...
        chainB(1).recursive_direction_components.(name),'AbsTol',0);
end
for k = 1:5
    source = chainB(k).linearization_identity_before;
    verifyEqual(testCase, ...
        chainB(k).recursive_direction_linearization_identity,source);
    verifyEqual(testCase, ...
        chainB(k).full_kkt_direction_linearization_identity,source);
    verifyEqual(testCase, ...
        chainB(k).direction_audit_linearization_identity,source);
    verifyTrue(testCase,contains(source,"diagnostic_chain=A4-2C-B"));
    verifyLessThanOrEqual(testCase,chainB(k).direction_relative_error,1e-10);
    verifyLessThanOrEqual(testCase, ...
        chainB(k).recursive_kkt_relative_residual,1e-10);
    verifyLessThanOrEqual(testCase,chainB(k).full_kkt_relative_residual,1e-10);
    verifyTrue(testCase,chainB(k).no_full_direction_fallback);
    verifyTrue(testCase,chainBAudits(k).all_pass);
    verifyEqual(testCase,sort(chainBAudits(k).not_evaluated_checks), ...
        sort(["constraint_family_summary_closed"; ...
        "asset_type_summary_closed";"top20_traceable"]));
    if k>1
        verifyEqual(testCase,chainB(k).canonical_state_before.xi, ...
            chainB(k-1).canonical_state_after.xi,'AbsTol',0);
        verifyEqual(testCase,chainB(k).canonical_state_before.y, ...
            chainB(k-1).canonical_state_after.y,'AbsTol',0);
        verifyEqual(testCase,chainB(k).canonical_state_before.l, ...
            chainB(k-1).canonical_state_after.l,'AbsTol',0);
        verifyEqual(testCase,chainB(k).canonical_state_before.z, ...
            chainB(k-1).canonical_state_after.z,'AbsTol',0);
    end
end
end

function testResidualCentralityObjectiveCapacityComparisonIsComplete(testCase)
result = testCase.TestData.result;
verifyEqual(testCase,height(result.chain_summary),10);
verifyEqual(testCase,height(result.residual_gap_comparison),55);
verifyEqual(testCase,height(result.capacity_history),20);
verifyEqual(testCase,height(result.centrality_statistics),40);
verifyEqual(testCase,height(result.residual_scale_statistics),40);
verifyEqual(testCase,height(result.inequality_family_scale_statistics),640);
verifyEqual(testCase,width(result.capacity_history),19);
verifyTrue(testCase,all(isfinite(result.chain_summary.objective_after)));
capacityNames = ["QW1","QW2","QW3","QW4","QW5", ...
    "QP1","QP2","QP3","QP4","QP5","QS1","QS2","ES1","ES2"];
verifyTrue(testCase,all(ismember(capacityNames, ...
    string(result.capacity_history.Properties.VariableNames))));
for chain = ["A4-2C-A","A4-2C-B"]
    rows = result.chain_summary(result.chain_summary.chain_id==chain,:);
    verifyEqual(testCase,height(rows),5);
    verifyTrue(testCase,all(isfinite(table2array(rows(:, ...
        setdiff(string(rows.Properties.VariableNames), ...
        ["chain_id","strategy","primal_limiter","dual_limiter", ...
        "primal_limiter_asset_type","dual_limiter_asset_type"], ...
        'stable')))),'all'));
    verifyGreaterThan(testCase,min(rows.minimum_l_after),0);
    verifyGreaterThan(testCase,min(rows.minimum_z_after),0);
end
verify_chain_summary_traceability(testCase,result);
verify_capacity_history_traceability(testCase,result);
verify_comparison_traceability(testCase,result);
verify_centrality_traceability(testCase,result);
slackRows = result.residual_gap_comparison( ...
    result.residual_gap_comparison.metric=="slack_equality_inf",:);
verifyEqual(testCase,slackRows.initial_value,zeros(5,1),'AbsTol',0);
verifyFalse(testCase,any(slackRows.chain_a_ratio_defined));
verifyFalse(testCase,any(slackRows.chain_b_ratio_defined));
verifyTrue(testCase,all(isnan(slackRows.chain_a_ratio_to_initial)));
gapRows = result.residual_gap_comparison( ...
    result.residual_gap_comparison.metric=="complementarity_gap",:);
verifyTrue(testCase,all(gapRows.chain_a_ratio_defined));
verifyTrue(testCase,all(gapRows.chain_b_ratio_defined));
verifyTrue(testCase,all(isfinite(gapRows.chain_b_to_chain_a_ratio)));
verifyFalse(testCase,result.convergence_claimed);
verifyFalse(testCase,result.formal_step_rule_replaced);
verifyTrue(testCase,result.numeric_audit.passed);
verifyTrue(testCase, ...
    result.numeric_audit.component_direction_errors_within_threshold);
end

function testResidualScalesCloseOverallAndByConstraintFamily(testCase)
result = testCase.TestData.result;
inventory = result.inequality_inventory;
verifyEqual(testCase,height(inventory),7248);
chains = {result.chain_a,result.chain_b};
for c = 1:2
    for k = 1:5
        item = chains{c}.iterations(k);
        audit = chains{c}.complementarity_audits(k);
        verifyTrue(testCase,audit.checks.residual_definitions_exact);
        verifyTrue(testCase,audit.checks.residual_scale_coverage_closed);
        for quantity = ["r_ineq","r_comp"]
            for state = ["before","after"]
                values = item.("residual_vectors_"+state).(quantity);
                overall = audit.residual_scale_statistics( ...
                    audit.residual_scale_statistics.quantity==quantity & ...
                    audit.residual_scale_statistics.state==state,:);
                verifyEqual(testCase,height(overall),1);
                verify_scale_row(testCase,overall,values);
                grouped = audit.inequality_family_scale_statistics( ...
                    audit.inequality_family_scale_statistics.quantity== ...
                        quantity & ...
                    audit.inequality_family_scale_statistics.state==state,:);
                verifyEqual(testCase,height(grouped),16);
                verifyEqual(testCase,sum(grouped.count),7248);
                for family = grouped.group_name.'
                    mask = string(inventory.constraint_name)==family;
                    row = grouped(grouped.group_name==family,:);
                    verifyEqual(testCase,height(row),1);
                    verify_scale_row(testCase,row,values(mask));
                end
            end
        end
    end
end
verifyTrue(testCase,result.scale_coverage.passed);
end

function testA42CProductionClosurePassesForbiddenCallScan(testCase)
result = testCase.TestData.result;
scan = scan_stage_a4_forbidden_code( ...
    testCase.TestData.project_root,result.config);
verifyEqual(testCase,string(scan.status),repmat("PASS",height(scan),1), ...
    evalc('disp(scan(scan.status~="PASS",:))'));
verifyEqual(testCase,scan.match_count,zeros(height(scan),1));
verifyTrue(testCase,any(scan.check_id== ...
    "NO-A42C-ADDITIONAL-DENSE-CONDITION-NUMBER"));
verifyTrue(testCase,any(scan.check_id=="NO-PREDICTOR-CORRECTOR"));
verifyFalse(testCase,any(contains(lower(scan.matched_files), ...
    ["tests/","runs/"])));
auditSource = string(fileread(fullfile(testCase.TestData.project_root, ...
    "src","diagnostics","audit_stage_a4_complementarity_change.m")));
verifyTrue(testCase,contains(auditSource, ...
    "max(summary.closure_relative_error)<=2048*eps"));
verifyFalse(testCase,contains(auditSource,"closure_tolerance"));
end

function testDiagnosticCreatesNoRunAndPreservesStageGovernance(testCase)
result = testCase.TestData.result;
verifyEqual(testCase,result.stage_id,"stage_A4");
verifyEqual(testCase,result.stage_status,"READY");
verifyEqual(testCase,result.milestone_status,"PASS");
verifyEqual(testCase,result.execution.chain_count,2);
verifyEqual(testCase,result.execution.iterations_per_chain,5);
verifyEqual(testCase,result.execution.newton_direction_count,10);
verifyEqual(testCase,result.execution.full_kkt_audit_count,10);
verifyEqual(testCase,result.execution.state_update_count,10);
verifyEqual(testCase,result.execution.solver_parameter_change_count,0);
verifyEqual(testCase,result.execution.formal_step_rule_change_count,0);
verifyFalse(testCase,result.execution.full_ipm_executed);
verifyFalse(testCase,result.execution.optimization_executed);
verifyFalse(testCase,result.execution.parallel_executed);
verifyFalse(testCase,result.execution.formal_a4_run_created);
verifyFalse(testCase,result.execution.stage_b_entered);
verifyEqual(testCase,result.config.initialization.centering_sigma,0.1, ...
    'AbsTol',0);
verifyEqual(testCase,result.config.fraction_to_boundary,0.9995,'AbsTol',0);
verifyEqual(testCase,testCase.TestData.runs_after, ...
    testCase.TestData.runs_before);
verifyEqual(testCase,testCase.TestData.current_stage_hash_after, ...
    testCase.TestData.current_stage_hash_before);
verifyEqual(testCase,testCase.TestData.solver_hash_after, ...
    testCase.TestData.solver_hash_before);
verifyEqual(testCase,testCase.TestData.stage_config_hash_after, ...
    testCase.TestData.stage_config_hash_before);
data = load_project_data(testCase.TestData.project_root);
index = build_stage_a4_index(data,"RunId","A4_2C_SCOPE_GUARD_TEST");
state = initialize_stage_a4_state(data,index,result.config);
verifyError(testCase,@()execute_stage_a4_iteration( ...
    state,data,index,result.config,"StepStrategy","common_min"), ...
    "stageA4:iteration:ExperimentalCommonStepScope");
state.diagnostic_chain_id = "A4-2C-A";
verifyError(testCase,@()execute_stage_a4_iteration( ...
    state,data,index,result.config,"StepStrategy","common_min"), ...
    "stageA4:iteration:ExperimentalCommonStepScope");
verifyError(testCase,@()run_stage_a4_five_iteration_diagnostic( ...
    data,index,result.config,"ComplementarityAudit",true, ...
    "ComplementarityContributionAnalysis",false), ...
    "stageA4:fiveIteration:ComplementarityContributionScope");
end

function verify_chain_summary_traceability(testCase,result)
chains = {result.chain_a,result.chain_b};
inventory = result.inequality_inventory;
for c = 1:2
    chain = chains{c};
    for k = 1:5
        item = chain.iterations(k);
        row = result.chain_summary( ...
            result.chain_summary.chain_id==chain.diagnostic_chain_id & ...
            result.chain_summary.iteration==k,:);
        verifyEqual(testCase,height(row),1);
        verifyEqual(testCase,row.strategy,chain.step_strategy);
        verifyEqual(testCase,row.candidate_alpha_primal, ...
            item.candidate_alpha_primal,'AbsTol',0);
        verifyEqual(testCase,row.candidate_alpha_dual, ...
            item.candidate_alpha_dual,'AbsTol',0);
        verifyEqual(testCase,row.applied_alpha_primal, ...
            item.applied_alpha_primal,'AbsTol',0);
        verifyEqual(testCase,row.applied_alpha_dual, ...
            item.applied_alpha_dual,'AbsTol',0);
        verify_limiter_traceability(testCase,row,"primal", ...
            item.primal_step,inventory);
        verify_limiter_traceability(testCase,row,"dual", ...
            item.dual_step,inventory);
        verify_residual_summary_fields(testCase,row,item);
        verifyEqual(testCase,row.direction_relative_error, ...
            item.direction_relative_error,'AbsTol',0);
        verifyEqual(testCase,row.xi_relative_error, ...
            item.component_relative_errors.xi,'AbsTol',0);
        verifyEqual(testCase,row.y_relative_error, ...
            item.component_relative_errors.y,'AbsTol',0);
        verifyEqual(testCase,row.l_relative_error, ...
            item.component_relative_errors.l,'AbsTol',0);
        verifyEqual(testCase,row.z_relative_error, ...
            item.component_relative_errors.z,'AbsTol',0);
        verifyEqual(testCase,row.recursive_kkt_relative_residual, ...
            item.recursive_kkt_relative_residual,'AbsTol',0);
        verifyEqual(testCase,row.full_kkt_relative_residual, ...
            item.full_kkt_relative_residual,'AbsTol',0);
        verifyEqual(testCase,row.objective_before, ...
            item.objective_value_before,'AbsTol',0);
        verifyEqual(testCase,row.objective_after, ...
            item.objective_value_after,'AbsTol',0);
    end
end
end

function verify_limiter_traceability(testCase,row,prefix,step,inventory)
verifyEqual(testCase,row.(prefix+"_limiter"), ...
    string(step.limiting_constraint_id));
names = ["global_row","day","hour","asset_id","value","direction"];
stepNames = ["limiting_constraint_global_row","limiting_day", ...
    "limiting_hour","limiting_asset_id","limiting_value", ...
    "limiting_direction"];
for k = 1:numel(names)
    actual = row.(prefix+"_limiter_"+names(k));
    expected = step.(stepNames(k));
    verifyTrue(testCase,isequaln(actual,expected));
end
verifyEqual(testCase,row.(prefix+"_limiter_asset_type"), ...
    string(step.limiting_asset_type));
if step.limiting_index>0
    source = inventory(inventory.inequality_index==step.limiting_index,:);
    verifyEqual(testCase,height(source),1);
    verifyEqual(testCase,string(source.constraint_id), ...
        string(step.limiting_constraint_id));
    verifyEqual(testCase,source.global_row, ...
        step.limiting_constraint_global_row);
    verifyTrue(testCase,isequaln(source.day,step.limiting_day));
    verifyTrue(testCase,isequaln(source.hour,step.limiting_hour));
    verifyEqual(testCase,string(source.asset_type), ...
        string(step.limiting_asset_type));
    verifyTrue(testCase,isequaln(source.asset_id,step.limiting_asset_id));
end
end

function verify_residual_summary_fields(testCase,row,item)
mapping = { ...
    'equality','equality_inf'; ...
    'slack_equality','slack_equality_inf'; ...
    'physical_violation','physical_inequality_violation'; ...
    'dual','dual_inf'; ...
    'complementarity_inf','complementarity_inf'; ...
    'gap','complementarity_gap'; ...
    'raw_complementarity','raw_complementarity'; ...
    'mu','mu'};
for stateName = ["before","after"]
    snapshot = item.("residuals_"+stateName);
    for k = 1:size(mapping,1)
        actual = row.(string(mapping{k,1})+"_"+stateName);
        expected = snapshot.(mapping{k,2});
        verifyEqual(testCase,actual,expected,'AbsTol',0);
    end
end
verifyEqual(testCase,row.minimum_l_after, ...
    item.residuals_after.minimum_l,'AbsTol',0);
verifyEqual(testCase,row.minimum_z_after, ...
    item.residuals_after.minimum_z,'AbsTol',0);
end

function verify_capacity_history_traceability(testCase,result)
chains = {result.chain_a,result.chain_b};
for c = 1:2
    chain = chains{c};
    capacityNames = string(chain.iterations(1).global_capacity_names);
    for k = 1:5
        item = chain.iterations(k);
        for stateName = ["before","after"]
            row = result.capacity_history( ...
                result.capacity_history.chain_id==chain.diagnostic_chain_id & ...
                result.capacity_history.iteration==k & ...
                result.capacity_history.state==stateName,:);
            verifyEqual(testCase,height(row),1);
            verifyEqual(testCase,row.strategy,chain.step_strategy);
            verifyEqual(testCase,row.investment_objective, ...
                item.("objective_value_"+stateName),'AbsTol',0);
            verifyEqual(testCase,table2array(row(:,cellstr(capacityNames))), ...
                reshape(item.("global_capacity_"+stateName),1,[]), ...
                'AbsTol',0);
        end
    end
end
end

function verify_comparison_traceability(testCase,result)
metrics = ["equality_inf","slack_equality_inf", ...
    "physical_inequality_violation","dual_inf","complementarity_inf", ...
    "complementarity_gap","raw_complementarity","mu", ...
    "minimum_l","minimum_z","investment_objective"];
for k = 1:5
    for metric = metrics
        row = result.residual_gap_comparison( ...
            result.residual_gap_comparison.iteration==k & ...
            result.residual_gap_comparison.metric==metric,:);
        verifyEqual(testCase,height(row),1);
        initial = comparison_metric(result.chain_a.iterations(1), ...
            metric,"before");
        valueA = comparison_metric(result.chain_a.iterations(k), ...
            metric,"after");
        valueB = comparison_metric(result.chain_b.iterations(k), ...
            metric,"after");
        [ratioA,definedA] = safe_ratio_local(valueA,initial);
        [ratioB,definedB] = safe_ratio_local(valueB,initial);
        [ratioBA,definedBA] = safe_ratio_local(valueB,valueA);
        verifyEqual(testCase,row.initial_value,initial,'AbsTol',0);
        verifyEqual(testCase,row.chain_a_value,valueA,'AbsTol',0);
        verifyEqual(testCase,row.chain_b_value,valueB,'AbsTol',0);
        verifyEqual(testCase,row.chain_a_delta_from_initial, ...
            valueA-initial,'AbsTol',0);
        verifyEqual(testCase,row.chain_b_delta_from_initial, ...
            valueB-initial,'AbsTol',0);
        verifyTrue(testCase,isequaln(row.chain_a_ratio_to_initial,ratioA));
        verifyTrue(testCase,isequaln(row.chain_b_ratio_to_initial,ratioB));
        verifyEqual(testCase,row.chain_a_ratio_defined,definedA);
        verifyEqual(testCase,row.chain_b_ratio_defined,definedB);
        verifyTrue(testCase,isequaln(row.chain_b_to_chain_a_ratio,ratioBA));
        verifyEqual(testCase,row.chain_b_to_chain_a_ratio_defined,definedBA);
        verifyEqual(testCase,row.chain_a_scaled_change, ...
            (valueA-initial)/max(1,abs(initial)),'AbsTol',0);
        verifyEqual(testCase,row.chain_b_scaled_change, ...
            (valueB-initial)/max(1,abs(initial)),'AbsTol',0);
        verifyEqual(testCase,row.between_chain_scaled_difference, ...
            (valueB-valueA)/max([1,abs(valueA),abs(valueB)]),'AbsTol',0);
    end
end
end

function value = comparison_metric(item,metric,stateName)
if metric=="investment_objective"
    value = item.("objective_value_"+stateName);
else
    value = item.("residuals_"+stateName).(metric);
end
end

function [ratio,defined] = safe_ratio_local(value,reference)
defined = reference~=0;
if defined
    ratio = value/reference;
else
    ratio = NaN;
end
end

function verify_centrality_traceability(testCase,result)
chains = {result.chain_a,result.chain_b};
for c = 1:2
    chain = chains{c};
    for k = 1:5
        item = chain.iterations(k);
        for stateName = ["before","after"]
            state = item.("canonical_state_"+stateName);
            product = state.l.*state.z;
            mu = item.("residuals_"+stateName).mu;
            for metric = ["l_times_z","l_times_z_over_mu"]
                if metric=="l_times_z"
                    values = product;
                else
                    values = product/mu;
                end
                row = result.centrality_statistics( ...
                    result.centrality_statistics.chain_id== ...
                    chain.diagnostic_chain_id & ...
                    result.centrality_statistics.iteration==k & ...
                    result.centrality_statistics.state==stateName & ...
                    result.centrality_statistics.metric==metric,:);
                verifyEqual(testCase,height(row),1);
                verify_distribution_row(testCase,row,values);
            end
        end
    end
end
end

function verify_distribution_row(testCase,row,values)
values = values(:);
minimumValue = min(values);
medianValue = median(values);
p95Value = percentile95(values);
maximumValue = max(values);
meanValue = mean(values);
standardDeviation = std(values,1);
verifyEqual(testCase,row.count,numel(values));
verifyEqual(testCase,row.minimum,minimumValue,'AbsTol',0);
verifyEqual(testCase,row.median,medianValue,'AbsTol',0);
verifyEqual(testCase,row.p95,p95Value,'AbsTol',0);
verifyEqual(testCase,row.maximum,maximumValue,'AbsTol',0);
verifyEqual(testCase,row.mean,meanValue,'AbsTol',0);
verifyEqual(testCase,row.range,maximumValue-minimumValue,'AbsTol',0);
verifyEqual(testCase,row.standard_deviation,standardDeviation,'AbsTol',0);
verifyTrue(testCase,isequaln(row.coefficient_of_variation, ...
    standardDeviation/abs(meanValue)));
verifyTrue(testCase,isequaln(row.maximum_to_minimum_ratio, ...
    maximumValue/minimumValue));
verifyTrue(testCase,isequaln(row.p95_to_median_ratio, ...
    p95Value/medianValue));
end

function verify_scale_row(testCase,row,values)
values = values(:);
absoluteValues = abs(values);
nonzero = absoluteValues(absoluteValues>0);
verifyEqual(testCase,row.count,numel(values));
verifyEqual(testCase,row.nonzero_count,numel(nonzero));
verifyEqual(testCase,row.negative_count,nnz(values<0));
verifyEqual(testCase,row.zero_count,nnz(values==0));
verifyEqual(testCase,row.positive_count,nnz(values>0));
verifyEqual(testCase,row.minimum_value,min(values),'AbsTol',0);
verifyEqual(testCase,row.maximum_value,max(values),'AbsTol',0);
verifyEqual(testCase,row.median_absolute,median(absoluteValues),'AbsTol',0);
verifyEqual(testCase,row.p95_absolute,percentile95(absoluteValues), ...
    'AbsTol',0);
verifyEqual(testCase,row.maximum_absolute,max(absoluteValues),'AbsTol',0);
if isempty(nonzero)
    verifyTrue(testCase,isnan(row.minimum_absolute_nonzero));
    verifyTrue(testCase,isnan(row.minimum_order_of_magnitude));
    verifyTrue(testCase,isnan(row.maximum_order_of_magnitude));
    verifyTrue(testCase,isnan(row.order_of_magnitude_span));
else
    minimumOrder = floor(log10(min(nonzero)));
    maximumOrder = floor(log10(max(nonzero)));
    verifyEqual(testCase,row.minimum_absolute_nonzero,min(nonzero), ...
        'AbsTol',0);
    verifyEqual(testCase,row.minimum_order_of_magnitude,minimumOrder, ...
        'AbsTol',0);
    verifyEqual(testCase,row.maximum_order_of_magnitude,maximumOrder, ...
        'AbsTol',0);
    verifyEqual(testCase,row.order_of_magnitude_span, ...
        maximumOrder-minimumOrder,'AbsTol',0);
end
end

function value = percentile95(values)
values = sort(values(:));
position = 1+0.95*(numel(values)-1);
lowerPosition = floor(position);
upperPosition = ceil(position);
if lowerPosition==upperPosition
    value = values(lowerPosition);
else
    weight = position-lowerPosition;
    value = (1-weight)*values(lowerPosition)+weight*values(upperPosition);
end
end

function inventory = recursive_run_inventory(projectRoot)
runRoot = fullfile(projectRoot,"runs");
entries = dir(fullfile(runRoot,"**","*"));
entries = entries(~ismember(string({entries.name}),[".",".."])) ;
relativePath = strings(numel(entries),1);
for entryIndex = 1:numel(entries)
    absolutePath = fullfile(entries(entryIndex).folder,entries(entryIndex).name);
    relativePath(entryIndex) = replace(extractAfter(string(absolutePath), ...
        strlength(runRoot)+1),'\','/');
end
isDirectory = [entries.isdir].';
bytes = [entries.bytes].';
modifiedDatenum = [entries.datenum].';
[relativePath,order] = sort(relativePath);
inventory = table(relativePath,isDirectory(order),bytes(order), ...
    modifiedDatenum(order),'VariableNames', ...
    {'relative_path','is_directory','bytes','modified_datenum'});
end
