function contract = stage_b2b_linearization_contract(lin)
%STAGE_B2B_LINEARIZATION_CONTRACT Validate and normalize the B-2B object.
%
% B-2B keeps the canonical Stage-A variable/equality order and appends the
% 56 daily water inequalities after the 7-day Stage-A inequality prefix.
% This contract deliberately exposes the water rows separately: they are
% daily border rows in the recursive route and must not be silently put into
% an hourly inequality slice.

arguments
    lin (1,1) struct
end

required = ["H","A","G","r_dual","r_eq","r_ineq","r_comp", ...
    "l","z","state","identity","index","maps","layout"];
for name = required
    assert(isfield(lin,char(name)), ...
        "stageB2B:contract:MissingField", ...
        "B-2B linearization is missing field '%s'.",name);
end
assert(string(lin.stage_id) == "stage_B", ...
    "stageB2B:contract:Stage", ...
    "B-2B linearization must have stage_id stage_B.");
if isfield(lin,"milestone_id")
    assert(ismember(string(lin.milestone_id),["B-2B","B2B"]), ...
        "stageB2B:contract:Milestone", ...
        "B-2B linearization must identify milestone B-2B.");
end

nx = size(lin.H,1);
neq = size(lin.A,1);
ni = size(lin.G,1);
assert(size(lin.H,2)==nx && isequal(size(lin.A),[neq,nx]) && ...
    isequal(size(lin.G),[ni,nx]), ...
    "stageB2B:contract:Shape", ...
    "H, A, and G shapes are inconsistent.");
assert(nx==3722 && neq==618 && ni==7304, ...
    "stageB2B:contract:Dimensions", ...
    "B-2B requires 3722 primal, 618 equality, and 7304 inequality rows.");

index = lin.index;
assert(isfield(index,"stage_a_base_index") && ...
    isfield(index,"water_constraint_index"), ...
    "stageB2B:contract:Index", ...
    "B-2B index must preserve the Stage-A base and water row index.");
baseIndex = index.stage_a_base_index;
waterIndex = index.water_constraint_index;
assert(baseIndex.counts.inequalities==7248 && height(waterIndex)==56, ...
    "stageB2B:contract:WaterCount", ...
    "The B-2B inequality prefix/water suffix must be 7248/56.");
waterRows = (7248+(1:56)).';
assert(isequal(waterIndex.inequality_position(:),waterRows), ...
    "stageB2B:contract:WaterPositions", ...
    "Water inequalities must occupy canonical rows 7249:7304.");

days = read_scope_vector(lin.layout,"days",14:20);
hours = read_scope_vector(lin.layout,"hours",1:24);
assert(isequal(days(:).',14:20) && isequal(hours(:).',1:24), ...
    "stageB2B:contract:Scope", ...
    "B-2B requires formal days 14:20 and hours 1:24.");

maps = normalize_maps(lin.maps,index,days,hours,nx,neq,ni);

contract = struct();
contract.stage_id = "stage_B";
if isfield(lin,"milestone_id")
    contract.milestone_id = string(lin.milestone_id);
else
    contract.milestone_id = "B-2B";
end
contract.identity = lin.identity;
contract.nx = nx;
contract.neq = neq;
contract.nineq = ni;
contract.n_base_inequality = 7248;
contract.n_water_inequality = 56;
contract.days = days(:).';
contract.hours = hours(:).';
contract.n_days = numel(days);
contract.n_hours = numel(hours);
contract.base_inequality = (1:7248).';
contract.water_inequality = waterRows;
contract.q_global = maps.q_global;
contract.q_day_by_day = maps.q_day_by_day;
contract.y_duration = maps.y_duration;
contract.y_binding_by_day = maps.y_binding_by_day;
contract.x_by_day_hour = maps.x_by_day_hour;
contract.y_by_day_hour = maps.y_by_day_hour;
contract.ineq_global = maps.ineq_global;
contract.ineq_by_day_hour = maps.ineq_by_day_hour;
contract.water_by_day = maps.water_by_day;
contract.maps = maps;
contract.index = index;
contract.r_dual = normalize_vector(lin.r_dual,nx,"r_dual");
contract.r_eq = normalize_vector(lin.r_eq,neq,"r_eq");
contract.r_ineq = normalize_vector(lin.r_ineq,ni,"r_ineq");
contract.r_comp = normalize_vector(lin.r_comp,ni,"r_comp");
contract.l = normalize_vector(lin.l,ni,"l");
contract.z = normalize_vector(lin.z,ni,"z");
contract.xi = normalize_vector(lin.state.xi,nx,"state.xi");
assert(all(contract.l>0) && all(contract.z>0), ...
    "stageB2B:contract:Positivity", ...
    "All B-2B slacks and inequality multipliers must be positive.");
assert(issparse(lin.H) && issparse(lin.A) && issparse(lin.G) && ...
    all(isfinite(nonzeros(lin.H))) && all(isfinite(nonzeros(lin.A))) && ...
    all(isfinite(nonzeros(lin.G))), ...
    "stageB2B:contract:FiniteSparse", ...
    "B-2B H/A/G must be finite sparse matrices.");
contract.l_water = contract.l(contract.water_inequality);
contract.z_water = contract.z(contract.water_inequality);
contract.l_base = contract.l(contract.base_inequality);
contract.z_base = contract.z(contract.base_inequality);
contract.r_ineq_water = contract.r_ineq(contract.water_inequality);
contract.r_comp_water = contract.r_comp(contract.water_inequality);
contract.r_ineq_base = contract.r_ineq(contract.base_inequality);
contract.r_comp_base = contract.r_comp(contract.base_inequality);
end

function value = read_scope_vector(layout,name,defaultValue)
if isfield(layout,name)
    value = double(layout.(name));
else
    value = double(defaultValue);
end
value = value(:).';
assert(~isempty(value) && all(isfinite(value)) && all(value==fix(value)), ...
    "stageB2B:contract:ScopeVector", ...
    "layout.%s must be a finite integer vector.",name);
end

function maps = normalize_maps(source,index,days,hours,nx,neq,ni)
names = ["q_global","q_day_by_day","y_duration", ...
    "y_binding_by_day","x_by_day_hour","y_by_day_hour", ...
    "ineq_global","ineq_by_day_hour"];
for name = names
    assert(isfield(source,char(name)),"stageB2B:contract:MapField", ...
        "B-2B maps are missing '%s'.",name);
end
maps = struct();
maps.q_global = normalize_index(source.q_global,"q_global");
maps.q_day_by_day = normalize_day(source.q_day_by_day,numel(days), ...
    "q_day_by_day");
maps.y_duration = normalize_index(source.y_duration,"y_duration");
maps.y_binding_by_day = normalize_day(source.y_binding_by_day, ...
    numel(days),"y_binding_by_day");
maps.x_by_day_hour = normalize_day_hour(source.x_by_day_hour, ...
    numel(days),numel(hours),"x_by_day_hour");
maps.y_by_day_hour = normalize_day_hour(source.y_by_day_hour, ...
    numel(days),numel(hours),"y_by_day_hour");
maps.ineq_global = normalize_index(source.ineq_global,"ineq_global");
maps.ineq_by_day_hour = normalize_day_hour(source.ineq_by_day_hour, ...
    numel(days),numel(hours),"ineq_by_day_hour");

% Water rows are deliberately a separate map.  Rebuild by day from the
% persisted canonical table so a caller cannot accidentally include them in
% an hourly two-bound slice.
water = index.water_constraint_index;
maps.water_by_day = cell(numel(days),1);
for d = 1:numel(days)
    rows = find(water.day==days(d));
    assert(numel(rows)==8 && ...
        isequal(water.hydro_id(rows),repelem((1:4).',2,1)) && ...
        isequal(string(water.bound_type(rows)),repmat(["upper";"lower"],4,1)), ...
        "stageB2B:contract:WaterDayMap", ...
        "Day %d water rows must be hydro 1:4 upper/lower.",days(d));
    maps.water_by_day{d} = water.inequality_position(rows);
end

assert_partition([maps.q_global;vertcat(maps.q_day_by_day{:}); ...
    vertcat(maps.x_by_day_hour{:})],nx,"primal");
assert_partition([maps.y_duration;vertcat(maps.y_binding_by_day{:}); ...
    vertcat(maps.y_by_day_hour{:})],neq,"equality");
assert_partition([maps.ineq_global;vertcat(maps.ineq_by_day_hour{:}); ...
    vertcat(maps.water_by_day{:})],ni,"inequality");
assert(numel(maps.q_global)==14 && numel(maps.y_duration)==2 && ...
    numel(maps.ineq_global)==28, ...
    "stageB2B:contract:GlobalSlices", ...
    "Global q/rho/inequality slices have invalid dimensions.");
end

function slices = normalize_day(value,count,name)
assert(iscell(value) && numel(value)==count, ...
    "stageB2B:contract:DayMapShape", ...
    "%s must contain %d day slices.",name,count);
slices = cell(count,1);
for d = 1:count
    slices{d} = normalize_index(value{d},sprintf("%s{%d}",name,d));
end
end

function slices = normalize_day_hour(value,nDays,nHours,name)
assert(iscell(value) && isequal(size(value),[nDays,nHours]), ...
    "stageB2B:contract:DayHourMapShape", ...
    "%s must be a %d-by-%d cell array.",name,nDays,nHours);
slices = cell(nDays,nHours);
for d = 1:nDays
    for t = 1:nHours
        slices{d,t} = normalize_index(value{d,t}, ...
            sprintf("%s{%d,%d}",name,d,t));
    end
end
end

function indices = normalize_index(value,name)
assert(isnumeric(value) && isreal(value) && isvector(value), ...
    "stageB2B:contract:IndexType", ...
    "%s must be a real numeric vector.",name);
indices = double(value(:));
assert(~isempty(indices) && all(isfinite(indices)) && ...
    all(indices>=1) && all(indices==fix(indices)) && ...
    numel(unique(indices))==numel(indices), ...
    "stageB2B:contract:IndexValue", ...
    "%s must contain unique positive integer indices.",name);
end

function value = normalize_vector(raw,n,name)
assert(isnumeric(raw) && isreal(raw) && isvector(raw), ...
    "stageB2B:contract:VectorType", ...
    "%s must be a real vector.",name);
value = double(raw(:));
assert(numel(value)==n && all(isfinite(value)), ...
    "stageB2B:contract:VectorValue", ...
    "%s must contain %d finite values.",name,n);
end

function assert_partition(indices,n,name)
indices = double(indices(:));
assert(numel(indices)==n && isequal(sort(indices),(1:n).'), ...
    "stageB2B:contract:Partition", ...
    "%s maps must partition 1:%d exactly.",name,n);
end
