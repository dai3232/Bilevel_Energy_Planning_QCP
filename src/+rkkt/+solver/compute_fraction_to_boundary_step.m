function step = compute_fraction_to_boundary_step(values,direction,tau)
%COMPUTE_FRACTION_TO_BOUNDARY_STEP Preserve strict positivity along a direction.
%
% For every component with direction(i) < 0, the unscaled distance to the
% positivity boundary is -values(i)/direction(i).  The returned step is
% exactly
%
%   tau * min(min_i(-values(i)/direction(i)), 1).
%
% This is the literal primal/dual step formula in Yang et al. equation
% (19).  No line search, centering adjustment, or regularization is
% performed.

validate_positive_column(values,"values");
validate_finite_column(direction,"direction");
if numel(values) ~= numel(direction)
    error("stageA4:step:DimensionMismatch", ...
        "values and direction must contain the same number of entries.");
end
if ~(isa(tau,"double") && isreal(tau) && isscalar(tau) && ...
        isfinite(tau) && tau > 0 && tau < 1)
    error("stageA4:step:InvalidTau", ...
        "tau must be a finite real double scalar strictly between zero and one.");
end

negative = direction < 0;
negativeIndices = find(negative);
if isempty(negativeIndices)
    rawBoundaryStep = Inf;
    alpha = tau;
    limitingIndex = 0;
    limitingValue = NaN;
    limitingDirection = NaN;
else
    boundarySteps = -values(negative)./direction(negative);
    [rawBoundaryStep,localIndex] = min(boundarySteps);
    limitingIndex = negativeIndices(localIndex);
    limitingValue = values(limitingIndex);
    limitingDirection = direction(limitingIndex);
    alpha = tau*min(rawBoundaryStep,1);
end

if ~(isfinite(alpha) && alpha > 0 && alpha <= 1)
    error("stageA4:step:InvalidComputedStep", ...
        "The fraction-to-boundary formula did not produce a finite step in (0,1].");
end
updatedValues = values + alpha*direction;
if any(~isfinite(updatedValues)) || any(updatedValues <= 0)
    error("stageA4:step:NonpositiveTrialValue", ...
        "The computed step does not preserve finite, strictly positive values.");
end

step = struct();
step.alpha = alpha;
step.tau = tau;
step.raw_boundary_step = rawBoundaryStep;
step.limiting_index = limitingIndex;
step.limiting_value = limitingValue;
step.limiting_direction = limitingDirection;
step.negative_direction_count = nnz(negative);
step.step_was_limited = rawBoundaryStep < 1;
step.minimum_trial_value = min(updatedValues);
end

function validate_positive_column(value,name)
validate_finite_column(value,name);
if any(value <= 0)
    error("stageA4:step:NonpositiveValues", ...
        "%s must be strictly positive componentwise.",name);
end
end

function validate_finite_column(value,name)
if ~(isa(value,"double") && isreal(value) && ismatrix(value) && ...
        size(value,2) == 1 && ~isempty(value))
    error("stageA4:step:InvalidVector", ...
        "%s must be a nonempty real double column vector.",name);
end
if any(~isfinite(value))
    error("stageA4:step:NonfiniteVector", ...
        "%s must contain only finite values.",name);
end
end
