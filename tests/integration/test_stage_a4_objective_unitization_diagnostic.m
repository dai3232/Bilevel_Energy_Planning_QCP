function tests = test_stage_a4_objective_unitization_diagnostic
%TEST_STAGE_A4_OBJECTIVE_UNITIZATION_DIAGNOSTIC Fixed A4-2D-2A evidence.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
projectRoot = string(fileparts(fileparts(fileparts(mfilename("fullpath")))));
addpath(projectRoot);
addpath(genpath(fullfile(projectRoot,"src")));
protected = protected_hashes(projectRoot);
runsBefore = recursive_run_inventory(projectRoot);
result = main_stage_A4_2D_2A();
testCase.TestData.project_root = projectRoot;
testCase.TestData.result = result;
testCase.TestData.protected_before = protected;
testCase.TestData.protected_after = protected_hashes(projectRoot);
testCase.TestData.runs_before = runsBefore;
testCase.TestData.runs_after = recursive_run_inventory(projectRoot);
end

function testUnscaledBaselineMatchesFrozenFixture(testCase)
result = testCase.TestData.result;
audit = result.baseline_fixture_audit;
verifyTrue(testCase,audit.row_count_exact);
verifyTrue(testCase,audit.column_names_and_order_exact);
verifyTrue(testCase,audit.string_fields_exact);
verifyTrue(testCase,audit.numeric_fields_zero_tolerance_exact);
verifyTrue(testCase,audit.all_pass);
verifyEqual(testCase,result.baseline_five.iteration_count,5);
verifyTrue(testCase,result.baseline_five.all_pass);
end

function testScaleDerivedFromActualCapacityGradient(testCase)
chain = testCase.TestData.result.scaled_five;
base = chain.initial_unscaled_linearization;
q = base.maps.q_global(:);
expected = max(abs(base.objective.gradient(q)));
verifyEqual(testCase,numel(q),14);
verifyEqual(testCase,numel(unique(q)),14);
verifyEqual(testCase,chain.objective_scale.factor,expected,'AbsTol',0);
verifyTrue(testCase,isfinite(expected) && expected>0);
verifyEqual(testCase,chain.objective_scale.scale_source, ...
    "max_abs_global_capacity_gradient");
outside = true(numel(base.objective.gradient),1);
outside(q) = false;
verifyTrue(testCase,all(base.objective.gradient(outside)==0));
end

function testScalingPreservesMatricesOffsetsAndInitialState(testCase)
result = testCase.TestData.result;
chain = result.scaled_five;
base = chain.initial_unscaled_linearization;
scaled = chain.initial_scaled_linearization;
verifyEqual(testCase,scaled.H,base.H,'AbsTol',0);
verifyEqual(testCase,scaled.A,base.A,'AbsTol',0);
verifyEqual(testCase,scaled.G,base.G,'AbsTol',0);
verifyEqual(testCase,scaled.eq_offset,base.eq_offset,'AbsTol',0);
verifyEqual(testCase,scaled.ineq_offset,base.ineq_offset,'AbsTol',0);
verifyEqual(testCase,scaled.state,base.state);
verifyEqual(testCase,scaled.maps,base.maps);
verifyEqual(testCase,scaled.capacity_parameters,base.capacity_parameters);
verifyEqual(testCase,nnz(scaled.H),0);
verifyTrue(testCase,result.initialization_audit.all_pass);
verifyEqual(testCase,result.scaled_twenty.initial_state, ...
    result.scaled_five.initial_state);
end

function testObjectiveAndGradientShareScaleMetadata(testCase)
result = testCase.TestData.result;
for chain = [result.scaled_five,result.scaled_twenty]
    base = chain.initial_unscaled_linearization;
    scaled = chain.initial_scaled_linearization;
    scale = chain.objective_scale.factor;
    verifyEqual(testCase,scaled.objective.gradient, ...
        base.objective.gradient/scale,'AbsTol',0);
    verifyEqual(testCase,scaled.objective.value, ...
        base.objective.value/scale,'AbsTol',0);
    verifyTrue(testCase,contains(scaled.identity, ...
        "objective_scale=positive_scalar_unitization"));
    verifyEqual(testCase,scaled.base_identity,base.identity);
    verifyTrue(testCase,all([chain.iterations.objective_scale_factor]==scale));
end
end

function testDualResidualAndOriginalMappingRebuild(testCase)
result = testCase.TestData.result;
for chain = [result.scaled_five,result.scaled_twenty]
    lin = chain.initial_scaled_linearization;
    scale = chain.objective_scale.factor;
    originalGradient = lin.objective.original_gradient;
    scaledGradient = lin.objective.gradient;
    for item = chain.iterations.'
        states = {item.state_before,item.state_after};
        metrics = {item.metrics_before,item.metrics_after};
        for position = 1:2
            state = states{position};
            metric = metrics{position};
            rebuiltScaled = scaledGradient+ ...
                lin.A.'*state.y+lin.G.'*state.z;
            mappedY = scale*state.y;
            mappedZ = scale*state.z;
            rebuiltMapped = originalGradient+ ...
                lin.A.'*mappedY+lin.G.'*mappedZ;
            verifyLessThanOrEqual(testCase, ...
                relative_inf_error(scale*rebuiltScaled,rebuiltMapped), ...
                2048*eps);
            verifyEqual(testCase,norm(rebuiltScaled,inf), ...
                metric.dual_scaled_inf,'RelTol',16*eps);
            verifyLessThanOrEqual(testCase, ...
                metric.mapping_r_dual_scaled_error,2048*eps);
            verifyLessThanOrEqual(testCase, ...
                metric.mapping_r_comp_scaled_error,2048*eps);
            verifyEqual(testCase,metric.mapped_raw_gap, ...
                scale*metric.raw_gap_scaled,'RelTol',16*eps);
        end
    end
end
end

function testDirectionsMatchSparseKktWithoutFallback(testCase)
result = testCase.TestData.result;
items = [result.scaled_five.iterations;result.scaled_twenty.iterations];
verifyLessThanOrEqual(testCase,max([items.direction_relative_error]),1e-10);
verifyLessThanOrEqual(testCase, ...
    max([items.recursive_kkt_relative_residual]),1e-10);
verifyLessThanOrEqual(testCase,max([items.full_kkt_relative_residual]),1e-10);
verifyTrue(testCase,all([items.no_full_direction_fallback]));
verifyFalse(testCase,any([items.full_direction_consumed]));
verifyTrue(testCase,all([items.same_scaled_linearization_identity]));
for item = items.'
    verifyLessThanOrEqual(testCase, ...
        max(cell2mat(struct2cell(item.component_relative_errors))),1e-10);
end
end

function testUpdatesUseRecursiveDirectionAndIndependentSteps(testCase)
result = testCase.TestData.result;
items = [result.scaled_five.iterations;result.scaled_twenty.iterations];
for item = items.'
    before = item.state_before;
    after = item.state_after;
    direction = item.recursive_direction;
    ap = item.applied_alpha_primal;
    ad = item.applied_alpha_dual;
    verifyLessThanOrEqual(testCase,relative_inf_error( ...
        after.xi,before.xi+ap*direction.xi),16*eps);
    verifyLessThanOrEqual(testCase,relative_inf_error( ...
        after.l,before.l+ap*direction.l),16*eps);
    verifyLessThanOrEqual(testCase,relative_inf_error( ...
        after.y,before.y+ad*direction.y),16*eps);
    verifyLessThanOrEqual(testCase,relative_inf_error( ...
        after.z,before.z+ad*direction.z),16*eps);
    verifyEqual(testCase,item.candidate_alpha_primal,ap,'AbsTol',0);
    verifyEqual(testCase,item.candidate_alpha_dual,ad,'AbsTol',0);
    verifyTrue(testCase,item.state_update_consumed_recursive_only);
end
verifyFalse(testCase,result.execution.common_step_used);
verifyFalse(testCase,result.execution.formal_step_rule_modified);
end

function testFiveAndTwentyRoundsStayPositiveAndFeasible(testCase)
% This is intentionally blocking: the current controlled run stops at
% round 19 and therefore cannot satisfy the requested twenty-round claim.
result = testCase.TestData.result;
for chain = [result.scaled_five,result.scaled_twenty]
    verifyTrue(testCase,all(arrayfun(@(x) ...
        x.metrics_before.all_finite && x.metrics_after.all_finite && ...
        x.metrics_after.minimum_l>0 && x.metrics_after.minimum_z>0 && ...
        x.metrics_after.physical_inequality_violation<= ...
            x.physical_violation_threshold,chain.iterations)));
end
verifyEqual(testCase,result.scaled_five.iteration_count,5);
verifyEqual(testCase,result.scaled_twenty.iteration_count,20, ...
    "The frozen recursive audit stopped the chain before 20 rounds.");
verifyFalse(testCase,result.scaled_twenty.failure.present);
end

function testFiveRoundGatePrecedesTwentyRoundAttempt(testCase)
result = testCase.TestData.result;
verifyTrue(testCase,result.five_round_gate.passed);
verifyTrue(testCase, ...
    result.five_round_gate.permission_to_start_twenty_round_chain);
verifyEqual(testCase,result.execution_sequence, ...
    ["baseline5_completed";"scaled5_completed"; ...
    "five_round_gate_evaluated";"five_round_gate_passed"; ...
    "scaled20_started";"scaled20_failed"]);
verifyTrue(testCase,result.first_five_reproduction_audit.all_pass);
tampered = result.scaled_five;
tampered.iterations(1).no_full_direction_fallback = false;
gate = rkkt.diagnostics.evaluate_stage_a4_scaled_five_round_gate(tampered);
verifyFalse(testCase,gate.passed);
verifyFalse(testCase,gate.permission_to_start_twenty_round_chain);
end

function testBudgetsAndResidualProductLawsClose(testCase)
result = testCase.TestData.result;
for chain = [result.scaled_five,result.scaled_twenty]
    lin = chain.initial_scaled_linearization;
    initialEq = lin.A*lin.state.xi+lin.eq_offset;
    initialDual = lin.objective.gradient+ ...
        lin.A.'*lin.state.y+lin.G.'*lin.state.z;
    alphaP = reshape([chain.iterations.applied_alpha_primal],[],1);
    alphaD = reshape([chain.iterations.applied_alpha_dual],[],1);
    for k = 1:chain.iteration_count
        item = chain.iterations(k);
        expectedBp = -sum(log1p(-alphaP(1:k)));
        expectedBd = -sum(log1p(-alphaD(1:k)));
        productP = prod(1-alphaP(1:k));
        productD = prod(1-alphaD(1:k));
        state = item.state_after;
        actualEq = lin.A*state.xi+lin.eq_offset;
        actualDual = lin.objective.gradient+ ...
            lin.A.'*state.y+lin.G.'*state.z;
        verify_budget(testCase,item.cumulative_primal_step_budget, ...
            expectedBp);
        verify_budget(testCase,item.cumulative_dual_step_budget, ...
            expectedBd);
        verifyLessThanOrEqual(testCase,norm( ...
            actualEq-productP*initialEq,inf)/max(1,norm(initialEq,inf)), ...
            2048*eps);
        verifyLessThanOrEqual(testCase,norm( ...
            actualDual-productD*initialDual,inf)/ ...
            max(1,norm(initialDual,inf)),2048*eps);
        verifyLessThanOrEqual(testCase, ...
            abs(productP-exp(-expectedBp)),2048*eps);
        verifyLessThanOrEqual(testCase, ...
            abs(productD-exp(-expectedBd)),2048*eps);
    end
end
end

function testScaledDimensionlessMappedMetricsTraceable(testCase)
result = testCase.TestData.result;
required = ["objective_original","objective_scaled","equality_inf", ...
    "slack_equality_inf","physical_inequality_violation", ...
    "dual_scaled_inf","mean_gap_scaled","raw_gap_scaled","mu_scaled", ...
    "eta_dual_scaled","eta_gap_scaled","y_original_mapped", ...
    "z_original_mapped","mapped_y_inf","mapped_z_inf", ...
    "r_dual_original_mapped","mapped_r_dual_inf", ...
    "mapped_mean_gap","mapped_raw_gap","mapped_mu", ...
    "gap_original_mapped","r_comp_original_mapped", ...
    "eta_dual_mapped","eta_gap_mapped","minimum_l","minimum_z"];
scale = result.objective_scale.factor;
base = result.scaled_five.initial_scaled_linearization;
for chain = [result.scaled_five,result.scaled_twenty]
    for item = chain.iterations.'
        verifyTrue(testCase,all(isfield( ...
            item.metrics_after,cellstr(required))));
        metric = item.metrics_after;
        verifyEqual(testCase,metric.mu_scaled, ...
            0.1*metric.mean_gap_scaled,'RelTol',16*eps);
        verifyEqual(testCase,numel(item.global_capacity_after),14);
        verifyTrue(testCase,all(isfinite(item.global_capacity_after)));
        verifyTrue(testCase,isfinite(item.delta_qp5));
        state = item.state_after;
        expectedY = scale*state.y;
        expectedZ = scale*state.z;
        expectedRdual = base.objective.original_gradient+ ...
            base.A.'*expectedY+base.G.'*expectedZ;
        expectedRcomp = state.l.*expectedZ-scale*metric.mu_scaled;
        verifyEqual(testCase,metric.y_original_mapped,expectedY);
        verifyEqual(testCase,metric.z_original_mapped,expectedZ);
        verifyLessThanOrEqual(testCase,relative_inf_error( ...
            metric.r_dual_original_mapped,expectedRdual),2048*eps);
        verifyLessThanOrEqual(testCase,relative_inf_error( ...
            metric.r_comp_original_mapped,expectedRcomp),2048*eps);
        verifyEqual(testCase,metric.gap_original_mapped, ...
            scale*metric.raw_gap_scaled);
        expectedEtaDual = norm(expectedRdual,inf)/max(1, ...
            norm(base.objective.original_gradient,inf)+ ...
            norm(base.A.'*expectedY,inf)+norm(base.G.'*expectedZ,inf));
        expectedEtaGap = metric.gap_original_mapped/max(1, ...
            abs(metric.objective_original));
        verifyLessThanOrEqual(testCase,abs( ...
            metric.eta_dual_mapped-expectedEtaDual),2048*eps);
        verifyLessThanOrEqual(testCase,abs( ...
            metric.eta_gap_mapped-expectedEtaGap),2048*eps);
    end
end
end

function testConclusionUsesObservedFailureWithoutPassClaim(testCase)
result = testCase.TestData.result;
verifyEqual(testCase,result.milestone_status,"FAIL_RETRYABLE");
verifyFalse(testCase,result.all_pass);
verifyFalse(testCase,result.conclusion.experiment_correct);
verifyFalse(testCase, ...
    result.convergence_diagnostics.twenty_round_chain_completed);
verifyEqual(testCase,result.conclusion.next_single_factor, ...
    "resolve_recursive_round_failure_before_next_factor");
verifyFalse(testCase,result.conclusion.formal_ipm_convergence_claimed);
verifyFalse(testCase,result.conclusion.stage_a4_pass_claimed);
verifyFalse(testCase,result.conclusion.formal_objective_unitization_adopted);
verifyFalse(testCase,result.formal_acceptance_metric_changed);
verifyFalse(testCase,result.formal_algorithm_replaced);
verifyTrue(testCase,result.scaled_twenty.failure.present);
verifyEqual(testCase,result.scaled_twenty.failure.attempted_iteration,19);
end

function testGovernanceAndProtectedArtifactsUnchanged(testCase)
result = testCase.TestData.result;
verifyEqual(testCase,testCase.TestData.protected_after, ...
    testCase.TestData.protected_before);
verifyEqual(testCase,testCase.TestData.runs_after, ...
    testCase.TestData.runs_before);
verifyEqual(testCase,result.stage_id,"stage_A4");
verifyEqual(testCase,result.stage_status,"READY");
verifyFalse(testCase,result.execution.full_ipm_executed);
verifyFalse(testCase,result.execution.optimization_executed);
verifyFalse(testCase,result.execution.parallel_executed);
verifyFalse(testCase,result.execution.formal_a4_run_created);
verifyFalse(testCase,result.execution.stage_b_entered);
verifyFalse(testCase,result.execution.hundred_round_run_executed);
verifyEqual(testCase,result.evidence_tail_issue.status,"OPEN_NONBLOCKING");
verifyFalse(testCase,result.evidence_tail_issue.resolved);
config = rkkt.model.load_stage_a4_configuration(testCase.TestData.project_root);
scan = rkkt.diagnostics.scan_stage_a4_forbidden_code( ...
    testCase.TestData.project_root,config);
verifyEqual(testCase,height(scan),26);
verifyTrue(testCase,all(scan.status=="PASS"), ...
    evalc('disp(scan(scan.status~="PASS",:))'));
end

function hashes = protected_hashes(projectRoot)
relative = [ ...
    "CURRENT_STAGE.md"
    "config/solver.yaml"
    "config/stage_A4.yaml"
    "src/+rkkt/+model/initialize_stage_a4_state.m"
    "src/+rkkt/+model/initialize_stage_a_multiday_state.m"
    "src/+rkkt/+model/build_stage_a4_linearization.m"
    "src/+rkkt/+model/build_stage_a_multiday_linearization.m"
    "inputs/raw/基础参数.xlsx"
    "inputs/raw/输入数据.xlsx"
    "stages/stage_A4/阶段A4_验收矩阵.csv"];
sha256 = strings(numel(relative),1);
for k = 1:numel(relative)
    sha256(k) = lower(string(rkkt.data.compute_sha256_file( ...
        fullfile(projectRoot,strrep(relative(k),"/",filesep)))));
end
hashes = table(relative,sha256, ...
    'VariableNames',{'relative_path','sha256'});
end

function inventory = recursive_run_inventory(projectRoot)
runRoot = fullfile(projectRoot,"runs");
entries = dir(fullfile(runRoot,"**","*"));
entries = entries(~ismember(string({entries.name}),[".",".."]));
relativePath = strings(numel(entries),1);
for k = 1:numel(entries)
    absolutePath = fullfile(entries(k).folder,entries(k).name);
    relativePath(k) = replace(extractAfter(string(absolutePath), ...
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

function value = relative_inf_error(actual,expected)
value = norm(actual-expected,inf)/ ...
    max([1,norm(actual,inf),norm(expected,inf)]);
end

function value = relative_scalar_error(actual,expected)
value = abs(actual-expected)/max([1,abs(actual),abs(expected)]);
end

function verify_budget(testCase,actual,expected)
if isinf(expected)
    verifyEqual(testCase,actual,expected);
else
    verifyLessThanOrEqual(testCase, ...
        relative_scalar_error(actual,expected),16*eps);
end
end
