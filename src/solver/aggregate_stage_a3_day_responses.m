function aggregation = aggregate_stage_a3_day_responses(responses,expectedDays)
%AGGREGATE_STAGE_A3_DAY_RESPONSES Sort by day_id before fixed-order sums.

arguments
    responses (:,1) struct
    expectedDays (1,:) double = 14:20
end

assert(numel(responses)==7,"stageA3:solver:DailyResponseCount", ...
    "A3 aggregation requires exactly seven day responses.");
inputOrder = reshape([responses.day_id],1,[]);
assert(numel(unique(inputOrder))==7 && ...
    isequal(sort(inputOrder),expectedDays), ...
    "stageA3:solver:DailyResponseDayIds", ...
    "Daily response IDs must be exactly %s.",mat2str(expectedDays));
[dayIdsSorted,sortOrder] = sort(inputOrder);
sorted = responses(sortOrder);
[Ssum,gammaSum] = fixed_order_sum(sorted);

reverseInput = responses(end:-1:1);
[~,reverseSort] = sort(reshape([reverseInput.day_id],1,[]));
[Scheck,gammaCheck] = fixed_order_sum(reverseInput(reverseSort));
Srelative = norm(Scheck-Ssum,"fro")/max(1,norm(Ssum,"fro"));
gammaRelative = norm(gammaCheck-gammaSum,2)/max(1,norm(gammaSum,2));
identity = sorted(1).linearization_identity;
for d = 1:7
    assert(isequal(sorted(d).linearization_identity,identity), ...
        "stageA3:solver:LinearizationIdentityMismatch", ...
        "Day %d response identity differs from the shared linearization.", ...
        sorted(d).day_id);
end

aggregation = struct();
aggregation.linearization_identity = identity;
aggregation.day_ids_sorted = dayIdsSorted;
aggregation.input_order = inputOrder;
aggregation.sort_order = sortOrder;
aggregation.S_sum = sparse(Ssum);
aggregation.gamma_sum = gammaSum;
aggregation.daily_responses_sorted = sorted;
aggregation.order_invariant_S_relative_error = Srelative;
aggregation.order_invariant_gamma_relative_error = gammaRelative;
aggregation.order_invariant_passed = Srelative==0 && gammaRelative==0;
aggregation.accumulation_contract = ...
    "sort day_id ascending, then accumulate days 14,15,16,17,18,19,20";
end

function [Ssum,gammaSum] = fixed_order_sum(responses)
Ssum = sparse(14,14);
gammaSum = zeros(14,1);
for d = 1:numel(responses)
    assert(isequal(size(responses(d).S),[14,14]) && ...
        numel(responses(d).c)==14 && ...
        numel(responses(d).beta)==14 && ...
        numel(responses(d).gamma)==14, ...
        "stageA3:solver:DailyResponseDimension", ...
        "Day %d response has an invalid dimension.",responses(d).day_id);
    Ssum = Ssum+responses(d).S;
    gammaSum = gammaSum+responses(d).gamma;
end
end
