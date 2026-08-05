function status = aggregate_stage_a1_status(acceptance)
%AGGREGATE_STAGE_A1_STATUS Map complete A1 gates to one legal terminal state.

assert(istable(acceptance) && height(acceptance) > 0, ...
    "stageA1:acceptance:Empty","Stage A1 acceptance table is empty.");
blocking = acceptance(logical(acceptance.blocking),:);
assert(height(blocking) > 0,"stageA1:acceptance:NoBlockingRows", ...
    "Stage A1 has no blocking acceptance rows.");
rowStatus = string(blocking.status);
assert(~any(rowStatus == "NOT_RUN" | strlength(rowStatus) == 0), ...
    "stageA1:acceptance:Incomplete", ...
    "A terminal Stage A1 status cannot be computed while a gate is NOT_RUN.");
if all(rowStatus == "PASS")
    status = "PASS";
    return
end
externalIds = ismember(string(blocking.test_id), ...
    ["SA1-ENV-001","SA1-DATA-001"]);
if any(rowStatus(externalIds) == "BLOCKED")
    status = "BLOCKED_EXTERNAL";
elseif any(rowStatus == "NEEDS_MODEL_DECISION")
    status = "NEEDS_MODEL_DECISION";
else
    status = "FAIL_RETRYABLE";
end
end
