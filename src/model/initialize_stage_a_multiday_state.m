function state = initialize_stage_a_multiday_state(data,index,config)
%INITIALIZE_STAGE_A_MULTIDAY_STATE Build a deterministic multiday Stage-A point.
%
% This creates one state for one shared linearization. It does not perform
% an interior-point iteration or optimization.

stageId = string(config.stage_id);
if ~ismember(stageId,["stage_A3","stage_A4"])
    error("stageA:state:StageId", ...
        "The multiday initializer supports only stage_A3 and stage_A4.");
end
parameters = stage_a_capacity_parameters(data);
variables = index.variable_index;
constraints = index.constraint_index;
constraintTypes = string(constraints.constraint_type);
nPrimal = height(variables);
nEquality = nnz(constraintTypes == "equality");
nInequality = nnz(constraintTypes == "inequality");

xi = nan(nPrimal,1);
q = (parameters.lower + parameters.upper) / 2;
globalRows = variables(variables.day == 0 & variables.hour == 0,:);
if height(globalRows) ~= 14
        error(error_id(stageId,"GlobalCapacityCount"), ...
        "The global capacity block must contain exactly 14 variables.");
end
xi(globalRows.global_index_start) = q;

for day = config.days
    dailyRows = variables(variables.day == day & variables.hour == 0,:);
    if height(dailyRows) ~= 14
        error(error_id(stageId,"DailyCapacityCount"), ...
            "Day %d must contain exactly 14 capacity-copy variables.",day);
    end
    xi(dailyRows.global_index_start) = q;
end

hourlyRowNumbers = find(variables.hour > 0).';
for rowNumber = hourlyRowNumbers
    row = variables(rowNumber,:);
    day = row.day;
    hour = row.hour;
    asset = row.asset_id;
    name = string(row.variable_name);
    type = string(row.asset_type);
    value = nan;
    if type == "wind"
        upper = data.timeseries.windAvailability(day,hour,asset)*q(asset);
        value = config.initialization.active_wind_solar_fraction_of_upper*upper;
    elseif type == "solar"
        upper = data.timeseries.solarAvailability(day,hour,asset)*q(5+asset);
        value = config.initialization.active_wind_solar_fraction_of_upper*upper;
    elseif type == "hydro"
        upper = data.base.hydro.maxOutputMW(asset);
        value = config.initialization.hydro_thermal_fraction_of_upper*upper;
    elseif type == "thermal"
        upper = data.base.thermal.maxOutputMW(asset);
        value = config.initialization.hydro_thermal_fraction_of_upper*upper;
    elseif type == "storage" && ismember(name,["Pch","Pdis"])
        upper = q(10+asset);
        value = ...
            config.initialization.charge_discharge_fraction_of_power_capacity*upper;
    elseif type == "storage" && name == "SOC"
        value = config.initialization.soc_fraction_of_energy_capacity*q(12+asset);
    end
    if ~(isscalar(value) && isfinite(value) && value > 0)
        error(error_id(stageId,"HourlyInitialization"), ...
            "Could not initialize active variable %s at day %d hour %d.", ...
            name,day,hour);
    end
    xi(row.global_index_start) = value;
end
if any(~isfinite(xi))
    error(error_id(stageId,"IncompletePrimal"), ...
        "The deterministic primal vector contains an uninitialized entry.");
end

state = struct();
state.xi = xi;
state.y = repmat(config.initialization.equality_multipliers,nEquality,1);
state.l = zeros(0,1);
state.z = repmat(config.initialization.inequality_multiplier,nInequality,1);
state.mu = nan;
state.capacity_midpoint = q;
state.stage_id = stageId;
state.initialization_version = stage_token(stageId)+"-deterministic-v1.0";
state.newton_direction_number = 1;
end

function identifier = error_id(stageId,suffix)
identifier = char(stage_token(stageId)+":state:"+string(suffix));
end

function token = stage_token(stageId)
token = erase(string(stageId),"_");
end
