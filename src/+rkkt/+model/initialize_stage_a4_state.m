function state = initialize_stage_a4_state(data,index,config)
%INITIALIZE_STAGE_A4_STATE Build the strictly interior A4 iteration-zero state.

if string(config.stage_id) ~= "stage_A4" || ...
        ~isfield(index,"scope") || string(index.scope.stage_id) ~= "stage_A4"
    error("stageA4:state:StageId", ...
        "A4 state initialization requires an A4 configuration and index.");
end
seed = rkkt.model.initialize_stage_a_multiday_state(data,index,config);
seed.iteration_index = 0;
seed.state_revision = 0;
initialized = rkkt.model.build_stage_a_multiday_linearization( ...
    seed,data,index,config,"SlackMode","initialize");
state = initialized.state;
state.iteration_index = 0;
state.state_revision = 0;
state.newton_direction_number = 0;
state.completed_newton_direction_count = 0;
state.fixed_zero_values = index.fixed_zero_map.fixed_value;
state.fixed_zero_directions = index.fixed_zero_map.fixed_direction_value;
state.initialization_version = "stageA4-deterministic-interior-v1.0";

validate_state(state,index,initialized);
end

function validate_state(state,index,linearization)
nPrimal = height(index.variable_index);
types = string(index.constraint_index.constraint_type);
nEquality = nnz(types == "equality");
nInequality = nnz(types == "inequality");
if numel(state.xi) ~= nPrimal || numel(state.y) ~= nEquality || ...
        numel(state.l) ~= nInequality || numel(state.z) ~= nInequality
    error("stageA4:state:Dimension", ...
        "A4 xi, y, l, and z must match the canonical index dimensions.");
end
if any(~isfinite([state.xi;state.y;state.l;state.z])) || ...
        any(state.l <= 0) || any(state.z <= 0)
    error("stageA4:state:StrictInterior", ...
        "A4 initial l and z must be finite and strictly positive.");
end
if numel(state.fixed_zero_values) ~= 422 || ...
        any(state.fixed_zero_values ~= 0) || ...
        any(state.fixed_zero_directions ~= 0)
    error("stageA4:state:FixedZero", ...
        "All 422 removed renewable values and directions must be exact zero.");
end
if norm(linearization.r_ineq,inf) ~= 0 || ...
        norm(linearization.slack_consistency.audit_error,inf) ~= 0
    error("stageA4:state:SlackInitialization", ...
        "The deterministic initial slack must satisfy its equality exactly.");
end
links = index.soc_link_map;
for day = 14:20
    first = links(links.day == day & links.hour == 1,:);
    terminal = links(links.day == day & links.terminal_equality,:);
    if height(first) ~= 2 || any(~isnan(first.predecessor_hour)) || ...
            any(first.predecessor_soc_global_index ~= 0) || ...
            any(first.initial_energy_fraction ~= 0.5) || ...
            height(terminal) ~= 2 || any(terminal.hour ~= 24) || ...
            any(terminal.terminal_energy_fraction ~= 0.5)
        error("stageA4:state:SocBoundary", ...
            "Each A4 day must have independent 0.5E initial/terminal SOC.");
    end
end
end
