function linearization = build_stage_a_linearization(state,data,index,config)
%BUILD_STAGE_A_LINEARIZATION Build one shared Stage-A model evaluation.
%
% Complete-KKT and recursive routes must consume this returned object.  SOC
% predecessor and boundary coefficients are read exclusively from the
% canonical soc_link_map, so an A1 artificial window and the A2 formal day
% cannot silently inherit one another's boundary semantics.

validate_stage_scope(index,config);
variables = index.variable_index;
constraints = index.constraint_index;
constraintTypes = string(constraints.constraint_type);
equalityTable = constraints(constraintTypes == "equality",:);
inequalityTable = constraints(constraintTypes == "inequality",:);
nPrimal = height(variables);
nEquality = height(equalityTable);
nInequality = height(inequalityTable);

assert(numel(state.xi) == nPrimal && numel(state.y) == nEquality && ...
    numel(state.z) == nInequality,"stageA:linearization:StateDimension", ...
    "The primal-dual state does not match the canonical index.");

parameters = stage_a_capacity_parameters(data);
maps = build_maps(variables,equalityTable,inequalityTable,config);
[A,equalityOffset] = assemble_equalities( ...
    index,equalityTable,maps,data,parameters,config,nPrimal);
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
    error("stageA:linearization:NonpositiveSlack", ...
        "Inequality %s has invalid initial slack %.17g.", ...
        string(inequalityTable.constraint_id(first)),l(first));
end
z = state.z;
if any(~isfinite(z)) || any(z <= 0)
    error("stageA:linearization:NonpositiveMultiplier", ...
        "All inequality multipliers must be finite and strictly positive.");
end
mu = config.initialization.centering_sigma * mean(l.*z);

rDual = gradient + A.'*state.y + G.'*z;
rEq = equalityValues;
rIneq = inequalityValues + l;
rComp = l.*z - mu;

assert(nnz(H) == 0,"stageA:linearization:NonzeroHessian", ...
    "Stage A Hessian must be the exact sparse zero matrix.");
assert(all(isfinite([rDual;rEq;rIneq;rComp])) && isfinite(mu) && mu > 0, ...
    "stageA:linearization:NonfiniteResidual", ...
    "The shared linearization contains a nonfinite residual or barrier value.");
assert(norm(rIneq,inf) == 0,"stageA:linearization:SlackEquation", ...
    "The deterministic slack initialization must satisfy c+l exactly.");

finalState = state;
finalState.l = l;
finalState.z = z;
finalState.mu = mu;

layout = build_layout(index,maps,data,config);
inputHashes = lower(string(data.hashes.actualSHA256));
version = stage_token(config)+"-linearization-v1.0";
identity = version+"|"+strjoin(inputHashes,"|")+"|day"+ ...
    string(config.days(1))+"|hours"+string(config.hours(1))+"-"+ ...
    string(config.hours(end))+"|"+string(index.version);

linearization = struct();
linearization.identity = identity;
linearization.version = version;
linearization.stage_id = string(config.stage_id);
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
    "stageA:linearization:CapacityMap", ...
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

function [A,offset] = assemble_equalities(index,equalities,maps, ...
        data,parameters,config,nPrimal)
variables = index.variable_index;
nEquality = height(equalities);
A = spalloc(nEquality,nPrimal,max(160,8*nEquality));
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
            coefficient = double(ismember(variableName, ...
                ["PW","PP","PH","PF","Pdis"])) - ...
                double(variableName == "Pch");
            if coefficient ~= 0
                A(rowNumber,hourRows.global_index_start(k)) = coefficient;
            end
        end
        offset(rowNumber) = -data.timeseries.planMW(day,hour);
    elseif name == "soc_dynamics"
        link = locate_soc_link(index.soc_link_map,day,hour,asset);
        currentPch = locate_hour_variable( ...
            variables,day,hour,"storage",asset,"Pch");
        currentPdis = locate_hour_variable( ...
            variables,day,hour,"storage",asset,"Pdis");
        currentSoc = locate_hour_variable( ...
            variables,day,hour,"storage",asset,"SOC");
        assert(link.current_soc_global_index == currentSoc, ...
            "stageA:linearization:CurrentSocMap", ...
            "soc_link_map current SOC index disagrees with variable_index.");
        A(rowNumber,currentPch) = ...
            -parameters.charge_efficiency(asset)*data.meta.dtHours;
        A(rowNumber,currentPdis) = ...
            data.meta.dtHours/parameters.discharge_efficiency(asset);
        A(rowNumber,currentSoc) = 1;
        if isnan(link.predecessor_hour)
            assert(link.predecessor_soc_global_index == 0 && ...
                isfinite(link.initial_energy_fraction), ...
                "stageA:linearization:InitialSocMap", ...
                "An initial SOC row requires no predecessor and a finite energy fraction.");
            A(rowNumber,maps.q_day(12+asset)) = ...
                -link.initial_energy_fraction;
        else
            assert(link.predecessor_soc_global_index > 0 && ...
                ismember(link.predecessor_hour,config.hours), ...
                "stageA:linearization:SocPredecessor", ...
                "An internal SOC row requires an indexed predecessor inside the configured scope.");
            expectedPredecessor = locate_hour_variable(variables,day, ...
                link.predecessor_hour,"storage",asset,"SOC");
            assert(link.predecessor_soc_global_index == expectedPredecessor, ...
                "stageA:linearization:SocPredecessorMap", ...
                "soc_link_map predecessor index disagrees with variable_index.");
            A(rowNumber,link.predecessor_soc_global_index) = -1;
        end
    elseif name == "terminal_soc"
        link = locate_soc_link(index.soc_link_map,day,hour,asset);
        assert(link.terminal_equality && ...
            isfinite(link.terminal_energy_fraction), ...
            "stageA:linearization:TerminalSocMap", ...
            "A terminal SOC row requires a terminal soc_link_map record.");
        currentSoc = locate_hour_variable( ...
            variables,day,hour,"storage",asset,"SOC");
        assert(link.current_soc_global_index == currentSoc, ...
            "stageA:linearization:TerminalCurrentSocMap", ...
            "Terminal SOC mapping disagrees with variable_index.");
        A(rowNumber,currentSoc) = 1;
        A(rowNumber,maps.q_day(12+asset)) = ...
            -link.terminal_energy_fraction;
    else
        error("stageA:linearization:UnknownEquality", ...
            "Unsupported Stage A equality %s.",name);
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
            error("stageA:linearization:GlobalBoundSide", ...
                "Could not identify global capacity bound side for %s.",name);
        end
        continue;
    end

    variableName = variable_name_for_constraint(row);
    variableIndex = locate_hour_variable(variables,row.day,row.hour, ...
        string(row.asset_type),row.asset_id,variableName);
    isLower = contains(name,"lower_bound");
    isUpper = contains(name,"upper_bound");
    assert(xor(isLower,isUpper),"stageA:linearization:HourlyBoundSide", ...
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
        error("stageA:linearization:UnknownUpperBound", ...
            "Unsupported upper bound %s.",name);
    end
end
end

function layout = build_layout(index,maps,data,config)
layout = struct();
layout.day = config.days(1);
layout.hours = config.hours;
layout.time_scope_type = time_scope_type(config);
if isfield(config,"window_type")
    layout.window_type = config.window_type;
end
layout.start_hour = config.start_hour;
layout.terminal_hour = config.terminal_hour;
layout.soc_boundary_mode = config.soc_boundary_mode;
layout.hour = repmat(struct(),1,numel(config.hours));
variables = index.variable_index;
for position = 1:numel(config.hours)
    hour = config.hours(position);
    xRows = variables(variables.day == config.days(1) & ...
        variables.hour == hour,:);
    fixedRows = index.fixed_zero_map(index.fixed_zero_map.day == ...
        config.days(1) & index.fixed_zero_map.hour == hour,:);
    hourLinks = index.soc_link_map(index.soc_link_map.day == ...
        config.days(1) & index.soc_link_map.hour == hour,:);
    assert(height(hourLinks) == data.meta.nStorage, ...
        "stageA:linearization:LayoutSocLinks", ...
        "Every modeled hour must have one SOC link per storage asset.");
    [predecessor,boundarySource] = common_link_boundary(hourLinks);
    nPrimal = numel(maps.x_by_hour{position});
    nEquality = numel(maps.y_by_hour{position});
    layout.hour(position).physical_hour = hour;
    layout.hour(position).hour_position = position;
    layout.hour(position).window_position = position;
    layout.hour(position).x_indices = maps.x_by_hour{position};
    layout.hour(position).equality_indices = maps.y_by_hour{position};
    layout.hour(position).inequality_indices = maps.ineq_by_hour{position};
    layout.hour(position).n_primal = nPrimal;
    layout.hour(position).n_equalities = nEquality;
    layout.hour(position).kkt_dimension = nPrimal+nEquality;
    layout.hour(position).active_wind = ...
        nnz(string(xRows.asset_type) == "wind");
    layout.hour(position).active_solar = ...
        nnz(string(xRows.asset_type) == "solar");
    layout.hour(position).fixed_zero_count = height(fixedRows);
    layout.hour(position).predecessor_hour = predecessor;
    layout.hour(position).boundary_source = boundarySource;
    layout.hour(position).terminal_equality_count = ...
        nnz(hourLinks.terminal_equality);
    layout.hour(position).plan_mw = ...
        data.timeseries.planMW(config.days(1),hour);
end
end

function validate_linearization_contract(lin,config)
nPrimal = lin.counts.primal;
nEquality = lin.counts.equalities;
nInequality = lin.counts.inequalities;
assert(issparse(lin.H) && issparse(lin.A) && issparse(lin.G), ...
    "stageA:linearization:SparseContract", ...
    "H, A, and G must be sparse matrices.");
assert(isequal(size(lin.H),[nPrimal,nPrimal]) && ...
    isequal(size(lin.A),[nEquality,nPrimal]) && ...
    isequal(size(lin.G),[nInequality,nPrimal]), ...
    "stageA:linearization:MatrixDimension", ...
    "Linearization matrix dimensions do not match the canonical index.");
assert(lin.counts.full_kkt == config.expected_full_kkt_dimension, ...
    "stageA:linearization:FullKktDimension", ...
    "Complete KKT dimension is %d rather than %d.", ...
    lin.counts.full_kkt,config.expected_full_kkt_dimension);
actualBlocks = [lin.layout.hour.kkt_dimension];
assert(isequal(actualBlocks,config.expected_hourly_kkt_block_dimensions), ...
    "stageA:linearization:HourlyBlockDimensions", ...
    "Hourly block dimensions are %s.",mat2str(actualBlocks));
if isfield(config,"expected_hourly_chain_dimension")
    assert(sum(actualBlocks) == config.expected_hourly_chain_dimension, ...
        "stageA:linearization:HourlyChainDimension", ...
        "Hourly chain dimension is %d rather than %d.", ...
        sum(actualBlocks),config.expected_hourly_chain_dimension);
end
if isfield(config,"expected_fixed_zero_count")
    assert(height(lin.fixed_zero_map) == config.expected_fixed_zero_count, ...
        "stageA:linearization:FixedZeroCount", ...
        "fixed_zero_map has %d rather than %d rows.", ...
        height(lin.fixed_zero_map),config.expected_fixed_zero_count);
end
assert(numel(lin.maps.y_duration) == 2 && ...
    numel(lin.maps.y_binding) == 14 && ...
    numel(lin.maps.ineq_global) == 28, ...
    "stageA:linearization:CanonicalSlices", ...
    "Duration, binding, and global-bound slices are not 2, 14, and 28.");

variables = lin.index.variable_index;
equalities = lin.index.constraint_index( ...
    string(lin.index.constraint_index.constraint_type) == "equality",:);
day = config.days(1);
firstHour = config.start_hour;
balanceRow = find(equalities.day == day & equalities.hour == firstHour & ...
    string(equalities.constraint_name) == "hourly_power_balance");
pch = locate_hour_variable(variables,day,firstHour,"storage",1,"Pch");
pdis = locate_hour_variable(variables,day,firstHour,"storage",1,"Pdis");
assert(numel(balanceRow) == 1 && lin.A(balanceRow,pch) == -1 && ...
    lin.A(balanceRow,pdis) == 1, ...
    "stageA:linearization:PowerBalanceSigns", ...
    "Power balance must use Pdis-Pch.");

for storage = 1:2
    firstLink = locate_soc_link(lin.index.soc_link_map, ...
        day,firstHour,storage);
    firstSocRow = find(equalities.day == day & ...
        equalities.hour == firstHour & ...
        string(equalities.constraint_name) == "soc_dynamics" & ...
        equalities.asset_id == storage);
    assert(numel(firstSocRow) == 1 && ...
        isnan(firstLink.predecessor_hour) && ...
        firstLink.predecessor_soc_global_index == 0 && ...
        lin.A(firstSocRow,lin.maps.q_day(12+storage)) == ...
            -firstLink.initial_energy_fraction, ...
        "stageA:linearization:InitialSocBoundary", ...
        "The first SOC row must use its indexed fixed-energy boundary.");
end

for position = 2:numel(config.hours)
    hour = config.hours(position);
    for storage = 1:2
        link = locate_soc_link(lin.index.soc_link_map,day,hour,storage);
        row = find(equalities.day == day & equalities.hour == hour & ...
            string(equalities.constraint_name) == "soc_dynamics" & ...
            equalities.asset_id == storage);
        assert(numel(row) == 1 && link.predecessor_soc_global_index > 0 && ...
            lin.A(row,link.predecessor_soc_global_index) == -1, ...
            "stageA:linearization:InternalSocCoefficient", ...
            "An internal SOC row is missing its exact -1 predecessor coefficient.");
    end
end

terminalRows = find(string(equalities.constraint_name) == "terminal_soc");
assert(numel(terminalRows) == config.terminal_soc_equality_count && ...
    all(equalities.hour(terminalRows) == config.terminal_hour), ...
    "stageA:linearization:TerminalSocRows", ...
    "Terminal SOC rows must occur exactly at the configured terminal hour.");
for storage = 1:2
    link = locate_soc_link(lin.index.soc_link_map, ...
        day,config.terminal_hour,storage);
    row = find(equalities.day == day & ...
        equalities.hour == config.terminal_hour & ...
        string(equalities.constraint_name) == "terminal_soc" & ...
        equalities.asset_id == storage);
    assert(numel(row) == 1 && link.terminal_equality && ...
        lin.A(row,link.current_soc_global_index) == 1 && ...
        lin.A(row,lin.maps.q_day(12+storage)) == ...
            -link.terminal_energy_fraction, ...
        "stageA:linearization:TerminalSocCoefficients", ...
        "A terminal SOC row has incorrect SOC or energy-capacity coefficients.");
end

if ~isempty(lin.fixed_zero_map)
    assert(all(lin.fixed_zero_map.fixed_value == 0) && ...
        all(lin.fixed_zero_map.fixed_direction_value == 0), ...
        "stageA:linearization:FixedZeroMap", ...
        "All fixed-zero map values and directions must be exact numeric zero.");
end
end

function link = locate_soc_link(links,day,hour,storage)
mask = links.day == day & links.hour == hour & links.storage_id == storage;
assert(nnz(mask) == 1,"stageA:linearization:SocLinkLookup", ...
    "Expected one SOC link for day %d hour %d storage %d; found %d.", ...
    day,hour,storage,nnz(mask));
link = links(mask,:);
end

function [predecessor,boundarySource] = common_link_boundary(links)
sources = unique(string(links.boundary_source));
assert(numel(sources) == 1,"stageA:linearization:BoundarySource", ...
    "Storage links in one hour must share one boundary source.");
boundarySource = sources(1);
values = links.predecessor_hour;
if all(isnan(values))
    predecessor = nan;
else
    assert(all(isfinite(values)) && numel(unique(values)) == 1, ...
        "stageA:linearization:PredecessorHour", ...
        "Storage links in one hour must share one predecessor hour.");
    predecessor = values(1);
end
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
    error("stageA:linearization:ConstraintVariable", ...
        "Could not identify the variable for constraint %s.",constraintName);
end
end

function globalIndex = locate_hour_variable(variables,day,hour, ...
        assetType,assetId,name)
mask = variables.day == day & variables.hour == hour & ...
    string(variables.asset_type) == string(assetType) & ...
    variables.asset_id == assetId & ...
    string(variables.variable_name) == string(name);
assert(nnz(mask) == 1,"stageA:linearization:VariableLookup", ...
    "Expected one %s variable for day %d hour %d asset %d; found %d.", ...
    string(name),day,hour,assetId,nnz(mask));
globalIndex = variables.global_index_start(mask);
end

function validate_stage_scope(index,config)
assert(isfield(config,"stage_id") && ...
    ismember(string(config.stage_id),["stage_A1","stage_A2"]), ...
    "stageA:linearization:UnsupportedStage", ...
    "The shared Stage-A linearization currently supports only A1 and A2.");
assert(isfield(index,"scope") && isfield(index.scope,"stage_id") && ...
    string(index.scope.stage_id) == string(config.stage_id), ...
    "stageA:linearization:StageIndexMismatch", ...
    "Configuration and canonical index stage identifiers disagree.");
assert(numel(config.days) == 1 && numel(unique(config.days)) == 1 && ...
    isequal(reshape(index.scope.days,1,[]),reshape(config.days,1,[])) && ...
    isequal(reshape(index.scope.hours,1,[]),reshape(config.hours,1,[])), ...
    "stageA:linearization:ScopeMismatch", ...
    "Configuration and canonical index day/hour scopes disagree.");
end

function token = stage_token(config)
token = erase(string(config.stage_id),"_");
end

function value = time_scope_type(config)
if isfield(config,"time_scope_type")
    value = string(config.time_scope_type);
elseif isfield(config,"window_type")
    value = string(config.window_type);
else
    error("stageA:linearization:MissingTimeScopeType", ...
        "Stage configuration must identify its time scope.");
end
end
