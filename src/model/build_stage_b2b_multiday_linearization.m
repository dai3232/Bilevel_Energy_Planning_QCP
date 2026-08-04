function lin = build_stage_b2b_multiday_linearization(state,data,index,config)
%BUILD_STAGE_B2B_MULTIDAY_LINEARIZATION Build the shared B-2B object.
%
% The audited B-2A equations are reused without copying their implementation.
% Only milestone identity and execution role are changed.  All water
% Lagrangian-Hessian terms are rebuilt from the supplied current positive z.

arguments
    state (1,1) struct
    data (1,1) struct
    index (1,1) struct
    config (1,1) struct
end
assert(string(state.milestone_id)=="B-2B" && ...
    string(config.milestone_id)=="B-2B" && ...
    string(index.scope.milestone_id)=="B-2B" && ...
    all(state.l>0) && all(state.z>0), ...
    "stageB2B:linearization:Contract", ...
    "B-2B state/index/config identity or positivity is invalid.");

compatState = state;
compatState.milestone_id = "B-2A";
compatIndex = index;
% Keep the B-2B marker on the index so the shared builder can apply only
% the narrowly-scoped zero-curvature validation exception above.
compatConfig = config;
compatConfig.milestone_id = "B-2A";
lin = build_stage_b_multiday_linearization( ...
    compatState,data,compatIndex,compatConfig);

lin.version = "stage-B2B-linearization-v1.0";
lin.stage_id = "stage_B";
lin.milestone_id = "B-2B";
lin.state = state;
lin.index = index;
lin.index_version = index.version;
lin.identity = replace(lin.identity, ...
    "stage-B2A-linearization-v1.0","stage-B2B-linearization-v1.0");
lin.identity = replace(lin.identity, ...
    "stage-B2A-water-index-v1.0","stage-B2B-water-index-v1.0");
lin.execution = struct("full_kkt_assembled",false, ...
    "full_kkt_solved",false,"full_kkt_role","independent_audit_only", ...
    "recursive_direction_executed",false,"newton_direction_count",0, ...
    "full_ipm_executed",false,"optimization_executed",false, ...
    "state_update_executed",false,"parallel_executed",false, ...
    "stage_c1_entered",false,"fallback_used",false);
lin.water_multiplier_source = "current_positive_state_z";
lin.water_hessian_rebuilt_from_current_state = true;
lin.config = config;
lin.fixed_zero_map = index.fixed_zero_map;
lin.maps.ineq_water = index.water_constraint_index.inequality_position;
assert(isequal(lin.z,state.z) && isequal(lin.l,state.l) && ...
    lin.counts.full_kkt==18948 && lin.counts.water_inequalities==56, ...
    "stageB2B:linearization:StateReuse", ...
    "B-2B linearization did not consume the supplied current state.");
end
