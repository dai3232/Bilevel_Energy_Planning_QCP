function reduced = eliminate_stage_a3_inequality_directions(lin)
%ELIMINATE_STAGE_A3_INEQUALITY_DIRECTIONS Exact diagonal elimination.

arguments
    lin (1,1) struct
end

contract = stage_a3_linearization_contract(lin);
if any(contract.l<=0)
    row = find(contract.l<=0,1,"first");
    error("stageA3:solver:NonpositiveSlack", ...
        "Inequality row %d has nonpositive slack %.17g.",row,contract.l(row));
end
if any(contract.z<=0)
    row = find(contract.z<=0,1,"first");
    error("stageA3:solver:NonpositiveMultiplier", ...
        "Inequality row %d has nonpositive multiplier %.17g.", ...
        row,contract.z(row));
end

theta = contract.z./contract.l;
phi = (contract.r_comp-contract.z.*contract.r_ineq)./contract.l;
weightedG = spdiags(theta,0,contract.nineq,contract.nineq)*sparse(lin.G);
W = sparse(lin.H)+sparse(lin.G.')*weightedG;
bXi = -contract.r_dual+sparse(lin.G.')*phi;
assert(all(isfinite(nonzeros(W))) && all(isfinite(bXi)), ...
    "stageA3:solver:EliminationNonfinite", ...
    "Inequality elimination produced NaN or Inf.");

reduced = struct();
reduced.linearization_identity = contract.identity;
reduced.theta = theta;
reduced.phi = phi;
reduced.W = W;
reduced.b_xi = bXi;
reduced.A = sparse(lin.A);
reduced.saddle = [W,sparse(lin.A.'); ...
    sparse(lin.A),sparse(contract.neq,contract.neq)];
reduced.rhs = [bXi;-contract.r_eq];
reduced.symmetry_relative = norm(W-W.',"fro")/max(1,norm(W,"fro"));
reduced.nnz_W = nnz(W);
reduced.recovery_contract = ...
    "dl=-r_ineq-G*dxi; dz=(-r_comp+z.*r_ineq+z.*(G*dxi))./l";
end
