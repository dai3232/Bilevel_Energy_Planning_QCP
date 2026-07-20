function factor = factor_symmetric_ldl(matrix, label, symmetryTolerance)
%FACTOR_SYMMETRIC_LDL Factor one small symmetric block without modification.

arguments
    matrix {mustBeNumeric,mustBeReal}
    label (1,1) string
    symmetryTolerance (1,1) double {mustBeNonnegative,mustBeFinite} = 1.0e-12
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

denseDiagnostic = full(matrix); % Small hourly block or 16-by-16 core only.
numericRank = rank(denseDiagnostic);
condition2 = cond(denseDiagnostic, 2);
if numericRank < n || ~isfinite(condition2)
    error("stageA1:solver:LDLRankDeficient", ...
        "%s is rank deficient or has a nonfinite condition number (rank=%d, n=%d, cond2=%.17g).", ...
        label, numericRank, n, condition2);
end

lastwarn("");
[lowerFactor, blockDiagonal, permutation] = ldl(matrix, "vector");
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
    matrix(permutation, permutation), "fro");

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
factor.matrix = matrix;
factor.L = lowerFactor;
factor.D = blockDiagonal;
factor.permutation = permutation(:);
factor.dimension = n;
factor.nnz = nnz(matrix);
factor.symmetry_relative = symmetryRelative;
factor.numeric_rank = numericRank;
factor.condition_2 = condition2;
factor.inertia_positive = inertiaPositive;
factor.inertia_negative = inertiaNegative;
factor.inertia_zero = inertiaZero;
factor.factor_relative_residual = factorResidual;
factor.warning_id = string(warningId);
factor.warning_message = string(warningMessage);
factor.warning_present = false;
end
