function acceptance = set_stage_a3_acceptance_result(acceptance,testId, ...
        status,actualValue,comparison,evidencePath)
%SET_STAGE_A3_ACCEPTANCE_RESULT Set one frozen acceptance fact.

allowed = ["PASS","FAIL","BLOCKED","NEEDS_MODEL_DECISION"];
testId = string(testId); status = upper(string(status));
assert(isscalar(testId) && nnz(acceptance.test_id==testId)==1, ...
    "stageA3:acceptance:UnknownTestId","Unknown or duplicate test id %s.",testId);
assert(isscalar(status) && ismember(status,allowed), ...
    "stageA3:acceptance:InvalidStatus","Invalid acceptance status %s.",status);
row = find(acceptance.test_id==testId,1);
acceptance.actual_value(row) = string(actualValue);
acceptance.comparison(row) = string(comparison);
acceptance.status(row) = status;
acceptance.evidence_path(row) = replace(string(evidencePath),'\','/');
acceptance.checked_at(row) = string(datetime('now','TimeZone','Asia/Shanghai', ...
    'Format','yyyy-MM-dd''T''HH:mm:ssXXX'));
end
