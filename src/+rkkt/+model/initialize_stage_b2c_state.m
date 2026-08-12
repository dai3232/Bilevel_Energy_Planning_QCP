function state = initialize_stage_b2c_state(data,index,config)
%INITIALIZE_STAGE_B2C_STATE Extend the A4 state with daily water rows.

arguments
    data (1,1) struct
    index (1,1) struct
    config (1,1) struct
end
assert(string(config.milestone_id)=="B-2C" && ...
    string(index.scope.milestone_id)=="B-2C", ...
    "stageB2C:state:Identity","B-2C state requires B-2C index/config.");
base = rkkt.model.initialize_stage_a4_state( ...
    data,index.stage_a_base_index,config.stage_a_compatibility);
water = rkkt.model.assemble_stage_b_water_linearization(base.xi,data,index,config);
nWater = height(index.water_constraint_index);
waterSlack = max(ones(nWater,1),-water.constraint_value);
waterMultiplier = repmat(config.initialization.inequality_multiplier,nWater,1);
state = base;
state.l = [base.l;waterSlack];
state.z = [base.z;waterMultiplier];
state.mu = NaN;
state.stage_id = "stage_B";
state.milestone_id = "B-2C";
state.iteration_index = 0;
state.state_revision = 0;
state.newton_direction_number = 0;
state.completed_newton_direction_count = 0;
state.initialization_version = "stage-B2C-formal-interior-v1.0";
state.water_slack_rule = "max(1,-g_current)";
state.water_multiplier_rule = "shared_positive_inequality_multiplier";
state.nonzero_hessian_gate_state = false;
state.optimization_state = true;
assert(numel(state.xi)==index.counts.variables && ...
    numel(state.y)==index.counts.equalities && ...
    numel(state.l)==index.counts.inequalities && ...
    numel(state.z)==index.counts.inequalities && ...
    all(isfinite([state.xi;state.y;state.l;state.z])) && ...
    all(state.l>0) && all(state.z>0), ...
    "stageB2C:state:StrictInterior", ...
    "The formal B-2C initial state must be finite and strictly interior.");
end
