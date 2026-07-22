function aggregation = aggregate_stage_a3_day_responses(responses,expectedDays)
%AGGREGATE_STAGE_A3_DAY_RESPONSES Backward-compatible A3 wrapper.
arguments
    responses (:,1) struct
    expectedDays (1,:) double = 14:20
end
aggregation = aggregate_stage_a_multiday_day_responses(responses,expectedDays);
end
