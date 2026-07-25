function [value,present] = stage_a4_r1_test_cache(action,input)
%STAGE_A4_R1_TEST_CACHE Pass one precomputed R1 result into a test process.
%
% This process-local cache prevents the fixed suite from solving another
% 30 Newton systems when the official result was just computed in the same
% MATLAB process.  Standalone test runs still execute the real entry once.

arguments
    action (1,1) string {mustBeMember(action,["set","get","clear"])}
    input (1,1) struct = struct()
end
persistent cached hasValue
if isempty(hasValue)
    cached = struct();
    hasValue = false;
end
switch action
    case "set"
        assert(~isempty(fieldnames(input)), ...
            "stageA4:tests:R1EmptyCache", ...
            "A precomputed R1 test result must be nonempty.");
        cached = input;
        hasValue = true;
    case "clear"
        cached = struct();
        hasValue = false;
end
value = cached;
present = hasValue;
end
