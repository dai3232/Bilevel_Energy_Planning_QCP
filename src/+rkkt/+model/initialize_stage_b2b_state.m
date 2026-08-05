function state = initialize_stage_b2b_state(data,index,config)
%INITIALIZE_STAGE_B2B_STATE Build the positive one-direction test state.
%
% Water multipliers come from the same positive deterministic inequality
% initialization as every other row.  The B-2A diagnostic 1.25/0.75 pair
% is intentionally not consumed.  Future states can supply their own
% positive l/z and the linearization will rebuild the Hessian from them.

baseIndex = index.stage_a_base_index;
baseConfig = config.stage_a_compatibility;
baseState = rkkt.model.initialize_stage_a_multiday_state(data,baseIndex,baseConfig);
baseState.iteration_index = 0;
baseState.state_revision = 0;
baseState.newton_direction_number = 0;
baseState.completed_newton_direction_count = 0;
baseLin = rkkt.model.build_stage_a_multiday_linearization( ...
    baseState,data,baseIndex,baseConfig,"SlackMode","initialize");
water = rkkt.model.assemble_stage_b_water_linearization( ...
    baseLin.state.xi,data,index,config);

nWater = height(index.water_constraint_index);
waterSlack = max(ones(nWater,1),-water.constraint_value);
waterMultiplier = repmat(config.initialization.inequality_multiplier,nWater,1);
assert(all(waterSlack>0) && all(waterMultiplier>0), ...
    "stageB2B:state:Positivity","Water l/z must be strictly positive.");

state = baseLin.state;
state.l = [baseLin.l;waterSlack];
state.z = [baseLin.z;waterMultiplier];
state.mu = nan;
state.stage_id = "stage_B";
state.milestone_id = "B-2B";
state.initialization_version = ...
    "stage-B2B-shared-positive-inequality-state-v1.0";
state.iteration_index = 0;
state.state_revision = 0;
state.newton_direction_number = 1;
state.completed_newton_direction_count = 0;
state.water_slack_rule = "max(1,-g_current)";
state.water_multiplier_rule = "shared_positive_inequality_multiplier";
state.water_multiplier_initial_value = ...
    config.initialization.inequality_multiplier;
state.direction_test_state = true;
state.optimization_state = false;
state.state_update_executed = false;
assert(~contains(state.water_multiplier_rule,["1.25","0.75","diagnostic"]), ...
    "stageB2B:state:DiagnosticMultiplier", ...
    "B-2A diagnostic water multipliers leaked into B-2B.");
end
