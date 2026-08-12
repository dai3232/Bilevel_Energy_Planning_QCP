function index = build_canonical_index_framework(data, days, hours, thermalMask, runId, windowSpec)
%BUILD_CANONICAL_INDEX_FRAMEWORK Build the stage-0 canonical index framework.
% This function allocates names and contiguous indices only.  It does not
% assemble objectives, residuals, Jacobians, KKT matrices, or a solver.
% An optional explicit windowSpec lets algorithm-only fixtures place their
% own initial and terminal SOC boundaries without changing the default
% formal-day behavior (initial hour 1, terminal hour 24).

arguments
    data (1,1) struct
    days (1,:) double {mustBeInteger,mustBePositive} = 1
    hours (1,:) double {mustBeInteger,mustBePositive} = 1:24
    thermalMask = []
    runId (1,1) string = "FRAMEWORK"
    windowSpec (1,1) struct = struct()
end

requestedDays = days;
requestedHours = hours;
boundary = normalize_window_spec(windowSpec, requestedDays, requestedHours, data);
if boundary.is_explicit
    days = requestedDays;
    hours = requestedHours;
else
    % Preserve the stage-0/default interface behavior for existing callers.
    days = unique(requestedDays, "stable");
    hours = unique(requestedHours, "stable");
end
assert(all(days <= data.meta.nDays), ...
    "stage0:index:DayOutOfRange", "Requested day exceeds the data horizon.");
assert(all(hours <= data.meta.nHours), ...
    "stage0:index:HourOutOfRange", "Requested hour exceeds the daily horizon.");

if isempty(thermalMask)
    thermalMask = true(data.meta.nDays, data.meta.nHours, data.meta.nThermal);
    solvePass = "pass_1";
else
    assert(isequal(size(thermalMask), ...
        [data.meta.nDays, data.meta.nHours, data.meta.nThermal]), ...
        "stage0:index:ThermalMaskShape", ...
        "thermalMask must be nDays-by-nHours-by-nThermal.");
    thermalMask = logical(thermalMask);
    solvePass = "pass_2";
end

rowCounts = calculate_row_counts(data,days,hours,thermalMask,boundary);
varRows = repmat(empty_variable_row(),rowCounts.variables,1);
conRows = repmat(empty_constraint_row(),rowCounts.constraints,1);
fixedRows = repmat(empty_fixed_row(),rowCounts.fixed,1);
blockRows = repmat(empty_block_row(),rowCounts.blocks,1);
permRows = repmat(empty_permutation_row(),rowCounts.permutations,1);
socLinkRows = repmat(empty_soc_link_row(),rowCounts.soc_links,1);

globalVariable = 0;
globalConstraint = 0;
equalityCanonical = 0;
inequalityCanonical = 0;
fixedCount = 0;
blockCount = 0;
permutationCount = 0;
socLinkCount = 0;
socVariableIndex = zeros(data.meta.nDays,data.meta.nHours, ...
    data.meta.nStorage);
dailyEnergyCapacityIndex = zeros(data.meta.nDays,data.meta.nStorage);

capacityNames = ["QW1","QW2","QW3","QW4","QW5", ...
    "QP1","QP2","QP3","QP4","QP5", ...
    "QS1","QS2","ES1","ES2"];
capacityTypes = [repmat("wind_capacity",1,5), ...
    repmat("solar_capacity",1,5), repmat("storage_power_capacity",1,2), ...
    repmat("storage_energy_capacity",1,2)];
capacityIds = [1:5,1:5,1:2,1:2];
capacityUnits = [repmat("MW",1,12),repmat("MWh",1,2)];

% 1) Global capacity q, strictly 14 dimensional.
globalStart = globalVariable + 1;
for k = 1:numel(capacityNames)
    globalVariable = globalVariable + 1;
    varRows(globalVariable) = make_variable_row(runId, 0, 0, capacityTypes(k), ...
        capacityIds(k), capacityNames(k), capacityUnits(k), ...
        "GLOBAL_CAPACITY", k, globalVariable);
end
globalEnd = globalVariable;

% 2) Daily capacity copies q_d.
dayBlockRanges = struct();
for d = days
    blockId = sprintf("D%03d_CAPACITY", d);
    startIndex = globalVariable + 1;
    for k = 1:numel(capacityNames)
        globalVariable = globalVariable + 1;
        copyName = sprintf("%s_d%03d", capacityNames(k), d);
        varRows(globalVariable) = make_variable_row(runId, d, 0, capacityTypes(k), ...
            capacityIds(k), copyName, capacityUnits(k), blockId, k, ...
            globalVariable);
        if capacityTypes(k)=="storage_energy_capacity"
            dailyEnergyCapacityIndex(d,capacityIds(k)) = globalVariable;
        end
    end
    dayBlockRanges.(sprintf("d%d",d)).variable = [startIndex, globalVariable];
end

% 3) Active hourly variables and exact fixed-zero recovery records.
hourBlockRanges = struct();
for d = days
    for h = hours
        blockId = sprintf("D%03d_H%02d", d, h);
        blockStart = globalVariable + 1;
        localIndex = 0;

        for asset = 1:data.meta.nWind
            if data.timeseries.windAvailability(d,h,asset) == 0
                fixedCount = fixedCount+1;
                fixedRows(fixedCount) = make_fixed_row(runId, solvePass, d, h, ...
                    "wind", asset, "PW", sprintf("PW(%d,%d,%d)",d,asset,h), ...
                    "zero_availability");
            else
                localIndex = localIndex + 1;
                globalVariable = globalVariable + 1;
                varRows(globalVariable) = make_variable_row(runId,d,h,"wind",asset, ...
                    "PW","MW",blockId,localIndex,globalVariable);
            end
        end

        for asset = 1:data.meta.nSolar
            if data.timeseries.solarAvailability(d,h,asset) == 0
                fixedCount = fixedCount+1;
                fixedRows(fixedCount) = make_fixed_row(runId, solvePass, d, h, ...
                    "solar", asset, "PP", sprintf("PP(%d,%d,%d)",d,asset,h), ...
                    "zero_availability");
            else
                localIndex = localIndex + 1;
                globalVariable = globalVariable + 1;
                varRows(globalVariable) = make_variable_row(runId,d,h,"solar",asset, ...
                    "PP","MW",blockId,localIndex,globalVariable);
            end
        end

        for asset = 1:data.meta.nHydro
            localIndex = localIndex + 1;
            globalVariable = globalVariable + 1;
            varRows(globalVariable) = make_variable_row(runId,d,h,"hydro",asset, ...
                "PH","MW",blockId,localIndex,globalVariable);
        end

        for asset = 1:data.meta.nThermal
            if ~thermalMask(d,h,asset)
                fixedCount = fixedCount+1;
                fixedRows(fixedCount) = make_fixed_row(runId, solvePass, d, h, ...
                    "thermal", asset, "PF", sprintf("PF(%d,%d,%d)",d,asset,h), ...
                    "thermal_pass2_mask");
            else
                localIndex = localIndex + 1;
                globalVariable = globalVariable + 1;
                varRows(globalVariable) = make_variable_row(runId,d,h,"thermal",asset, ...
                    "PF","MW",blockId,localIndex,globalVariable);
            end
        end

        storageNames = [repmat("Pch",1,data.meta.nStorage), ...
            repmat("Pdis",1,data.meta.nStorage), ...
            repmat("SOC",1,data.meta.nStorage)];
        storageIds = repmat(1:data.meta.nStorage,1,3);
        storageUnits = [repmat("MW",1,2*data.meta.nStorage), ...
            repmat("MWh",1,data.meta.nStorage)];
        for k = 1:numel(storageNames)
            localIndex = localIndex + 1;
            globalVariable = globalVariable + 1;
            varRows(globalVariable) = make_variable_row(runId,d,h,"storage",storageIds(k), ...
                storageNames(k),storageUnits(k),blockId,localIndex,globalVariable);
            if storageNames(k)=="SOC"
                socVariableIndex(d,h,storageIds(k)) = globalVariable;
            end
        end

        hourBlockRanges.(sprintf("d%d_h%d",d,h)).variable = ...
            [blockStart, globalVariable];
        hourBlockRanges.(sprintf("d%d_h%d",d,h)).dimension = localIndex;
    end
end

% Canonical equality order: duration, daily binding, hourly balance/SOC,
% then terminal SOC rows in the final hour.
durationStart = globalConstraint + 1;
for storage = 1:data.meta.nStorage
    globalConstraint = globalConstraint + 1;
    equalityCanonical = equalityCanonical + 1;
    conRows(globalConstraint) = make_constraint_row(runId, ...
        sprintf("EQ-DURATION-S%02d",storage),"equality",0,0,"storage", ...
        storage,"storage_duration",storage,globalConstraint,"MWh");
end
durationEnd = globalConstraint;

for d = days
    eqStart = globalConstraint + 1;
    for k = 1:numel(capacityNames)
        globalConstraint = globalConstraint + 1;
        equalityCanonical = equalityCanonical + 1;
        conRows(globalConstraint) = make_constraint_row(runId, ...
            sprintf("EQ-QBIND-D%03d-%s",d,capacityNames(k)),"equality",d,0, ...
            capacityTypes(k),capacityIds(k),"daily_capacity_binding",k, ...
            globalConstraint,capacityUnits(k));
    end
    dayBlockRanges.(sprintf("d%d",d)).equality = [eqStart, globalConstraint];

    for h = hours
        windowPosition = find(hours == h, 1, "first");
        [predecessorHour, boundarySource] = soc_predecessor( ...
            boundary, hours, windowPosition, h);
        isTerminalHour = boundary.append_terminal_soc && ...
            h == boundary.terminal_hour;
        localRow = 0;
        hourEqStart = globalConstraint + 1;
        localRow = localRow + 1;
        globalConstraint = globalConstraint + 1;
        equalityCanonical = equalityCanonical + 1;
        constraintRow = make_constraint_row(runId, ...
            sprintf("EQ-BAL-D%03d-H%02d",d,h),"equality",d,h,"system",0, ...
            "hourly_power_balance",localRow,globalConstraint,"MW");
        constraintRow.window_position = windowPosition;
        conRows(globalConstraint) = constraintRow;
        for storage = 1:data.meta.nStorage
            localRow = localRow + 1;
            globalConstraint = globalConstraint + 1;
            equalityCanonical = equalityCanonical + 1;
            constraintRow = make_constraint_row(runId, ...
                sprintf("EQ-SOC-D%03d-H%02d-S%02d",d,h,storage), ...
                "equality",d,h,"storage",storage,"soc_dynamics",localRow, ...
                globalConstraint,"MWh");
            constraintRow.window_position = windowPosition;
            constraintRow.predecessor_hour = predecessorHour;
            constraintRow.boundary_role = char(boundarySource);
            conRows(globalConstraint) = constraintRow;

            currentSocIndex = socVariableIndex(d,h,storage);
            predecessorSocIndex = 0;
            if isfinite(predecessorHour)
                predecessorSocIndex = ...
                    socVariableIndex(d,predecessorHour,storage);
            end
            energyCapacityIndex = dailyEnergyCapacityIndex(d,storage);
            assert(currentSocIndex>0 && energyCapacityIndex>0 && ...
                (~isfinite(predecessorHour) || predecessorSocIndex>0), ...
                "stage0:index:SocLookup", ...
                "The preallocated SOC or daily-energy index is missing.");
            initialFraction = NaN;
            if ~isfinite(predecessorHour)
                initialFraction = data.base.storage.initialSocFraction(storage);
            end
            terminalFraction = NaN;
            if isTerminalHour
                terminalFraction = data.base.storage.initialSocFraction(storage);
            end
            socLinkCount = socLinkCount+1;
            socLinkRows(socLinkCount) = make_soc_link_row(runId, d, h, ...
                windowPosition, storage, currentSocIndex, predecessorHour, ...
                predecessorSocIndex, energyCapacityIndex, boundarySource, ...
                initialFraction, isTerminalHour, terminalFraction);
        end
        if isTerminalHour
            for storage = 1:data.meta.nStorage
                localRow = localRow + 1;
                globalConstraint = globalConstraint + 1;
                equalityCanonical = equalityCanonical + 1;
                if boundary.is_explicit
                    terminalId = sprintf( ...
                        "EQ-SOC-WINDOW-END-D%03d-H%02d-S%02d",d,h,storage);
                else
                    terminalId = sprintf("EQ-SOC-END-D%03d-S%02d",d,storage);
                end
                constraintRow = make_constraint_row(runId, ...
                    terminalId, ...
                    "equality",d,h,"storage",storage,"terminal_soc",localRow, ...
                    globalConstraint,"MWh");
                constraintRow.window_position = windowPosition;
                constraintRow.boundary_role = char(boundary.terminal_role);
                conRows(globalConstraint) = constraintRow;
            end
        end
        hourBlockRanges.(sprintf("d%d_h%d",d,h)).equality = ...
            [hourEqStart, globalConstraint];
    end
end

% Canonical inequalities: global q bounds, then hourly active-variable
% lower/upper bounds. Daily copies intentionally receive no duplicate bounds.
globalBoundStart = globalConstraint + 1;
for k = 1:numel(capacityNames)
    for side = ["lower","upper"]
        globalConstraint = globalConstraint + 1;
        inequalityCanonical = inequalityCanonical + 1;
        conRows(globalConstraint) = make_constraint_row(runId, ...
            sprintf("INEQ-Q-%s-%s",upper(side),capacityNames(k)), ...
            "inequality",0,0,capacityTypes(k),capacityIds(k), ...
            sprintf("global_capacity_%s_bound",side),2*k-(side=="lower"), ...
            globalConstraint,capacityUnits(k));
    end
end
globalBoundEnd = globalConstraint;

hourlyRows = find([varRows.hour] > 0);
for idx = hourlyRows
    row = varRows(idx);
    for side = ["lower","upper"]
        globalConstraint = globalConstraint + 1;
        inequalityCanonical = inequalityCanonical + 1;
        localRow = 2*row.local_index_start-(side=="lower");
        conRows(globalConstraint) = make_constraint_row(runId, ...
            sprintf("INEQ-%s-D%03d-H%02d-%s%02d",upper(side),row.day,row.hour, ...
            row.variable_name,row.asset_id),"inequality",row.day,row.hour, ...
            row.asset_type,row.asset_id,sprintf("%s_%s_bound", ...
            lower(row.variable_name),side),localRow,globalConstraint,row.unit);
    end
end

% Declarative block ranges.
blockCount = blockCount+1;
blockRows(blockCount) = make_block_row(runId,"GLOBAL_CAPACITY",0,0,0, ...
    globalStart,globalEnd,durationStart,durationEnd,globalEnd-globalStart+1);
for d = days
    key = sprintf("d%d",d);
    vr = dayBlockRanges.(key).variable;
    er = dayBlockRanges.(key).equality;
    blockCount = blockCount+1;
    blockRows(blockCount) = make_block_row(runId,sprintf("D%03d_CAPACITY",d),d,0,0, ...
        vr(1),vr(2),er(1),er(2),vr(2)-vr(1)+1);
    for h = hours
        hr = hourBlockRanges.(sprintf("d%d_h%d",d,h));
        blockRow = make_block_row(runId,sprintf("D%03d_H%02d",d,h), ...
            d,h,h,hr.variable(1),hr.variable(2),hr.equality(1), ...
            hr.equality(2),hr.dimension);
        blockRow.window_position = find(hours == h, 1, "first");
        blockRow.terminal_equality_count = ...
            data.meta.nStorage * double(boundary.append_terminal_soc && ...
            h == boundary.terminal_hour);
        blockCount = blockCount+1;
        blockRows(blockCount) = blockRow;
    end
end

% Identity permutation is the stage-0 framework baseline.
for k = 1:numel(varRows)
    permutationCount = permutationCount+1;
    permRows(permutationCount) = make_permutation_row(runId, ...
        "variable",k,k,"variable",varRows(k).variable_name);
end
eqRows = find(strcmp({conRows.constraint_type},"equality"));
for k = 1:numel(eqRows)
    permutationCount = permutationCount+1;
    permRows(permutationCount) = make_permutation_row(runId, ...
        "equality",k,k,"constraint",conRows(eqRows(k)).constraint_id);
end
ineqRows = find(strcmp({conRows.constraint_type},"inequality"));
for k = 1:numel(ineqRows)
    permutationCount = permutationCount+1;
    permRows(permutationCount) = make_permutation_row(runId, ...
        "inequality",k,k,"constraint",conRows(ineqRows(k)).constraint_id);
end

assert(globalVariable==rowCounts.variables && ...
    globalConstraint==rowCounts.constraints && ...
    fixedCount==rowCounts.fixed && blockCount==rowCounts.blocks && ...
    permutationCount==rowCounts.permutations && ...
    socLinkCount==rowCounts.soc_links && ...
    equalityCanonical==rowCounts.equalities && ...
    inequalityCanonical==rowCounts.inequalities, ...
    "stage0:index:PreallocationCount", ...
    "Canonical index row preallocation does not match emitted rows.");

index = struct();
index.version = "1.1-window-aware-framework";
index.model_contract_version = "1.0";
index.scope = struct("days",days,"hours",hours,"solve_pass",solvePass, ...
    "is_explicit_window",boundary.is_explicit, ...
    "window_type",boundary.window_type, ...
    "start_hour",boundary.start_hour, ...
    "terminal_hour",boundary.terminal_hour, ...
    "soc_boundary_mode",boundary.soc_boundary_mode, ...
    "terminal_soc_equality_count",boundary.terminal_soc_equality_count);
index.variable_index = struct2table(varRows);
index.constraint_index = struct2table(conRows);
index.block_index = struct2table(blockRows);
index.fixed_zero_map = struct2table(fixedRows);
index.permutation_map = struct2table(permRows);
index.soc_link_map = struct2table(socLinkRows);
index.counts = struct("variables",globalVariable, ...
    "constraints",globalConstraint,"equalities",equalityCanonical, ...
    "inequalities",inequalityCanonical,"fixed_zero",numel(fixedRows), ...
    "global_capacity_bounds",globalBoundEnd-globalBoundStart+1, ...
    "full_kkt_dimension",globalVariable + equalityCanonical + ...
    2 * inequalityCanonical);
end

function counts = calculate_row_counts(data,days,hours,thermalMask,boundary)
nDays = numel(days);
nHours = numel(hours);
windActive = nnz(data.timeseries.windAvailability(days,hours,:)~=0);
solarActive = nnz(data.timeseries.solarAvailability(days,hours,:)~=0);
thermalActive = nnz(thermalMask(days,hours,:));
alwaysActivePerHour = data.meta.nHydro+3*data.meta.nStorage;
hourlyActive = windActive+solarActive+thermalActive+ ...
    nDays*nHours*alwaysActivePerHour;
possibleAvailabilityRows = nDays*nHours*(data.meta.nWind+ ...
    data.meta.nSolar+data.meta.nThermal);
fixed = possibleAvailabilityRows-windActive-solarActive-thermalActive;
variables = 14+14*nDays+hourlyActive;
equalities = data.meta.nStorage+14*nDays+ ...
    nDays*nHours*(1+data.meta.nStorage)+ ...
    nDays*boundary.terminal_soc_equality_count;
inequalities = 28+2*hourlyActive;
constraints = equalities+inequalities;
blocks = 1+nDays*(1+nHours);
socLinks = nDays*nHours*data.meta.nStorage;
counts = struct("variables",variables,"equalities",equalities, ...
    "inequalities",inequalities,"constraints",constraints, ...
    "fixed",fixed,"blocks",blocks, ...
    "permutations",variables+constraints,"soc_links",socLinks);
end

function row = empty_variable_row()
row = struct("run_id","","model_contract_version","1.0","day",0,"hour",0, ...
    "asset_type","","asset_id",0,"variable_name","","unit","", ...
    "active_flag",true,"fixed_reason","","block_id","", ...
    "local_index_start",0,"local_index_end",0, ...
    "global_index_start",0,"global_index_end",0);
end

function row = make_variable_row(runId,day,hour,assetType,assetId,name,unit,blockId,local,globalIndex)
row = empty_variable_row();
row.run_id = char(runId); row.day = day; row.hour = hour;
row.asset_type = char(assetType); row.asset_id = assetId;
row.variable_name = char(name); row.unit = char(unit); row.block_id = char(blockId);
row.local_index_start = local; row.local_index_end = local;
row.global_index_start = globalIndex; row.global_index_end = globalIndex;
end

function row = empty_constraint_row()
row = struct("run_id","","constraint_id","","constraint_type","", ...
    "day",0,"hour",0,"asset_type","","asset_id",0, ...
    "constraint_name","","active_flag",true,"local_row",0, ...
    "global_row",0,"unit","","window_position",0, ...
    "predecessor_hour",NaN,"boundary_role","");
end

function row = make_constraint_row(runId,id,type,day,hour,assetType,assetId,name,local,globalIndex,unit)
row = empty_constraint_row(); row.run_id = char(runId); row.constraint_id = char(id);
row.constraint_type = char(type); row.day = day; row.hour = hour;
row.asset_type = char(assetType); row.asset_id = assetId;
row.constraint_name = char(name); row.local_row = local;
row.global_row = globalIndex; row.unit = char(unit);
end

function row = empty_fixed_row()
row = struct("run_id","","solve_pass","","day",0,"hour",0, ...
    "asset_type","","asset_id",0,"variable_name","", ...
    "physical_array_index","","fixed_value",0,"fixed_direction_value",0, ...
    "reason","", ...
    "inequality_status","NOT_APPLICABLE_BOTH_BOUNDS");
end

function row = make_fixed_row(runId,solvePass,day,hour,assetType,assetId,name,physical,reason)
row = empty_fixed_row(); row.run_id = char(runId); row.solve_pass = char(solvePass);
row.day = day; row.hour = hour; row.asset_type = char(assetType);
row.asset_id = assetId; row.variable_name = char(name);
row.physical_array_index = char(physical); row.reason = char(reason);
end

function row = empty_block_row()
row = struct("run_id","","block_id","","day",0,"hour_start",0, ...
    "hour_end",0,"variable_start",0,"variable_end",0, ...
    "equality_start",0,"equality_end",0,"dimension",0, ...
    "n_primal",0,"n_equalities",0,"kkt_block_dimension",0, ...
    "window_position",0,"terminal_equality_count",0);
end

function row = make_block_row(runId,id,day,hourStart,hourEnd,varStart,varEnd,eqStart,eqEnd,dimension)
row = empty_block_row(); row.run_id = char(runId); row.block_id = char(id);
row.day = day; row.hour_start = hourStart; row.hour_end = hourEnd;
row.variable_start = varStart; row.variable_end = varEnd;
row.equality_start = eqStart; row.equality_end = eqEnd; row.dimension = dimension;
row.n_primal = dimension;
row.n_equalities = eqEnd - eqStart + 1;
row.kkt_block_dimension = row.n_primal + row.n_equalities;
end

function row = empty_permutation_row()
row = struct("run_id","","space_name","","canonical_index",0, ...
    "solver_index",0,"object_type","","object_name","");
end

function row = make_permutation_row(runId,space,canonical,solver,type,name)
row = empty_permutation_row(); row.run_id = char(runId); row.space_name = char(space);
row.canonical_index = canonical; row.solver_index = solver;
row.object_type = char(type); row.object_name = char(name);
end

function row = empty_soc_link_row()
row = struct("run_id","","day",0,"hour",0,"window_position",0, ...
    "storage_id",0,"current_soc_global_index",0, ...
    "predecessor_hour",NaN,"predecessor_soc_global_index",0, ...
    "energy_capacity_global_index",0,"boundary_source","", ...
    "initial_energy_fraction",NaN,"terminal_equality",false, ...
    "terminal_energy_fraction",NaN);
end

function row = make_soc_link_row(runId,day,hour,windowPosition,storageId, ...
        currentSocIndex,predecessorHour,predecessorSocIndex,energyCapacityIndex, ...
        boundarySource,initialFraction,terminalEquality,terminalFraction)
row = empty_soc_link_row();
row.run_id = char(runId); row.day = day; row.hour = hour;
row.window_position = windowPosition; row.storage_id = storageId;
row.current_soc_global_index = currentSocIndex;
row.predecessor_hour = predecessorHour;
row.predecessor_soc_global_index = predecessorSocIndex;
row.energy_capacity_global_index = energyCapacityIndex;
row.boundary_source = char(boundarySource);
row.initial_energy_fraction = initialFraction;
row.terminal_equality = logical(terminalEquality);
row.terminal_energy_fraction = terminalFraction;
end

function boundary = normalize_window_spec(windowSpec,days,hours,data)
boundary = struct();
boundary.is_explicit = ~isempty(fieldnames(windowSpec));
if ~boundary.is_explicit
    boundary.window_type = "formal_day_default";
    boundary.start_hour = hours(1);
    boundary.terminal_hour = data.meta.nHours;
    boundary.soc_boundary_mode = "formal_daily_fixed_half_energy";
    boundary.append_terminal_soc = any(hours == data.meta.nHours);
    boundary.terminal_soc_equality_count = ...
        data.meta.nStorage * double(boundary.append_terminal_soc);
    boundary.terminal_role = "formal_day_terminal_fixed_half_energy";
    return
end

requiredFields = ["window_type","start_hour","terminal_hour", ...
    "soc_boundary_mode","terminal_soc_equality_count"];
missing = requiredFields(~isfield(windowSpec,cellstr(requiredFields)));
if ~isempty(missing)
    error("stage0:index:WindowSpecMissingField", ...
        "Explicit windowSpec is missing required fields: %s.", ...
        strjoin(missing, ", "));
end

windowType = string(windowSpec.window_type);
boundaryMode = string(windowSpec.soc_boundary_mode);
if ~isscalar(windowType) || windowType ~= "synthetic_closed_test_window"
    error("stage0:index:UnsupportedWindowType", ...
        "Only window_type='synthetic_closed_test_window' is supported.");
end
if ~isscalar(boundaryMode) || boundaryMode ~= "fixed_half_energy"
    error("stage0:index:UnsupportedSocBoundaryMode", ...
        "Synthetic windows require soc_boundary_mode='fixed_half_energy'.");
end
if numel(days) ~= 1 || numel(unique(days)) ~= 1
    error("stage0:index:WindowDayCount", ...
        "A synthetic closed test window must select exactly one day.");
end
if numel(unique(hours)) ~= numel(hours) || any(diff(hours) <= 0)
    error("stage0:index:WindowHoursOrder", ...
        "Explicit window hours must be unique and strictly increasing; they are never reordered.");
end

startHour = double(windowSpec.start_hour);
terminalHour = double(windowSpec.terminal_hour);
terminalCount = double(windowSpec.terminal_soc_equality_count);
if ~isscalar(startHour) || ~isfinite(startHour) || startHour ~= fix(startHour) || ...
        startHour < 1 || startHour > data.meta.nHours
    error("stage0:index:InvalidWindowStart", ...
        "windowSpec.start_hour must be an in-range integer scalar.");
end
if ~isscalar(terminalHour) || ~isfinite(terminalHour) || ...
        terminalHour ~= fix(terminalHour) || terminalHour < startHour || ...
        terminalHour > data.meta.nHours
    error("stage0:index:InvalidWindowTerminal", ...
        "windowSpec.terminal_hour must be an in-range integer not before start_hour.");
end
if hours(1) ~= startHour
    error("stage0:index:WindowStartMismatch", ...
        "The first requested hour must equal windowSpec.start_hour.");
end
if hours(end) ~= terminalHour
    error("stage0:index:WindowTerminalMismatch", ...
        "The last requested hour must equal windowSpec.terminal_hour.");
end
if ~isequal(hours,startHour:terminalHour)
    error("stage0:index:WindowHoursNotContiguous", ...
        "Explicit window hours must equal start_hour:terminal_hour without gaps.");
end
if ~isscalar(terminalCount) || ~isfinite(terminalCount) || ...
        terminalCount ~= data.meta.nStorage
    error("stage0:index:TerminalEqualityCount", ...
        "terminal_soc_equality_count must equal the number of storage units (%d).", ...
        data.meta.nStorage);
end

boundary.window_type = windowType;
boundary.start_hour = startHour;
boundary.terminal_hour = terminalHour;
boundary.soc_boundary_mode = boundaryMode;
boundary.append_terminal_soc = true;
boundary.terminal_soc_equality_count = terminalCount;
boundary.terminal_role = "synthetic_window_terminal_fixed_half_energy";
end

function [predecessorHour,boundarySource] = soc_predecessor( ...
        boundary,hours,windowPosition,hour)
if boundary.is_explicit
    if windowPosition == 1
        predecessorHour = NaN;
        boundarySource = "fixed_half_energy";
    else
        predecessorHour = hours(windowPosition - 1);
        boundarySource = "previous_window_hour";
    end
elseif hour == 1
    predecessorHour = NaN;
    boundarySource = "formal_daily_fixed_half_energy";
else
    predecessorHour = hour - 1;
    boundarySource = "previous_physical_hour";
end
end
