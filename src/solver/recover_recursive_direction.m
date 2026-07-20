function recovery = recover_recursive_direction(lin, partition, response, core)
%RECOVER_RECURSIVE_DIRECTION Recover every canonical Newton component.

arguments
    lin (1,1) struct
    partition (1,1) struct
    response (1,1) struct
    core (1,1) struct
end

contract = solver_linearization_contract(lin);
assert(isequal(contract.identity,partition.linearization_identity) && ...
    isequal(contract.identity,response.linearization_identity) && ...
    isequal(contract.identity,core.linearization_identity), ...
    "stageA1:solver:LinearizationIdentityMismatch", ...
    "Recovery inputs do not share one linearization identity.");

deltaQ = core.delta_q;
deltaRho = core.delta_rho;
deltaQDay = deltaQ + response.beta;
deltaPi = response.c - response.S*deltaQDay;

deltaXi = zeros(contract.nx,1);
deltaY = zeros(contract.neq,1);
deltaXi(contract.q_global) = deltaQ;
deltaXi(contract.q_day) = deltaQDay;
deltaY(contract.y_duration) = deltaRho;
deltaY(contract.y_binding) = deltaPi;

nHours = contract.n_hours;
vByHour = cell(nHours,1);
for t = 1:nHours
    v = response.a_by_hour{t} - response.U_by_hour{t}*deltaQDay;
    nxHour = numel(contract.x_by_hour{t});
    neqHour = numel(contract.y_by_hour{t});
    assert(numel(v) == nxHour + neqHour, ...
        "stageA1:solver:HourlyRecoveryDimension", ...
        "Hour %d recovery dimension is inconsistent with its maps.", ...
        contract.hours(t));
    deltaXi(contract.x_by_hour{t}) = v(1:nxHour);
    deltaY(contract.y_by_hour{t}) = v(nxHour+1:end);
    vByHour{t} = v;
end

deltaL = -contract.r_ineq - sparse(lin.G)*deltaXi;
gDelta = sparse(lin.G)*deltaXi;
deltaZ = (-contract.r_comp + contract.z.*contract.r_ineq + ...
    contract.z.*gDelta) ./ contract.l;
if any(~isfinite(deltaXi)) || any(~isfinite(deltaY)) || ...
        any(~isfinite(deltaL)) || any(~isfinite(deltaZ))
    error("stageA1:solver:RecoveryNonfinite", ...
        "Strict reverse recovery produced NaN or Inf.");
end

direction = [deltaXi;deltaY;deltaL;deltaZ];
[fixedZeroCount,fixedZeroMap,fixedZeroValue,mapDirection] = ...
    fixed_zero_evidence(lin.index);
fixedZeroDirection = zeros(fixedZeroCount,1);
if ~isempty(mapDirection) && any(mapDirection ~= fixedZeroDirection)
    error("stageA1:solver:FixedZeroMapDirection", ...
        "Fixed-zero map contains a nonzero prescribed direction.");
end

recovery = struct();
recovery.linearization_identity = contract.identity;
recovery.direction = direction;
recovery.components = struct( ...
    "xi",deltaXi,"y",deltaY,"l",deltaL,"z",deltaZ, ...
    "q",deltaQ,"rho",deltaRho,"q_day",deltaQDay,"pi",deltaPi, ...
    "v_by_hour",{vByHour});
recovery.fixed_zero = struct( ...
    "count",fixedZeroCount, ...
    "map",fixedZeroMap, ...
    "value",fixedZeroValue, ...
    "direction",fixedZeroDirection, ...
    "all_exact_zero",all(fixedZeroValue == 0) && all(fixedZeroDirection == 0), ...
    "inequality_directions_applicable",false(fixedZeroCount,1));
recovery.diagnostics = struct( ...
    "delta_l_formula_residual",norm(deltaL + contract.r_ineq + gDelta,2), ...
    "delta_z_formula_residual",norm(contract.l.*deltaZ + contract.r_comp - ...
        contract.z.*contract.r_ineq - contract.z.*gDelta,2));
end

function [count,map,value,direction] = fixed_zero_evidence(index)
map = [];
count = 0;
if isstruct(index) && isfield(index,"fixed_zero_map")
    map = index.fixed_zero_map;
    if istable(map)
        count = height(map);
    elseif isstruct(map)
        count = numel(map);
    elseif ~isempty(map)
        count = size(map,1);
    end
end
value = zeros(count,1);
direction = zeros(count,1);
if istable(map)
    names = string(map.Properties.VariableNames);
    assert(count==0 || any(names=="fixed_value"), ...
        "stageA1:solver:FixedZeroValueMissing", ...
        "A nonempty fixed-zero map must contain fixed_value.");
    assert(count==0 || any(names=="fixed_direction_value") || ...
        any(names=="fixed_direction"), ...
        "stageA1:solver:FixedZeroDirectionMissing", ...
        "A nonempty fixed-zero map must contain fixed_direction_value.");
    if any(names=="fixed_value"), value = double(map.fixed_value(:)); end
    if any(names=="fixed_direction_value")
        direction = double(map.fixed_direction_value(:));
    elseif any(names=="fixed_direction")
        direction = double(map.fixed_direction(:));
    end
elseif isstruct(map) && count > 0
    if isfield(map,"fixed_value")
        value = reshape(double([map.fixed_value]),[],1);
    end
    if isfield(map,"fixed_direction_value")
        direction = reshape(double([map.fixed_direction_value]),[],1);
    elseif isfield(map,"fixed_direction")
        direction = reshape(double([map.fixed_direction]),[],1);
    else
        error("stageA1:solver:FixedZeroDirectionMissing", ...
            "A nonempty fixed-zero map must contain fixed_direction_value.");
    end
end
assert(numel(value)==count && numel(direction)==count && ...
    all(isfinite(value)) && all(isfinite(direction)), ...
    "stageA1:solver:FixedZeroMapShape", ...
    "Fixed-zero value/direction evidence has an invalid shape or nonfinite entry.");
assert(all(value==0) && all(direction==0), ...
    "stageA1:solver:FixedZeroMapNonzero", ...
    "Fixed-zero map values and directions must be exact numeric zero.");
end
