function evidence = run_stage_A3_tests(varargin)
%RUN_STAGE_A3_TESTS Run only the explicit Stage A3 fixed test suite.
% A2/A1 regression suites are deliberately executed separately.

repoRoot=fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(repoRoot,'src')));
parser=inputParser; parser.FunctionName=mfilename;
addParameter(parser,'EvidenceDirectory',"",@is_text_scalar);
addParameter(parser,'CommandText',"run_stage_A3_tests()",@is_text_scalar);
parse(parser,varargin{:});
evidenceDirectory=strip(string(parser.Results.EvidenceDirectory));
commandText=strip(string(parser.Results.CommandText));
assert(strlength(commandText)>0,'stageA3:tests:EmptyCommandText', ...
    'CommandText must be nonempty.');
[suite,inventory]=fixed_stage_a3_suite(repoRoot);
assert_fixed_inventory(inventory);
inventoryAudit=rkkt.diagnostics.validate_stage_a3_test_inventory_contract(inventory,repoRoot);
if strlength(evidenceDirectory)==0
    runner=create_text_runner(); rawResults=runner.run(suite);
    resultTable=result_table_from_results(rawResults);
    assert_result_identity(resultTable,inventory);
    summary=make_summary(resultTable,sum(resultTable.duration_seconds), ...
        "COMPLETE","","");
    summary=attach_inventory_audit(summary,inventoryAudit); paths=empty_paths();
    disp(table(rawResults));
else
    [resultTable,summary,paths]=run_with_evidence(suite,inventory, ...
        inventoryAudit,char(evidenceDirectory),char(commandText));
end
allPass=height(resultTable)==height(inventory)&&all(resultTable.passed)&& ...
    ~any(resultTable.failed)&&~any(resultTable.incomplete)&& ...
    inventoryAudit.matches_expected;
evidence=struct('inventory',inventory,'results',resultTable, ...
    'summary',summary,'paths',paths,'inventory_audit',inventoryAudit, ...
    'all_pass',allPass);
if ~allPass
    error('stageA3:tests:Failed', ...
        'One or more fixed Stage A3 tests failed or were incomplete.');
end
end

function [suite,inventory]=fixed_stage_a3_suite(repoRoot)
relativeFiles=[ ...
    "tests/unit/test_stage_a3_index.m"
    "tests/unit/test_stage_a3_linearization.m"
    "tests/unit/test_stage_a3_solver_components.m"
    "tests/unit/test_stage_a3_historical_preflight.m"
    "tests/unit/test_stage_a3_test_inventory_contract.m"
    "tests/equivalence/test_stage_a3_direction_equivalence.m"
    "tests/equivalence/test_stage_a3_nonzero_binding_residual.m"
    "tests/integration/test_stage_a3_artifacts.m"
    "tests/integration/test_stage_a3_report.m"];
sourceFiles=strings(0,1);
for fileIndex=1:numel(relativeFiles)
    absolutePath=fullfile(repoRoot,strrep(relativeFiles(fileIndex),'/',filesep));
    assert(isfile(absolutePath),'stageA3:tests:MissingFixedTestFile', ...
        'Fixed A3 test file is missing: %s',absolutePath);
    fileSuite=matlab.unittest.TestSuite.fromFile(absolutePath);
    assert(~isempty(fileSuite),'stageA3:tests:EmptyFixedTestFile', ...
        'Fixed A3 test file defines no tests: %s',absolutePath);
    if fileIndex==1, suite=fileSuite; else, suite=[suite,fileSuite]; end %#ok<AGROW>
    sourceFiles=[sourceFiles;repmat(relativeFiles(fileIndex),numel(fileSuite),1)]; %#ok<AGROW>
end
testNames=string({suite.Name})';
inventory=table(uint32((1:numel(suite))'),testNames,sourceFiles, ...
    'VariableNames',{'test_order','test_name','source_file'});
end

function assert_fixed_inventory(inventory)
assert(height(inventory)>0,'stageA3:tests:EmptyInventory', ...
    'The explicit A3 suite must contain tests.');
names=string(inventory.test_name);
assert(all(strlength(strip(names))>0)&&numel(unique(names))==numel(names), ...
    'stageA3:tests:InvalidInventory', ...
    'A3 test names must be nonempty and unique.');
assert(all(startsWith(string(inventory.source_file),"tests/") & ...
    contains(string(inventory.source_file),"stage_a3")), ...
    'stageA3:tests:ForeignTest', ...
    'The fixed A3 inventory may contain only explicitly named A3 test files.');
end

function runner=create_text_runner()
runner=matlab.unittest.TestRunner.withTextOutput('OutputDetail', ...
    matlab.unittest.Verbosity.Detailed);
end

function [resultTable,summary,paths]=run_with_evidence( ...
        suite,inventory,inventoryAudit,evidenceDirectory,commandText)
paths=evidence_paths(evidenceDirectory);
prepare_evidence_directory(evidenceDirectory,paths);
rkkt.artifacts.write_table_csv_17g(paths.inventory,inventory);
write_utf8_text(paths.command,[commandText,newline]);
initial=incomplete_result_table(inventory,"Test execution has not completed.");
rkkt.artifacts.write_table_csv_17g(paths.results_csv,initial);
initialSummary=make_summary(initial,0,"RUNNING","","");
rkkt.artifacts.write_json_file(paths.summary,attach_inventory_audit( ...
    initialSummary,inventoryAudit));
write_utf8_text(paths.console_log,sprintf( ...
    'Stage A3 test console evidence initialized at %s.\n',char(now_text())));
rawResults=matlab.unittest.TestResult.empty; timer=tic;
diaryGuard=onCleanup(@close_diary_safely);
try
    diary(paths.console_log);
    fprintf('Fixed Stage A3 test inventory (%d tests):\n',height(inventory));
    disp(inventory(:,{'test_order','test_name','source_file'}));
    fprintf('Test command: %s\n',commandText);
    runner=create_text_runner();
    plugin=matlab.unittest.plugins.XMLPlugin.producingJUnitFormat(paths.results_xml);
    runner.addPlugin(plugin); rawResults=runner.run(suite); wall=toc(timer);
    disp(table(rawResults));
    resultTable=result_table_from_results(rawResults);
    assert_result_identity(resultTable,inventory);
    summary=make_summary(resultTable,wall,"COMPLETE","","");
    summary=attach_inventory_audit(summary,inventoryAudit);
    rkkt.artifacts.write_table_csv_17g(paths.results_csv,resultTable);
    rkkt.artifacts.write_json_file(paths.summary,summary);
    assert(is_complete_junit(paths.results_xml,height(inventory)), ...
        'stageA3:tests:IncompleteJUnit', ...
        'JUnit evidence does not contain the complete A3 inventory.');
    fprintf(['Stage A3 summary: total=%d, passed=%d, failed=%d, ' ...
        'incomplete=%d, duration=%.17g, wall=%.17g\n'], ...
        height(resultTable),sum(resultTable.passed),sum(resultTable.failed), ...
        sum(resultTable.incomplete),sum(resultTable.duration_seconds),wall);
catch exception
    wall=toc(timer);
    fprintf(2,'Stage A3 test/evidence failure:\n%s\n', ...
        getReport(exception,'extended','hyperlinks','off'));
    persist_exception_evidence(paths,inventory,inventoryAudit, ...
        rawResults,wall,exception);
    clear diaryGuard;
    rethrow(exception);
end
clear diaryGuard;
end

function paths=evidence_paths(directory)
paths=struct('results_csv',fullfile(directory,'test_results.csv'), ...
    'results_xml',fullfile(directory,'test_results.xml'), ...
    'console_log',fullfile(directory,'matlab_test_console.log'), ...
    'command',fullfile(directory,'test_command.txt'), ...
    'summary',fullfile(directory,'test_summary.json'), ...
    'inventory',fullfile(directory,'test_inventory.csv'));
end
function paths=empty_paths()
paths=struct('results_csv',"",'results_xml',"",'console_log',"", ...
    'command',"",'summary',"",'inventory',"");
end
function prepare_evidence_directory(directory,paths)
if isfile(directory), error('stageA3:tests:EvidencePathConflict', ...
        'Evidence directory conflicts with a file: %s',directory); end
if ~isfolder(directory)
    [created,message]=mkdir(directory);
    assert(created,'stageA3:tests:EvidenceDirectoryCreateFailed','%s',message);
end
targets=struct2cell(paths); exists=cellfun(@(p)isfile(p)||isfolder(p),targets);
assert(~any(exists),'stageA3:tests:EvidenceArtifactExists', ...
    'Refusing to overwrite existing A3 evidence: %s', ...
    strjoin(string(targets(exists)),', '));
end
function result=incomplete_result_table(inventory,details)
n=height(inventory);
result=table(string(inventory.test_name),false(n,1),false(n,1), ...
    true(n,1),zeros(n,1),repmat(string(details),n,1), ...
    'VariableNames',{'test_name','passed','failed','incomplete', ...
    'duration_seconds','details'});
end
function result=result_table_from_results(raw)
n=numel(raw); names=strings(n,1); passed=false(n,1); failed=false(n,1);
incomplete=false(n,1); duration_seconds=zeros(n,1); details=strings(n,1);
for k=1:n
    names(k)=string(raw(k).Name); passed(k)=logical(raw(k).Passed);
    failed(k)=logical(raw(k).Failed); incomplete(k)=logical(raw(k).Incomplete);
    duration=raw(k).Duration;
    if isduration(duration), duration_seconds(k)=seconds(duration); ...
    else, duration_seconds(k)=double(duration); end
    try
        if isempty(raw(k).Details), details(k)=""; ...
        else, details(k)=string(strtrim(evalc('disp(raw(k).Details)'))); end
    catch
        details(k)="Details unavailable.";
    end
end
result=table(names,passed,failed,incomplete,duration_seconds,details, ...
    'VariableNames',{'test_name','passed','failed','incomplete', ...
    'duration_seconds','details'});
end
function assert_result_identity(result,inventory)
names=string(result.test_name); expected=string(inventory.test_name);
assert(height(result)==height(inventory)&&numel(unique(names))==height(inventory)&& ...
    isequal(names,expected),'stageA3:tests:ResultInventoryMismatch', ...
    'A3 result identity/order differs from the persisted inventory.');
end
function summary=make_summary(result,wall,status,errorId,errorMessage)
summary=struct('execution_status',char(status),'test_total',height(result), ...
    'test_passed',sum(result.passed),'test_failed',sum(result.failed), ...
    'test_incomplete',sum(result.incomplete), ...
    'duration_seconds',sum(result.duration_seconds), ...
    'total_duration_seconds',sum(result.duration_seconds), ...
    'wall_clock_seconds',double(wall),'error_identifier',char(errorId), ...
    'error_message',char(errorMessage));
end
function persist_exception_evidence(paths,inventory,inventoryAudit,raw,wall,exception)
if isempty(raw)
    result=incomplete_result_table(inventory, ...
        "Infrastructure exception: "+string(exception.message));
else
    result=result_table_from_results(raw);
    if height(result)~=height(inventory)|| ...
            ~isequal(string(result.test_name),string(inventory.test_name))
        result=incomplete_result_table(inventory, ...
            "Incomplete result set: "+string(exception.message));
    end
end
summary=make_summary(result,wall,"ERROR",exception.identifier,exception.message);
summary=attach_inventory_audit(summary,inventoryAudit);
try
    rkkt.artifacts.write_table_csv_17g(paths.results_csv,result);
    rkkt.artifacts.write_json_file(paths.summary,summary);
catch persistenceException
    fprintf(2,'Could not update A3 CSV/JSON evidence: %s\n', ...
        persistenceException.message);
end
try
    if ~is_complete_junit(paths.results_xml,height(inventory))
        if isfile(paths.results_xml)
            backup=paths.results_xml+".plugin_incomplete";
            assert(~isfile(backup),'stageA3:tests:JUnitBackupExists', ...
                'JUnit backup already exists.');
            movefile(paths.results_xml,backup);
        end
        write_exception_junit(paths.results_xml,inventory,wall,exception);
    end
catch persistenceException
    fprintf(2,'Could not create A3 fallback JUnit: %s\n', ...
        persistenceException.message);
end
end
function summary=attach_inventory_audit(summary,audit)
summary.expected_inventory_match=logical(audit.matches_expected);
summary.expected_inventory_count=double(audit.expected_count);
summary.expected_inventory_relative_path= ...
    char(audit.expected_inventory_relative_path);
summary.expected_inventory_sha256=char(audit.expected_inventory_sha256);
summary.test_names_unique=logical(audit.test_names_unique);
summary.inventory_missing_count=double(audit.missing_count);
summary.inventory_unexpected_count=double(audit.unexpected_count);
end
function complete=is_complete_junit(pathValue,count)
complete=false; if ~isfile(pathValue), return; end
try
    document=xmlread(pathValue);
    complete=double(document.getElementsByTagName('testcase').getLength())==count;
catch
end
end
function write_exception_junit(pathValue,inventory,wall,exception)
errorText=xml_escape(string(exception.identifier)+": "+string(exception.message));
lines=["<?xml version=""1.0"" encoding=""UTF-8""?>"; ...
    sprintf('<testsuites name="stage_A3" tests="%d" failures="0" errors="%d" skipped="0" time="%.17g">',height(inventory),height(inventory),wall); ...
    sprintf('<testsuite name="fixed_stage_A3_suite" tests="%d" failures="0" errors="%d" skipped="0" time="%.17g">',height(inventory),height(inventory),wall)];
for k=1:height(inventory)
    lines=[lines;"<testcase classname=""stage_A3"" name="""+ ...
        xml_escape(inventory.test_name(k))+""" time=""0"">"; ...
        "<error message=""Test execution incomplete"">"+errorText+"</error>"; ...
        "</testcase>"]; %#ok<AGROW>
end
lines=[lines;"</testsuite>";"</testsuites>"];
write_utf8_text(pathValue,strjoin(lines,newline)+newline);
end
function value=xml_escape(value)
value=replace(string(value),'&','&amp;'); value=replace(value,'<','&lt;');
value=replace(value,'>','&gt;'); value=replace(value,'"','&quot;');
value=replace(value,'''','&apos;');
end
function write_utf8_text(pathValue,textValue)
[fileId,message]=fopen(pathValue,'wb','n','UTF-8');
assert(fileId>=0,'stageA3:tests:EvidenceFileOpenFailed','%s',message);
guard=onCleanup(@()close_file_safely(fileId));
bytes=unicode2native(char(textValue),'UTF-8'); written=fwrite(fileId,bytes,'uint8');
assert(written==numel(bytes),'stageA3:tests:EvidenceFileWriteFailed', ...
    'Incomplete write for %s.',pathValue);
status=fclose(fileId); clear guard;
assert(status==0,'stageA3:tests:EvidenceFileCloseFailed', ...
    'Could not close %s.',pathValue);
end
function close_diary_safely()
try
    diary('off');
catch
end
end
function close_file_safely(fileId)
try
    if ischar(fopen(fileId))
        fclose(fileId);
    end
catch
end
end
function value=now_text()
value=string(datetime('now','TimeZone','Asia/Shanghai', ...
    'Format','yyyy-MM-dd''T''HH:mm:ssXXX'));
end
function tf=is_text_scalar(value)
tf=ischar(value)||(isstring(value)&&isscalar(value));
end
