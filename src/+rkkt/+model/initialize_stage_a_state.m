function state = initialize_stage_a_state(data,index,config)
%INITIALIZE_STAGE_A_STATE Build one deterministic Stage-A primal-dual point.
%
% The compact canonical index already excludes every fixed-zero renewable.
% The slack vector is finalized by build_stage_a_linearization from the
% actual inequality values.  This state defines one linearization only and
% is not an authorization to run an interior-point iteration.

parameters = rkkt.model.stage_a_capacity_parameters(data);
variables = index.variable_index;
constraints = index.constraint_index;
constraintTypes = string(constraints.constraint_type);
equalityRows = constraintTypes == "equality";
inequalityRows = constraintTypes == "inequality";
nPrimal = height(variables);
nEquality = nnz(equalityRows);
nInequality = nnz(inequalityRows);

xi = nan(nPrimal,1);
q = (parameters.lower + parameters.upper) / 2;
globalMask = variables.day == 0 & variables.hour == 0;
globalRows = variables(globalMask,:);
assert(height(globalRows) == 14,"stageA:state:GlobalCapacityCount", ...
    "The global capacity block must contain 14 variables.");
xi(globalRows.global_index_start) = q;

for day = config.days
    dayMask = variables.day == day & variables.hour == 0;
    dayRows = variables(dayMask,:);
    assert(height(dayRows) == 14,"stageA:state:DailyCapacityCount", ...
        "Every daily capacity-copy block must contain 14 variables.");
    xi(dayRows.global_index_start) = q;
end

for rowNumber = find(variables.hour > 0).'
    row = variables(rowNumber,:);
    day = row.day;
    hour = row.hour;
    asset = row.asset_id;
    name = string(row.variable_name);
    type = string(row.asset_type);
    value = nan;
    if type == "wind"
        upper = data.timeseries.windAvailability(day,hour,asset) * q(asset);
        value = config.initialization.active_wind_solar_fraction_of_upper * upper;
    elseif type == "solar"
        capacityIndex = 5 + asset;
        upper = data.timeseries.solarAvailability(day,hour,asset) * ...
            q(capacityIndex);
        value = config.initialization.active_wind_solar_fraction_of_upper * upper;
    elseif type == "hydro"
        upper = data.base.hydro.maxOutputMW(asset);
        value = config.initialization.hydro_thermal_fraction_of_upper * upper;
    elseif type == "thermal"
        upper = data.base.thermal.maxOutputMW(asset);
        value = config.initialization.hydro_thermal_fraction_of_upper * upper;
    elseif type == "storage" && ismember(name,["Pch","Pdis"])
        upper = q(10 + asset);
        value = config.initialization.charge_discharge_fraction_of_power_capacity * upper;
    elseif type == "storage" && name == "SOC"
        energy = q(12 + asset);
        value = config.initialization.soc_fraction_of_energy_capacity * energy;
    end
    assert(isscalar(value) && isfinite(value) && value > 0, ...
        "stageA:state:HourlyInitialization", ...
        "Could not initialize active variable %s at day %d hour %d.", ...
        name,day,hour);
    xi(row.global_index_start) = value;
end

assert(all(isfinite(xi)),"stageA:state:IncompletePrimal", ...
    "The deterministic primal vector contains an uninitialized entry.");

state = struct();
state.xi = xi;
state.y = repmat(config.initialization.equality_multipliers,nEquality,1);
state.l = zeros(0,1);
state.z = repmat(config.initialization.inequality_multiplier,nInequality,1);
state.mu = nan;
state.capacity_midpoint = q;
state.stage_id = string(config.stage_id);
state.initialization_version = stage_token(config)+"-deterministic-v1.0";
state.newton_direction_number = 1;
end

function token = stage_token(config)
token = erase(string(config.stage_id),"_");
assert(ismember(token,["stageA1","stageA2"]), ...
    "stageA:state:UnsupportedStage", ...
    "The shared Stage-A initializer currently supports only A1 and A2.");
end
