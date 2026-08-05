function status = aggregate_stage_a3_status(acceptance,options)
%AGGREGATE_STAGE_A3_STATUS Map the frozen gates to a legal terminal state.

arguments
    acceptance table
    options.ExternalBlock (1,1) logical = false
end
assert(height(acceptance)==6 && all(logical(acceptance.blocking)), ...
    "stageA3:acceptance:InvalidInventory", ...
    "A3 terminal status requires all six frozen blocking rows.");
rowStatus = string(acceptance.status);
assert(~any(rowStatus=="NOT_RUN" | strlength(rowStatus)==0), ...
    "stageA3:acceptance:Incomplete", ...
    "A3 terminal status cannot be computed with NOT_RUN rows.");
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
