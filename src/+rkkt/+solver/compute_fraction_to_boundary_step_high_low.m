function step = compute_fraction_to_boundary_step_high_low( ...
        values,directionHigh,directionLow,tau)
%COMPUTE_FRACTION_TO_BOUNDARY_STEP_HIGH_LOW Consume a twofold direction.
%
% This is the same fraction-to-boundary rule as
% compute_fraction_to_boundary_step, evaluated before the retained high/low
% direction is collapsed to one binary64 vector.

validate_positive_column(values,"values");
validate_finite_column(directionHigh,"directionHigh");
validate_finite_column(directionLow,"directionLow");
if numel(values)~=numel(directionHigh) || ...
        numel(values)~=numel(directionLow)
    error("stageB2C:stepHighLow:DimensionMismatch", ...
        "values and both direction parts must have the same dimension.");
end
if ~(isa(tau,"double") && isreal(tau) && isscalar(tau) && ...
        isfinite(tau) && tau>0 && tau<1)
    error("stageB2C:stepHighLow:InvalidTau", ...
        "tau must be a finite real double scalar strictly between zero and one.");
end

[directionHigh,directionLow] = two_sum(directionHigh,directionLow);
assert(all(isfinite(directionHigh)) && all(isfinite(directionLow)), ...
    "stageB2C:stepHighLow:DirectionPair", ...
    "The normalized high/low direction must remain finite.");
negative = directionHigh<0 | (directionHigh==0 & directionLow<0);
negativeIndices = find(negative);
if isempty(negativeIndices)
    rawBoundaryStep = Inf;
    alpha = tau;
    limitingIndex = 0;
    limitingValue = NaN;
    limitingDirectionHigh = NaN;
    limitingDirectionLow = NaN;
else
    count = numel(negativeIndices);
    boundarySteps = zeros(count,1);
    for k = 1:count
        position = negativeIndices(k);
        boundarySteps(k) = divide_positive_double_by_pair( ...
            values(position),-directionHigh(position), ...
            -directionLow(position));
    end
    [rawBoundaryStep,localIndex] = min(boundarySteps);
    limitingIndex = negativeIndices(localIndex);
    limitingValue = values(limitingIndex);
    limitingDirectionHigh = directionHigh(limitingIndex);
    limitingDirectionLow = directionLow(limitingIndex);
    alpha = tau*min(rawBoundaryStep,1);
end
if ~(isfinite(alpha) && alpha>0 && alpha<=1)
    error("stageB2C:stepHighLow:InvalidComputedStep", ...
        "The high/low fraction-to-boundary formula did not produce a valid step.");
end

updatedValues = scaled_pair_update( ...
    values,alpha,directionHigh,directionLow);
if any(~isfinite(updatedValues)) || any(updatedValues<=0)
    error("stageB2C:stepHighLow:NonpositiveTrialValue", ...
        "The high/low fraction-to-boundary step lost strict positivity.");
end

step = struct( ...
    "alpha",alpha,"tau",tau, ...
    "raw_boundary_step",rawBoundaryStep, ...
    "limiting_index",limitingIndex, ...
    "limiting_value",limitingValue, ...
    "limiting_direction",limitingDirectionHigh+limitingDirectionLow, ...
    "limiting_direction_high",limitingDirectionHigh, ...
    "limiting_direction_low",limitingDirectionLow, ...
    "negative_direction_count",nnz(negative), ...
    "step_was_limited",rawBoundaryStep<1, ...
    "minimum_trial_value",min(updatedValues), ...
    "high_low_direction_consumed",true, ...
    "method","twofold_fraction_to_boundary");
end

function quotient = divide_positive_double_by_pair( ...
        numerator,denominatorHigh,denominatorLow)
[denominatorHigh,denominatorLow] = ...
    two_sum(denominatorHigh,denominatorLow);
assert(denominatorHigh>0 || ...
    (denominatorHigh==0 && denominatorLow>0), ...
    "stageB2C:stepHighLow:BoundaryDenominator", ...
    "A boundary denominator must be strictly positive.");
primary = denominatorHigh;
if primary==0
    primary = denominatorLow;
end
quotient = numerator/primary;
if ~isfinite(quotient)
    quotient = Inf;
    return
end
for pass = 1:2
    [firstHigh,firstLow] = two_product(denominatorHigh,quotient);
    [secondHigh,secondLow] = two_product(denominatorLow,quotient);
    [productHigh,productLow] = add_pairs( ...
        firstHigh,firstLow,secondHigh,secondLow);
    [residualHigh,residualLow] = add_pairs( ...
        numerator,0,-productHigh,-productLow);
    quotient = quotient+(residualHigh+residualLow)/primary;
end
assert(isfinite(quotient) && quotient>0, ...
    "stageB2C:stepHighLow:BoundaryQuotient", ...
    "The high/low boundary quotient must be finite and positive.");
end

function value = scaled_pair_update(base,alpha,high,low)
[firstHigh,firstLow] = two_product(alpha,high);
[secondHigh,secondLow] = two_product(alpha,low);
[productHigh,productLow] = add_pairs( ...
    firstHigh,firstLow,secondHigh,secondLow);
[sumHigh,sumLow] = add_pairs( ...
    base,zeros(size(base)),productHigh,productLow);
value = sumHigh+sumLow;
end

function [high,low] = add_pairs(aHigh,aLow,bHigh,bLow)
[sumHigh,sumError] = two_sum(aHigh,bHigh);
[lowHigh,lowError] = two_sum(aLow,bLow);
[sumError,lowCarry] = two_sum(sumError,lowHigh);
[sumHigh,sumCarry] = two_sum(sumHigh,sumError);
low = sumCarry+lowCarry+lowError;
[high,low] = two_sum(sumHigh,low);
end

function [product,errorValue] = two_product(left,right)
product = left.*right;
splitter = 134217729;
leftScaled = splitter*left;
leftHigh = leftScaled-(leftScaled-left);
leftLow = left-leftHigh;
rightScaled = splitter*right;
rightHigh = rightScaled-(rightScaled-right);
rightLow = right-rightHigh;
errorValue = ((leftHigh.*rightHigh-product)+ ...
    leftHigh.*rightLow+leftLow.*rightHigh)+leftLow.*rightLow;
end

function [sumValue,errorValue] = two_sum(left,right)
sumValue = left+right;
rightVirtual = sumValue-left;
leftVirtual = sumValue-rightVirtual;
rightError = right-rightVirtual;
leftError = left-leftVirtual;
errorValue = leftError+rightError;
end

function validate_positive_column(value,name)
validate_finite_column(value,name);
if any(value<=0)
    error("stageB2C:stepHighLow:NonpositiveValues", ...
        "%s must be strictly positive componentwise.",name);
end
end

function validate_finite_column(value,name)
if ~(isa(value,"double") && isreal(value) && ismatrix(value) && ...
        size(value,2)==1 && ~isempty(value))
    error("stageB2C:stepHighLow:InvalidVector", ...
        "%s must be a nonempty real double column vector.",name);
end
if any(~isfinite(value))
    error("stageB2C:stepHighLow:NonfiniteVector", ...
        "%s must contain only finite values.",name);
end
end
