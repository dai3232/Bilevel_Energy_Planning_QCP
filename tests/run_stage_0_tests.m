function results = run_stage_0_tests()
%RUN_STAGE_0_TESTS Execute only stage-0 unit and integration tests.

repoRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(repoRoot,'src')));
testFolders = {fullfile(repoRoot,'tests','unit'), ...
    fullfile(repoRoot,'tests','integration')};
suite = matlab.unittest.TestSuite.fromFolder(testFolders{1},'IncludingSubfolders',true);
suite = [suite, matlab.unittest.TestSuite.fromFolder(testFolders{2}, ...
    'IncludingSubfolders',true)];
runner = matlab.unittest.TestRunner.withTextOutput('OutputDetail', ...
    matlab.unittest.Verbosity.Detailed);
results = runner.run(suite);
disp(table(results));
assert(all([results.Passed]),"stage0:tests:Failed", ...
    "One or more stage-0 tests failed.");
end
