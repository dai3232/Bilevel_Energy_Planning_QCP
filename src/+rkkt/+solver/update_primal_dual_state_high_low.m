function [updated,audit,displacementHigh,displacementLow] = ...
        update_primal_dual_state_high_low( ...
        state,directionHigh,directionLow,alphaPrimal,alphaDual)
%UPDATE_PRIMAL_DUAL_STATE_HIGH_LOW Consume a twofold Newton direction.
%
% The accepted state remains binary64, but each state + alpha*direction
% update is evaluated from the retained high/low direction pair before the
% final rounding.  This prevents a confirmed micro-border direction from
% being collapsed to one double before it is consumed by the IPM update.

arguments
    state (1,1) struct
    directionHigh (1,1) struct
    directionLow (1,1) struct
    alphaPrimal (1,1) double
    alphaDual (1,1) double
end
validate_step(alphaPrimal,"alphaPrimal");
validate_step(alphaDual,"alphaDual");
required = ["xi","y","l","z"];
for name = required
    field = char(name);
    validate_column(state.(field),"state."+name);
    validate_column(directionHigh.(field),"directionHigh."+name);
    validate_column(directionLow.(field),"directionLow."+name);
    assert(numel(state.(field))==numel(directionHigh.(field)) && ...
        numel(state.(field))==numel(directionLow.(field)), ...
        "stageB2C:updateHighLow:Dimension", ...
        "The state and high/low direction field %s must align.",name);
end
assert(all(state.l>0) && all(state.z>0), ...
    "stageB2C:updateHighLow:PositiveInput", ...
    "The input slack and multiplier must be strictly positive.");

updated = state;
updated.xi = scaled_pair_update( ...
    state.xi,alphaPrimal,directionHigh.xi,directionLow.xi);
updated.l = scaled_pair_update( ...
    state.l,alphaPrimal,directionHigh.l,directionLow.l);
updated.y = scaled_pair_update( ...
    state.y,alphaDual,directionHigh.y,directionLow.y);
updated.z = scaled_pair_update( ...
    state.z,alphaDual,directionHigh.z,directionLow.z);
assert(all(isfinite([updated.xi;updated.y;updated.l;updated.z])) && ...
    all(updated.l>0) && all(updated.z>0), ...
    "stageB2C:updateHighLow:Output", ...
    "The high/low update did not produce a finite strictly positive state.");

displacementHigh = struct();
displacementLow = struct();
for k = 1:numel(required)
    field = char(required(k));
    [displacementHigh.(field),displacementLow.(field)] = ...
        two_sum(updated.(field),-state.(field));
end

naive = struct( ...
    "xi",state.xi+alphaPrimal*(directionHigh.xi+directionLow.xi), ...
    "l",state.l+alphaPrimal*(directionHigh.l+directionLow.l), ...
    "y",state.y+alphaDual*(directionHigh.y+directionLow.y), ...
    "z",state.z+alphaDual*(directionHigh.z+directionLow.z));
differences = zeros(numel(required),1);
for k = 1:numel(required)
    field = char(required(k));
    differences(k) = norm(updated.(field)-naive.(field),inf)/ ...
        max([1,norm(updated.(field),inf),norm(naive.(field),inf)]);
end
audit = struct( ...
    "method","twofold_direction_single_round_state_update", ...
    "high_low_direction_consumed",true, ...
    "accepted_displacement_retained_high_low",true, ...
    "state_storage","binary64_after_single_final_rounding", ...
    "component_relative_difference_from_naive",differences, ...
    "maximum_relative_difference_from_naive",max(differences), ...
    "minimum_updated_l",min(updated.l), ...
    "minimum_updated_z",min(updated.z));
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

function validate_step(value,name)
assert(isfinite(value) && value>0 && value<=1, ...
    "stageB2C:updateHighLow:Step", ...
    "%s must be finite and in (0,1].",name);
end

function validate_column(value,name)
assert(isa(value,"double") && isreal(value) && iscolumn(value) && ...
    ~isempty(value) && all(isfinite(value)), ...
    "stageB2C:updateHighLow:Vector", ...
    "%s must be a finite real double column.",name);
end
