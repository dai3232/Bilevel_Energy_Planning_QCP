function reduced = eliminate_stage_b2c_all_inequality_directions(lin)
%ELIMINATE_STAGE_B2C_ALL_INEQUALITY_DIRECTIONS Eliminate all 7304 rows.
%
% This is the experimental Stage B-2C reduction.  Water inequalities use
% the same diagonal elimination as every other inequality; no water eta or
% diag(l_water./z_water) border remains in the reduced unknown vector.

arguments
    lin (1,1) struct
end

contract = rkkt.solver.stage_b2b_linearization_contract(lin);
assert(contract.milestone_id=="B-2C", ...
    "stageB2C:dailyJoint:Milestone", ...
    "The daily-joint experiment requires a B-2C linearization.");

G = sparse(lin.G);
A = sparse(lin.A);
H = sparse(lin.H);
theta = contract.z./contract.l;
phi = (contract.r_comp-contract.z.*contract.r_ineq)./contract.l;
D = spdiags(theta,0,contract.nineq,contract.nineq);
W = H+G.'*(D*G);
bXi = -contract.r_dual+G.'*phi;
saddle = [W,A.';A,sparse(contract.neq,contract.neq)];
rhs = [bXi;-contract.r_eq];

assert(issparse(W) && issparse(saddle) && ...
    all(isfinite(nonzeros(W))) && all(isfinite(bXi)), ...
    "stageB2C:dailyJoint:EliminationFinite", ...
    "Full inequality elimination produced a nonfinite reduced system.");

reduced = struct();
reduced.stage_id = "stage_B";
reduced.milestone_id = "B-2C-DAILY-JOINT-EXPERIMENT";
reduced.linearization_identity = lin.identity;
reduced.nx = contract.nx;
reduced.neq = contract.neq;
reduced.nineq = contract.nineq;
reduced.theta = theta;
reduced.phi = phi;
reduced.W = sparse(W);
reduced.b_xi = bXi;
reduced.A = A;
reduced.saddle = sparse(saddle);
reduced.rhs = rhs;
reduced.water_rows = contract.water_inequality;
reduced.water_theta = theta(contract.water_inequality);
reduced.water_l_over_z = ...
    contract.l(contract.water_inequality)./contract.z(contract.water_inequality);
reduced.symmetry_relative = ...
    norm(W-W.',"fro")/max(1,norm(W,"fro"));
reduced.recovery_contract = ...
    "dl=-r_ineq-G*dx; dz=(-r_comp-z.*dl)./l";
reduced.water_border_retained = false;
reduced.water_eta_retained = false;
reduced.regularization_used = false;
reduced.full_direction_consumed = false;
end
