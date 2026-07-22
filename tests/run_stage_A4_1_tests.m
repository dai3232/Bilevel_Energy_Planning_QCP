function evidence = run_stage_A4_1_tests()
%RUN_STAGE_A4_1_TESTS Run only the non-formal A4-1 milestone tests.

repoRoot = string(fileparts(fileparts(mfilename("fullpath"))));
addpath(repoRoot);
addpath(genpath(fullfile(repoRoot,"src")));
relativeFiles = [ ...
    "tests/unit/test_stage_a4_model.m"
    "tests/unit/test_stage_a4_step_update.m"
    "tests/integration/test_stage_a4_single_iteration.m"];

sourceFiles = strings(0,1);
for fileIndex = 1:numel(relativeFiles)
    absolutePath = fullfile(repoRoot,strrep(relativeFiles(fileIndex), ...
        "/",filesep));
    assert(isfile(absolutePath),"stageA4:tests:MissingFixedTestFile", ...
        "A4-1 test file is missing: %s",absolutePath);
    fileSuite = matlab.unittest.TestSuite.fromFile(absolutePath);
    assert(~isempty(fileSuite),"stageA4:tests:EmptyFixedTestFile", ...
        "A4-1 test file defines no tests: %s",absolutePath);
    if fileIndex==1
        suite = fileSuite;
    else
        suite = [suite,fileSuite]; %#ok<AGROW>
    end
    sourceFiles = [sourceFiles; ...
        repmat(relativeFiles(fileIndex),numel(fileSuite),1)]; %#ok<AGROW>
end

testNames = string({suite.Name}).';
assert(numel(unique(testNames))==numel(testNames), ...
    "stageA4:tests:DuplicateTestName", ...
    "A4-1 test names must be unique.");
inventory = table(uint32((1:numel(suite)).'),testNames,sourceFiles, ...
    'VariableNames',{'test_order','test_name','source_file'});
fprintf("Fixed A4-1 test inventory (%d tests):\n",height(inventory));
disp(inventory);

runner = matlab.unittest.TestRunner.withTextOutput( ...
    "OutputDetail",matlab.unittest.Verbosity.Detailed);
raw = runner.run(suite);
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
results = table(testNames,passed,failed,incomplete,durationSeconds, ...
    'VariableNames',{'test_name','passed','failed','incomplete', ...
    'duration_seconds'});
summary = struct( ...
    "test_total",height(results), ...
    "test_passed",nnz(passed), ...
    "test_failed",nnz(failed), ...
    "test_incomplete",nnz(incomplete), ...
    "duration_seconds",sum(durationSeconds));
allPass = summary.test_total==height(inventory) && all(passed) && ...
    ~any(failed) && ~any(incomplete);
evidence = struct("inventory",inventory,"results",results, ...
    "summary",summary,"all_pass",allPass);
if ~allPass
    error("stageA4:tests:Failed", ...
        "One or more fixed A4-1 tests failed or were incomplete.");
end
end
