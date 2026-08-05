function acceptance = set_stage_a2_acceptance_result(acceptance,testId, ...
        status,actualValue,comparison,evidencePath)
%SET_STAGE_A2_ACCEPTANCE_RESULT Update exactly one frozen A2 row.

allowed = ["PASS","FAIL","BLOCKED","NOT_RUN","NEEDS_MODEL_DECISION"];
status = upper(string(status));
assert(isscalar(status) && ismember(status,allowed), ...
    "stageA2:acceptance:InvalidStatus","Invalid A2 row status %s.",status);
row = string(acceptance.test_id)==string(testId);
assert(nnz(row)==1,"stageA2:acceptance:UnknownTestId", ...
    "Expected exactly one Stage A2 row for %s.",string(testId));
acceptance.actual_value(row) = string(actualValue);
acceptance.comparison(row) = string(comparison);
acceptance.status(row) = status;
acceptance.evidence_path(row) = replace(string(evidencePath),'\','/');
acceptance.checked_at(row) = string(datetime('now','TimeZone', ...
    'Asia/Shanghai','Format','yyyy-MM-dd''T''HH:mm:ssXXX'));
end
