function linearization = build_stage_a1_linearization(state,data,index,config)
%BUILD_STAGE_A1_LINEARIZATION Build the sole Stage A1 model evaluation.
%
% Both the complete sparse KKT audit route and the recursive route must
% consume the returned object.  No solver is permitted to reevaluate the
% objective, constraints, Jacobians, Hessian, or residuals.

variables = index.variable_index;
constraints = index.constraint_index;
constraintTypes = string(constraints.constraint_type);
equalityTable = constraints(constraintTypes == "equality",:);
inequalityTable = constraints(constraintTypes == "inequality",:);
nPrimal = height(variables);
nEquality = height(equalityTable);
nInequality = height(inequalityTable);

assert(numel(state.xi) == nPrimal && numel(state.y) == nEquality && ...
    numel(state.z) == nInequality,"stageA1:linearization:StateDimension", ...
    "The primal-dual state does not match the canonical index.");

parameters = stage_a_capacity_parameters(data);
maps = build_maps(variables,equalityTable,inequalityTable,config);
[A,equalityOffset] = assemble_equalities( ...
    variables,equalityTable,maps,data,parameters,config,nPrimal);
[G,inequalityOffset] = assemble_inequalities( ...
    variables,inequalityTable,maps,data,parameters,nPrimal);

H = sparse(nPrimal,nPrimal);
gradient = zeros(nPrimal,1);
gradient(maps.q_global) = parameters.cost;
objectiveValue = parameters.cost.' * state.xi(maps.q_global);

equalityValues = A*state.xi + equalityOffset;
inequalityValues = G*state.xi + inequalityOffset;
l = -inequalityValues;
if any(~isfinite(l)) || any(l <= 0)
    first = find(~isfinite(l) | l <= 0,1,'first');
    error("stageA1:linearization:NonpositiveSlack", ...
        "Inequality %s has invalid initial slack %.17g.", ...
        string(inequalityTable.constraint_id(first)),l(first));
end
z = state.z;
if any(~isfinite(z)) || any(z <= 0)
    error("stageA1:linearization:NonpositiveMultiplier", ...
        "All inequality multipliers must be finite and strictly positive.");
end
mu = config.initialization.centering_sigma * mean(l.*z);

rDual = gradient + A.'*state.y + G.'*z;
rEq = equalityValues;
rIneq = inequalityValues + l;
rComp = l.*z - mu;

assert(nnz(H) == 0,"stageA1:linearization:NonzeroHessian", ...
    "Stage A1 Hessian must be the exact sparse zero matrix.");
assert(all(isfinite([rDual;rEq;rIneq;rComp])) && isfinite(mu) && mu > 0, ...
    "stageA1:linearization:NonfiniteResidual", ...
    "The unique linearization contains a nonfinite residual or barrier value.");
assert(norm(rIneq,inf) == 0,"stageA1:linearization:SlackEquation", ...
    "The deterministic slack initialization must satisfy c+l exactly.");

finalState = state;
finalState.l = l;
finalState.z = z;
finalState.mu = mu;

layout = build_layout(index,maps,data,config);
inputHashes = lower(string(data.hashes.actualSHA256));
identity = "stageA1-linearization-v1.0|" + strjoin(inputHashes,"|") + ...
    "|day1|hours8-10|" + string(index.version);

linearization = struct();
linearization.identity = identity;
linearization.version = "stageA1-linearization-v1.0";
linearization.state = finalState;
linearization.objective = struct("value",objectiveValue,"gradient",gradient);
linearization.constraints = struct("eq",equalityValues, ...
    "ineq",inequalityValues,"eq_offset",equalityOffset, ...
    "ineq_offset",inequalityOffset);
linearization.jacobian = struct("A",A,"G",G);
linearization.hessian = struct("H",H);
linearization.H = H;
linearization.A = A;
linearization.G = G;
linearization.r_dual = rDual;
linearization.r_eq = rEq;
linearization.r_ineq = rIneq;
linearization.r_comp = rComp;
linearization.l = l;
linearization.z = z;
linearization.mu = mu;
linearization.index = index;
linearization.maps = maps;
linearization.layout = layout;
linearization.fixed_zero_map = index.fixed_zero_map;
linearization.permutation = index.permutation_map;
linearization.capacity_parameters = parameters;
linearization.model_contract_version = "1.0";
linearization.index_version = index.version;
linearization.counts = struct("primal",nPrimal,"equalities",nEquality, ...
    "inequalities",nInequality,"full_kkt", ...
    nPrimal+nEquality+2*nInequality);

validate_linearization_contract(linearization,config);
end

function maps = build_maps(variables,equalities,inequalities,config)
maps = struct();
maps.q_global = variables.global_index_start( ...
    variables.day == 0 & variables.hour == 0);
maps.q_day = variables.global_index_start( ...
    variables.day == config.days(1) & variables.hour == 0);
assert(numel(maps.q_global) == 14 && numel(maps.q_day) == 14, ...
    "stageA1:linearization:CapacityMap", ...
    "Global and daily capacity maps must each contain 14 entries.");

maps.x_by_hour = cell(1,numel(config.hours));
maps.y_by_hour = cell(1,numel(config.hours));
maps.ineq_by_hour = cell(1,numel(config.hours));
for position = 1:numel(config.hours)
    hour = config.hours(position);
    maps.x_by_hour{position} = variables.global_index_start( ...
        variables.day == config.days(1) & variables.hour == hour);
    maps.y_by_hour{position} = find(equalities.day == config.days(1) & ...
        equalities.hour == hour);
    maps.ineq_by_hour{position} = find(inequalities.day == config.days(1) & ...
        inequalities.hour == hour);
end
maps.y_duration = find(string(equalities.constraint_name) == ...
    "storage_duration");
maps.y_binding = find(string(equalities.constraint_name) == ...
    "daily_capacity_binding");
maps.ineq_global = find(inequalities.day == 0 & inequalities.hour == 0);

nPrimal = height(variables);
nEquality = height(equalities);
nInequality = height(inequalities);
maps.direction = struct( ...
    "xi",(1:nPrimal).', ...
    "y",(nPrimal+(1:nEquality)).', ...
    "l",(nPrimal+nEquality+(1:nInequality)).', ...
    "z",(nPrimal+nEquality+nInequality+(1:nInequality)).');
end

function [A,offset] = assemble_equalities(variables,equalities,maps, ...
        data,parameters,config,nPrimal)
nEquality = height(equalities);
A = spalloc(nEquality,nPrimal,160);
offset = zeros(nEquality,1);
day = config.days(1);
for rowNumber = 1:nEquality
    row = equalities(rowNumber,:);
    name = string(row.constraint_name);
    asset = row.asset_id;
    hour = row.hour;
    if name == "storage_duration"
        A(rowNumber,maps.q_global(10+asset)) = ...
            -parameters.storage_duration_hours(asset);
        A(rowNumber,maps.q_global(12+asset)) = 1;
    elseif name == "daily_capacity_binding"
        capacityIndex = row.local_row;
        A(rowNumber,maps.q_day(capacityIndex)) = 1;
        A(rowNumber,maps.q_global(capacityIndex)) = -1;
    elseif name == "hourly_power_balance"
        hourRows = variables(variables.day == day & variables.hour == hour,:);
        for k = 1:height(hourRows)
            variableName = string(hourRows.variable_name(k));
            coefficient = double(ismember(variableName,["PW","PP","PH","PF","Pdis"])) ...
                - double(variableName == "Pch");
            if coefficient ~= 0
                A(rowNumber,hourRows.global_index_start(k)) = coefficient;
            end
        end
        offset(rowNumber) = -data.timeseries.planMW(day,hour);
    elseif name == "soc_dynamics"
        currentPch = locate_hour_variable(variables,day,hour,"storage",asset,"Pch");
        currentPdis = locate_hour_variable(variables,day,hour,"storage",asset,"Pdis");
        currentSoc = locate_hour_variable(variables,day,hour,"storage",asset,"SOC");
        A(rowNumber,currentPch) = -parameters.charge_efficiency(asset)*data.meta.dtHours;
        A(rowNumber,currentPdis) = data.meta.dtHours/parameters.discharge_efficiency(asset);
        A(rowNumber,currentSoc) = 1;
        if hour == config.start_hour
            A(rowNumber,maps.q_day(12+asset)) = ...
                -parameters.initial_soc_fraction(asset);
        else
            previousHour = hour - 1;
            assert(ismember(previousHour,config.hours), ...
                "stageA1:linearization:SocPredecessor", ...
                "SOC dynamics may only connect hours inside the configured window.");
            previousSoc = locate_hour_variable( ...
                variables,day,previousHour,"storage",asset,"SOC");
            A(rowNumber,previousSoc) = -1;
        end
    elseif ismember(name,["terminal_soc","synthetic_window_terminal_soc"])
        assert(hour == config.terminal_hour, ...
            "stageA1:linearization:TerminalHour", ...
            "Synthetic terminal SOC rows must be attached to terminal_hour.");
        currentSoc = locate_hour_variable(variables,day,hour,"storage",asset,"SOC");
        A(rowNumber,currentSoc) = 1;
        A(rowNumber,maps.q_day(12+asset)) = ...
            -parameters.initial_soc_fraction(asset);
    else
        error("stageA1:linearization:UnknownEquality", ...
            "Unsupported Stage A1 equality %s.",name);
    end
end
end

function [G,offset] = assemble_inequalities(variables,inequalities,maps, ...
        data,parameters,nPrimal)
nInequality = height(inequalities);
G = spalloc(nInequality,nPrimal,2*nInequality);
offset = zeros(nInequality,1);
for rowNumber = 1:nInequality
    row = inequalities(rowNumber,:);
    name = string(row.constraint_name);
    if row.day == 0
        capacityIndex = ceil(row.local_row/2);
        if contains(name,"lower")
            G(rowNumber,maps.q_global(capacityIndex)) = -1;
            offset(rowNumber) = parameters.lower(capacityIndex);
        elseif contains(name,"upper")
            G(rowNumber,maps.q_global(capacityIndex)) = 1;
            offset(rowNumber) = -parameters.upper(capacityIndex);
        else
            error("stageA1:linearization:GlobalBoundSide", ...
                "Could not identify global capacity bound side for %s.",name);
        end
        continue;
    end

    variableName = variable_name_for_constraint(row);
    variableIndex = locate_hour_variable(variables,row.day,row.hour, ...
        string(row.asset_type),row.asset_id,variableName);
    isLower = contains(name,"lower_bound");
    isUpper = contains(name,"upper_bound");
    assert(xor(isLower,isUpper),"stageA1:linearization:HourlyBoundSide", ...
        "Could not identify hourly bound side for %s.",name);
    if isLower
        if variableName == "SOC"
            G(rowNumber,variableIndex) = -1;
            G(rowNumber,maps.q_day(12+row.asset_id)) = ...
                parameters.soc_lower_fraction(row.asset_id);
        else
            G(rowNumber,variableIndex) = -1;
        end
        continue;
    end

    G(rowNumber,variableIndex) = 1;
    type = string(row.asset_type);
    asset = row.asset_id;
    if type == "wind"
        G(rowNumber,maps.q_day(asset)) = ...
            -data.timeseries.windAvailability(row.day,row.hour,asset);
    elseif type == "solar"
        G(rowNumber,maps.q_day(5+asset)) = ...
            -data.timeseries.solarAvailability(row.day,row.hour,asset);
    elseif type == "hydro"
        offset(rowNumber) = -data.base.hydro.maxOutputMW(asset);
    elseif type == "thermal"
        offset(rowNumber) = -data.base.thermal.maxOutputMW(asset);
    elseif type == "storage" && ismember(variableName,["Pch","Pdis"])
        G(rowNumber,maps.q_day(10+asset)) = -1;
    elseif type == "storage" && variableName == "SOC"
        G(rowNumber,maps.q_day(12+asset)) = ...
            -parameters.soc_upper_fraction(asset);
    else
        error("stageA1:linearization:UnknownUpperBound", ...
            "Unsupported upper bound %s.",name);
    end
end
end

function layout = build_layout(index,maps,data,config)
layout = struct();
layout.day = config.days(1);
layout.hours = config.hours;
layout.window_type = config.window_type;
layout.start_hour = config.start_hour;
layout.terminal_hour = config.terminal_hour;
layout.soc_boundary_mode = config.soc_boundary_mode;
layout.hour = repmat(struct(),1,numel(config.hours));
variables = index.variable_index;
for position = 1:numel(config.hours)
    hour = config.hours(position);
    xRows = variables(variables.day == config.days(1) & variables.hour == hour,:);
    fixedRows = index.fixed_zero_map(index.fixed_zero_map.day == config.days(1) & ...
        index.fixed_zero_map.hour == hour,:);
    nPrimal = numel(maps.x_by_hour{position});
    nEquality = numel(maps.y_by_hour{position});
    layout.hour(position).physical_hour = hour;
    layout.hour(position).window_position = position;
    layout.hour(position).x_indices = maps.x_by_hour{position};
    layout.hour(position).equality_indices = maps.y_by_hour{position};
    layout.hour(position).inequality_indices = maps.ineq_by_hour{position};
    layout.hour(position).n_primal = nPrimal;
    layout.hour(position).n_equalities = nEquality;
    layout.hour(position).kkt_dimension = nPrimal+nEquality;
    layout.hour(position).active_wind = nnz(string(xRows.asset_type) == "wind");
    layout.hour(position).active_solar = nnz(string(xRows.asset_type) == "solar");
    layout.hour(position).fixed_zero_count = height(fixedRows);
    if position == 1
        layout.hour(position).predecessor_hour = nan;
        layout.hour(position).boundary_source = "fixed_half_energy";
    else
        layout.hour(position).predecessor_hour = config.hours(position-1);
        layout.hour(position).boundary_source = "previous_window_hour";
    end
    layout.hour(position).plan_mw = data.timeseries.planMW(config.days(1),hour);
end
end

function validate_linearization_contract(lin,config)
nPrimal = lin.counts.primal;
nEquality = lin.counts.equalities;
nInequality = lin.counts.inequalities;
assert(issparse(lin.H) && issparse(lin.A) && issparse(lin.G), ...
    "stageA1:linearization:SparseContract", ...
    "H, A, and G must be sparse matrices.");
assert(isequal(size(lin.H),[nPrimal,nPrimal]) && ...
    isequal(size(lin.A),[nEquality,nPrimal]) && ...
    isequal(size(lin.G),[nInequality,nPrimal]), ...
    "stageA1:linearization:MatrixDimension", ...
    "Linearization matrix dimensions do not match the canonical index.");
assert(lin.counts.full_kkt == config.expected_full_kkt_dimension, ...
    "stageA1:linearization:FullKktDimension", ...
    "Complete KKT dimension is %d rather than %d.", ...
    lin.counts.full_kkt,config.expected_full_kkt_dimension);
actualBlocks = [lin.layout.hour.kkt_dimension];
assert(isequal(actualBlocks,config.expected_hourly_kkt_block_dimensions), ...
    "stageA1:linearization:HourlyBlockDimensions", ...
    "Hourly block dimensions are %s.",mat2str(actualBlocks));
assert(numel(lin.maps.y_duration) == 2 && ...
    numel(lin.maps.y_binding) == 14 && ...
    numel(lin.maps.ineq_global) == 28, ...
    "stageA1:linearization:CanonicalSlices", ...
    "Duration, binding, and global-bound slices are not 2, 14, and 28.");

% Independent sign checks guard against two solvers sharing the same wrong
% linearization.  These assertions inspect the actual persisted Jacobians.
variables = lin.index.variable_index;
equalities = lin.index.constraint_index( ...
    string(lin.index.constraint_index.constraint_type) == "equality",:);
day = config.days(1);
firstHour = config.start_hour;
balanceRow = find(equalities.day == day & equalities.hour == firstHour & ...
    string(equalities.constraint_name) == "hourly_power_balance");
pch = locate_hour_variable(variables,day,firstHour,"storage",1,"Pch");
pdis = locate_hour_variable(variables,day,firstHour,"storage",1,"Pdis");
assert(lin.A(balanceRow,pch) == -1 && lin.A(balanceRow,pdis) == 1, ...
    "stageA1:linearization:PowerBalanceSigns", ...
    "Power balance must use Pdis-Pch.");
firstSocRow = find(equalities.day == day & equalities.hour == firstHour & ...
    string(equalities.constraint_name) == "soc_dynamics" & ...
    equalities.asset_id == 1);
previousSocMask = variables.day == day & variables.hour == firstHour-1 & ...
    string(variables.variable_name) == "SOC";
if any(previousSocMask)
    assert(all(lin.A(firstSocRow,variables.global_index_start(previousSocMask)) == 0), ...
        "stageA1:linearization:ForbiddenHourSevenLink", ...
        "The first window SOC row must not connect to hour 7.");
end
terminalRows = find(equalities.day == day & ...
    equalities.hour == config.terminal_hour & ...
    ismember(string(equalities.constraint_name), ...
    ["terminal_soc","synthetic_window_terminal_soc"]));
assert(numel(terminalRows) == 2, ...
    "stageA1:linearization:TerminalSocRows", ...
    "The synthetic window must have two terminal SOC rows.");
end

function name = variable_name_for_constraint(row)
type = string(row.asset_type);
constraintName = string(row.constraint_name);
if type == "wind"
    name = "PW";
elseif type == "solar"
    name = "PP";
elseif type == "hydro"
    name = "PH";
elseif type == "thermal"
    name = "PF";
elseif type == "storage" && startsWith(constraintName,"pch_")
    name = "Pch";
elseif type == "storage" && startsWith(constraintName,"pdis_")
    name = "Pdis";
elseif type == "storage" && startsWith(constraintName,"soc_")
    name = "SOC";
else
    error("stageA1:linearization:ConstraintVariable", ...
        "Could not identify the variable for constraint %s.",constraintName);
end
end

function globalIndex = locate_hour_variable(variables,day,hour,assetType,assetId,name)
mask = variables.day == day & variables.hour == hour & ...
    string(variables.asset_type) == string(assetType) & ...
    variables.asset_id == assetId & ...
    string(variables.variable_name) == string(name);
assert(nnz(mask) == 1,"stageA1:linearization:VariableLookup", ...
    "Expected one %s variable for day %d hour %d asset %d; found %d.", ...
    string(name),day,hour,assetId,nnz(mask));
globalIndex = variables.global_index_start(mask);
end
