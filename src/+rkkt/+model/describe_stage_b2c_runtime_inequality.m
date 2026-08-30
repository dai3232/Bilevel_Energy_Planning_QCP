function value = describe_stage_b2c_runtime_inequality(runtime,position)
%DESCRIBE_STAGE_B2C_RUNTIME_INEQUALITY Decode one compact canonical row.

arguments
    runtime (1,1) struct
    position (1,1) double {mustBeInteger,mustBeNonnegative}
end
if position==0
    value = empty_value();
    return
end
map = runtime.constraint_map;
assert(position<=numel(map.kind), ...
    "stageB2C:runtimeInequality:Position", ...
    "The limiting inequality position is outside the runtime map.");
kind = map.kind(position);
side = ["LOWER","UPPER"];
assetTypes = ["wind","solar","hydro","thermal","storage", ...
    "wind_capacity","solar_capacity","storage_power_capacity", ...
    "storage_energy_capacity"];
variableNames = ["PW","PP","PH","PF","Pch","Pdis","SOC"];
capacityNames = ["QW1","QW2","QW3","QW4","QW5", ...
    "QP1","QP2","QP3","QP4","QP5","QS1","QS2","ES1","ES2"];
if kind==1
    capacity = double(map.capacity(position));
    identifier = "INEQ-Q-"+side(map.bound_side(position))+"-"+ ...
        capacityNames(capacity);
elseif kind==2
    variable = variableNames(map.variable(position));
    identifier = compose("INEQ-%s-D%03d-H%02d-%s%02d", ...
        side(map.bound_side(position)),double(map.day(position)), ...
        double(map.hour(position)),variable,double(map.asset_id(position)));
else
    identifier = compose("INEQ-WATER-D%03d-HYDRO%02d-%s", ...
        double(map.day(position)),double(map.asset_id(position)), ...
        side(map.bound_side(position)));
end
value = struct("constraint_id",string(identifier), ...
    "day",double(map.day(position)),"hour",double(map.hour(position)), ...
    "asset_type",assetTypes(map.asset_type(position)), ...
    "asset_id",double(map.asset_id(position)));
end

function value = empty_value()
value = struct("constraint_id","","day",NaN,"hour",NaN, ...
    "asset_type","","asset_id",NaN);
end
