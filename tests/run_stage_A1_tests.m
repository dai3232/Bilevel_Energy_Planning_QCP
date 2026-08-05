function evidence = run_stage_A1_tests(varargin)
%RUN_STAGE_A1_TESTS Run the explicit Stage A1 regression suite.
%
% EVIDENCE = RUN_STAGE_A1_TESTS() runs the same fixed, explicitly listed
% Stage A1 test files used by a formal run. It prints detailed output and
% errors unless every test passes.
%
% EVIDENCE = RUN_STAGE_A1_TESTS('EvidenceDirectory',DIRECTORY, ...
%     'CommandText',COMMAND) also persists the pre-run inventory, result
% CSV, JUnit XML, complete console diary, command text, and JSON summary.
% Existing evidence artifacts are never overwritten.

repoRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(repoRoot,'src')));

parser = inputParser;
parser.FunctionName = mfilename;
addParameter(parser,'EvidenceDirectory',"",@is_text_scalar);
addParameter(parser,'CommandText',"run_stage_A1_tests()",@is_text_scalar);
parse(parser,varargin{:});

evidenceDirectory = strtrim(string(parser.Results.EvidenceDirectory));
commandText = strtrim(string(parser.Results.CommandText));
if strlength(commandText) == 0
    error('stageA1:tests:EmptyCommandText', ...
        'CommandText must be a non-empty text scalar.');
end

[suite,inventory] = fixed_stage_a1_suite(repoRoot);
assert_fixed_inventory(inventory);

if strlength(evidenceDirectory) == 0
    runner = create_text_runner();
    rawResults = runner.run(suite);
    resultTable = result_table_from_results(rawResults);
    assert_result_identity(resultTable,inventory);
    summary = make_summary(resultTable,sum(resultTable.duration_seconds), ...
        "COMPLETE","","");
    paths = empty_paths();
    disp(table(rawResults));
else
    [resultTable,summary,paths] = run_with_evidence(suite,inventory, ...
        char(evidenceDirectory),char(commandText));
end

allPass = height(resultTable) == height(inventory) && ...
    all(resultTable.passed) && ~any(resultTable.failed) && ...
    ~any(resultTable.incomplete);
evidence = struct('inventory',inventory,'results',resultTable, ...
    'summary',summary,'paths',paths,'all_pass',allPass);
if ~allPass
    error('stageA1:tests:Failed', ...
        'One or more fixed Stage A1 tests failed or were incomplete.');
end
end

function [suite,inventory] = fixed_stage_a1_suite(repoRoot)
% Folder discovery is intentionally forbidden here. Future-stage tests and
% tests outside this frozen A1 suite must not enter a formal A1 inventory.
relativeFiles = [ ...
    "tests/unit/test_stage_a1_index.m"
    "tests/unit/test_stage_a1_linearization.m"
    "tests/unit/test_stage_a1_solver_components.m"
    "tests/equivalence/test_stage_a1_direction_equivalence.m"
    "tests/integration/test_stage_a1_artifacts.m"
    "tests/integration/test_stage_a1_report.m"
    ];

sourceFiles = strings(0,1);
for fileIndex = 1:numel(relativeFiles)
    relativePath = strrep(relativeFiles(fileIndex),'/',filesep);
    absolutePath = fullfile(repoRoot,char(relativePath));
    if ~isfile(absolutePath)
        error('stageA1:tests:MissingFixedTestFile', ...
            'The fixed Stage A1 test file is missing: %s',absolutePath);
    end
    fileSuite = matlab.unittest.TestSuite.fromFile(absolutePath);
    if isempty(fileSuite)
        error('stageA1:tests:EmptyFixedTestFile', ...
            'The fixed Stage A1 test file defines no tests: %s',absolutePath);
    end
    if fileIndex == 1
        suite = fileSuite;
    else
        suite = [suite,fileSuite]; %#ok<AGROW>
    end
    sourceFiles = [sourceFiles;repmat(relativeFiles(fileIndex), ...
        numel(fileSuite),1)]; %#ok<AGROW>
end

testNames = string({suite.Name})';
inventory = table(uint32((1:numel(suite))'),testNames,sourceFiles, ...
    'VariableNames',{'test_order','test_name','source_file'});
end

function assert_fixed_inventory(inventory)
if height(inventory) == 0
    error('stageA1:tests:EmptyInventory', ...
        'The explicit Stage A1 suite must contain at least one test.');
end
testNames = string(inventory.test_name);
if any(strlength(strtrim(testNames)) == 0)
    error('stageA1:tests:EmptyTestName', ...
        'The fixed Stage A1 inventory contains an empty test name.');
end
if numel(unique(testNames)) ~= numel(testNames)
    duplicateNames = unique(testNames(duplicated_entries(testNames)));
    error('stageA1:tests:DuplicateTestName', ...
        'The fixed Stage A1 inventory contains duplicate names: %s', ...
        strjoin(duplicateNames,', '));
end
end

function mask = duplicated_entries(values)
[~,~,group] = unique(values);
counts = accumarray(group,1);
mask = counts(group) > 1;
end

function runner = create_text_runner()
runner = matlab.unittest.TestRunner.withTextOutput('OutputDetail', ...
    matlab.unittest.Verbosity.Detailed);
end

function [resultTable,summary,paths] = run_with_evidence( ...
        suite,inventory,evidenceDirectory,commandText)
paths = evidence_paths(evidenceDirectory);
prepare_evidence_directory(evidenceDirectory,paths);

% These artifacts are deliberately written before the first test executes.
rkkt.artifacts.write_table_csv_17g(paths.inventory,inventory);
write_utf8_text(paths.command,[commandText,newline]);
initialResults = incomplete_result_table(inventory, ...
    "Test execution has not completed.");
rkkt.artifacts.write_table_csv_17g(paths.results_csv,initialResults);
rkkt.artifacts.write_json_file(paths.summary,make_summary(initialResults,0, ...
    "RUNNING","",""));
write_utf8_text(paths.console_log, ...
    sprintf('Stage A1 test console evidence initialized at %s.\n', ...
    char(now_text())));

rawResults = matlab.unittest.TestResult.empty;
executionTimer = tic;
diaryGuard = onCleanup(@() close_diary_safely());
try
    diary(paths.console_log);
    fprintf('Fixed Stage A1 test inventory (%d tests):\n',height(inventory));
    disp(inventory(:,{'test_order','test_name','source_file'}));
    fprintf('Test command: %s\n',commandText);

    runner = create_text_runner();
    xmlPlugin = matlab.unittest.plugins.XMLPlugin.producingJUnitFormat( ...
        paths.results_xml);
    runner.addPlugin(xmlPlugin);
    rawResults = runner.run(suite);
    wallClockSeconds = toc(executionTimer);
    disp(table(rawResults));

    resultTable = result_table_from_results(rawResults);
    assert_result_identity(resultTable,inventory);
    summary = make_summary(resultTable,wallClockSeconds, ...
        "COMPLETE","","");
    rkkt.artifacts.write_table_csv_17g(paths.results_csv,resultTable);
    rkkt.artifacts.write_json_file(paths.summary,summary);
    if ~is_complete_junit(paths.results_xml,height(inventory))
        error('stageA1:tests:IncompleteJUnit', ...
            'JUnit evidence does not contain the complete test inventory.');
    end
    fprintf(['Stage A1 test summary: total=%d, passed=%d, failed=%d, ' ...
        'incomplete=%d, total_duration_seconds=%.17g, ' ...
        'wall_clock_seconds=%.17g\n'], ...
        height(resultTable),sum(resultTable.passed), ...
        sum(resultTable.failed),sum(resultTable.incomplete), ...
        sum(resultTable.duration_seconds),wallClockSeconds);
catch exception
    wallClockSeconds = toc(executionTimer);
    fprintf(2,'Stage A1 test execution or evidence persistence failed:\n%s\n', ...
        getReport(exception,'extended','hyperlinks','off'));
    persist_exception_evidence(paths,inventory,rawResults, ...
        wallClockSeconds,exception);
    clear diaryGuard;
    rethrow(exception);
end
clear diaryGuard;
end

function paths = evidence_paths(evidenceDirectory)
paths = struct( ...
    'results_csv',fullfile(evidenceDirectory,'test_results.csv'), ...
    'results_xml',fullfile(evidenceDirectory,'test_results.xml'), ...
    'console_log',fullfile(evidenceDirectory,'matlab_test_console.log'), ...
    'command',fullfile(evidenceDirectory,'test_command.txt'), ...
    'summary',fullfile(evidenceDirectory,'test_summary.json'), ...
    'inventory',fullfile(evidenceDirectory,'test_inventory.csv'));
end

function paths = empty_paths()
paths = struct('results_csv',"",'results_xml',"",'console_log',"", ...
    'command',"",'summary',"",'inventory',"");
end

function prepare_evidence_directory(evidenceDirectory,paths)
if isfile(evidenceDirectory)
    error('stageA1:tests:EvidencePathConflict', ...
        'A file exists where the evidence directory is required: %s', ...
        evidenceDirectory);
end
if ~isfolder(evidenceDirectory)
    [created,message] = mkdir(evidenceDirectory);
    if ~created
        error('stageA1:tests:EvidenceDirectoryCreateFailed', ...
            'Could not create evidence directory %s: %s', ...
            evidenceDirectory,message);
    end
end
targetPaths = struct2cell(paths);
existingMask = cellfun(@(pathValue) isfile(pathValue) || ...
    isfolder(pathValue),targetPaths);
if any(existingMask)
    error('stageA1:tests:EvidenceArtifactExists', ...
        'Refusing to overwrite existing test evidence: %s', ...
        strjoin(string(targetPaths(existingMask)),', '));
end
end

function resultTable = incomplete_result_table(inventory,detailText)
rowCount = height(inventory);
resultTable = table(string(inventory.test_name),false(rowCount,1), ...
    false(rowCount,1),true(rowCount,1),zeros(rowCount,1), ...
    repmat(string(detailText),rowCount,1), ...
    'VariableNames',{'test_name','passed','failed','incomplete', ...
    'duration_seconds','details'});
end

function resultTable = result_table_from_results(results)
rowCount = numel(results);
testNames = strings(rowCount,1);
passed = false(rowCount,1);
failed = false(rowCount,1);
incomplete = false(rowCount,1);
durationSeconds = zeros(rowCount,1);
details = strings(rowCount,1);
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
resultTable = table(testNames,passed,failed,incomplete, ...
    durationSeconds,details,'VariableNames',{'test_name','passed', ...
    'failed','incomplete','duration_seconds','details'});
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
    textValue = "Details could not be rendered (class: "+ ...
        string(class(detailsValue))+").";
end
end

function assert_result_identity(resultTable,inventory)
actualNames = string(resultTable.test_name);
expectedNames = string(inventory.test_name);
if height(resultTable) ~= height(inventory) || ...
        numel(unique(actualNames)) ~= height(inventory)
    error('stageA1:tests:InvalidResultInventory', ...
        ['Test results must contain exactly the pre-run inventory count ' ...
        'with uniquely named rows.']);
end
if ~isequal(actualNames,expectedNames)
    error('stageA1:tests:ResultInventoryMismatch', ...
        'Result names or order do not match the persisted pre-run inventory.');
end
end

function summary = make_summary(resultTable,wallClockSeconds, ...
        executionStatus,errorIdentifier,errorMessage)
summary = struct( ...
    'execution_status',char(executionStatus), ...
    'test_total',height(resultTable), ...
    'test_passed',sum(resultTable.passed), ...
    'test_failed',sum(resultTable.failed), ...
    'test_incomplete',sum(resultTable.incomplete), ...
    'duration_seconds',sum(resultTable.duration_seconds), ...
    'total_duration_seconds',sum(resultTable.duration_seconds), ...
    'wall_clock_seconds',double(wallClockSeconds), ...
    'error_identifier',char(errorIdentifier), ...
    'error_message',char(errorMessage));
end

function [resultTable,summary] = persist_exception_evidence( ...
        paths,inventory,rawResults,wallClockSeconds,exception)
if isempty(rawResults)
    resultTable = incomplete_result_table(inventory, ...
        "Infrastructure exception: "+string(exception.message));
else
    resultTable = result_table_from_results(rawResults);
    if height(resultTable) ~= height(inventory) || ...
            ~isequal(string(resultTable.test_name),string(inventory.test_name))
        resultTable = incomplete_result_table(inventory, ...
            "Result set was incomplete after infrastructure exception: "+ ...
            string(exception.message));
    end
end
summary = make_summary(resultTable,wallClockSeconds,"ERROR", ...
    string(exception.identifier),string(exception.message));
try
    rkkt.artifacts.write_table_csv_17g(paths.results_csv,resultTable);
    rkkt.artifacts.write_json_file(paths.summary,summary);
catch persistenceException
    fprintf(2,'Could not update exception CSV/JSON evidence: %s\n', ...
        persistenceException.message);
end
try
    if ~is_complete_junit(paths.results_xml,height(inventory))
        preserve_invalid_plugin_junit(paths.results_xml);
        write_exception_junit(paths.results_xml,inventory, ...
            wallClockSeconds,exception);
    end
catch persistenceException
    fprintf(2,'Could not create fallback JUnit evidence: %s\n', ...
        persistenceException.message);
end
end

function complete = is_complete_junit(filePath,expectedTestCount)
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
backupPath = [filePath,'.plugin_incomplete'];
if isfile(backupPath) || isfolder(backupPath)
    error('stageA1:tests:JUnitBackupExists', ...
        'Refusing to overwrite an existing plugin JUnit backup: %s',backupPath);
end
[moved,message] = movefile(filePath,backupPath);
if ~moved
    error('stageA1:tests:JUnitBackupFailed', ...
        'Could not preserve incomplete plugin JUnit evidence: %s',message);
end
end

function write_exception_junit(filePath,inventory,wallClockSeconds,exception)
if isfile(filePath) || isfolder(filePath)
    error('stageA1:tests:EvidenceArtifactExists', ...
        'Refusing to overwrite JUnit evidence: %s',filePath);
end
errorText = xml_escape(string(exception.identifier)+": "+ ...
    string(exception.message));
testCount = height(inventory);
lines = strings(5+3*testCount,1);
lineIndex = 1;
lines(lineIndex) = "<?xml version=""1.0"" encoding=""UTF-8""?>";
lineIndex = lineIndex+1;
lines(lineIndex) = sprintf([ ...
    '<testsuites name="stage_A1" tests="%d" failures="0" errors="%d" ' ...
    'skipped="0" time="%.17g">'],testCount,testCount,wallClockSeconds);
lineIndex = lineIndex+1;
lines(lineIndex) = sprintf([ ...
    '<testsuite name="fixed_stage_A1_suite" tests="%d" failures="0" ' ...
    'errors="%d" skipped="0" time="%.17g">'], ...
    testCount,testCount,wallClockSeconds);
lineIndex = lineIndex+1;
for rowIndex = 1:testCount
    testName = xml_escape(inventory.test_name(rowIndex));
    lines(lineIndex) = "<testcase classname=""stage_A1"" name="""+ ...
        testName+""" time=""0"">";
    lineIndex = lineIndex+1;
    lines(lineIndex) = "<error message=""Test execution incomplete"">"+ ...
        errorText+"</error>";
    lineIndex = lineIndex+1;
    lines(lineIndex) = "</testcase>";
    lineIndex = lineIndex+1;
end
lines(lineIndex) = "</testsuite>";
lineIndex = lineIndex+1;
lines(lineIndex) = "</testsuites>";
write_utf8_text(filePath,strjoin(lines,newline)+newline);
end

function value = xml_escape(value)
value = string(value);
value = replace(value,'&','&amp;');
value = replace(value,'<','&lt;');
value = replace(value,'>','&gt;');
value = replace(value,'"','&quot;');
value = replace(value,'''','&apos;');
end

function write_utf8_text(filePath,textValue)
[fileId,message] = fopen(filePath,'wb','n','UTF-8');
if fileId < 0
    error('stageA1:tests:EvidenceFileOpenFailed', ...
        'Could not open %s: %s',filePath,message);
end
closeGuard = onCleanup(@() close_file_safely(fileId));
bytes = unicode2native(char(textValue),'UTF-8');
written = fwrite(fileId,bytes,'uint8');
if written ~= numel(bytes)
    error('stageA1:tests:EvidenceFileWriteFailed', ...
        'Incomplete write for %s.',filePath);
end
closeStatus = fclose(fileId);
clear closeGuard;
if closeStatus ~= 0
    error('stageA1:tests:EvidenceFileCloseFailed', ...
        'Could not close %s after writing.',filePath);
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

function value = now_text()
value = string(datetime('now','TimeZone','Asia/Shanghai', ...
    'Format','yyyy-MM-dd''T''HH:mm:ssXXX'));
end

function tf = is_text_scalar(value)
tf = ischar(value) || (isstring(value) && isscalar(value));
end
