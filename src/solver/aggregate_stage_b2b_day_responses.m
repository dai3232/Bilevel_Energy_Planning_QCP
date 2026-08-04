function aggregation = aggregate_stage_b2b_day_responses(responses,expectedDays)
%AGGREGATE_STAGE_B2B_DAY_RESPONSES Sort and sum daily responses explicitly.
arguments
    responses (:,1) struct
    expectedDays (1,:) double = 14:20
end
assert(numel(responses)==numel(expectedDays), ...
    "stageB2B:aggregation:Count","Exactly seven day responses are required.");
ids = reshape([responses.day_id],1,[]);
assert(isequal(sort(ids),expectedDays) && numel(unique(ids))==numel(ids), ...
    "stageB2B:aggregation:DayIds","Daily response day IDs are invalid.");
[~,order] = sort(ids); sorted = responses(order);
Ssum=sparse(14,14); gammaSum=zeros(14,1);
for k=1:numel(sorted)
    assert(isequal(size(sorted(k).S),[14,14]) && numel(sorted(k).gamma)==14, ...
        "stageB2B:aggregation:Dimension","Day %d response dimension invalid.",sorted(k).day_id);
    Ssum=Ssum+sorted(k).S; gammaSum=gammaSum+sorted(k).gamma(:);
end
identity=sorted(1).linearization_identity;
assert(all(arrayfun(@(x)isequal(x.linearization_identity,identity),sorted)), ...
    "stageB2B:aggregation:Identity","Daily identities differ.");
reverseInput=responses(end:-1:1);
[~,reverseOrder]=sort([reverseInput.day_id]);
reverseSorted=reverseInput(reverseOrder);
Scheck=sparse(14,14); gcheck=zeros(14,1);
for k=1:numel(reverseSorted)
    Scheck=Scheck+reverseSorted(k).S;
    gcheck=gcheck+reverseSorted(k).gamma(:);
end
aggregation=struct("stage_id","stage_B","milestone_id","B-2B", ...
    "linearization_identity",identity,"day_ids_sorted",[sorted.day_id], ...
    "input_order",ids,"sort_order",order,"S_sum",Ssum,"gamma_sum",gammaSum, ...
    "order_invariant_S_relative_error",norm(Scheck-Ssum,"fro")/max(1,norm(Ssum,"fro")), ...
    "order_invariant_gamma_relative_error",norm(gcheck-gammaSum,2)/max(1,norm(gammaSum,2)), ...
    "order_invariant_passed",isequal(Scheck,Ssum)&&isequal(gcheck,gammaSum), ...
    "daily_responses_sorted",sorted, ...
    "accumulation_contract","sort day_id then sum 14,15,16,17,18,19,20");
end
