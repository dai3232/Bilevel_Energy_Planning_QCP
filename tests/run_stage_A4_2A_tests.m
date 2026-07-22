function evidence = run_stage_A4_2A_tests()
%RUN_STAGE_A4_2A_TESTS Run only the non-formal five-iteration diagnostics.

repoRoot = string(fileparts(fileparts(mfilename("fullpath"))));
addpath(repoRoot);
addpath(genpath(fullfile(repoRoot,"src")));
relativeFile = "tests/integration/test_stage_a4_five_iteration_diagnostic.m";
absolutePath = fullfile(repoRoot,strrep(relativeFile,"/",filesep));
assert(isfile(absolutePath),"stageA4:tests:A42AMissingFile", ...
    "A4-2A integration test file is missing: %s",absolutePath);
suite = matlab.unittest.TestSuite.fromFile(absolutePath);
expectedNames = "test_stage_a4_five_iteration_diagnostic/"+[ ...
    "testExactlyFiveExplicitStateRevisions"
    "testEveryRecursiveDirectionHasIndependentCompleteAudit"
    "testIndependentFractionStepsAndLimitersAreRecorded"
    "testAllResidualsAndComplementarityAreRecorded"
    "testQP5CapacityAndBothBoundsAreRecorded"
    "testUpdatedDailySocBoundaryAuditPassesEveryRound"
    "testFixedZerosAndRecursivePermutationRemainExact"
    "testEveryPhaseTimingIsFiniteAndNonnegative"
    "testRecoverySummaryMatchesFiveObservedSteps"
    "testDiagnosticCreatesNoRunAndDoesNotAdvanceStage"
    "testA4ProductionClosurePassesForbiddenCallScan"];
testNames = string({suite.Name}).';
assert(numel(suite)==11 && isequal(testNames,expectedNames) && ...
    numel(unique(testNames))==11, ...
    "stageA4:tests:A42AInventory", ...
    "The A4-2A suite must contain exactly the 11 explicit tests in order.");
inventory = table(uint32((1:11).'),testNames, ...
    repmat(relativeFile,11,1),'VariableNames', ...
    {'test_order','test_name','source_file'});
fprintf("Fixed A4-2A diagnostic test inventory (%d tests):\n", ...
    height(inventory));
disp(inventory);

runner = matlab.unittest.TestRunner.withTextOutput( ...
    "OutputDetail",matlab.unittest.Verbosity.Detailed);
raw = runner.run(suite);
rawNames = string({raw.Name}).';
passed = logical([raw.Passed]).';
failed = logical([raw.Failed]).';
incomplete = logical([raw.Incomplete]).';
durationSeconds = zeros(numel(raw),1);
for testIndex = 1:numel(raw)
    duration = raw(testIndex).Duration;
    if isduration(duration)
        durationSeconds(testIndex) = seconds(duration);
    else
        durationSeconds(testIndex) = double(duration);
    end
end
assert(numel(raw)==11 && isequal(rawNames,testNames), ...
    "stageA4:tests:A42AResultIdentity", ...
    "A4-2A result identity/order differs from its fixed inventory.");
results = table(rawNames,passed,failed,incomplete,durationSeconds, ...
    'VariableNames',{'test_name','passed','failed','incomplete', ...
    'duration_seconds'});
summary = struct("test_total",height(results), ...
    "test_passed",nnz(passed),"test_failed",nnz(failed), ...
    "test_incomplete",nnz(incomplete), ...
    "duration_seconds",sum(durationSeconds));
allPass = summary.test_total==11 && all(passed) && ...
    ~any(failed) && ~any(incomplete);
evidence = struct("inventory",inventory,"results",results, ...
    "summary",summary,"all_pass",allPass);
if ~allPass
    error("stageA4:tests:A42AFailed", ...
        "One or more fixed A4-2A tests failed or were incomplete.");
end
end
