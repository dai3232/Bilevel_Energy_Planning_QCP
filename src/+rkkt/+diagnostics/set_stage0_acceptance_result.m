function acceptance = set_stage0_acceptance_result(acceptance,testId,status, ...
        actualValue,comparison,evidencePath)
%SET_STAGE0_ACCEPTANCE_RESULT Set exactly one controlled acceptance row.

allowed = ["PASS","FAIL","BLOCKED","NOT_RUN","NOT_APPLICABLE", ...
    "NEEDS_MODEL_DECISION"];
status = upper(string(status));
if ~isscalar(status) || ~ismember(status,allowed)
    error('stage0:acceptance:InvalidStatus','Invalid row status: %s',status);
end
row = string(acceptance.test_id) == string(testId);
if nnz(row) ~= 1
    error('stage0:acceptance:UnknownTestId', ...
        'Expected exactly one acceptance row for %s.',string(testId));
end
acceptance.actual_value(row) = string(actualValue);
acceptance.comparison(row) = string(comparison);
acceptance.status(row) = status;
acceptance.evidence_path(row) = replace(string(evidencePath),'\','/');
acceptance.checked_at(row) = string(datetime('now','TimeZone','Asia/Shanghai', ...
    'Format','yyyy-MM-dd''T''HH:mm:ssXXX'));
end
