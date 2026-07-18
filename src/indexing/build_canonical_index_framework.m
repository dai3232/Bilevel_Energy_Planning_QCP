function index = build_canonical_index_framework(data, days, hours, thermalMask, runId)
%BUILD_CANONICAL_INDEX_FRAMEWORK Build the stage-0 canonical index framework.
% This function allocates names and contiguous indices only.  It does not
% assemble objectives, residuals, Jacobians, KKT matrices, or a solver.

arguments
    data (1,1) struct
    days (1,:) double {mustBeInteger,mustBePositive} = 1
    hours (1,:) double {mustBeInteger,mustBePositive} = 1:24
    thermalMask = []
    runId (1,1) string = "FRAMEWORK"
end

days = unique(days, "stable");
hours = unique(hours, "stable");
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

varRows = repmat(empty_variable_row(), 0, 1);
conRows = repmat(empty_constraint_row(), 0, 1);
fixedRows = repmat(empty_fixed_row(), 0, 1);
blockRows = repmat(empty_block_row(), 0, 1);
permRows = repmat(empty_permutation_row(), 0, 1);

globalVariable = 0;
globalConstraint = 0;
equalityCanonical = 0;
inequalityCanonical = 0;

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
    varRows(end+1) = make_variable_row(runId, 0, 0, capacityTypes(k), ...
        capacityIds(k), capacityNames(k), capacityUnits(k), ...
        "GLOBAL_CAPACITY", k, globalVariable); %#ok<AGROW>
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
        varRows(end+1) = make_variable_row(runId, d, 0, capacityTypes(k), ...
            capacityIds(k), copyName, capacityUnits(k), blockId, k, ...
            globalVariable); %#ok<AGROW>
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
                fixedRows(end+1) = make_fixed_row(runId, solvePass, d, h, ...
                    "wind", asset, "PW", sprintf("PW(%d,%d,%d)",d,asset,h), ...
                    "zero_availability"); %#ok<AGROW>
            else
                localIndex = localIndex + 1;
                globalVariable = globalVariable + 1;
                varRows(end+1) = make_variable_row(runId,d,h,"wind",asset, ...
                    "PW","MW",blockId,localIndex,globalVariable); %#ok<AGROW>
            end
        end

        for asset = 1:data.meta.nSolar
            if data.timeseries.solarAvailability(d,h,asset) == 0
                fixedRows(end+1) = make_fixed_row(runId, solvePass, d, h, ...
                    "solar", asset, "PP", sprintf("PP(%d,%d,%d)",d,asset,h), ...
                    "zero_availability"); %#ok<AGROW>
            else
                localIndex = localIndex + 1;
                globalVariable = globalVariable + 1;
                varRows(end+1) = make_variable_row(runId,d,h,"solar",asset, ...
                    "PP","MW",blockId,localIndex,globalVariable); %#ok<AGROW>
            end
        end

        for asset = 1:data.meta.nHydro
            localIndex = localIndex + 1;
            globalVariable = globalVariable + 1;
            varRows(end+1) = make_variable_row(runId,d,h,"hydro",asset, ...
                "PH","MW",blockId,localIndex,globalVariable); %#ok<AGROW>
        end

        for asset = 1:data.meta.nThermal
            if ~thermalMask(d,h,asset)
                fixedRows(end+1) = make_fixed_row(runId, solvePass, d, h, ...
                    "thermal", asset, "PF", sprintf("PF(%d,%d,%d)",d,asset,h), ...
                    "thermal_pass2_mask"); %#ok<AGROW>
            else
                localIndex = localIndex + 1;
                globalVariable = globalVariable + 1;
                varRows(end+1) = make_variable_row(runId,d,h,"thermal",asset, ...
                    "PF","MW",blockId,localIndex,globalVariable); %#ok<AGROW>
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
            varRows(end+1) = make_variable_row(runId,d,h,"storage",storageIds(k), ...
                storageNames(k),storageUnits(k),blockId,localIndex,globalVariable); %#ok<AGROW>
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
    conRows(end+1) = make_constraint_row(runId, ...
        sprintf("EQ-DURATION-S%02d",storage),"equality",0,0,"storage", ...
        storage,"storage_duration",storage,globalConstraint,"MWh"); %#ok<AGROW>
end
durationEnd = globalConstraint;

for d = days
    eqStart = globalConstraint + 1;
    for k = 1:numel(capacityNames)
        globalConstraint = globalConstraint + 1;
        equalityCanonical = equalityCanonical + 1;
        conRows(end+1) = make_constraint_row(runId, ...
            sprintf("EQ-QBIND-D%03d-%s",d,capacityNames(k)),"equality",d,0, ...
            capacityTypes(k),capacityIds(k),"daily_capacity_binding",k, ...
            globalConstraint,capacityUnits(k)); %#ok<AGROW>
    end
    dayBlockRanges.(sprintf("d%d",d)).equality = [eqStart, globalConstraint];

    for h = hours
        localRow = 0;
        hourEqStart = globalConstraint + 1;
        localRow = localRow + 1;
        globalConstraint = globalConstraint + 1;
        equalityCanonical = equalityCanonical + 1;
        conRows(end+1) = make_constraint_row(runId, ...
            sprintf("EQ-BAL-D%03d-H%02d",d,h),"equality",d,h,"system",0, ...
            "hourly_power_balance",localRow,globalConstraint,"MW"); %#ok<AGROW>
        for storage = 1:data.meta.nStorage
            localRow = localRow + 1;
            globalConstraint = globalConstraint + 1;
            equalityCanonical = equalityCanonical + 1;
            conRows(end+1) = make_constraint_row(runId, ...
                sprintf("EQ-SOC-D%03d-H%02d-S%02d",d,h,storage), ...
                "equality",d,h,"storage",storage,"soc_dynamics",localRow, ...
                globalConstraint,"MWh"); %#ok<AGROW>
        end
        if h == data.meta.nHours
            for storage = 1:data.meta.nStorage
                localRow = localRow + 1;
                globalConstraint = globalConstraint + 1;
                equalityCanonical = equalityCanonical + 1;
                conRows(end+1) = make_constraint_row(runId, ...
                    sprintf("EQ-SOC-END-D%03d-S%02d",d,storage), ...
                    "equality",d,h,"storage",storage,"terminal_soc",localRow, ...
                    globalConstraint,"MWh"); %#ok<AGROW>
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
        conRows(end+1) = make_constraint_row(runId, ...
            sprintf("INEQ-Q-%s-%s",upper(side),capacityNames(k)), ...
            "inequality",0,0,capacityTypes(k),capacityIds(k), ...
            sprintf("global_capacity_%s_bound",side),2*k-(side=="lower"), ...
            globalConstraint,capacityUnits(k)); %#ok<AGROW>
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
        conRows(end+1) = make_constraint_row(runId, ...
            sprintf("INEQ-%s-D%03d-H%02d-%s%02d",upper(side),row.day,row.hour, ...
            row.variable_name,row.asset_id),"inequality",row.day,row.hour, ...
            row.asset_type,row.asset_id,sprintf("%s_%s_bound", ...
            lower(row.variable_name),side),localRow,globalConstraint,row.unit); %#ok<AGROW>
    end
end

% Declarative block ranges.
blockRows(end+1) = make_block_row(runId,"GLOBAL_CAPACITY",0,0,0, ...
    globalStart,globalEnd,durationStart,durationEnd,globalEnd-globalStart+1); %#ok<AGROW>
for d = days
    key = sprintf("d%d",d);
    vr = dayBlockRanges.(key).variable;
    er = dayBlockRanges.(key).equality;
    blockRows(end+1) = make_block_row(runId,sprintf("D%03d_CAPACITY",d),d,0,0, ...
        vr(1),vr(2),er(1),er(2),vr(2)-vr(1)+1); %#ok<AGROW>
    for h = hours
        hr = hourBlockRanges.(sprintf("d%d_h%d",d,h));
        blockRows(end+1) = make_block_row(runId,sprintf("D%03d_H%02d",d,h), ...
            d,h,h,hr.variable(1),hr.variable(2),hr.equality(1), ...
            hr.equality(2),hr.dimension); %#ok<AGROW>
    end
end

% Identity permutation is the stage-0 framework baseline.
for k = 1:numel(varRows)
    permRows(end+1) = make_permutation_row(runId,"variable",k,k, ...
        "variable",varRows(k).variable_name); %#ok<AGROW>
end
eqRows = find(strcmp({conRows.constraint_type},"equality"));
for k = 1:numel(eqRows)
    permRows(end+1) = make_permutation_row(runId,"equality",k,k, ...
        "constraint",conRows(eqRows(k)).constraint_id); %#ok<AGROW>
end
ineqRows = find(strcmp({conRows.constraint_type},"inequality"));
for k = 1:numel(ineqRows)
    permRows(end+1) = make_permutation_row(runId,"inequality",k,k, ...
        "constraint",conRows(ineqRows(k)).constraint_id); %#ok<AGROW>
end

index = struct();
index.version = "1.0-stage0-framework";
index.model_contract_version = "1.0";
index.scope = struct("days",days,"hours",hours,"solve_pass",solvePass);
index.variable_index = struct2table(varRows);
index.constraint_index = struct2table(conRows);
index.block_index = struct2table(blockRows);
index.fixed_zero_map = struct2table(fixedRows);
index.permutation_map = struct2table(permRows);
index.counts = struct("variables",globalVariable, ...
    "constraints",globalConstraint,"equalities",equalityCanonical, ...
    "inequalities",inequalityCanonical,"fixed_zero",numel(fixedRows), ...
    "global_capacity_bounds",globalBoundEnd-globalBoundStart+1);
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
    "global_row",0,"unit","");
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
    "physical_array_index","","fixed_value",0,"reason","", ...
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
    "equality_start",0,"equality_end",0,"dimension",0);
end

function row = make_block_row(runId,id,day,hourStart,hourEnd,varStart,varEnd,eqStart,eqEnd,dimension)
row = empty_block_row(); row.run_id = char(runId); row.block_id = char(id);
row.day = day; row.hour_start = hourStart; row.hour_end = hourEnd;
row.variable_start = varStart; row.variable_end = varEnd;
row.equality_start = eqStart; row.equality_end = eqEnd; row.dimension = dimension;
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
