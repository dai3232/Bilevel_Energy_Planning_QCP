function reduced = eliminate_stage_b2b_inequality_directions(lin)
%ELIMINATE_STAGE_B2B_INEQUALITY_DIRECTIONS Eliminate diagonal inequality rows.
%
% The B-2B reduction keeps the eight daily water rows as an explicit
% low-rank border.  All Stage-A rows are eliminated into W_base and
% b_xi_base; the water rows are represented by U, Dinv, and phi.  This
% prevents G_water'*D_water*G_water from being inserted into an hourly
% tridiagonal block while remaining algebraically identical to the full
% diagonal elimination.

arguments
    lin (1,1) struct
end

[nx,neq,ni] = matrix_dimensions(lin);
identity = required_identity(lin);
waterRows = water_row_positions(lin,ni);
baseRows = setdiff((1:ni).',waterRows,'stable');
l = vector_field(lin,'l',ni);
z = vector_field(lin,'z',ni);
rDual = vector_field(lin,'r_dual',nx);
rEq = vector_field(lin,'r_eq',neq);
rIneq = vector_field(lin,'r_ineq',ni);
rComp = vector_field(lin,'r_comp',ni);
assert(all(l>0) && all(z>0), ...
    "stageB2B:elimination:Positivity", ...
    "B-2B inequality elimination requires strictly positive l and z.");

H = sparse(lin.H);
A = sparse(lin.A);
G = sparse(lin.G);

theta = z./l;
phi = (rComp-z.*rIneq)./l;
thetaBase = theta(baseRows);
phiBase = phi(baseRows);
GBase = G(baseRows,:);
% Keep the Lagrangian Hessian supplied by the shared linearization intact.
% It already includes the current z-weighted water Hessians.
WBase = H + GBase.'*(spdiags(thetaBase,0,numel(baseRows),numel(baseRows))*GBase);
bBase = -rDual + GBase.'*phiBase;

thetaWater = theta(waterRows);
phiWater = phi(waterRows);
GWater = G(waterRows,:);
DinvWater = l(waterRows)./z(waterRows);
UCanonical = GWater.';

% Full elimination is retained as an independent algebraic audit.  It is
% never solved here and is not consumed by the recursive route.
WFull = H + G.'*(spdiags(theta,0,ni,ni)*G);
bFull = -rDual + G.'*phi;
fullSaddle = [WFull,A.';A,sparse(neq,neq)];
fullRhs = [bFull;-rEq];

assert(all(isfinite(nonzeros(WBase))) && all(isfinite(bBase)) && ...
    all(isfinite(nonzeros(WFull))) && all(isfinite(bFull)), ...
    "stageB2B:elimination:Nonfinite", ...
    "B-2B elimination produced a nonfinite reduced operator or RHS.");

reduced = struct();
reduced.stage_id = string(get_field_or(lin,'stage_id',"stage_B"));
reduced.milestone_id = "B-2B";
reduced.linearization_identity = identity;
reduced.nx = nx;
reduced.neq = neq;
reduced.nineq = ni;
reduced.water_rows = waterRows;
reduced.base_rows = baseRows;
reduced.theta = theta;
reduced.phi = phi;
reduced.theta_base = thetaBase;
reduced.phi_base = phiBase;
reduced.W_base = sparse(WBase);
reduced.b_xi_base = bBase;
reduced.W = sparse(WFull);
reduced.b_xi = bFull;
reduced.A = A;
reduced.saddle = sparse(fullSaddle);
reduced.rhs = fullRhs;
reduced.symmetry_relative = relative_symmetry(WFull);
waterW = UCanonical*spdiags(thetaWater,0,numel(waterRows), ...
    numel(waterRows))*UCanonical.';
wDifference = WFull-(WBase+waterW);
bDifference = bFull-(bBase+UCanonical*phiWater);
identityTolerance = 64*eps(max(1,norm(bFull,inf)));
reduced.full_elimination_identity = struct( ...
    "W_difference_nnz",nnz(wDifference), ...
    "W_difference_frobenius",norm(wDifference,"fro"), ...
    "b_difference_norm",norm(bDifference,inf), ...
    "tolerance",identityTolerance, ...
    "passed",norm(wDifference,"fro")<=identityTolerance && ...
        norm(bDifference,inf)<=identityTolerance);
reduced.water = struct( ...
    "rows",waterRows, ...
    "theta",thetaWater, ...
    "phi",phiWater, ...
    "Dinv",spdiags(DinvWater,0,numel(waterRows),numel(waterRows)), ...
    "Dinv_diagonal",DinvWater, ...
    "G",GWater, ...
    "U_canonical",UCanonical, ...
    "dimension",numel(waterRows), ...
    "border_variable_definition","eta=delta_z_water");
reduced.recovery_contract = ...
    "dl=-r_ineq-G*dx; dz=(-r_comp-z.*dl)./l";
reduced.recursive_rhs_contract = ...
    "rhs=-r_dual-G'*(D*r_ineq)+G'*(r_comp./l)";
reduced.no_full_direction_consumed = true;
reduced.full_direction_fallback_used = false;
end

function [nx,neq,ni] = matrix_dimensions(lin)
assert(isfield(lin,'H')&&isfield(lin,'A')&&isfield(lin,'G'), ...
    "stageB2B:elimination:MissingMatrices", ...
    "B-2B linearization must contain H, A, and G.");
nx = size(lin.H,1);
neq = size(lin.A,1);
ni = size(lin.G,1);
assert(size(lin.H,2)==nx && isequal(size(lin.A),[neq,nx]) && ...
    size(lin.G,1)==ni && size(lin.G,2)==nx, ...
    "stageB2B:elimination:MatrixShape", ...
    "B-2B linearization matrix dimensions are inconsistent.");
end

function value = required_identity(lin)
assert(isfield(lin,'identity') && isscalar(lin.identity), ...
    "stageB2B:elimination:Identity", ...
    "B-2B linearization identity is missing.");
value = lin.identity;
end

function rows = water_row_positions(lin,ni)
if isfield(lin,'maps') && isfield(lin.maps,'ineq_water')
    rows = double(lin.maps.ineq_water(:));
elseif isfield(lin,'index') && isfield(lin.index,'water_constraint_index')
    rows = double(lin.index.water_constraint_index.inequality_position(:));
elseif isfield(lin,'water_rows')
    rows = double(lin.water_rows(:));
else
    error("stageB2B:elimination:WaterRows", ...
        "The B-2B linearization has no daily-water row map.");
end
assert(~isempty(rows) && all(rows>=1) && all(rows<=ni) && ...
    all(rows==fix(rows)) && numel(unique(rows))==numel(rows), ...
    "stageB2B:elimination:WaterRows", ...
    "Daily-water row positions must be unique positive indices.");
rows = sort(rows);
assert(numel(rows)==56 && isequal(rows,(ni-55:ni).'), ...
    "stageB2B:elimination:WaterRows", ...
    "B-2B water rows must be the final 56 inequality positions.");
end

function value = vector_field(s,name,n)
assert(isfield(s,name),"stageB2B:elimination:MissingVector", ...
    "B-2B linearization is missing %s.",name);
value = double(s.(name)(:));
assert(numel(value)==n && all(isfinite(value)), ...
    "stageB2B:elimination:VectorShape", ...
    "B-2B vector %s must contain %d finite values.",name,n);
end

function value = get_field_or(s,name,default)
if isfield(s,name)
    value = s.(name);
else
    value = default;
end
end

function value = relative_symmetry(A)
value = norm(A-A.',"fro")/max(1,norm(A,"fro"));
end
