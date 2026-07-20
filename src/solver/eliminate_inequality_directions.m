function reduced = eliminate_inequality_directions(lin)
%ELIMINATE_INEQUALITY_DIRECTIONS Perform the exact diagonal elimination.

arguments
    lin (1,1) struct
end

contract = solver_linearization_contract(lin);
if any(contract.l <= 0)
    first = find(contract.l <= 0,1,"first");
    error("stageA1:solver:NonpositiveSlack", ...
        "Inequality elimination failed at row %d because l=%.17g is not positive.", ...
        first, contract.l(first));
end
if any(contract.z <= 0)
    first = find(contract.z <= 0,1,"first");
    error("stageA1:solver:NonpositiveMultiplier", ...
        "Inequality elimination failed at row %d because z=%.17g is not positive.", ...
        first, contract.z(first));
end

theta = contract.z ./ contract.l;
phi = (contract.r_comp - contract.z .* contract.r_ineq) ./ contract.l;
weightedG = spdiags(theta,0,contract.nineq,contract.nineq) * sparse(lin.G);
W = sparse(lin.H) + sparse(lin.G.') * weightedG;
bXi = -contract.r_dual + sparse(lin.G.') * phi;
if any(~isfinite(nonzeros(W))) || any(~isfinite(bXi))
    error("stageA1:solver:EliminationNonfinite", ...
        "Inequality elimination produced NaN or Inf in W or b_xi.");
end

symmetryRelative = norm(W-W.',"fro") / max(1,norm(W,"fro"));
saddle = [W, sparse(lin.A.'); sparse(lin.A), sparse(contract.neq,contract.neq)];
rhs = [bXi; -contract.r_eq];

reduced = struct();
reduced.linearization_identity = contract.identity;
reduced.theta = theta;
reduced.phi = phi;
reduced.W = W;
reduced.b_xi = bXi;
reduced.A = sparse(lin.A);
reduced.saddle = saddle;
reduced.rhs = rhs;
reduced.symmetry_relative = symmetryRelative;
reduced.nnz_W = nnz(W);
reduced.recovery_contract = ...
    "dl=-r_ineq-G*dxi; dz=(-r_comp+z.*r_ineq+z.*(G*dxi))./l";
end
