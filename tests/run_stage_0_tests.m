function results = run_stage_0_tests(varargin)
%RUN_STAGE_0_TESTS Execute the fixed 14-test stage-0 regression suite.
%
%   RESULTS = RUN_STAGE_0_TESTS() preserves the original no-argument
%   behaviour: the fixed stage-0 suite is run with detailed console output,
%   and the function errors unless every test passes.
%
%   RESULTS = RUN_STAGE_0_TESTS('EvidenceDirectory', DIRECTORY, ...
%       'TestCommand', COMMAND) additionally persists the inventory, result
%   CSV, JUnit XML, MATLAB console log, command, and JSON summary in
%   DIRECTORY.  The evidence targets must not already exist.

repoRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(repoRoot, 'src')));

parser = inputParser;
parser.FunctionName = mfilename;
addParameter(parser, 'EvidenceDirectory', "", @is_text_scalar);
addParameter(parser, 'TestCommand', "run_stage_0_tests()", @is_text_scalar);
parse(parser, varargin{:});

evidenceDirectory = string(parser.Results.EvidenceDirectory);
testCommand = string(parser.Results.TestCommand);
if strlength(strtrim(testCommand)) == 0
    error('stage0:tests:EmptyTestCommand', ...
        'TestCommand must be a non-empty text scalar.');
end

[suite, inventory] = fixed_stage0_suite(repoRoot);
assert_fixed_inventory(inventory);

if strlength(evidenceDirectory) == 0
    runner = create_text_runner();
    results = runner.run(suite);
    disp(table(results));
else
    results = run_with_evidence(suite, inventory, ...
        char(evidenceDirectory), char(testCommand));
end

assert(numel(results) == 14, 'stage0:tests:UnexpectedResultCount', ...
    'The fixed stage-0 suite must return exactly 14 results, but returned %d.', ...
    numel(results));
assert(all([results.Passed]) && ~any([results.Failed]) && ...
    ~any([results.Incomplete]), 'stage0:tests:Failed', ...
    'One or more fixed stage-0 tests failed or were incomplete.');
end

function [suite, inventory] = fixed_stage0_suite(repoRoot)
% Do not replace this explicit list with folder discovery.  New A1 tests and
% tests of this evidence framework must never silently enter the 14-test
% stage-0 regression inventory.
relativeFiles = [
    "tests/unit/test_canonical_index_framework.m"
    "tests/unit/test_stage0_data_reader.m"
    "tests/unit/test_stage0_environment.m"
    "tests/integration/test_run_context.m"
    "tests/integration/test_stage0_report.m"
    ];

sourceFiles = strings(0, 1);
for fileIndex = 1:numel(relativeFiles)
    relativePath = strrep(relativeFiles(fileIndex), '/', filesep);
    absolutePath = fullfile(repoRoot, char(relativePath));
    if ~isfile(absolutePath)
        error('stage0:tests:MissingFixedTestFile', ...
            'The fixed stage-0 test file is missing: %s', absolutePath);
    end
    fileSuite = matlab.unittest.TestSuite.fromFile(absolutePath);
    if fileIndex == 1
        suite = fileSuite;
    else
        suite = [suite, fileSuite]; %#ok<AGROW>
    end
    sourceFiles = [sourceFiles; ...
        repmat(relativeFiles(fileIndex), numel(fileSuite), 1)]; %#ok<AGROW>
end

testNames = string({suite.Name})';
inventory = table(uint32((1:numel(suite))'), testNames, sourceFiles, ...
    'VariableNames', {'test_order', 'test_name', 'source_file'});
end

function assert_fixed_inventory(inventory)
testNames = string(inventory.test_name);
if height(inventory) ~= 14
    error('stage0:tests:UnexpectedInventoryCount', ...
        'The fixed stage-0 inventory must contain exactly 14 tests, but contains %d.', ...
        height(inventory));
end
if numel(unique(testNames)) ~= numel(testNames)
    duplicateNames = unique(testNames(duplicated_entries(testNames)));
    error('stage0:tests:DuplicateTestName', ...
        'The fixed stage-0 inventory contains duplicate names: %s', ...
        strjoin(duplicateNames, ', '));
end
end

function mask = duplicated_entries(values)
[~, ~, group] = unique(values);
counts = accumarray(group, 1);
mask = counts(group) > 1;
end

function runner = create_text_runner()
runner = matlab.unittest.TestRunner.withTextOutput('OutputDetail', ...
    matlab.unittest.Verbosity.Detailed);
end

function results = run_with_evidence(suite, inventory, evidenceDirectory, testCommand)
paths = evidence_paths(evidenceDirectory);
prepare_evidence_directory(evidenceDirectory, paths);

write_table_csv_17g(paths.inventory, inventory);
write_utf8_text(paths.command, [testCommand, newline]);

initialResults = incomplete_result_table(inventory, ...
    "Test execution has not completed.");
write_table_csv_17g(paths.resultsCsv, initialResults);
write_json_file(paths.summary, make_summary(initialResults, 0, ...
    "RUNNING", "", ""));

results = matlab.unittest.TestResult.empty;
executionTimer = tic;
diary(paths.consoleLog);
diaryGuard = onCleanup(@() close_diary_safely());
fprintf('Fixed stage-0 test inventory (%d tests):\n', height(inventory));
disp(inventory(:, {'test_order', 'test_name'}));
fprintf('Test command: %s\n', testCommand);

try
    runner = create_text_runner();
    xmlPlugin = matlab.unittest.plugins.XMLPlugin.producingJUnitFormat( ...
        paths.resultsXml);
    runner.addPlugin(xmlPlugin);
    results = runner.run(suite);
    wallClockSeconds = toc(executionTimer);
    disp(table(results));

    resultTable = result_table_from_results(results);
    assert_result_identity(resultTable, inventory);
    write_table_csv_17g(paths.resultsCsv, resultTable);
    write_json_file(paths.summary, make_summary(resultTable, ...
        wallClockSeconds, "COMPLETE", "", ""));
    fprintf(['Stage-0 test summary: total=%d, passed=%d, failed=%d, ' ...
        'incomplete=%d, total_duration_seconds=%.17g, ' ...
        'wall_clock_seconds=%.17g\n'], ...
        height(resultTable), sum(resultTable.passed), ...
        sum(resultTable.failed), sum(resultTable.incomplete), ...
        sum(resultTable.duration_seconds), wallClockSeconds);
catch exception
    wallClockSeconds = toc(executionTimer);
    fprintf(2, 'Stage-0 test execution or evidence persistence failed:\n%s\n', ...
        getReport(exception, 'extended', 'hyperlinks', 'off'));
    persist_exception_evidence(paths, inventory, results, ...
        wallClockSeconds, exception);
    clear diaryGuard;
    rethrow(exception);
end

clear diaryGuard;
end

function paths = evidence_paths(evidenceDirectory)
paths = struct( ...
    'resultsCsv', fullfile(evidenceDirectory, 'test_results.csv'), ...
    'resultsXml', fullfile(evidenceDirectory, 'test_results.xml'), ...
    'consoleLog', fullfile(evidenceDirectory, 'matlab_test_console.log'), ...
    'command', fullfile(evidenceDirectory, 'test_command.txt'), ...
    'summary', fullfile(evidenceDirectory, 'test_summary.json'), ...
    'inventory', fullfile(evidenceDirectory, 'test_inventory.csv'));
end

function prepare_evidence_directory(evidenceDirectory, paths)
if ~isfolder(evidenceDirectory)
    [created, message] = mkdir(evidenceDirectory);
    if ~created
        error('stage0:tests:EvidenceDirectoryCreateFailed', ...
            'Could not create evidence directory %s: %s', ...
            evidenceDirectory, message);
    end
end

targetPaths = struct2cell(paths);
existingMask = cellfun(@isfile, targetPaths);
if any(existingMask)
    error('stage0:tests:EvidenceArtifactExists', ...
        'Refusing to overwrite existing test evidence: %s', ...
        strjoin(string(targetPaths(existingMask)), ', '));
end
end

function resultTable = incomplete_result_table(inventory, detailText)
rowCount = height(inventory);
resultTable = table(string(inventory.test_name), false(rowCount, 1), ...
    false(rowCount, 1), true(rowCount, 1), zeros(rowCount, 1), ...
    repmat(string(detailText), rowCount, 1), ...
    'VariableNames', {'test_name', 'passed', 'failed', 'incomplete', ...
    'duration_seconds', 'details'});
end

function resultTable = result_table_from_results(results)
rowCount = numel(results);
testNames = strings(rowCount, 1);
passed = false(rowCount, 1);
failed = false(rowCount, 1);
incomplete = false(rowCount, 1);
durationSeconds = zeros(rowCount, 1);
details = strings(rowCount, 1);
for rowIndex = 1:rowCount
    testNames(rowIndex) = string(results(rowIndex).Name);
    passed(rowIndex) = logical(results(rowIndex).Passed);
    failed(rowIndex) = logical(results(rowIndex).Failed);
    incomplete(rowIndex) = logical(results(rowIndex).Incomplete);
    durationValue = results(rowIndex).Duration;
    if isduration(durationValue)
        durationSeconds(rowIndex) = seconds(durationValue);
    else
        durationSeconds(rowIndex) = double(durationValue);
    end
    details(rowIndex) = details_as_text(results(rowIndex).Details);
end
resultTable = table(testNames, passed, failed, incomplete, ...
    durationSeconds, details, 'VariableNames', {'test_name', 'passed', ...
    'failed', 'incomplete', 'duration_seconds', 'details'});
end

function textValue = details_as_text(detailsValue)
if isempty(detailsValue)
    textValue = "";
    return;
end
try
    if ischar(detailsValue) || (isstring(detailsValue) && isscalar(detailsValue))
        textValue = string(detailsValue);
    else
        textValue = string(strtrim(evalc('disp(detailsValue)')));
    end
catch
    textValue = "Details could not be rendered (class: " + ...
        string(class(detailsValue)) + ").";
end
end

function assert_result_identity(resultTable, inventory)
actualNames = string(resultTable.test_name);
expectedNames = string(inventory.test_name);
if height(resultTable) ~= 14 || numel(unique(actualNames)) ~= 14
    error('stage0:tests:InvalidResultInventory', ...
        'Test results must contain exactly 14 uniquely named rows.');
end
if ~isequal(actualNames, expectedNames)
    error('stage0:tests:ResultInventoryMismatch', ...
        'The result names or order do not match the persisted pre-run inventory.');
end
end

function summary = make_summary(resultTable, wallClockSeconds, ...
        executionStatus, errorIdentifier, errorMessage)
summary = struct( ...
    'execution_status', char(executionStatus), ...
    'test_total', height(resultTable), ...
    'test_passed', sum(resultTable.passed), ...
    'test_failed', sum(resultTable.failed), ...
    'test_incomplete', sum(resultTable.incomplete), ...
    'duration_seconds', sum(resultTable.duration_seconds), ...
    'total_duration_seconds', sum(resultTable.duration_seconds), ...
    'wall_clock_seconds', double(wallClockSeconds), ...
    'error_identifier', char(errorIdentifier), ...
    'error_message', char(errorMessage));
end

function persist_exception_evidence(paths, inventory, results, ...
        wallClockSeconds, exception)
try
    if isempty(results)
        resultTable = incomplete_result_table(inventory, ...
            "Infrastructure exception: " + string(exception.message));
    else
        resultTable = result_table_from_results(results);
        if height(resultTable) ~= height(inventory)
            resultTable = incomplete_result_table(inventory, ...
                "Result set was incomplete after infrastructure exception: " + ...
                string(exception.message));
        end
    end
    write_table_csv_17g(paths.resultsCsv, resultTable);
    write_json_file(paths.summary, make_summary(resultTable, ...
        wallClockSeconds, "ERROR", string(exception.identifier), ...
        string(exception.message)));
catch persistenceException
    fprintf(2, 'Could not update exception evidence: %s\n', ...
        persistenceException.message);
end

try
    if ~is_complete_junit(paths.resultsXml, height(inventory))
        preserve_invalid_plugin_junit(paths.resultsXml);
        write_stage0_exception_junit(paths.resultsXml, inventory, ...
            wallClockSeconds, exception);
    end
catch persistenceException
    fprintf(2, 'Could not create fallback JUnit evidence: %s\n', ...
        persistenceException.message);
end
end

function complete = is_complete_junit(filePath, expectedTestCount)
complete = false;
if ~isfile(filePath)
    return;
end
try
    document = xmlread(filePath);
    complete = double(document.getElementsByTagName( ...
        'testcase').getLength()) == expectedTestCount;
catch
    complete = false;
end
end

function preserve_invalid_plugin_junit(filePath)
if ~isfile(filePath)
    return;
end
backupPath = [filePath, '.plugin_incomplete'];
if isfile(backupPath) || isfolder(backupPath)
    error('stage0:tests:JUnitBackupExists', ...
        'Refusing to overwrite an existing plugin JUnit backup: %s', ...
        backupPath);
end
[moved, message] = movefile(filePath, backupPath);
if ~moved
    error('stage0:tests:JUnitBackupFailed', ...
        'Could not preserve the incomplete plugin JUnit file: %s', message);
end
end

function write_utf8_text(filePath, textValue)
[fileId, message] = fopen(filePath, 'wb', 'n', 'UTF-8');
if fileId < 0
    error('stage0:tests:EvidenceFileOpenFailed', ...
        'Could not open %s: %s', filePath, message);
end
closeGuard = onCleanup(@() close_file_safely(fileId));
bytes = unicode2native(char(textValue), 'UTF-8');
written = fwrite(fileId, bytes, 'uint8');
if written ~= numel(bytes)
    error('stage0:tests:EvidenceFileWriteFailed', ...
        'Incomplete write for %s.', filePath);
end
closeStatus = fclose(fileId);
clear closeGuard;
if closeStatus ~= 0
    error('stage0:tests:EvidenceFileCloseFailed', ...
        'Could not close %s after writing.', filePath);
end
end

function close_diary_safely()
try
    diary('off');
catch
end
end

function close_file_safely(fileId)
try
    openName = fopen(fileId);
    if ischar(openName) && ~isempty(openName)
        fclose(fileId);
    end
catch
end
end

function tf = is_text_scalar(value)
tf = ischar(value) || (isstring(value) && isscalar(value));
end
