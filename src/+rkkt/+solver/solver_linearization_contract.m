function contract = solver_linearization_contract(lin)
%SOLVER_LINEARIZATION_CONTRACT Validate and normalize the shared A1 object.

arguments
    lin (1,1) struct
end

required = ["H","A","G","r_dual","r_eq","r_ineq","r_comp", ...
    "l","z","state","identity","index","maps","layout"];
for name = required
    assert(isfield(lin, name), "stageA1:solver:MissingLinearizationField", ...
        "Shared linearization is missing field '%s'.", name);
end
assert(isfield(lin.state, "xi"), "stageA1:solver:MissingStateXi", ...
    "Shared linearization state must contain state.xi.");
assert(isfield(lin.layout, "hours"), "stageA1:solver:MissingLayoutHours", ...
    "Shared linearization layout must contain layout.hours.");

mapsRequired = ["q_global","q_day","x_by_hour","y_duration", ...
    "y_binding","y_by_hour","ineq_global","ineq_by_hour"];
for name = mapsRequired
    assert(isfield(lin.maps, name), "stageA1:solver:MissingMapField", ...
        "Shared linearization maps are missing field '%s'.", name);
end

nx = size(lin.H, 1);
neq = size(lin.A, 1);
nineq = size(lin.G, 1);
assert(size(lin.H,2) == nx, "stageA1:solver:HessianNotSquare", ...
    "H must be square.");
assert(isequal(size(lin.A), [neq,nx]), "stageA1:solver:EqualityJacobianShape", ...
    "A has an invalid shape.");
assert(isequal(size(lin.G), [nineq,nx]), "stageA1:solver:InequalityJacobianShape", ...
    "G has an invalid shape.");

contract = struct();
contract.nx = nx;
contract.neq = neq;
contract.nineq = nineq;
contract.identity = lin.identity;
contract.hours = normalize_index_vector(lin.layout.hours, "layout.hours").';
contract.n_hours = numel(contract.hours);
assert(contract.n_hours >= 1, "stageA1:solver:EmptyHourLayout", ...
    "At least one hour is required.");
assert(all(diff(contract.hours) == 1), "stageA1:solver:NonContiguousHours", ...
    "layout.hours must be strictly increasing and contiguous.");

contract.q_global = normalize_index_vector(lin.maps.q_global, "maps.q_global");
contract.q_day = normalize_index_vector(lin.maps.q_day, "maps.q_day");
contract.y_duration = normalize_index_vector(lin.maps.y_duration, "maps.y_duration");
contract.y_binding = normalize_index_vector(lin.maps.y_binding, "maps.y_binding");
contract.ineq_global = normalize_index_vector(lin.maps.ineq_global, "maps.ineq_global");
contract.x_by_hour = normalize_hour_slices(lin.maps.x_by_hour, ...
    contract.n_hours, "maps.x_by_hour");
contract.y_by_hour = normalize_hour_slices(lin.maps.y_by_hour, ...
    contract.n_hours, "maps.y_by_hour");
contract.ineq_by_hour = normalize_hour_slices(lin.maps.ineq_by_hour, ...
    contract.n_hours, "maps.ineq_by_hour");

assert(numel(contract.q_global) == 14, "stageA1:solver:GlobalCapacityDimension", ...
    "Global capacity direction must be 14-dimensional.");
assert(numel(contract.q_day) == 14, "stageA1:solver:DayCapacityDimension", ...
    "Daily capacity-copy direction must be 14-dimensional.");
assert(numel(contract.y_duration) == 2, "stageA1:solver:DurationDimension", ...
    "Storage-duration multiplier direction must be 2-dimensional.");
assert(numel(contract.y_binding) == 14, "stageA1:solver:BindingDimension", ...
    "Capacity-binding multiplier direction must be 14-dimensional.");
assert(numel(contract.ineq_global) == 28, "stageA1:solver:GlobalBoundDimension", ...
    "Global capacity bounds must contain 28 inequality rows.");

for t = 1:contract.n_hours
    assert(numel(contract.ineq_by_hour{t}) == 2*numel(contract.x_by_hour{t}), ...
        "stageA1:solver:HourlyBoundDimension", ...
        "Hour %d must contain exactly two inequality rows per active variable.", ...
        contract.hours(t));
end

assert_partition([contract.q_global; contract.q_day; ...
    vertcat(contract.x_by_hour{:})], nx, "primal-variable");
assert_partition([contract.y_duration; contract.y_binding; ...
    vertcat(contract.y_by_hour{:})], neq, "equality");
assert_partition([contract.ineq_global; vertcat(contract.ineq_by_hour{:})], ...
    nineq, "inequality");

contract.r_dual = normalize_numeric_vector(lin.r_dual, nx, "r_dual");
contract.r_eq = normalize_numeric_vector(lin.r_eq, neq, "r_eq");
contract.r_ineq = normalize_numeric_vector(lin.r_ineq, nineq, "r_ineq");
contract.r_comp = normalize_numeric_vector(lin.r_comp, nineq, "r_comp");
contract.l = normalize_numeric_vector(lin.l, nineq, "l");
contract.z = normalize_numeric_vector(lin.z, nineq, "z");
contract.xi = normalize_numeric_vector(lin.state.xi, nx, "state.xi");

assert(isreal(lin.H) && isreal(lin.A) && isreal(lin.G), ...
    "stageA1:solver:ComplexMatrix", "H, A, and G must be real.");
assert(all(isfinite(nonzeros(lin.H))) && all(isfinite(nonzeros(lin.A))) && ...
    all(isfinite(nonzeros(lin.G))), "stageA1:solver:NonfiniteMatrix", ...
    "H, A, and G must contain only finite values.");
end

function slices = normalize_hour_slices(value, count, fieldName)
slices = cell(count,1);
if iscell(value)
    assert(numel(value) == count, "stageA1:solver:HourMapCount", ...
        "%s must contain one slice per configured hour.", fieldName);
    for k = 1:count
        slices{k} = normalize_index_vector(value{k}, sprintf("%s{%d}", fieldName, k));
    end
elseif isstruct(value)
    assert(numel(value) == count, "stageA1:solver:HourMapCount", ...
        "%s must contain one slice per configured hour.", fieldName);
    for k = 1:count
        if isfield(value(k), "indices")
            raw = value(k).indices;
        elseif isfield(value(k), "canonical_indices")
            raw = value(k).canonical_indices;
        elseif isfield(value(k), "index")
            raw = value(k).index;
        else
            error("stageA1:solver:HourMapStructField", ...
                "%s struct entries need indices, canonical_indices, or index.", fieldName);
        end
        slices{k} = normalize_index_vector(raw, sprintf("%s(%d)", fieldName, k));
    end
elseif isnumeric(value)
    if count == 1 && isvector(value)
        slices{1} = normalize_index_vector(value, fieldName);
    elseif size(value,2) == count
        for k = 1:count
            slices{k} = normalize_index_vector(value(:,k), sprintf("%s(:,%d)", fieldName, k));
        end
    elseif size(value,1) == count
        for k = 1:count
            slices{k} = normalize_index_vector(value(k,:), sprintf("%s(%d,:)", fieldName, k));
        end
    else
        error("stageA1:solver:HourMapShape", ...
            "%s numeric layout cannot be mapped to %d hours.", fieldName, count);
    end
else
    error("stageA1:solver:HourMapType", ...
        "%s must be a cell array, struct array, or numeric matrix.", fieldName);
end
end

function indices = normalize_index_vector(value, fieldName)
assert(isnumeric(value) && isreal(value) && isvector(value), ...
    "stageA1:solver:IndexVectorType", "%s must be a real numeric vector.", fieldName);
indices = double(value(:));
assert(~isempty(indices) && all(isfinite(indices)) && ...
    all(indices >= 1) && all(indices == fix(indices)), ...
    "stageA1:solver:IndexVectorValue", ...
    "%s must contain finite positive integer indices.", fieldName);
assert(numel(unique(indices)) == numel(indices), ...
    "stageA1:solver:DuplicateMapIndex", "%s contains duplicate indices.", fieldName);
end

function vector = normalize_numeric_vector(value, expectedLength, fieldName)
assert(isnumeric(value) && isreal(value) && isvector(value), ...
    "stageA1:solver:VectorType", "%s must be a real numeric vector.", fieldName);
vector = double(value(:));
assert(numel(vector) == expectedLength, "stageA1:solver:VectorLength", ...
    "%s must have length %d; found %d.", fieldName, expectedLength, numel(vector));
assert(all(isfinite(vector)), "stageA1:solver:NonfiniteVector", ...
    "%s contains NaN or Inf.", fieldName);
end

function assert_partition(indices, expectedCount, label)
indices = double(indices(:));
assert(numel(indices) == expectedCount && ...
    isequal(sort(indices), (1:expectedCount).'), ...
    "stageA1:solver:MapPartition", ...
    "The %s maps must form a gap-free, overlap-free partition of 1:%d.", ...
    label, expectedCount);
end
