function physical = recover_stage_a_physical_arrays(xi,deltaXi,index,data)
%RECOVER_STAGE_A_PHYSICAL_ARRAYS Restore compact values and directions.
%
% Fixed-zero wind, solar, or thermal variables are written as exact numeric
% zero.  Their removed lower/upper inequality directions remain not
% applicable and are never fabricated.

arguments
    xi (:,1) double
    deltaXi (:,1) double
    index (1,1) struct
    data (1,1) struct
end

variables = index.variable_index;
assert(numel(xi) == height(variables) && numel(deltaXi) == height(variables), ...
    "stageA:recovery:DirectionDimension", ...
    "Compact values and directions must match variable_index.");
days = unique(variables.day(variables.day > 0),'stable').';
hours = unique(variables.hour(variables.hour > 0),'stable').';
nDays = numel(days);
nHours = numel(hours);

physical = struct();
physical.days = days;
physical.hours = hours;
physical.value = allocate_arrays(nDays,nHours,data);
physical.direction = allocate_arrays(nDays,nHours,data);

globalRows = variables.day == 0 & variables.hour == 0;
physical.value.global_capacity = xi(variables.global_index_start(globalRows));
physical.direction.global_capacity = deltaXi(variables.global_index_start(globalRows));
physical.value.daily_capacity = zeros(nDays,14);
physical.direction.daily_capacity = zeros(nDays,14);

for rowNumber = 1:height(variables)
    row = variables(rowNumber,:);
    if row.day <= 0
        continue;
    end
    dayPosition = find(days == row.day,1);
    value = xi(row.global_index_start);
    direction = deltaXi(row.global_index_start);
    if row.hour == 0
        physical.value.daily_capacity(dayPosition,row.local_index_start) = value;
        physical.direction.daily_capacity(dayPosition,row.local_index_start) = direction;
        continue;
    end
    hourPosition = find(hours == row.hour,1);
    field = field_for_variable(string(row.asset_type),string(row.variable_name));
    physical.value.(field)(dayPosition,hourPosition,row.asset_id) = value;
    physical.direction.(field)(dayPosition,hourPosition,row.asset_id) = direction;
end

fixedCount = height(index.fixed_zero_map);
fixedNames = string(index.fixed_zero_map.Properties.VariableNames);
assert(all(ismember(["fixed_value","fixed_direction_value"],fixedNames)), ...
    "stageA:recovery:FixedZeroColumns", ...
    "fixed_zero_map must contain fixed_value and fixed_direction_value.");
assert(all(index.fixed_zero_map.fixed_value==0) && ...
    all(index.fixed_zero_map.fixed_direction_value==0), ...
    "stageA:recovery:FixedZeroMapNonzero", ...
    "Fixed-zero mappings must prescribe exact zero values and directions.");
fixedValueMaximum = 0;
fixedDirectionMaximum = 0;
for rowNumber = 1:fixedCount
    row = index.fixed_zero_map(rowNumber,:);
    dayPosition = find(days == row.day,1);
    hourPosition = find(hours == row.hour,1);
    if isempty(dayPosition) || isempty(hourPosition)
        continue;
    end
    field = field_for_variable(string(row.asset_type),string(row.variable_name));
    physical.value.(field)(dayPosition,hourPosition,row.asset_id) = 0;
    physical.direction.(field)(dayPosition,hourPosition,row.asset_id) = 0;
    fixedValueMaximum = max(fixedValueMaximum, ...
        abs(physical.value.(field)(dayPosition,hourPosition,row.asset_id)));
    fixedDirectionMaximum = max(fixedDirectionMaximum, ...
        abs(physical.direction.(field)(dayPosition,hourPosition,row.asset_id)));
end

physical.fixed_zero_audit = struct( ...
    "count",fixedCount, ...
    "maximum_absolute_value",fixedValueMaximum, ...
    "maximum_absolute_direction",fixedDirectionMaximum, ...
    "values_exact_zero",fixedValueMaximum == 0, ...
    "directions_exact_zero",fixedDirectionMaximum == 0, ...
    "removed_bound_direction_status","NOT_APPLICABLE_BOTH_BOUNDS");
end

function arrays = allocate_arrays(nDays,nHours,data)
arrays = struct( ...
    "wind",zeros(nDays,nHours,data.meta.nWind), ...
    "solar",zeros(nDays,nHours,data.meta.nSolar), ...
    "hydro",zeros(nDays,nHours,data.meta.nHydro), ...
    "thermal",zeros(nDays,nHours,data.meta.nThermal), ...
    "charge",zeros(nDays,nHours,data.meta.nStorage), ...
    "discharge",zeros(nDays,nHours,data.meta.nStorage), ...
    "soc",zeros(nDays,nHours,data.meta.nStorage));
end

function field = field_for_variable(assetType,variableName)
if assetType == "wind" && variableName == "PW"
    field = "wind";
elseif assetType == "solar" && variableName == "PP"
    field = "solar";
elseif assetType == "hydro" && variableName == "PH"
    field = "hydro";
elseif assetType == "thermal" && variableName == "PF"
    field = "thermal";
elseif assetType == "storage" && variableName == "Pch"
    field = "charge";
elseif assetType == "storage" && variableName == "Pdis"
    field = "discharge";
elseif assetType == "storage" && variableName == "SOC"
    field = "soc";
else
    error("stageA:recovery:UnknownVariable", ...
        "Unsupported physical variable %s/%s.",assetType,variableName);
end
end
