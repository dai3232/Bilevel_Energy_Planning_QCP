function aggregation = aggregateDayResponses(responses,expectedDays)
%AGGREGATEDAYRESPONSES Aggregate daily responses in fixed day order.

arguments
    responses (:,1) struct
    expectedDays (1,:) double = 14:20
end

aggregation = rkkt.solver.aggregate_stage_a_multiday_day_responses( ...
    responses,expectedDays);
end
