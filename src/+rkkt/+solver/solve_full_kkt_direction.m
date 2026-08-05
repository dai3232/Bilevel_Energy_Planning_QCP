function result = solve_full_kkt_direction(lin)
%SOLVE_FULL_KKT_DIRECTION Compute the sparse direct audit direction once.

arguments
    lin (1,1) struct
end

assembly = rkkt.solver.assemble_full_kkt(lin);
lastwarn("");
direction = assembly.matrix \ assembly.rhs;
[warningMessage, warningId] = lastwarn;
if strlength(string(warningId)) > 0 || strlength(string(warningMessage)) > 0
    error("stageA1:solver:FullKktSolveWarning", ...
        "Sparse full-KKT solve emitted warning %s: %s", ...
        string(warningId),string(warningMessage));
end
if any(~isfinite(direction))
    error("stageA1:solver:FullDirectionNonfinite", ...
        "Sparse full-KKT solve returned NaN or Inf.");
end

residual = assembly.matrix * direction - assembly.rhs;
relativeResidual = norm(residual,2) / max(1,norm(assembly.rhs,2));
[maxAbsoluteResidual,maxResidualRow] = max(abs(residual));

result = struct();
result.method = "sparse_backslash_audit";
result.linearization_identity = assembly.linearization_identity;
result.direction = direction;
result.components = split_canonical_direction(direction, assembly.slices);
result.kkt = assembly;
result.diagnostics = struct( ...
    "relative_residual", relativeResidual, ...
    "max_absolute_residual", maxAbsoluteResidual, ...
    "max_residual_row", maxResidualRow, ...
    "warning_id", string(warningId), ...
    "warning_message", string(warningMessage), ...
    "warning_present",false);
end

function components = split_canonical_direction(direction, slices)
components = struct();
components.xi = direction(slices.xi);
components.y = direction(slices.y);
components.l = direction(slices.l);
components.z = direction(slices.z);
end
