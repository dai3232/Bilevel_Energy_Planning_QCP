function acceptance = set_stage_a1_acceptance_result(acceptance,testId, ...
        status,actualValue,comparison,evidencePath)
%SET_STAGE_A1_ACCEPTANCE_RESULT Set exactly one frozen A1 gate row.

allowed = ["PASS","FAIL","BLOCKED","NOT_RUN","NEEDS_MODEL_DECISION"];
status = upper(string(status));
assert(isscalar(status) && ismember(status,allowed), ...
    "stageA1:acceptance:InvalidStatus", ...
    "Invalid Stage A1 row status %s.",status);
row = string(acceptance.test_id) == string(testId);
assert(nnz(row) == 1,"stageA1:acceptance:UnknownTestId", ...
    "Expected exactly one Stage A1 row for %s.",string(testId));
acceptance.actual_value(row) = string(actualValue);
acceptance.comparison(row) = string(comparison);
acceptance.status(row) = status;
acceptance.evidence_path(row) = replace(string(evidencePath),'\','/');
acceptance.checked_at(row) = string(datetime('now', ...
    'TimeZone','Asia/Shanghai','Format','yyyy-MM-dd''T''HH:mm:ssXXX'));
end
