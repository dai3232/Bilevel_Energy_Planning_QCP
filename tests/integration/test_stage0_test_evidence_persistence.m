function tests = test_stage0_test_evidence_persistence
%TEST_STAGE0_TEST_EVIDENCE_PERSISTENCE Coverage outside the fixed 14 tests.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
testFile = mfilename('fullpath');
repositoryRoot = fileparts(fileparts(fileparts(testFile)));
addpath(genpath(fullfile(repositoryRoot, 'src')));
addpath(fullfile(repositoryRoot, 'tests'));
testCase.TestData.RepositoryRoot = repositoryRoot;
end

function testWritesCompleteEvidenceForOnlyTheFixedFourteenTests(testCase)
evidenceDirectory = create_temporary_directory(testCase);
commandText = "run_stage_0_tests evidence framework integration test";

results = run_stage_0_tests('EvidenceDirectory', evidenceDirectory, ...
    'TestCommand', commandText);

verifyNumElements(testCase, results, 14);
verifyTrue(testCase, all([results.Passed]));
expectedFiles = [
    "test_results.csv"
    "test_results.xml"
    "matlab_test_console.log"
    "test_command.txt"
    "test_summary.json"
    "test_inventory.csv"
    ];
for fileIndex = 1:numel(expectedFiles)
    verifyTrue(testCase, isfile(fullfile(evidenceDirectory, ...
        expectedFiles(fileIndex))), expectedFiles(fileIndex));
end

inventory = readtable(fullfile(evidenceDirectory, 'test_inventory.csv'), ...
    'TextType', 'string', 'VariableNamingRule', 'preserve');
resultTable = readtable(fullfile(evidenceDirectory, 'test_results.csv'), ...
    'TextType', 'string', 'VariableNamingRule', 'preserve');
summary = jsondecode(fileread(fullfile(evidenceDirectory, ...
    'test_summary.json')));
xmlText = fileread(fullfile(evidenceDirectory, 'test_results.xml'));
xmlDocument = xmlread(fullfile(evidenceDirectory, 'test_results.xml'));
logText = fileread(fullfile(evidenceDirectory, ...
    'matlab_test_console.log'));

verifyEqual(testCase, height(inventory), 14);
verifyEqual(testCase, numel(unique(inventory.test_name)), 14);
verifyEqual(testCase, height(resultTable), 14);
verifyEqual(testCase, string(resultTable.Properties.VariableNames), ...
    ["test_name", "passed", "failed", "incomplete", ...
    "duration_seconds", "details"]);
verifyEqual(testCase, string(resultTable.test_name), ...
    string(inventory.test_name));
verifyTrue(testCase, all(lower(string(resultTable.passed)) == "true"));
verifyFalse(testCase, any(lower(string(resultTable.failed)) == "true"));
verifyFalse(testCase, any(lower(string(resultTable.incomplete)) == "true"));
verifyFalse(testCase, any(contains(inventory.test_name, ...
    'test_stage0_test_evidence_persistence')));
verifyEqual(testCase, summary.test_total, 14);
verifyEqual(testCase, summary.test_passed, 14);
verifyEqual(testCase, summary.test_failed, 0);
verifyEqual(testCase, summary.test_incomplete, 0);
verifyEqual(testCase, string(summary.execution_status), "COMPLETE");
verifyEqual(testCase, summary.duration_seconds, ...
    summary.total_duration_seconds, 'AbsTol', eps(max(1, ...
    summary.total_duration_seconds)));
verifySubstring(testCase, xmlText, '<testsuite');
verifyEqual(testCase, double(xmlDocument.getElementsByTagName( ...
    'testcase').getLength()), 14);
caseNodes = xmlDocument.getElementsByTagName('testcase');
junitNames = strings(14,1);
for caseIndex = 1:14
    junitNames(caseIndex) = string(char( ...
        caseNodes.item(caseIndex-1).getAttribute('name')));
end
expectedJunitNames = extractAfter(string(inventory.test_name),'/');
verifyEqual(testCase,sort(junitNames),sort(expectedJunitNames));
verifySubstring(testCase, logText, 'Fixed stage-0 test inventory (14 tests)');
verifyEqual(testCase, strtrim(string(fileread(fullfile( ...
    evidenceDirectory, 'test_command.txt')))), commandText);
logPath = fullfile(evidenceDirectory,'matlab_test_console.log');
closedProbePath = [logPath,'.closed_probe'];
[moved,message] = movefile(logPath,closedProbePath);
verifyTrue(testCase,moved,message);
if moved
    [restored,restoreMessage] = movefile(closedProbePath,logPath);
    verifyTrue(testCase,restored,restoreMessage);
end
end

function testRefusesToOverwriteEvidenceArtifact(testCase)
evidenceDirectory = create_temporary_directory(testCase);
commandPath = fullfile(evidenceDirectory, 'test_command.txt');
write_test_text(commandPath, 'preserve-this-file');

verifyError(testCase, @() run_stage_0_tests( ...
    'EvidenceDirectory', evidenceDirectory), ...
    'stage0:tests:EvidenceArtifactExists');
verifyEqual(testCase, fileread(commandPath), 'preserve-this-file');
end

function testFallbackJUnitIsWellFormedAndNeverReportsPass(testCase)
evidenceDirectory = create_temporary_directory(testCase);
junitPath = fullfile(evidenceDirectory, 'fallback.xml');
inventory = table(uint32([1; 2]), ["fixture/testOne"; "fixture/test<&Two"], ...
    ["fixture.m"; "fixture.m"], ...
    'VariableNames', {'test_order', 'test_name', 'source_file'});
exception = MException('stage0:tests:FixtureFailure', ...
    'fixture failure with <xml> & quotes');

% A plugin can leave a zero-byte target after an interrupted run.  The
% fallback is allowed to replace only that empty current-run artifact.
write_test_text(junitPath, '');

rkkt.testing.write_stage0_exception_junit(junitPath, inventory, pi, exception);

xmlDocument = xmlread(junitPath);
rootElement = xmlDocument.getDocumentElement();
verifyEqual(testCase, string(char(rootElement.getNodeName())), "testsuites");
verifyEqual(testCase, string(char(rootElement.getAttribute('tests'))), "2");
verifyEqual(testCase, string(char(rootElement.getAttribute('errors'))), "2");
verifyEqual(testCase, double(rootElement.getElementsByTagName( ...
    'testcase').getLength()), 2);
verifyEqual(testCase, double(rootElement.getElementsByTagName( ...
    'error').getLength()), 2);
verifyEqual(testCase, double(rootElement.getElementsByTagName( ...
    'failure').getLength()), 0);
verifyFalse(testCase, contains(fileread(junitPath), 'passed'));
verifyError(testCase, @() rkkt.testing.write_stage0_exception_junit( ...
    junitPath, inventory, pi, exception), ...
    'stage0:tests:EvidenceArtifactExists');
end

function testRunContextExposesDedicatedTestEvidencePaths(testCase)
projectRoot = create_temporary_directory(testCase);
metadata = struct( ...
    'run_purpose','stage_0_test_evidence_addendum', ...
    'parent_run_id','20260718_163832_stage_0_9e12222e', ...
    'historical_baseline_commit','b74a2ac', ...
    'actual_test_command','fixture command', ...
    'optimization_executed',false, ...
    'a1_solver_executed',false);
context = rkkt.artifacts.create_run_context(projectRoot,'stage_0', ...
    'RunId','20260719_000000_stage_0_fixture', ...
    'ManifestMetadata',metadata);

verifyTrue(testCase,isfolder(context.tests_dir));
verifyEqual(testCase,string(context.tests_dir), ...
    string(fullfile(context.root,'tests')));
expectedPaths = [ ...
    string(fullfile(context.tests_dir,'test_inventory.csv'))
    string(fullfile(context.tests_dir,'test_results.csv'))
    string(fullfile(context.tests_dir,'test_results.xml'))
    string(fullfile(context.tests_dir,'matlab_test_console.log'))
    string(fullfile(context.tests_dir,'test_command.txt'))
    string(fullfile(context.tests_dir,'test_summary.json'))
    string(fullfile(context.tests_dir,'test_evidence_manifest.csv'))];
actualPaths = [string(context.test_inventory_path)
    string(context.test_results_csv_path)
    string(context.test_results_xml_path)
    string(context.test_console_log_path)
    string(context.test_command_path)
    string(context.test_summary_path)
    string(context.test_evidence_manifest_path)];
verifyEqual(testCase,actualPaths,expectedPaths);

manifest = jsondecode(fileread(context.run_manifest_path));
verifyEqual(testCase,string(manifest.run_purpose), ...
    "stage_0_test_evidence_addendum");
verifyFalse(testCase,logical(manifest.optimization_executed));
verifyFalse(testCase,logical(manifest.a1_solver_executed));
rkkt.artifacts.update_running_run_manifest(context,struct('test_total',14, ...
    'candidate_terminal_status','FAIL_RETRYABLE'));
finalManifest = rkkt.artifacts.finalize_run_manifest(context,'FAIL_RETRYABLE');
verifyEqual(testCase,string(finalManifest.status),"FAIL_RETRYABLE");
verifyEqual(testCase,double(finalManifest.test_total),14);
end

function testGeneratesArtifactBackedAddendumReportInTemporaryRun(testCase)
runRoot = create_temporary_directory(testCase);
testsDirectory = fullfile(runRoot,'tests');
reportsDirectory = fullfile(runRoot,'reports');
mkdir(testsDirectory);
mkdir(reportsDirectory);
commandText = "matlab -batch fixture_stage0_evidence";

testNames = compose("fixture/test_%02d",(1:14)');
inventory = table(uint32((1:14)'),testNames, ...
    repmat("tests/fixture.m",14,1), ...
    'VariableNames',{'test_order','test_name','source_file'});
durations = (1:14)'/100;
results = table(testNames,true(14,1),false(14,1),false(14,1), ...
    durations,repmat("",14,1), ...
    'VariableNames',{'test_name','passed','failed','incomplete', ...
    'duration_seconds','details'});
rkkt.artifacts.write_table_csv_17g(fullfile(testsDirectory,'test_inventory.csv'),inventory);
rkkt.artifacts.write_table_csv_17g(fullfile(testsDirectory,'test_results.csv'),results);
write_test_text(fullfile(testsDirectory,'test_results.xml'), ...
    char(passing_junit(testNames,durations)));
write_test_text(fullfile(testsDirectory,'matlab_test_console.log'), ...
    sprintf(['Fixed stage-0 test inventory (14 tests):\n' ...
    'Stage-0 test summary: total=14, passed=14, failed=0, incomplete=0\n']));
write_test_text(fullfile(testsDirectory,'test_command.txt'), ...
    char(commandText+newline));
durationTotal = sum(durations);
rkkt.artifacts.write_json_file(fullfile(testsDirectory,'test_summary.json'),struct( ...
    'execution_status','COMPLETE','test_total',14,'test_passed',14, ...
    'test_failed',0,'test_incomplete',0, ...
    'duration_seconds',durationTotal, ...
    'total_duration_seconds',durationTotal));

environment = fixture_environment("fixture_stage0_report");
environmentPath = fullfile(runRoot,'environment.csv');
rkkt.artifacts.write_table_csv_17g(environmentPath,environment);
hashA = string(repmat('a',1,64));
hashB = string(repmat('b',1,64));
inputHashes = table( ...
    repmat("fixture_stage0_report",2,1), ...
    ["inputs/raw/基础参数.xlsx";"inputs/raw/输入数据.xlsx"], ...
    [hashA;hashB],[hashA;hashB],["PASS";"PASS"],[14585;821811], ...
    repmat("2026-07-19T00:00:00+08:00",2,1), ...
    'VariableNames',{'run_id','relative_path','expected_sha256', ...
    'actual_sha256','status','bytes','checked_at'});
rkkt.artifacts.write_table_csv_17g(fullfile(runRoot,'input_hashes.csv'),inputHashes);

evidenceManifest = fixture_evidence_manifest(testsDirectory);
rkkt.artifacts.write_table_csv_17g(fullfile(testsDirectory, ...
    'test_evidence_manifest.csv'),evidenceManifest);
manifest = struct( ...
    'run_id','fixture_stage0_report', ...
    'stage_id','stage_0', ...
    'status','RUNNING', ...
    'run_purpose','stage_0_test_evidence_addendum', ...
    'parent_run_id','20260718_163832_stage_0_9e12222e', ...
    'historical_baseline_commit','b74a2ac', ...
    'git_commit',repmat('c',1,40), ...
    'actual_test_command',char(commandText), ...
    'optimization_executed',false, ...
    'a1_solver_executed',false, ...
    'test_total',14,'test_passed',14,'test_failed',0, ...
    'test_incomplete',0,'candidate_terminal_status','PASS', ...
    'environment',struct('relative_path','environment.csv', ...
    'sha256',char(rkkt.data.compute_sha256_file(string(environmentPath))), ...
    'all_checks_passed',true));
rkkt.artifacts.write_json_file(fullfile(runRoot,'run_manifest.json'),manifest);

context = struct('root',runRoot,'tests_dir',testsDirectory);
reportPath = rkkt.reporting.generate_stage0_test_evidence_report(context);
[valid,details] = rkkt.reporting.validate_docx_package(reportPath);
verifyTrue(testCase,valid,strjoin(details.errors,'; '));
verifySubstring(testCase,details.document_text,'fixture/test_01');
verifySubstring(testCase,details.document_text,'不能反向证明历史 run');
verifySubstring(testCase,details.document_text,'正式优化目标');
verifySubstring(testCase,details.document_text,'全部未启用/未求值');
verifyError(testCase,@() rkkt.reporting.generate_stage0_test_evidence_report(context), ...
    'stage0:testEvidenceReport:ArtifactExists');
end

function testEndToEndAddendumUsesOnlyTemporaryRunDirectory(testCase)
repositoryRoot = testCase.TestData.RepositoryRoot;
projectRoot = create_temporary_directory(testCase);
mkdir(fullfile(projectRoot,'inputs','raw'));
copyfile(fullfile(repositoryRoot,'inputs','数据文件清单与SHA256.csv'), ...
    fullfile(projectRoot,'inputs','数据文件清单与SHA256.csv'));
copyfile(fullfile(repositoryRoot,'inputs','raw','基础参数.xlsx'), ...
    fullfile(projectRoot,'inputs','raw','基础参数.xlsx'));
copyfile(fullfile(repositoryRoot,'inputs','raw','输入数据.xlsx'), ...
    fullfile(projectRoot,'inputs','raw','输入数据.xlsx'));

commandText = 'temporary stage0 addendum integration command';
metadata = struct( ...
    'run_purpose','stage_0_test_evidence_addendum', ...
    'parent_run_id','20260718_163832_stage_0_9e12222e', ...
    'historical_baseline_commit','b74a2ac', ...
    'actual_test_command',commandText, ...
    'optimization_executed',false, ...
    'a1_solver_executed',false);
context = rkkt.artifacts.create_run_context(projectRoot,'stage_0', ...
    'RunId','20260719_010000_stage_0_addendum_fixture', ...
    'ManifestMetadata',metadata);

result = rkkt.diagnostics.run_stage0_test_evidence_addendum(context,commandText);

verifyEqual(testCase,result.status,"PASS");
manifest = jsondecode(fileread(context.run_manifest_path));
verifyEqual(testCase,string(manifest.status),"PASS");
verifyEqual(testCase,double(manifest.test_total),14);
verifyEqual(testCase,double(manifest.test_passed),14);
verifyEqual(testCase,double(manifest.test_failed),0);
verifyEqual(testCase,double(manifest.test_incomplete),0);
verifyFalse(testCase,logical(manifest.optimization_executed));
verifyFalse(testCase,logical(manifest.a1_solver_executed));
verifyTrue(testCase,logical(manifest.environment.all_checks_passed));
verifyEqual(testCase,strlength(string(manifest.environment.sha256)),64);
verifyEqual(testCase,strlength(string(manifest.report.sha256)),64);

acceptance = readtable(context.acceptance_results_path, ...
    'TextType','string','VariableNamingRule','preserve');
verifyEqual(testCase,height(acceptance),1);
verifyEqual(testCase,string(acceptance.test_id), ...
    "S0-TEST-EVIDENCE-001");
verifyEqual(testCase,string(acceptance.status),"PASS");
issues = readtable(context.issue_log_path,'TextType','string', ...
    'VariableNamingRule','preserve');
verifyEqual(testCase,height(issues),0);

evidence = readtable(context.test_evidence_manifest_path, ...
    'TextType','string','VariableNamingRule','preserve');
verifyEqual(testCase,height(evidence),6);
existsText = lower(string(evidence.exists));
verifyTrue(testCase,all(existsText == "true" | existsText == "1"));
verifyTrue(testCase,all(strlength(string(evidence.sha256)) == 64));
verifyEqual(testCase, ...
    rkkt.data.compute_sha256_file(string(context.test_evidence_manifest_path)), ...
    string(manifest.test_evidence_manifest_sha256));
[reportValid,reportDetails] = rkkt.reporting.validate_docx_package(result.report_path);
verifyTrue(testCase,reportValid,strjoin(reportDetails.errors,'; '));
end

function environment = fixture_environment(runId)
checkIds = ["MATLAB_RELEASE";"SPARSE_MLDIVIDE";"SPARSE_LDL"; ...
    "PCT_INSTALLED";"PCT_LICENSE";"PCT_WORKER"];
rowCount = numel(checkIds);
environment = table(repmat(string(runId),rowCount,1),checkIds, ...
    repmat("fixture component",rowCount,1), ...
    repmat("available",rowCount,1),repmat("fixture actual",rowCount,1), ...
    repmat("PASS",rowCount,1),true(rowCount,1), ...
    repmat("2026-07-19T00:00:00+08:00",rowCount,1), ...
    repmat("temporary integration fixture",rowCount,1), ...
    'VariableNames',{'run_id','check_id','component','expected','actual', ...
    'status','available','checked_at','details'});
end

function manifest = fixture_evidence_manifest(testsDirectory)
names = ["test_inventory.csv";"test_results.csv";"test_results.xml"; ...
    "matlab_test_console.log";"test_command.txt";"test_summary.json"];
types = ["inventory";"csv_results";"junit";"console_log"; ...
    "command";"summary"];
rowCount = numel(names);
bytes = zeros(rowCount,1);
sha = strings(rowCount,1);
for k = 1:rowCount
    filePath = fullfile(testsDirectory,char(names(k)));
    info = dir(filePath);
    bytes(k) = double(info.bytes);
    sha(k) = rkkt.data.compute_sha256_file(string(filePath));
end
manifest = table("tests/"+names,types,true(rowCount,1),bytes,sha, ...
    repmat("2026-07-19T00:00:00+08:00",rowCount,1), ...
    'VariableNames',{'relative_path','evidence_type','exists','bytes', ...
    'sha256','recorded_at'});
end

function xml = passing_junit(testNames,durations)
cases = strings(numel(testNames),1);
for k = 1:numel(testNames)
    cases(k) = "<testcase classname=""fixture"" name="""+ ...
        testNames(k)+""" time="""+compose("%.17g",durations(k))+"""/>";
end
xml = "<?xml version=""1.0"" encoding=""UTF-8""?>"+newline+ ...
    "<testsuite name=""fixture"" tests=""14"" failures=""0"" "+ ...
    "errors=""0"" skipped=""0"">"+newline+ ...
    strjoin(cases,newline)+newline+"</testsuite>"+newline;
end

function directory = create_temporary_directory(testCase)
directory = tempname(tempdir);
[created, message] = mkdir(directory);
assertTrue(testCase, created, message);
testCase.addTeardown(@() remove_temporary_directory(directory));
end

function remove_temporary_directory(directory)
if isfolder(directory)
    rmdir(directory, 's');
end
end

function write_test_text(filePath, content)
fileId = fopen(filePath, 'wb');
assert(fileId >= 0, 'Could not create test fixture.');
cleanup = onCleanup(@() fclose(fileId)); %#ok<NASGU>
fwrite(fileId, uint8(content), 'uint8');
end
