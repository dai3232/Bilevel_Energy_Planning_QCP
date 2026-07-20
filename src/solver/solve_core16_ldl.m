function core = solve_core16_ldl(partition, response, options)
%SOLVE_CORE16_LDL Solve the 14-capacity plus 2-duration multiplier core.

arguments
    partition (1,1) struct
    response (1,1) struct
    options.SymmetryTolerance (1,1) double {mustBeNonnegative,mustBeFinite} = 1.0e-12
end

assert(isequal(partition.linearization_identity,response.linearization_identity), ...
    "stageA1:solver:LinearizationIdentityMismatch", ...
    "Core inputs do not share one linearization identity.");

matrix = [partition.Q + response.S, partition.R.'; ...
          partition.R, sparse(2,2)];
rhs = [partition.b_q + response.gamma; -partition.r_duration];
assert(isequal(size(matrix),[16,16]) && numel(rhs)==16, ...
    "stageA1:solver:CoreDimension", ...
    "Global core must be exactly 16-by-16.");

try
    factor = factor_symmetric_ldl(matrix,"global_core_16",options.SymmetryTolerance);
    [solution,solveDiagnostics] = solve_with_ldl_factor( ...
        factor,rhs,"global_core_16_rhs");
catch cause
    message = "16-by-16 core failed for q indices 1:14 and duration multiplier " + ...
        "indices 1:2. Cause: %s";
    wrapped = MException("stageA1:solver:Core16Failure", ...
        message,cause.message);
    wrapped = addCause(wrapped,cause);
    throw(wrapped);
end
residual = matrix*solution-rhs;

core = struct();
core.linearization_identity = partition.linearization_identity;
core.matrix = sparse(matrix);
core.rhs = rhs;
core.solution = solution;
core.delta_q = solution(1:14);
core.delta_rho = solution(15:16);
core.factor = factor;
core.diagnostics = struct( ...
    "factor",strip_factor_matrices(factor), ...
    "solve",solveDiagnostics, ...
    "relative_residual",norm(residual,2)/max(1,norm(rhs,2)), ...
    "max_absolute_residual",max(abs(residual)));
end

function diagnostics = strip_factor_matrices(factor)
diagnostics = rmfield(factor,["matrix","L","D"]);
end
