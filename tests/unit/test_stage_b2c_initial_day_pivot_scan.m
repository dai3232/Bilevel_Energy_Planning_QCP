function tests = test_stage_b2c_initial_day_pivot_scan
tests = functiontests(localfunctions);
end

function testRecordsWeakPivotAndContinues(testCase)
blocks = repmat(struct("day_id",0,"matrix",sparse(0,0)),3,1);
blocks(1) = struct("day_id",1,"matrix",sparse(diag([2,-1])));
blocks(2) = struct("day_id",2,"matrix", ...
    sparse([1,1;1,1+eps]));
blocks(3) = struct("day_id",3,"matrix",sparse(diag([3,-2])));

actual = rkkt.diagnostics.scan_stage_b2c_initial_day_pivots(blocks);

verifyEqual(testCase,height(actual),3);
verifyEqual(testCase,actual.status(1),"PASS");
verifyTrue(testCase,actual.would_trigger_current_gate(2));
verifyGreaterThan(testCase,actual.numerical_zero_count(2),0);
verifyEqual(testCase,actual.status(2), ...
    "NUMERICAL_WEAK_PIVOT_RECORDED");
verifyEqual(testCase,actual.status(3),"PASS");
end
