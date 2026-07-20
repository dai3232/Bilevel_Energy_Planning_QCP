function state = initialize_stage_a1_state(data,index,config)
%INITIALIZE_STAGE_A1_STATE Build the one deterministic primal-dual point.
%
% The slack vector is finalized by build_stage_a1_linearization from the
% actual inequality values.  The returned state is never reused to perform
% an IPM iteration; it defines exactly one Newton linearization point.

parameters = stage_a_capacity_parameters(data);
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
assert(height(globalRows) == 14,"stageA1:state:GlobalCapacityCount", ...
    "The global capacity block must contain 14 variables.");
xi(globalRows.global_index_start) = q;

days = config.days;
for d = days
    dayMask = variables.day == d & variables.hour == 0;
    dayRows = variables(dayMask,:);
    assert(height(dayRows) == 14,"stageA1:state:DailyCapacityCount", ...
        "Every daily capacity-copy block must contain 14 variables.");
    xi(dayRows.global_index_start) = q;
end

for rowNumber = find(variables.hour > 0).'
    row = variables(rowNumber,:);
    d = row.day;
    h = row.hour;
    asset = row.asset_id;
    name = string(row.variable_name);
    type = string(row.asset_type);
    value = nan;
    if type == "wind"
        upper = data.timeseries.windAvailability(d,h,asset) * q(asset);
        value = config.initialization.active_wind_solar_fraction_of_upper * upper;
    elseif type == "solar"
        capacityIndex = 5 + asset;
        upper = data.timeseries.solarAvailability(d,h,asset) * q(capacityIndex);
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
        "stageA1:state:HourlyInitialization", ...
        "Could not initialize active variable %s at day %d hour %d.", ...
        name,d,h);
    xi(row.global_index_start) = value;
end

assert(all(isfinite(xi)),"stageA1:state:IncompletePrimal", ...
    "The deterministic primal vector contains an uninitialized entry.");

state = struct();
state.xi = xi;
state.y = repmat(config.initialization.equality_multipliers,nEquality,1);
state.l = zeros(0,1);
state.z = repmat(config.initialization.inequality_multiplier,nInequality,1);
state.mu = nan;
state.capacity_midpoint = q;
state.initialization_version = "stageA1-deterministic-v1.0";
state.newton_direction_number = 1;
end
