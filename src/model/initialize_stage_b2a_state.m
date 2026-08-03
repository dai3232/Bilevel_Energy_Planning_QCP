function state = initialize_stage_b2a_state(data,index,config)
%INITIALIZE_STAGE_B2A_STATE Build one deterministic structure-audit state.
%
% This is not an IPM initialization or update.  It reuses the frozen
% Stage-A point and appends positive diagnostic slack/multiplier entries for
% the 56 water rows so the complete KKT can be assembled without solving.

baseIndex = index.stage_a_base_index;
baseConfig = config.stage_a_compatibility;
baseState = initialize_stage_a_multiday_state(data,baseIndex,baseConfig);
baseState.iteration_index = 0;
baseState.state_revision = 0;
baseState.newton_direction_number = 0;
baseState.completed_newton_direction_count = 0;
baseLinearization = build_stage_a_multiday_linearization( ...
    baseState,data,baseIndex,baseConfig,"SlackMode","initialize");
water = assemble_stage_b_water_linearization( ...
    baseLinearization.state.xi,data,index,config);

waterSlack = max(ones(height(index.water_constraint_index),1), ...
    -water.constraint_value);
waterMultiplier = zeros(height(index.water_constraint_index),1);
upper = index.water_constraint_index.bound_type=="upper";
lower = index.water_constraint_index.bound_type=="lower";
waterMultiplier(upper) = config.diagnostic_water_upper_multiplier;
waterMultiplier(lower) = config.diagnostic_water_lower_multiplier;
assert(all(waterSlack>0) && all(waterMultiplier>0), ...
    "stageB2A:state:PositiveDiagnostics", ...
    "All diagnostic water slack and multiplier entries must be positive.");

state = baseLinearization.state;
state.l = [baseLinearization.l;waterSlack];
state.z = [baseLinearization.z;waterMultiplier];
state.mu = nan;
state.stage_id = "stage_B";
state.milestone_id = "B-2A";
state.initialization_version = ...
    "stage-B2A-structure-audit-deterministic-v1.0";
state.iteration_index = 0;
state.state_revision = 0;
state.newton_direction_number = 0;
state.completed_newton_direction_count = 0;
state.water_slack_rule = "max(1,-g_current)";
state.water_multiplier_rule = "upper=1.25,lower=0.75";
state.optimization_state = false;
state.state_update_executed = false;
end
