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
scalingUsed = isfield(factor,"scaling_used") && logical(factor.scaling_used);
if scalingUsed
    assert(isfield(factor,"congruence_scale") && ...
        numel(factor.congruence_scale)==factor.dimension, ...
        "stageA4:scaling:FactorScaleMissing", ...
        "%s has no valid congruence scale.",label);
    transformedRhs = factor.congruence_scale .* rhs;
else
    transformedRhs = rhs;
end
work = factor.L \ transformedRhs(factor.permutation,:);
work = factor.D \ work;
work = factor.L.' \ work;
[warningMessage, warningId] = lastwarn;
if strlength(string(warningId)) > 0 || strlength(string(warningMessage)) > 0
    error("stageA1:solver:LDLSolveWarning", ...
        "%s emitted warning %s: %s", ...
        label, string(warningId), string(warningMessage));
end

transformedSolution = zeros(size(rhs), "like", rhs);
transformedSolution(factor.permutation,:) = work;
if scalingUsed
    solution = factor.congruence_scale .* transformedSolution;
else
    solution = transformedSolution;
end
if any(~isfinite(solution), "all")
    error("stageA1:solver:LDLSolutionNonfinite", ...
        "%s solution contains NaN or Inf.", label);
end

rawResidual = factor.matrix*solution-rhs;
if isfield(factor,"factorized_operator")
    if scalingUsed
        factorizationCoordinateResidual = factor.factorized_operator * ...
            transformedSolution-transformedRhs;
        factorizedResidual = factor.factorized_operator_original * ...
            solution-rhs;
        factorizationCoordinateDenominator = ...
            max(1,norm(transformedRhs,"fro"));
    else
        factorizationCoordinateResidual = ...
            factor.factorized_operator*solution-rhs;
        factorizedResidual = factor.factorized_operator*solution-rhs;
        factorizationCoordinateDenominator = max(1,norm(rhs,"fro"));
    end
    rawToFactorizedRelative = ...
        factor.raw_to_factorized_operator_relative;
    actualOperatorAvailable = true;
else
    factorizedResidual = rawResidual;
    factorizationCoordinateResidual = rawResidual;
    factorizationCoordinateDenominator = max(1,norm(rhs,"fro"));
    rawToFactorizedRelative = 0;
    actualOperatorAvailable = false;
end
diagnostics = struct();
diagnostics.label = label;
diagnostics.rhs_columns = size(rhs,2);
diagnostics.relative_residual = ...
    norm(rawResidual,"fro")/max(1,norm(rhs,"fro"));
diagnostics.max_absolute_residual = max(abs(rawResidual),[],"all");
diagnostics.raw_operator_relative_residual = diagnostics.relative_residual;
diagnostics.raw_operator_max_absolute_residual = ...
    diagnostics.max_absolute_residual;
diagnostics.factorized_operator_relative_residual = ...
    norm(factorizedResidual,"fro")/max(1,norm(rhs,"fro"));
diagnostics.factorized_operator_max_absolute_residual = ...
    max(abs(factorizedResidual),[],"all");
diagnostics.factorization_coordinate_relative_residual = ...
    norm(factorizationCoordinateResidual,"fro") / ...
    factorizationCoordinateDenominator;
diagnostics.factorization_coordinate_max_absolute_residual = ...
    max(abs(factorizationCoordinateResidual),[],"all");
diagnostics.raw_to_factorized_operator_relative = ...
    rawToFactorizedRelative;
diagnostics.actual_factorized_operator_available = ...
    actualOperatorAvailable;
diagnostics.actual_factorized_operator_used_for_audit = ...
    actualOperatorAvailable;
diagnostics.warning_id = string(warningId);
diagnostics.warning_message = string(warningMessage);
diagnostics.warning_present = false;
end
