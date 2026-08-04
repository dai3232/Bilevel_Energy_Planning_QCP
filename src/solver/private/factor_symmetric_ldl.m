function factor = factor_symmetric_ldl(matrix, label, symmetryTolerance, options)
%FACTOR_SYMMETRIC_LDL Factor one small symmetric block.
%
% The default path is byte-for-byte equivalent in mathematical behavior to
% the original unscaled route.  The optional congruence path is reserved
% for the independently authorized numerical-stability stress test.  It
% factors D*M*D, solves with the corresponding transformed RHS, and keeps
% M as the immutable residual-audit operator.

arguments
    matrix {mustBeNumeric,mustBeReal}
    label (1,1) string
    symmetryTolerance (1,1) double {mustBeNonnegative,mustBeFinite} = 1.0e-12
    options.UseCongruenceScaling (1,1) logical = false
    options.EquilibrationPasses (1,1) double ...
        {mustBeInteger,mustBeNonnegative} = 8
end

assert(ismatrix(matrix) && size(matrix,1) == size(matrix,2), ...
    "stageA1:solver:LDLNotSquare", "%s is not square.", label);
assert(all(isfinite(nonzeros(matrix))), "stageA1:solver:LDLNonfinite", ...
    "%s contains NaN or Inf.", label);

matrix = sparse(matrix);
n = size(matrix,1);
symmetryRelative = norm(matrix - matrix.', "fro") / max(1, norm(matrix, "fro"));
if symmetryRelative > symmetryTolerance
    error("stageA1:solver:LDLAsymmetry", ...
        "%s symmetry error %.17g exceeds %.17g; no symmetrization was applied.", ...
        label, symmetryRelative, symmetryTolerance);
end

originalMatrix = matrix;
scalingUsed = logical(options.UseCongruenceScaling);
if scalingUsed
    [factorizationMatrix,congruenceScale,scalingTrace] = ...
        equilibrate_symmetric_congruence( ...
        originalMatrix,options.EquilibrationPasses);
else
    factorizationMatrix = originalMatrix;
    congruenceScale = ones(n,1);
    scalingTrace = table();
end
factorizationSymmetryRelative = ...
    norm(factorizationMatrix-factorizationMatrix.',"fro") / ...
    max(1,norm(factorizationMatrix,"fro"));
if factorizationSymmetryRelative > symmetryTolerance
    error("stageA1:solver:LDLScaledAsymmetry", ...
        "%s scaled-factor symmetry error %.17g exceeds %.17g; "+ ...
        "no symmetrization was applied.", ...
        label,factorizationSymmetryRelative,symmetryTolerance);
end

denseDiagnostic = full(factorizationMatrix); % Small hourly/core block only.
numericRank = rank(denseDiagnostic);
condition2 = cond(denseDiagnostic, 2);
if numericRank < n || ~isfinite(condition2)
    error("stageA1:solver:LDLRankDeficient", ...
        "%s is rank deficient or has a nonfinite condition number (rank=%d, n=%d, cond2=%.17g).", ...
        label, numericRank, n, condition2);
end

lastwarn("");
[lowerFactor, blockDiagonal, permutation] = ldl(factorizationMatrix, "vector");
[warningMessage, warningId] = lastwarn;
if strlength(string(warningId)) > 0 || strlength(string(warningMessage)) > 0
    error("stageA1:solver:LDLFactorWarning", ...
        "%s LDL factorization emitted warning %s: %s", ...
        label, string(warningId), string(warningMessage));
end
if any(~isfinite(nonzeros(lowerFactor))) || any(~isfinite(nonzeros(blockDiagonal)))
    error("stageA1:solver:LDLFactorNonfinite", ...
        "%s LDL factors contain NaN or Inf.", label);
end

factorResidual = solver_relative_error( ...
    lowerFactor * blockDiagonal * lowerFactor.', ...
    factorizationMatrix(permutation, permutation), "fro");
factorizedPermuted = lowerFactor*blockDiagonal*lowerFactor.';
factorizedOperator = sparse(n,n);
factorizedOperator(permutation,permutation) = factorizedPermuted;
if scalingUsed
    inverseCongruenceScale = 1 ./ congruenceScale;
    inverseCongruenceDiagonal = ...
        spdiags(inverseCongruenceScale,0,n,n);
    factorizedOperatorOriginal = inverseCongruenceDiagonal * ...
        factorizedOperator * inverseCongruenceDiagonal;
    rawToFactorizedRelative = solver_relative_error( ...
        factorizedOperatorOriginal,originalMatrix,"fro");
else
    factorizedOperatorOriginal = factorizedOperator;
    rawToFactorizedRelative = solver_relative_error( ...
        factorizedOperator,originalMatrix,"fro");
end

densePivot = full(blockDiagonal); % Small LDL pivot matrix only.
eigenvalues = eig(densePivot);
inertiaTolerance = max(1,n) * eps(max(1, norm(densePivot,2)));
inertiaPositive = nnz(eigenvalues > inertiaTolerance);
inertiaNegative = nnz(eigenvalues < -inertiaTolerance);
inertiaZero = n - inertiaPositive - inertiaNegative;
if inertiaZero > 0
    error("stageA1:solver:LDLZeroPivot", ...
        "%s LDL factor contains %d numerical zero pivot eigenvalue(s).", ...
        label, inertiaZero);
end

factor = struct();
factor.label = label;
factor.matrix = originalMatrix;
factor.factorization_matrix = factorizationMatrix;
factor.factorized_operator = factorizedOperator;
factor.factorized_operator_original = factorizedOperatorOriginal;
factor.L = lowerFactor;
factor.D = blockDiagonal;
factor.permutation = permutation(:);
factor.dimension = n;
factor.nnz = nnz(originalMatrix);
factor.symmetry_relative = symmetryRelative;
factor.numeric_rank = numericRank;
factor.condition_2 = condition2;
factor.inertia_positive = inertiaPositive;
factor.inertia_negative = inertiaNegative;
factor.inertia_zero = inertiaZero;
factor.factor_relative_residual = factorResidual;
factor.raw_to_factorized_operator_relative = rawToFactorizedRelative;
factor.actual_factorized_operator_reconstruction_exact = isequal( ...
    factorizedOperator(permutation,permutation),factorizedPermuted);
factor.actual_factorized_operator_available_for_residual_audit = true;
factor.scaling_used = scalingUsed;
factor.congruence_scale = congruenceScale;
factor.equilibration_passes = options.EquilibrationPasses * scalingUsed;
factor.scaling_trace = scalingTrace;
factor.original_numeric_rank = rank(full(originalMatrix));
originalSingularValues = svd(full(originalMatrix));
factor.original_condition_2 = cond(full(originalMatrix),2);
factor.original_smax = originalSingularValues(1);
factor.original_smin = originalSingularValues(end);
factor.factorization_matrix_symmetry_relative = ...
    factorizationSymmetryRelative;
factor.factorization_matrix_relative_to_original = ...
    norm(factorizationMatrix-originalMatrix,"fro") / ...
    max(1,norm(originalMatrix,"fro"));
factor.warning_id = string(warningId);
factor.warning_message = string(warningMessage);
factor.warning_present = false;
end
