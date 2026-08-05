function audit = validate_canonical_index_framework(index)
%VALIDATE_CANONICAL_INDEX_FRAMEWORK Audit gaps, overlaps, and recovery maps.

checks = strings(0,1); actual = strings(0,1); passed = false(0,1);

variableStarts = index.variable_index.global_index_start;
variableEnds = index.variable_index.global_index_end;
variableExpected = (1:height(index.variable_index))';
checks(end+1,1) = "variable_global_contiguous"; %#ok<AGROW>
passed(end+1,1) = isequal(variableStarts,variableExpected) && ...
    isequal(variableEnds,variableExpected); %#ok<AGROW>
actual(end+1,1) = sprintf("first=%d,last=%d,count=%d", ...
    variableStarts(1),variableEnds(end),height(index.variable_index)); %#ok<AGROW>

constraintRows = index.constraint_index.global_row;
constraintExpected = (1:height(index.constraint_index))';
checks(end+1,1) = "constraint_global_contiguous"; %#ok<AGROW>
passed(end+1,1) = isequal(constraintRows,constraintExpected); %#ok<AGROW>
actual(end+1,1) = sprintf("first=%d,last=%d,count=%d", ...
    constraintRows(1),constraintRows(end),height(index.constraint_index)); %#ok<AGROW>

variableKeys = compose("%d|%d|%s|%d|%s",index.variable_index.day, ...
    index.variable_index.hour,string(index.variable_index.asset_type), ...
    index.variable_index.asset_id,string(index.variable_index.variable_name));
checks(end+1,1) = "variable_keys_unique"; %#ok<AGROW>
passed(end+1,1) = numel(unique(variableKeys)) == numel(variableKeys); %#ok<AGROW>
actual(end+1,1) = sprintf("unique=%d,total=%d",numel(unique(variableKeys)),numel(variableKeys)); %#ok<AGROW>

constraintIds = string(index.constraint_index.constraint_id);
checks(end+1,1) = "constraint_ids_unique"; %#ok<AGROW>
passed(end+1,1) = numel(unique(constraintIds)) == numel(constraintIds); %#ok<AGROW>
actual(end+1,1) = sprintf("unique=%d,total=%d",numel(unique(constraintIds)),numel(constraintIds)); %#ok<AGROW>

fixedOk = true;
if ~isempty(index.fixed_zero_map)
    fixedOk = all(index.fixed_zero_map.fixed_value == 0) && ...
        all(index.fixed_zero_map.fixed_direction_value == 0) && ...
        all(string(index.fixed_zero_map.inequality_status) == ...
        "NOT_APPLICABLE_BOTH_BOUNDS");
    for k = 1:height(index.fixed_zero_map)
        f = index.fixed_zero_map(k,:);
        duplicate = index.variable_index.day == f.day & ...
            index.variable_index.hour == f.hour & ...
            string(index.variable_index.asset_type) == string(f.asset_type) & ...
            index.variable_index.asset_id == f.asset_id & ...
            string(index.variable_index.variable_name) == string(f.variable_name);
        fixedOk = fixedOk && ~any(duplicate);
    end
end
checks(end+1,1) = "fixed_zero_exactly_removed"; %#ok<AGROW>
passed(end+1,1) = fixedOk; %#ok<AGROW>
actual(end+1,1) = sprintf("fixed_zero_rows=%d",height(index.fixed_zero_map)); %#ok<AGROW>

spaces = unique(string(index.permutation_map.space_name),"stable");
permOk = true;
for s = spaces'
    rows = index.permutation_map(string(index.permutation_map.space_name)==s,:);
    expected = (1:height(rows))';
    permOk = permOk && isequal(rows.canonical_index,expected) && ...
        isequal(sort(rows.solver_index),expected);
end
checks(end+1,1) = "permutation_bijective"; %#ok<AGROW>
passed(end+1,1) = permOk; %#ok<AGROW>
actual(end+1,1) = strjoin(spaces,","); %#ok<AGROW>

status = repmat("FAIL",numel(checks),1); status(passed) = "PASS";
audit = table(checks,status,actual,passed, ...
    'VariableNames',{'check_id','status','actual_value','passed'});
end
