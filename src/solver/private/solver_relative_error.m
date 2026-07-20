function value = solver_relative_error(actual, reference, normType)
%SOLVER_RELATIVE_ERROR Stable relative error for vectors or matrices.

if nargin < 3
    normType = "fro";
end
if isvector(actual) && isvector(reference)
    value = norm(actual(:) - reference(:), 2) / max(1, norm(reference(:), 2));
else
    value = norm(actual - reference, char(normType)) / ...
        max(1, norm(reference, char(normType)));
end
end
