function status = aggregate_stage_a2_status(acceptance,options)
%AGGREGATE_STAGE_A2_STATUS Map six gates to a legal terminal state.

arguments
    acceptance table
    options.ExternalBlock (1,1) logical = false
end
assert(height(acceptance)==6 && all(logical(acceptance.blocking)), ...
    "stageA2:acceptance:InvalidInventory", ...
    "A2 terminal status requires all six frozen blocking rows.");
rowStatus = string(acceptance.status);
assert(~any(rowStatus=="NOT_RUN" | strlength(rowStatus)==0), ...
    "stageA2:acceptance:Incomplete", ...
    "A2 terminal status cannot be computed with NOT_RUN rows.");
if all(rowStatus=="PASS")
    status = "PASS";
elseif options.ExternalBlock
    status = "BLOCKED_EXTERNAL";
elseif any(rowStatus=="NEEDS_MODEL_DECISION")
    status = "NEEDS_MODEL_DECISION";
else
    status = "FAIL_RETRYABLE";
end
end
