function linearization = build_stage_a_multiday_linearization( ...
        state,data,index,config,options)
%BUILD_STAGE_A_MULTIDAY_LINEARIZATION Build one shared multiday model view.
%
% Both complete-KKT audit and recursive reduction must consume this exact
% object.  It contains one global q, daily q_d copies, independent formal
% daily SOC chains, and one canonical residual/direction ordering.

arguments
    state (1,1) struct
    data (1,1) struct
    index (1,1) struct
    config (1,1) struct
    options.SlackMode (1,1) string {mustBeMember( ...
        options.SlackMode,["initialize","explicit"])} = "initialize"
end

validate_stage_scope(index,config);
variables = index.variable_index;
constraints = index.constraint_index;
constraintTypes = string(constraints.constraint_type);
equalityTable = constraints(constraintTypes == "equality",:);
inequalityTable = constraints(constraintTypes == "inequality",:);
nPrimal = height(variables);
nEquality = height(equalityTable);
nInequality = height(inequalityTable);
if numel(state.xi) ~= nPrimal || numel(state.y) ~= nEquality || ...
        numel(state.z) ~= nInequality
    error("stageA:linearization:StateDimension", ...
        "The primal-dual state does not match the unified canonical index.");
end

parameters = rkkt.model.stage_a_capacity_parameters(data);
maps = build_maps(variables,equalityTable,inequalityTable,config);
[A,equalityOffset] = assemble_equalities( ...
    index,equalityTable,maps,data,parameters,config,nPrimal);
[G,inequalityOffset] = assemble_inequalities( ...
    variables,inequalityTable,maps,data,parameters,config,nPrimal);

H = sparse(nPrimal,nPrimal);
gradient = zeros(nPrimal,1);
gradient(maps.q_global) = parameters.cost;
objectiveValue = parameters.cost.'*state.xi(maps.q_global);

equalityValues = A*state.xi + equalityOffset;
inequalityValues = G*state.xi + inequalityOffset;
impliedSlack = -inequalityValues;
if options.SlackMode == "initialize"
    l = impliedSlack;
else
    if ~isfield(state,"l") || numel(state.l) ~= nInequality
        error("stageA:linearization:ExplicitSlackDimension", ...
            "Explicit slack mode requires state.l to match every inequality.");
    end
    l = state.l(:);
end
if any(~isfinite(l)) || any(l <= 0)
    first = find(~isfinite(l) | l <= 0,1,'first');
    error("stageA:linearization:NonpositiveSlack", ...
        "Inequality %s has invalid slack %.17g.", ...
        string(inequalityTable.constraint_id(first)),l(first));
end
z = state.z;
if any(~isfinite(z)) || any(z <= 0)
    error("stageA:multiday:NonpositiveMultiplier", ...
        "All inequality multipliers must be finite and strictly positive.");
end
complementarityGap = mean(l.*z);
rawComplementarity = l.'*z;
mu = config.initialization.centering_sigma*complementarityGap;

rDual = gradient + A.'*state.y + G.'*z;
rEq = equalityValues;
rIneq = inequalityValues + l;
rComp = l.*z - mu;
if nnz(H) ~= 0
    error("stageA:multiday:NonzeroHessian", ...
        "The Stage-A investment objective has an exact zero Hessian.");
end
if any(~isfinite([rDual;rEq;rIneq;rComp])) || ~isfinite(mu) || mu <= 0
    error("stageA:multiday:NonfiniteResidual", ...
        "The shared linearization contains a nonfinite residual or barrier value.");
end
if options.SlackMode == "initialize" && norm(rIneq,inf) ~= 0
    error("stageA:multiday:SlackEquation", ...
        "The deterministic slack initialization must satisfy c+l exactly.");
end

finalState = state;
finalState.l = l;
finalState.z = z;
finalState.mu = mu;
layout = build_layout(index,maps,data,config);
inputHashes = lower(string(data.hashes.actualSHA256));
stageId = string(config.stage_id);
if stageId == "stage_A3"
    version = "stageA3-linearization-v1.0";
    identity = version+"|"+strjoin(inputHashes,"|")+ ...
        "|day14-20|hours1-24|"+string(index.version);
else
    version = "stageA4-linearization-v1.0";
    [iterationIndex,stateRevision] = a4_state_revision(state);
    identity = version+"|"+strjoin(inputHashes,"|")+ ...
        "|day14-20|hours1-24|"+string(index.version)+ ...
        "|iteration"+string(iterationIndex)+ ...
        "|revision"+string(stateRevision);
end

linearization = struct();
linearization.identity = identity;
linearization.version = version;
linearization.stage_id = stageId;
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
linearization.implied_slack = impliedSlack;
linearization.slack_consistency = struct( ...
    "state_minus_implied",l-impliedSlack, ...
    "residual",rIneq, ...
    "audit_error",(l-impliedSlack)-rIneq);
linearization.physical_inequality_violation = max([inequalityValues;0]);
linearization.complementarity_gap = complementarityGap;
linearization.raw_complementarity = rawComplementarity;
linearization.index = index;
linearization.maps = maps;
linearization.layout = layout;
linearization.fixed_zero_map = index.fixed_zero_map;
linearization.permutation = index.permutation_map;
linearization.capacity_parameters = parameters;
linearization.model_contract_version = "1.0";
linearization.index_version = index.version;
linearization.counts = struct("primal",nPrimal, ...
    "equalities",nEquality,"inequalities",nInequality, ...
    "full_kkt",nPrimal+nEquality+2*nInequality, ...
    "days",numel(config.days), ...
    "hourly_chain",sum(layout.daily_chain_dimensions));

validate_linearization_contract(linearization,config);
end

function [iterationIndex,stateRevision] = a4_state_revision(state)
required = ["iteration_index","state_revision"];
for field = required
    if ~isfield(state,field) || ~isscalar(state.(field)) || ...
            ~isfinite(state.(field)) || state.(field) < 0 || ...
            state.(field) ~= fix(state.(field))
        error("stageA4:linearization:StateRevision", ...
            "A4 state.%s must be a finite nonnegative integer scalar.",field);
    end
end
iterationIndex = state.iteration_index;
stateRevision = state.state_revision;
end

function maps = build_maps(variables,equalities,inequalities,config)
nDays = numel(config.days);
nHours = numel(config.hours);
maps = struct();
maps.days = config.days;
maps.hours = config.hours;
maps.q_global = variables.global_index_start( ...
    variables.day == 0 & variables.hour == 0);
maps.q_day = zeros(14,nDays);
maps.q_day_by_day = cell(1,nDays);
maps.y_binding_by_day = cell(1,nDays);
maps.x_by_day_hour = cell(nDays,nHours);
maps.y_by_day_hour = cell(nDays,nHours);
maps.ineq_by_day_hour = cell(nDays,nHours);
storageRows = string(variables.asset_type)=="storage";
nStorage = max(variables.asset_id(storageRows));
maps.storage_pch = zeros(nDays,nHours,nStorage);
maps.storage_pdis = zeros(nDays,nHours,nStorage);
maps.storage_soc = zeros(nDays,nHours,nStorage);
if numel(maps.q_global) ~= 14
    error("stageA:multiday:GlobalCapacityMap", ...
        "The global q map must have exactly 14 entries.");
end
for dayPosition = 1:nDays
    day = config.days(dayPosition);
    qDay = variables.global_index_start( ...
        variables.day == day & variables.hour == 0);
    binding = find(equalities.day == day & ...
        string(equalities.constraint_name) == "daily_capacity_binding");
    if numel(qDay) ~= 14 || numel(binding) ~= 14
        error("stageA:multiday:DailyCapacityMap", ...
            "Day %d requires 14 q_d and 14 binding entries.",day);
    end
    maps.q_day(:,dayPosition) = qDay;
    maps.q_day_by_day{dayPosition} = qDay;
    maps.y_binding_by_day{dayPosition} = binding;
    for hourPosition = 1:nHours
        hour = config.hours(hourPosition);
        xIndices = variables.global_index_start(variables.day == day & ...
            variables.hour == hour);
        maps.x_by_day_hour{dayPosition,hourPosition} = xIndices;
        hourVariables = variables(xIndices,:);
        for storage = 1:nStorage
            storageMask = string(hourVariables.asset_type)=="storage" & ...
                hourVariables.asset_id==storage;
            storageVariables = hourVariables(storageMask,:);
            names = string(storageVariables.variable_name);
            assert(height(storageVariables)==3 && ...
                nnz(names=="Pch")==1 && nnz(names=="Pdis")==1 && ...
                nnz(names=="SOC")==1, ...
                "stageA:multiday:StorageVariableMap", ...
                "Each modeled day/hour requires Pch, Pdis, and SOC.");
            maps.storage_pch(dayPosition,hourPosition,storage) = ...
                storageVariables.global_index_start(names=="Pch");
            maps.storage_pdis(dayPosition,hourPosition,storage) = ...
                storageVariables.global_index_start(names=="Pdis");
            maps.storage_soc(dayPosition,hourPosition,storage) = ...
                storageVariables.global_index_start(names=="SOC");
        end
        maps.y_by_day_hour{dayPosition,hourPosition} = ...
            find(equalities.day == day & equalities.hour == hour);
        maps.ineq_by_day_hour{dayPosition,hourPosition} = ...
            find(inequalities.day == day & inequalities.hour == hour);
    end
end
maps.y_duration = find(string(equalities.constraint_name) == ...
    "storage_duration");
maps.y_binding = vertcat(maps.y_binding_by_day{:});
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
A = spalloc(nEquality,nPrimal,max(1000,8*nEquality));
offset = zeros(nEquality,1);
for rowNumber = 1:nEquality
    row = equalities(rowNumber,:);
    name = string(row.constraint_name);
    asset = row.asset_id;
    day = row.day;
    hour = row.hour;
    if name == "storage_duration"
        A(rowNumber,maps.q_global(10+asset)) = ...
            -parameters.storage_duration_hours(asset);
        A(rowNumber,maps.q_global(12+asset)) = 1;
    elseif name == "daily_capacity_binding"
        dayPosition = locate_day_position(config.days,day);
        capacityIndex = row.local_row;
        A(rowNumber,maps.q_day(capacityIndex,dayPosition)) = 1;
        A(rowNumber,maps.q_global(capacityIndex)) = -1;
    elseif name == "hourly_power_balance"
        dayPosition = locate_day_position(config.days,day);
        hourPosition = locate_day_position(config.hours,hour);
        hourRows = variables( ...
            maps.x_by_day_hour{dayPosition,hourPosition},:);
        for localRow = 1:height(hourRows)
            variableName = string(hourRows.variable_name(localRow));
            coefficient = double(ismember(variableName, ...
                ["PW","PP","PH","PF","Pdis"])) - ...
                double(variableName == "Pch");
            if coefficient ~= 0
                A(rowNumber,hourRows.global_index_start(localRow)) = coefficient;
            end
        end
        offset(rowNumber) = -data.timeseries.planMW(day,hour);
    elseif name == "soc_dynamics"
        dayPosition = locate_day_position(config.days,day);
        hourPosition = locate_day_position(config.hours,hour);
        link = locate_soc_link(index.soc_link_map,day,hour,asset);
        currentPch = maps.storage_pch(dayPosition,hourPosition,asset);
        currentPdis = maps.storage_pdis(dayPosition,hourPosition,asset);
        currentSoc = maps.storage_soc(dayPosition,hourPosition,asset);
        if link.current_soc_global_index ~= currentSoc
            error("stageA:multiday:CurrentSocMap", ...
                "soc_link_map current SOC index disagrees with variable_index.");
        end
        A(rowNumber,currentPch) = ...
            -parameters.charge_efficiency(asset)*data.meta.dtHours;
        A(rowNumber,currentPdis) = ...
            data.meta.dtHours/parameters.discharge_efficiency(asset);
        A(rowNumber,currentSoc) = 1;
        if isnan(link.predecessor_hour)
            if link.predecessor_soc_global_index ~= 0 || ...
                    ~isfinite(link.initial_energy_fraction)
                error("stageA:multiday:InitialSocMap", ...
                    "An initial SOC row requires no predecessor and a finite fraction.");
            end
            A(rowNumber,maps.q_day(12+asset,dayPosition)) = ...
                -link.initial_energy_fraction;
        else
            predecessorPosition = locate_day_position( ...
                config.hours,link.predecessor_hour);
            expectedPredecessor = maps.storage_soc( ...
                dayPosition,predecessorPosition,asset);
            if link.predecessor_soc_global_index ~= expectedPredecessor
                error("stageA:multiday:SocPredecessorMap", ...
                    "SOC predecessor index is cross-day or nonadjacent.");
            end
            A(rowNumber,link.predecessor_soc_global_index) = -1;
        end
    elseif name == "terminal_soc"
        dayPosition = locate_day_position(config.days,day);
        hourPosition = locate_day_position(config.hours,hour);
        link = locate_soc_link(index.soc_link_map,day,hour,asset);
        if ~link.terminal_equality || ...
                ~isfinite(link.terminal_energy_fraction)
            error("stageA:multiday:TerminalSocMap", ...
                "A terminal SOC row requires a terminal link record.");
        end
        currentSoc = maps.storage_soc(dayPosition,hourPosition,asset);
        A(rowNumber,currentSoc) = 1;
        A(rowNumber,maps.q_day(12+asset,dayPosition)) = ...
            -link.terminal_energy_fraction;
    else
        error("stageA:multiday:UnknownEquality", ...
            "Unsupported multiday Stage-A equality %s.",name);
    end
end
end

function [G,offset] = assemble_inequalities(variables,inequalities,maps, ...
        data,parameters,config,nPrimal)
nInequality = height(inequalities);
G = spalloc(nInequality,nPrimal,2*nInequality);
offset = zeros(nInequality,1);
hourlyVariableRows = find(variables.hour>0);
assert(nInequality==28+2*numel(hourlyVariableRows), ...
    "stageA:multiday:InequalityOrdering", ...
    "Stage-A inequalities must be 28 global bounds followed by two bounds per active hourly variable.");
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
            error("stageA:multiday:GlobalBoundSide", ...
                "Could not identify global capacity bound side for %s.",name);
        end
        continue;
    end

    hourlyPosition = ceil((rowNumber-28)/2);
    variable = variables(hourlyVariableRows(hourlyPosition),:);
    variableName = string(variable.variable_name);
    variableIndex = variable.global_index_start;
    assert(variable.day==row.day && variable.hour==row.hour && ...
        string(variable.asset_type)==string(row.asset_type) && ...
        variable.asset_id==row.asset_id, ...
        "stageA:multiday:InequalityVariableOrder", ...
        "An hourly bound row does not match canonical variable order.");
    dayPosition = locate_day_position(config.days,row.day);
    isLower = contains(name,"lower_bound");
    isUpper = contains(name,"upper_bound");
    if ~xor(isLower,isUpper)
        error("stageA:multiday:HourlyBoundSide", ...
            "Could not identify hourly bound side for %s.",name);
    end
    if isLower
        if variableName == "SOC"
            G(rowNumber,variableIndex) = -1;
            G(rowNumber,maps.q_day(12+row.asset_id,dayPosition)) = ...
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
        G(rowNumber,maps.q_day(asset,dayPosition)) = ...
            -data.timeseries.windAvailability(row.day,row.hour,asset);
    elseif type == "solar"
        G(rowNumber,maps.q_day(5+asset,dayPosition)) = ...
            -data.timeseries.solarAvailability(row.day,row.hour,asset);
    elseif type == "hydro"
        offset(rowNumber) = -data.base.hydro.maxOutputMW(asset);
    elseif type == "thermal"
        offset(rowNumber) = -data.base.thermal.maxOutputMW(asset);
    elseif type == "storage" && ismember(variableName,["Pch","Pdis"])
        G(rowNumber,maps.q_day(10+asset,dayPosition)) = -1;
    elseif type == "storage" && variableName == "SOC"
        G(rowNumber,maps.q_day(12+asset,dayPosition)) = ...
            -parameters.soc_upper_fraction(asset);
    else
        error("stageA:multiday:UnknownUpperBound", ...
            "Unsupported upper bound %s.",name);
    end
end
end

function layout = build_layout(index,maps,data,config)
nDays = numel(config.days);
nHours = numel(config.hours);
layout = struct();
layout.days = config.days;
layout.hours = config.hours;
layout.time_scope_type = config.time_scope_type;
layout.start_hour = config.start_hour;
layout.terminal_hour = config.terminal_hour;
layout.soc_boundary_mode = config.soc_boundary_mode;
layout.aggregation_day_order = config.aggregation_day_order;
layout.day = repmat(day_layout_template(),1,nDays);
layout.hour = repmat(hour_layout_template(),1,nDays*nHours);
layout.daily_chain_dimensions = zeros(1,nDays);
variables = index.variable_index;
flatPosition = 0;
for dayPosition = 1:nDays
    day = config.days(dayPosition);
    dayHours = repmat(hour_layout_template(),1,nHours);
    for hourPosition = 1:nHours
        flatPosition = flatPosition + 1;
        hour = config.hours(hourPosition);
        xRows = variables(variables.day == day & variables.hour == hour,:);
        fixedRows = index.fixed_zero_map(index.fixed_zero_map.day == day & ...
            index.fixed_zero_map.hour == hour,:);
        hourLinks = index.soc_link_map(index.soc_link_map.day == day & ...
            index.soc_link_map.hour == hour,:);
        if height(hourLinks) ~= data.meta.nStorage
            error("stageA:multiday:LayoutSocLinks", ...
                "Every modeled day/hour needs one SOC link per storage asset.");
        end
        [predecessor,boundarySource] = common_link_boundary(hourLinks);
        entry = struct();
        entry.day_id = day;
        entry.day_position = dayPosition;
        entry.physical_hour = hour;
        entry.hour_position = hourPosition;
        entry.x_indices = maps.x_by_day_hour{dayPosition,hourPosition};
        entry.equality_indices = ...
            maps.y_by_day_hour{dayPosition,hourPosition};
        entry.inequality_indices = ...
            maps.ineq_by_day_hour{dayPosition,hourPosition};
        entry.n_primal = numel(entry.x_indices);
        entry.n_equalities = numel(entry.equality_indices);
        entry.kkt_dimension = entry.n_primal + entry.n_equalities;
        entry.active_wind = nnz(string(xRows.asset_type) == "wind");
        entry.active_solar = nnz(string(xRows.asset_type) == "solar");
        entry.fixed_zero_count = height(fixedRows);
        entry.predecessor_hour = predecessor;
        entry.boundary_source = boundarySource;
        entry.terminal_equality_count = nnz(hourLinks.terminal_equality);
        entry.plan_mw = data.timeseries.planMW(day,hour);
        dayHours(hourPosition) = entry;
        layout.hour(flatPosition) = entry;
    end
    layout.day(dayPosition).day_id = day;
    layout.day(dayPosition).day_position = dayPosition;
    layout.day(dayPosition).hours = config.hours;
    layout.day(dayPosition).q_day_indices = maps.q_day(:,dayPosition);
    layout.day(dayPosition).binding_equality_indices = ...
        maps.y_binding_by_day{dayPosition};
    layout.day(dayPosition).hour = dayHours;
    layout.day(dayPosition).hourly_chain_dimension = ...
        sum([dayHours.kkt_dimension]);
    layout.day(dayPosition).fixed_zero_count = ...
        nnz(index.fixed_zero_map.day == day);
    layout.daily_chain_dimensions(dayPosition) = ...
        layout.day(dayPosition).hourly_chain_dimension;
end
layout.total_hourly_chain_dimension = sum(layout.daily_chain_dimensions);
end

function entry = hour_layout_template()
entry = struct("day_id",0,"day_position",0,"physical_hour",0, ...
    "hour_position",0,"x_indices",zeros(0,1), ...
    "equality_indices",zeros(0,1),"inequality_indices",zeros(0,1), ...
    "n_primal",0,"n_equalities",0,"kkt_dimension",0, ...
    "active_wind",0,"active_solar",0,"fixed_zero_count",0, ...
    "predecessor_hour",nan,"boundary_source","", ...
    "terminal_equality_count",0,"plan_mw",0);
end

function entry = day_layout_template()
entry = struct("day_id",0,"day_position",0,"hours",zeros(1,0), ...
    "q_day_indices",zeros(0,1), ...
    "binding_equality_indices",zeros(0,1), ...
    "hour",repmat(hour_layout_template(),1,0), ...
    "hourly_chain_dimension",0,"fixed_zero_count",0);
end

function validate_linearization_contract(lin,config)
nPrimal = lin.counts.primal;
nEquality = lin.counts.equalities;
nInequality = lin.counts.inequalities;
if ~issparse(lin.H) || ~issparse(lin.A) || ~issparse(lin.G)
    error("stageA:multiday:SparseContract", ...
        "H, A, and G must remain sparse.");
end
if ~isequal(size(lin.H),[nPrimal,nPrimal]) || ...
        ~isequal(size(lin.A),[nEquality,nPrimal]) || ...
        ~isequal(size(lin.G),[nInequality,nPrimal])
    error("stageA:multiday:MatrixDimension", ...
        "Linearization matrices do not match the canonical index.");
end
if lin.counts.full_kkt ~= config.expected_full_kkt_dimension
    error("stageA:multiday:FullKktDimension", ...
        "Complete KKT dimension is %d rather than %d.", ...
        lin.counts.full_kkt,config.expected_full_kkt_dimension);
end
if ~isequal(lin.layout.daily_chain_dimensions, ...
        config.expected_daily_hourly_chain_dimensions) || ...
        lin.layout.total_hourly_chain_dimension ~= ...
        config.expected_total_hourly_chain_dimension
    error("stageA:multiday:HourlyChainDimensions", ...
        "Seven daily chain dimensions disagree with controlled data.");
end
if height(lin.fixed_zero_map) ~= config.expected_fixed_zero_count
    error("stageA:multiday:FixedZeroCount", ...
        "fixed_zero_map has %d rather than %d rows.", ...
        height(lin.fixed_zero_map),config.expected_fixed_zero_count);
end
if numel(lin.maps.y_duration) ~= 2 || ...
        numel(lin.maps.y_binding) ~= 14*numel(config.days) || ...
        numel(lin.maps.ineq_global) ~= 28
    error("stageA:multiday:CanonicalSlices", ...
        "Global duration/bounds or daily binding slices have invalid sizes.");
end
if nnz(lin.objective.gradient(lin.maps.q_day)) ~= 0 || ...
        ~isequal(lin.objective.gradient(lin.maps.q_global), ...
        lin.capacity_parameters.cost)
    error("stageA:multiday:InvestmentObjectiveMultiplicity", ...
        "Investment cost must be applied to global q once and never to q_d.");
end

variables = lin.index.variable_index;
equalities = lin.index.constraint_index( ...
    string(lin.index.constraint_index.constraint_type) == "equality",:);
for dayPosition = 1:numel(config.days)
    day = config.days(dayPosition);
    firstHour = config.start_hour;
    balanceRow = find(equalities.day == day & ...
        equalities.hour == firstHour & ...
        string(equalities.constraint_name) == "hourly_power_balance");
    pch = locate_hour_variable( ...
        variables,day,firstHour,"storage",1,"Pch");
    pdis = locate_hour_variable( ...
        variables,day,firstHour,"storage",1,"Pdis");
    if numel(balanceRow) ~= 1 || lin.A(balanceRow,pch) ~= -1 || ...
            lin.A(balanceRow,pdis) ~= 1
        error("stageA:multiday:PowerBalanceSigns", ...
            "Day %d power balance must use Pdis-Pch.",day);
    end
    for storage = 1:2
        firstLink = locate_soc_link( ...
            lin.index.soc_link_map,day,firstHour,storage);
        firstRow = find(equalities.day == day & ...
            equalities.hour == firstHour & ...
            string(equalities.constraint_name) == "soc_dynamics" & ...
            equalities.asset_id == storage);
        qEnergy = lin.maps.q_day(12+storage,dayPosition);
        if numel(firstRow) ~= 1 || ~isnan(firstLink.predecessor_hour) || ...
                firstLink.predecessor_soc_global_index ~= 0 || ...
                lin.A(firstRow,qEnergy) ~= -0.5
            error("stageA:multiday:InitialSocBoundary", ...
                "Day %d hour 1 must use its independent fixed-half-energy boundary.",day);
        end
    end
    for hour = 2:24
        for storage = 1:2
            link = locate_soc_link( ...
                lin.index.soc_link_map,day,hour,storage);
            row = find(equalities.day == day & equalities.hour == hour & ...
                string(equalities.constraint_name) == "soc_dynamics" & ...
                equalities.asset_id == storage);
            if numel(row) ~= 1 || ...
                    lin.A(row,link.predecessor_soc_global_index) ~= -1
                error("stageA:multiday:InternalSocCoefficient", ...
                    "Day %d hour %d lacks its exact predecessor SOC coefficient.", ...
                    day,hour);
            end
            predecessor = variables(link.predecessor_soc_global_index,:);
            if predecessor.day ~= day || predecessor.hour ~= hour-1
                error("stageA:multiday:CrossDaySocCoupling", ...
                    "The multiday model contains a cross-day SOC coefficient.");
            end
        end
    end
    terminalRows = find(equalities.day == day & ...
        string(equalities.constraint_name) == "terminal_soc");
    if numel(terminalRows) ~= 2 || any(equalities.hour(terminalRows) ~= 24)
        error("stageA:multiday:TerminalSocRows", ...
            "Day %d must close with exactly two SOC rows at hour 24.",day);
    end
end
if any(lin.fixed_zero_map.fixed_value ~= 0) || ...
        any(lin.fixed_zero_map.fixed_direction_value ~= 0)
    error("stageA:multiday:FixedZeroMap", ...
        "Fixed-zero values and directions must be exact numeric zero.");
end
end

function position = locate_day_position(days,day)
position = find(days == day);
if ~isscalar(position)
    error("stageA:multiday:DayLookup", ...
        "Day %d is not unique in the configured day order.",day);
end
end

function link = locate_soc_link(links,day,hour,storage)
mask = links.day == day & links.hour == hour & links.storage_id == storage;
if nnz(mask) ~= 1
    error("stageA:multiday:SocLinkLookup", ...
        "Expected one SOC link for day %d hour %d storage %d; found %d.", ...
        day,hour,storage,nnz(mask));
end
link = links(mask,:);
end

function [predecessor,boundarySource] = common_link_boundary(links)
sources = unique(string(links.boundary_source));
if numel(sources) ~= 1
    error("stageA:multiday:BoundarySource", ...
        "Storage links in one hour must share one boundary source.");
end
boundarySource = sources(1);
values = links.predecessor_hour;
if all(isnan(values))
    predecessor = nan;
elseif all(isfinite(values)) && isscalar(unique(values))
    predecessor = values(1);
else
    error("stageA:multiday:PredecessorHour", ...
        "Storage links in one hour must share one predecessor hour.");
end
end

function globalIndex = locate_hour_variable(variables,day,hour, ...
        assetType,assetId,name)
mask = variables.day == day & variables.hour == hour & ...
    string(variables.asset_type) == string(assetType) & ...
    variables.asset_id == assetId & ...
    string(variables.variable_name) == string(name);
if nnz(mask) ~= 1
    error("stageA:multiday:VariableLookup", ...
        "Expected one %s variable for day %d hour %d asset %d; found %d.", ...
        string(name),day,hour,assetId,nnz(mask));
end
globalIndex = variables.global_index_start(mask);
end

function validate_stage_scope(index,config)
stageId = string(config.stage_id);
if ~ismember(stageId,["stage_A3","stage_A4"]) || ...
        ~isfield(index,"scope") || ~isfield(index.scope,"stage_id") || ...
        string(index.scope.stage_id) ~= stageId
    error("stageA:linearization:StageIndexMismatch", ...
        "Configuration and index must identify the same multiday Stage-A stage.");
end
if ~isequal(reshape(index.scope.days,1,[]),config.days) || ...
        ~isequal(reshape(index.scope.hours,1,[]),config.hours) || ...
        index.scope.is_explicit_window
    error("stageA:linearization:ScopeMismatch", ...
        "The multiday model requires seven formal days, not an explicit window.");
end
end
