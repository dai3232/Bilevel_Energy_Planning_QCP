function tests = test_stage_a4_five_iteration_diagnostic
%TEST_STAGE_A4_FIVE_ITERATION_DIAGNOSTIC Verify the non-formal A4-2A loop.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
projectRoot = string(fileparts(fileparts(fileparts(mfilename("fullpath")))));
addpath(projectRoot);
addpath(genpath(fullfile(projectRoot,"src")));
beforeRuns = recursive_run_inventory(projectRoot);
currentStagePath = fullfile(projectRoot,"CURRENT_STAGE.md");
solverPath = fullfile(projectRoot,"config","solver.yaml");
currentStageHashBefore = string(rkkt.data.compute_sha256_file(currentStagePath));
solverHashBefore = string(rkkt.data.compute_sha256_file(solverPath));
result = main_stage_A4_2A();
testCase.TestData.project_root = projectRoot;
testCase.TestData.result = result;
testCase.TestData.before_runs = beforeRuns;
testCase.TestData.after_runs = recursive_run_inventory(projectRoot);
testCase.TestData.current_stage_hash_before = currentStageHashBefore;
testCase.TestData.current_stage_hash_after = ...
    string(rkkt.data.compute_sha256_file(currentStagePath));
testCase.TestData.solver_hash_before = solverHashBefore;
testCase.TestData.solver_hash_after = string(rkkt.data.compute_sha256_file(solverPath));
end

function testExactlyFiveExplicitStateRevisions(testCase)
result = testCase.TestData.result;
verifyEqual(testCase,result.config.a4_2a_iteration_count,5);
verifyEqual(testCase,result.iteration_count,5);
verifyEqual(testCase,[result.iterations.iteration],1:5);
verifyEqual(testCase,[result.iterations.state_revision_before],0:4);
verifyEqual(testCase,[result.iterations.state_revision_after],1:5);
verifyTrue(testCase,all([result.iterations.explicit_slack_consumed_before]));
verifyTrue(testCase,all([result.iterations.explicit_slack_consumed_after]));
verifyTrue(testCase,all([result.iterations.input_state_exact]));
verifyTrue(testCase,all([result.iterations.previous_state_chain_exact]));
verifyEqual(testCase,result.final_state_revision,5);
verifyEqual(testCase,result.final_state.iteration_index,5);
verifyEqual(testCase,result.final_state.state_revision,5);
verifyEqual(testCase,result.final_state.newton_direction_number,5);
verifyEqual(testCase,result.final_state.completed_newton_direction_count,5);
verifyEqual(testCase,result.completed_newton_direction_count,5);
verifyTrue(testCase,all(isfinite([result.final_state.xi; ...
    result.final_state.y;result.final_state.l;result.final_state.z])));
verifyGreaterThan(testCase,min(result.final_state.l),0);
verifyGreaterThan(testCase,min(result.final_state.z),0);
for iteration = 2:5
    verifyEqual(testCase, ...
        result.iterations(iteration).linearization_identity_before, ...
        result.iterations(iteration-1).linearization_identity_after);
end
verifyEqual(testCase,numel(unique( ...
    result.linearization_before_identities)),5);
end

function testEveryRecursiveDirectionHasIndependentCompleteAudit(testCase)
result = testCase.TestData.result;
for iteration = 1:5
    item = result.iterations(iteration);
    verifyLessThanOrEqual(testCase,item.direction_relative_error,1e-10);
    verifyLessThanOrEqual(testCase, ...
        item.recursive_kkt_relative_residual,1e-10);
    verifyLessThanOrEqual(testCase,item.full_kkt_relative_residual,1e-10);
    for name = ["xi","y","l","z"]
        verifyLessThanOrEqual(testCase, ...
            item.component_relative_errors.(name),1e-10);
    end
    verifyTrue(testCase,item.no_full_direction_fallback);
    verifyTrue(testCase,item.checks.recursive_no_full_direction_fallback);
    verifyTrue(testCase,item.checks.direction_equivalence);
    verifyTrue(testCase,isfinite( ...
        item.maximum_direction_difference.absolute_value));
    verifyTrue(testCase,isfinite( ...
        item.maximum_recursive_residual.absolute_value));
    verifyTrue(testCase,isfinite( ...
        item.maximum_full_residual.absolute_value));
end
verifyTrue(testCase,result.execution.recursive_direction_is_official);
verifyFalse(testCase, ...
    result.execution.full_kkt_direction_consumed_by_recursive);
end

function testIndependentFractionStepsAndLimitersAreRecorded(testCase)
result = testCase.TestData.result;
for iteration = 1:5
    item = result.iterations(iteration);
    for step = [item.primal_step,item.dual_step]
        verifyGreaterThan(testCase,step.alpha,0);
        verifyLessThanOrEqual(testCase,step.alpha,1);
        verifyEqual(testCase,step.tau,0.9995,"AbsTol",0);
        if step.negative_direction_count==0
            verifyEqual(testCase,step.alpha,step.tau,"AbsTol",0);
            verifyEqual(testCase,step.limiting_index,0);
            verifyEmpty(testCase,step.limiting_constraint_id);
            verifyTrue(testCase,isinf(step.raw_boundary_step));
            verifyTrue(testCase,isnan(step.limiting_value));
            verifyTrue(testCase,isnan(step.limiting_direction));
        else
            verifyGreaterThan(testCase,step.limiting_index,0);
            verifyNotEmpty(testCase,step.limiting_constraint_id);
            verifyTrue(testCase,isfinite(step.raw_boundary_step));
            verifyTrue(testCase,isfinite(step.limiting_value));
            verifyLessThan(testCase,step.limiting_direction,0);
        end
        verifyGreaterThan(testCase,step.minimum_trial_value,0);
    end
    verifyEqual(testCase,item.alpha_primal,item.primal_step.alpha,"AbsTol",0);
    verifyEqual(testCase,item.alpha_dual,item.dual_step.alpha,"AbsTol",0);
    verifyTrue(testCase,item.checks.positive_fraction_to_boundary);
end
verifyEqual(testCase, ...
    result.iterations(1).primal_step.limiting_constraint_id, ...
    "INEQ-Q-LOWER-QP5");
verifyEqual(testCase, ...
    result.iterations(1).dual_step.limiting_constraint_id, ...
    "INEQ-Q-UPPER-QP5");
end

function testAllResidualsAndComplementarityAreRecorded(testCase)
result = testCase.TestData.result;
required = ["equality_inf","slack_equality_inf", ...
    "slack_equality_scaled","physical_inequality_violation", ...
    "physical_inequality_scale","dual_inf","complementarity_inf", ...
    "complementarity_gap","raw_complementarity","mu", ...
    "minimum_l","minimum_z"];
for iteration = 1:5
    item = result.iterations(iteration);
    for snapshot = [item.residuals_before,item.residuals_after]
        verifyTrue(testCase,all(isfield(snapshot,required)));
        values = cellfun(@double,struct2cell(snapshot));
        verifyTrue(testCase,all(isfinite(values)));
        verifyGreaterThan(testCase,snapshot.complementarity_gap,0);
        verifyGreaterThan(testCase,snapshot.raw_complementarity,0);
        verifyGreaterThan(testCase,snapshot.mu,0);
        verifyGreaterThan(testCase,snapshot.minimum_l,0);
        verifyGreaterThan(testCase,snapshot.minimum_z,0);
        verifyGreaterThanOrEqual(testCase, ...
            snapshot.physical_inequality_violation,0);
        verifyGreaterThanOrEqual(testCase,snapshot.complementarity_inf,0);
    end
    closureValues = cellfun(@double,struct2cell(item.closure));
    verifyTrue(testCase,all(isfinite(closureValues)));
    verifyTrue(testCase,item.checks.linear_update_closure);
end
end

function testQP5CapacityAndBothBoundsAreRecorded(testCase)
result = testCase.TestData.result;
for iteration = 1:5
    item = result.iterations(iteration);
    qp5 = item.qp5;
    verifyEqual(testCase,qp5.capacity_name,"QP5");
    verifyEqual(testCase,qp5.lower.constraint_id,"INEQ-Q-LOWER-QP5");
    verifyEqual(testCase,qp5.upper.constraint_id,"INEQ-Q-UPPER-QP5");
    verifyEqual(testCase,qp5.capacity_value_after, ...
        qp5.capacity_value_before+item.alpha_primal* ...
        qp5.capacity_direction,"AbsTol",0);
    verifyEqual(testCase,qp5.lower.slack_after, ...
        qp5.lower.slack_before+item.alpha_primal* ...
        qp5.lower.slack_direction,"AbsTol",0);
    verifyEqual(testCase,qp5.upper.slack_after, ...
        qp5.upper.slack_before+item.alpha_primal* ...
        qp5.upper.slack_direction,"AbsTol",0);
    verifyEqual(testCase,qp5.lower.multiplier_after, ...
        qp5.lower.multiplier_before+item.alpha_dual* ...
        qp5.lower.multiplier_direction,"AbsTol",0);
    verifyEqual(testCase,qp5.upper.multiplier_after, ...
        qp5.upper.multiplier_before+item.alpha_dual* ...
        qp5.upper.multiplier_direction,"AbsTol",0);
    verifyEqual(testCase,qp5.lower.physical_function_direction, ...
        -qp5.capacity_direction,"AbsTol",0);
    verifyEqual(testCase,qp5.upper.physical_function_direction, ...
        qp5.capacity_direction,"AbsTol",0);
    verifyTrue(testCase,qp5.passed);
    verifyTrue(testCase,item.checks.qp5_semantic_audit);
end
end

function testUpdatedDailySocBoundaryAuditPassesEveryRound(testCase)
result = testCase.TestData.result;
for iteration = 1:5
    soc = result.iterations(iteration).soc;
    verifyEqual(testCase,soc.day_ids,14:20);
    verifyEqual(testCase,soc.initial_half_energy_link_count,14);
    verifyEqual(testCase,soc.terminal_half_energy_link_count,14);
    verifyEqual(testCase,soc.cross_day_or_nonadjacent_link_count,0);
    verifyEqual(testCase,soc.initial_boundary_coefficient_failure_count,0);
    verifyEqual(testCase,soc.terminal_boundary_coefficient_failure_count,0);
    verifyLessThanOrEqual(testCase, ...
        soc.initial_linear_update_relative_error,256*eps);
    verifyLessThanOrEqual(testCase, ...
        soc.terminal_linear_update_relative_error,256*eps);
    verifyLessThanOrEqual(testCase, ...
        soc.terminal_maximum_locally_scaled_residual_after,512*eps);
    verifyTrue(testCase,soc.passed);
end
end

function testFixedZerosAndRecursivePermutationRemainExact(testCase)
result = testCase.TestData.result;
for iteration = 1:5
    item = result.iterations(iteration);
    verifyEqual(testCase,item.fixed_zero.count,422);
    verifyTrue(testCase,item.fixed_zero.values_exact_zero_before);
    verifyTrue(testCase,item.fixed_zero.values_exact_zero_after);
    verifyTrue(testCase,item.fixed_zero.directions_exact_zero);
    verifyEqual(testCase,item.fixed_zero.maximum_absolute_value_after,0);
    verifyEqual(testCase,item.fixed_zero.maximum_absolute_direction,0);
    verifyEqual(testCase,item.permutation.dimension,4340);
    verifyTrue(testCase,item.permutation.is_bijection);
    verifyTrue(testCase,item.permutation.is_nonidentity);
    verifyTrue(testCase,item.permutation.forward_inverse_composition_exact);
    verifyTrue(testCase,item.permutation.inverse_forward_composition_exact);
end
end

function testEveryPhaseTimingIsFiniteAndNonnegative(testCase)
result = testCase.TestData.result;
required = ["linearization_before_seconds","recursive_seconds", ...
    "recursive_direction_and_reinsertion_seconds", ...
    "full_kkt_audit_seconds","direction_equivalence_audit_seconds", ...
    "fraction_to_boundary_seconds","state_update_seconds", ...
    "linearization_after_seconds", ...
    "closure_and_structure_audit_seconds","total_seconds"];
for iteration = 1:5
    timing = result.iterations(iteration).timing;
    verifyTrue(testCase,all(isfield(timing,required)));
    values = cellfun(@double,struct2cell(timing));
    verifyTrue(testCase,all(isfinite(values)));
    verifyGreaterThanOrEqual(testCase,min(values),0);
    verifyGreaterThan(testCase,timing.total_seconds,0);
end
verifyTrue(testCase,isfinite(result.timing.initialization_seconds));
verifyTrue(testCase,isfinite(result.timing.total_seconds));
verifyGreaterThan(testCase,result.timing.total_seconds,0);
end

function testRecoverySummaryMatchesFiveObservedSteps(testCase)
result = testCase.TestData.result;
alphaPrimal = reshape([result.iterations.alpha_primal],[],1);
alphaDual = reshape([result.iterations.alpha_dual],[],1);
verifyEqual(testCase,result.step_recovery.alpha_primal,alphaPrimal,"AbsTol",0);
verifyEqual(testCase,result.step_recovery.alpha_dual,alphaDual,"AbsTol",0);
verifyEqual(testCase,result.step_recovery.primal_later_maximum, ...
    max(alphaPrimal(2:5)),"AbsTol",0);
verifyEqual(testCase,result.step_recovery.dual_later_maximum, ...
    max(alphaDual(2:5)),"AbsTol",0);
verifyEqual(testCase,result.step_recovery.primal_recovered_after_first, ...
    max(alphaPrimal(2:5))>alphaPrimal(1));
verifyEqual(testCase,result.step_recovery.dual_recovered_after_first, ...
    max(alphaDual(2:5))>alphaDual(1));
end

function testDiagnosticCreatesNoRunAndDoesNotAdvanceStage(testCase)
result = testCase.TestData.result;
verifyEqual(testCase,result.stage_id,"stage_A4");
verifyEqual(testCase,result.stage_status,"READY");
verifyEqual(testCase,result.milestone_status,"PASS");
verifyEqual(testCase,result.execution.newton_direction_count,5);
verifyEqual(testCase,result.execution.state_update_count,5);
verifyEqual(testCase,result.execution.full_kkt_audit_count,5);
verifyFalse(testCase,result.execution.full_ipm_executed);
verifyFalse(testCase,result.execution.optimization_executed);
verifyFalse(testCase,result.execution.parallel_executed);
verifyFalse(testCase,result.execution.formal_a4_run_created);
verifyFalse(testCase,result.execution.stage_b_entered);
verifyEqual(testCase,testCase.TestData.after_runs, ...
    testCase.TestData.before_runs);
verifyEqual(testCase,testCase.TestData.current_stage_hash_after, ...
    testCase.TestData.current_stage_hash_before);
verifyEqual(testCase,testCase.TestData.solver_hash_after, ...
    testCase.TestData.solver_hash_before);
end

function testA4ProductionClosurePassesForbiddenCallScan(testCase)
audit = rkkt.diagnostics.scan_stage_a4_forbidden_code( ...
    testCase.TestData.project_root,testCase.TestData.result.config);
verifyEqual(testCase,string(audit.status), ...
    repmat("PASS",height(audit),1), ...
    evalc('disp(audit(audit.status~="PASS",:))'));
verifyEqual(testCase,audit.match_count,zeros(height(audit),1));
verifyGreaterThan(testCase,min(audit.files_scanned),0);
end

function inventory = recursive_run_inventory(projectRoot)
runRoot = fullfile(projectRoot,"runs");
entries = dir(fullfile(runRoot,"**","*"));
entries = entries(~ismember(string({entries.name}),[".",".."])) ;
relativePath = strings(numel(entries),1);
for entryIndex = 1:numel(entries)
    absolutePath = fullfile(entries(entryIndex).folder,entries(entryIndex).name);
    relativePath(entryIndex) = replace( ...
        extractAfter(string(absolutePath),strlength(runRoot)+1),'\','/');
end
isDirectory = [entries.isdir].';
bytes = [entries.bytes].';
modifiedDatenum = [entries.datenum].';
[relativePath,order] = sort(relativePath);
inventory = table(relativePath,isDirectory(order),bytes(order), ...
    modifiedDatenum(order),'VariableNames', ...
    {'relative_path','is_directory','bytes','modified_datenum'});
end
