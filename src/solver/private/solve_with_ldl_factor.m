function [solution, diagnostics] = solve_with_ldl_factor(factor, rhs, label)
%SOLVE_WITH_LDL_FACTOR Reuse one LDL factor for one or many right-hand sides.

arguments
    factor (1,1) struct
    rhs {mustBeNumeric,mustBeReal}
    label (1,1) string
end

assert(size(rhs,1) == factor.dimension, "stageA1:solver:LDLRhsShape", ...
    "%s RHS row count must be %d; found %d.", ...
    label, factor.dimension, size(rhs,1));
assert(all(isfinite(nonzeros(rhs))), "stageA1:solver:LDLRhsNonfinite", ...
    "%s RHS contains NaN or Inf.", label);

lastwarn("");
work = factor.L \ rhs(factor.permutation,:);
work = factor.D \ work;
work = factor.L.' \ work;
[warningMessage, warningId] = lastwarn;
if strlength(string(warningId)) > 0 || strlength(string(warningMessage)) > 0
    error("stageA1:solver:LDLSolveWarning", ...
        "%s emitted warning %s: %s", ...
        label, string(warningId), string(warningMessage));
end

solution = zeros(size(rhs), "like", rhs);
solution(factor.permutation,:) = work;
if any(~isfinite(solution), "all")
    error("stageA1:solver:LDLSolutionNonfinite", ...
        "%s solution contains NaN or Inf.", label);
end

residual = factor.matrix * solution - rhs;
diagnostics = struct();
diagnostics.label = label;
diagnostics.rhs_columns = size(rhs,2);
diagnostics.relative_residual = norm(residual, "fro") / max(1, norm(rhs, "fro"));
diagnostics.max_absolute_residual = max(abs(residual), [], "all");
diagnostics.warning_id = string(warningId);
diagnostics.warning_message = string(warningMessage);
diagnostics.warning_present = false;
end
