function lin = build_stage_b2c_multiday_linearization(state,data,index,config)
%BUILD_STAGE_B2C_MULTIDAY_LINEARIZATION Build one explicit B-2C state view.

arguments
    state (1,1) struct
    data (1,1) struct
    index (1,1) struct
    config (1,1) struct
end
assert(string(state.milestone_id)=="B-2C" && ...
    string(config.milestone_id)=="B-2C" && ...
    string(index.scope.milestone_id)=="B-2C" && ...
    all(state.l>0) && all(state.z>0), ...
    "stageB2C:linearization:Contract", ...
    "B-2C state/index/config identity or positivity is invalid.");
compatState = state;
compatState.milestone_id = "B-2B";
compatIndex = index;
compatIndex.version = "stage-B2B-water-index-v1.0";
compatIndex.scope.milestone_id = "B-2B";
compatIndex.water_constraint_index.milestone_id(:) = "B-2B";
compatConfig = config;
compatConfig.milestone_id = "B-2B";
lin = rkkt.model.build_stage_b2b_multiday_linearization( ...
    compatState,data,compatIndex,compatConfig);
lin.version = "stage-B2C-linearization-v1.0";
lin.milestone_id = "B-2C";
lin.state = state;
lin.index = index;
lin.index_version = index.version;
lin.identity = replace(lin.identity, ...
    "stage-B2B-linearization-v1.0","stage-B2C-linearization-v1.0");
lin.identity = replace(lin.identity, ...
    "stage-B2B-water-index-v1.0","stage-B2C-water-index-v1.0");
lin.execution.full_ipm_executed = logical(state.optimization_state);
lin.execution.optimization_executed = logical(state.optimization_state);
lin.execution.state_update_executed = state.state_revision>0;
lin.execution.full_kkt_role = config.full_kkt_role;
lin.water_multiplier_source = "current_formal_positive_state_z";
lin.water_hessian_rebuilt_from_current_state = true;
lin.config = config;
lin.fixed_zero_map = index.fixed_zero_map;
lin.maps.ineq_water = index.water_constraint_index.inequality_position;
assert(isequal(lin.z,state.z) && isequal(lin.l,state.l) && ...
    lin.counts.full_kkt==config.expected_full_kkt_dimension && ...
    lin.counts.water_inequalities==config.expected_water_inequality_count, ...
    "stageB2C:linearization:StateReuse", ...
    "B-2C linearization did not consume the supplied current state.");
end
