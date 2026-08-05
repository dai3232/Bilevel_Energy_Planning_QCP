function result = run_stage_a4_complementarity_gap_diagnostic(data,index,config)
%RUN_STAGE_A4_COMPLEMENTARITY_GAP_DIAGNOSTIC Audit the fixed five-round chain.
%
% A4-2B reuses the exact A4-2A state transition driver.  The additional
% complementarity work is read-only: it observes each already-computed
% Newton direction and never supplies a state to the next official round.

arguments
    data (1,1) struct
    index (1,1) struct
    config (1,1) struct
end

assert(string(config.stage_id)=="stage_A4" && ...
    string(config.status)=="READY" && ...
    isfield(config,"a4_2b_iteration_count") && ...
    config.a4_2b_iteration_count==5 && ...
    string(config.a4_2b_run_purpose)== ...
        "five_iteration_complementarity_gap_cause_audit", ...
    "stageA4:complementarityAudit:Scope", ...
    "A4-2B requires the fixed five-round stage_A4 / READY scope.");

result = rkkt.diagnostics.run_stage_a4_five_iteration_diagnostic( ...
    data,index,config,"ComplementarityAudit",true);
assert(result.iteration_count==5 && ...
    numel(result.complementarity_audits)==5 && ...
    all([result.complementarity_audits.all_pass]) && ...
    all([result.complementarity_audits.official_state_unchanged]), ...
    "stageA4:complementarityAudit:FiveRoundAudit", ...
    "A4-2B did not complete five read-only complementarity audits.");

result.milestone = "A4-2B_complementarity_gap_cause_audit";
result.milestone_status = "PASS";
result.run_purpose = string(config.a4_2b_run_purpose);
result.baseline_table = make_baseline_table(result.iterations);
result.inequality_inventory = make_inequality_inventory(index);
gapBefore = result.baseline_table.gap_before;
gapAfter = result.baseline_table.gap_after;
result.gap_increase_rounds = result.baseline_table.iteration( ...
    gapAfter>gapBefore).';
result.execution.complementarity_audit_count = 5;
result.execution.counterfactual_evaluation_count = 5;
result.execution.counterfactual_state_update_count = 0;
result.execution.counterfactual_consumed_by_official_state = false;
result.execution.a4_2b_parameter_change_count = 0;
result.execution.a4_2b_additional_dense_condition_number_executed = false;
result.execution.predictor_corrector_executed = false;
end

function baseline = make_baseline_table(iterations)
count = numel(iterations);
iteration = reshape([iterations.iteration],[],1);
alphaPrimal = reshape([iterations.alpha_primal],[],1);
alphaDual = reshape([iterations.alpha_dual],[],1);
primalLimiter = strings(count,1);
dualLimiter = strings(count,1);
equalityBefore = zeros(count,1);
equalityAfter = zeros(count,1);
slackEqualityBefore = zeros(count,1);
slackEqualityAfter = zeros(count,1);
dualBefore = zeros(count,1);
dualAfter = zeros(count,1);
complementarityInfBefore = zeros(count,1);
complementarityInfAfter = zeros(count,1);
gapBefore = zeros(count,1);
gapAfter = zeros(count,1);
minimumLAfter = zeros(count,1);
minimumZAfter = zeros(count,1);
directionRelativeError = zeros(count,1);
xiRelativeError = zeros(count,1);
yRelativeError = zeros(count,1);
lRelativeError = zeros(count,1);
zRelativeError = zeros(count,1);
recursiveKktRelativeResidual = zeros(count,1);
fullKktRelativeResidual = zeros(count,1);
for k = 1:count
    item = iterations(k);
    primalLimiter(k) = item.primal_step.limiting_constraint_id;
    dualLimiter(k) = item.dual_step.limiting_constraint_id;
    equalityBefore(k) = item.residuals_before.equality_inf;
    equalityAfter(k) = item.residuals_after.equality_inf;
    slackEqualityBefore(k) = item.residuals_before.slack_equality_inf;
    slackEqualityAfter(k) = item.residuals_after.slack_equality_inf;
    dualBefore(k) = item.residuals_before.dual_inf;
    dualAfter(k) = item.residuals_after.dual_inf;
    complementarityInfBefore(k) = ...
        item.residuals_before.complementarity_inf;
    complementarityInfAfter(k) = ...
        item.residuals_after.complementarity_inf;
    gapBefore(k) = item.residuals_before.complementarity_gap;
    gapAfter(k) = item.residuals_after.complementarity_gap;
    minimumLAfter(k) = item.residuals_after.minimum_l;
    minimumZAfter(k) = item.residuals_after.minimum_z;
    directionRelativeError(k) = item.direction_relative_error;
    xiRelativeError(k) = item.component_relative_errors.xi;
    yRelativeError(k) = item.component_relative_errors.y;
    lRelativeError(k) = item.component_relative_errors.l;
    zRelativeError(k) = item.component_relative_errors.z;
    recursiveKktRelativeResidual(k) = ...
        item.recursive_kkt_relative_residual;
    fullKktRelativeResidual(k) = item.full_kkt_relative_residual;
end
baseline = table(iteration,alphaPrimal,alphaDual,primalLimiter, ...
    dualLimiter,equalityBefore,equalityAfter,slackEqualityBefore, ...
    slackEqualityAfter,dualBefore,dualAfter, ...
    complementarityInfBefore,complementarityInfAfter,gapBefore,gapAfter, ...
    minimumLAfter,minimumZAfter,directionRelativeError,xiRelativeError, ...
    yRelativeError,lRelativeError,zRelativeError, ...
    recursiveKktRelativeResidual,fullKktRelativeResidual, ...
    'VariableNames',{'iteration','alpha_primal','alpha_dual', ...
    'primal_limiter','dual_limiter','equality_before','equality_after', ...
    'slack_equality_before','slack_equality_after','dual_before', ...
    'dual_after','complementarity_inf_before', ...
    'complementarity_inf_after','gap_before','gap_after', ...
    'minimum_l_after','minimum_z_after','direction_relative_error', ...
    'xi_relative_error','y_relative_error','l_relative_error', ...
    'z_relative_error','recursive_kkt_relative_residual', ...
    'full_kkt_relative_residual'});
end

function inventory = make_inequality_inventory(index)
constraints = index.constraint_index;
inventory = constraints(string(constraints.constraint_type)=="inequality", ...
    {'global_row','constraint_id','constraint_name','day','hour', ...
    'asset_type','asset_id','local_row','unit'});
inventory = addvars(inventory,(1:height(inventory)).', ...
    'Before','global_row','NewVariableNames','inequality_index');
end
