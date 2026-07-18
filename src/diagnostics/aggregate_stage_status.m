function status = aggregate_stage_status(acceptance)
%AGGREGATE_STAGE_STATUS Map row-level acceptance to the four terminal states.

blocking = acceptance(logical(acceptance.blocking),:);
rowStatus = string(blocking.status);
if all(rowStatus == "PASS")
    status = "PASS";
    return
end

externalIds = startsWith(string(blocking.test_id),"S0-ENV-") | ...
    string(blocking.test_id) == "S0-DATA-001";
if any(rowStatus(externalIds) == "BLOCKED")
    status = "BLOCKED_EXTERNAL";
elseif any(rowStatus == "NEEDS_MODEL_DECISION")
    status = "NEEDS_MODEL_DECISION";
else
    status = "FAIL_RETRYABLE";
end
end
