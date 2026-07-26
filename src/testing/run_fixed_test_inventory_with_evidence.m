function evidence = run_fixed_test_inventory_with_evidence( ...
        repositoryRoot,relativeFiles,expectedInventoryPath,options)
%RUN_FIXED_TEST_INVENTORY_WITH_EVIDENCE Execute an exact persisted suite.

arguments
    repositoryRoot (1,1) string
    relativeFiles (:,1) string
    expectedInventoryPath (1,1) string
    options.EvidenceDirectory (1,1) string = ""
    options.CommandText (1,1) string = "NOT_RECORDED"
    options.SuiteLabel (1,1) string = "fixed_suite"
end

[suite,inventory] = make_suite(repositoryRoot,relativeFiles);
expected = read_csv_table(expectedInventoryPath);
assert(isequal(string(expected.Properties.VariableNames), ...
    ["test_order","test_name","source_file"]) && ...
    height(expected)==height(inventory) && ...
    isequal(double(expected.test_order),double(inventory.test_order)) && ...
    isequal(string(expected.test_name),string(inventory.test_name)) && ...
    isequal(string(expected.source_file),string(inventory.source_file)), ...
    "stageA4:tests:InventoryMismatch", ...
    "The executable test inventory differs from its version-controlled list.");
assert(numel(unique(inventory.test_name))==height(inventory), ...
    "stageA4:tests:DuplicateTestName", ...
    "Every fixed test name must be unique.");

directory = strip(options.EvidenceDirectory);
if strlength(directory)==0
    runner = text_runner();
    timer = tic;
    raw = runner.run(suite);
    wall = toc(timer);
    results = result_table(raw);
    paths = empty_paths();
else
    paths = evidence_paths(directory);
    prepare_directory(directory,paths);
    write_table_csv_17g(paths.inventory,inventory);
    write_text(paths.command,options.CommandText+newline);
    write_table_csv_17g(paths.results_csv, ...
        incomplete_results(inventory,"execution not completed"));
    write_json_file(paths.summary, ...
        make_summary(incomplete_results(inventory, ...
        "execution not completed"),0,"RUNNING","","", ...
        expectedInventoryPath,options.SuiteLabel));
    write_text(paths.console_log, ...
        "Test evidence initialized at "+now_text()+"."+newline);
    diaryGuard = onCleanup(@close_diary);
    raw = matlab.unittest.TestResult.empty;
    timer = tic;
    try
        diary(paths.console_log);
        fprintf("Fixed %s inventory (%d tests):\n", ...
            options.SuiteLabel,height(inventory));
        disp(inventory);
        fprintf("Actual test command: %s\n",options.CommandText);
        runner = text_runner();
        plugin = matlab.unittest.plugins.XMLPlugin.producingJUnitFormat( ...
            paths.results_xml);
        runner.addPlugin(plugin);
        raw = runner.run(suite);
        wall = toc(timer);
        results = result_table(raw);
        assert_result_identity(results,inventory);
        summary = make_summary(results,wall,"COMPLETE","","", ...
            expectedInventoryPath,options.SuiteLabel);
        write_table_csv_17g(paths.results_csv,results);
        write_json_file(paths.summary,summary);
        assert(junit_complete(paths.results_xml,height(inventory)), ...
            "stageA4:tests:IncompleteJUnit", ...
            "JUnit evidence does not contain the complete fixed inventory.");
        clear diaryGuard
        write_evidence_hashes(paths);
    catch cause
        wall = toc(timer);
        fprintf(2,"Fixed-suite execution failed:\n%s\n", ...
            getReport(cause,"extended","hyperlinks","off"));
        clear diaryGuard
        persist_failure(paths,inventory,raw,wall,cause, ...
            expectedInventoryPath,options.SuiteLabel);
        rethrow(cause)
    end
end

assert_result_identity(results,inventory);
summary = make_summary(results,wall,"COMPLETE","","", ...
    expectedInventoryPath,options.SuiteLabel);
allPass = height(results)==height(inventory) && ...
    all(results.passed) && ~any(results.failed) && ...
    ~any(results.incomplete);
evidence = struct("inventory",inventory,"results",results, ...
    "summary",summary,"paths",paths,"all_pass",allPass, ...
    "expected_inventory_sha256", ...
        compute_sha256_file(expectedInventoryPath));
if ~allPass
    error("stageA4:tests:FixedSuiteFailed", ...
        "One or more fixed tests failed or were incomplete.");
end
end

function value = read_csv_table(pathValue)
options = detectImportOptions(pathValue,"Delimiter",",", ...
    "TextType","string","VariableNamingRule","preserve");
value = readtable(pathValue,options);
end

function [suite,inventory] = make_suite(root,relativeFiles)
sourceFiles = strings(0,1);
for k = 1:numel(relativeFiles)
    absolute = fullfile(root,replace(relativeFiles(k),"/",filesep));
    assert(isfile(absolute),"stageA4:tests:MissingFile", ...
        "Fixed test file is missing: %s",absolute);
    current = matlab.unittest.TestSuite.fromFile(absolute);
    assert(~isempty(current),"stageA4:tests:EmptyFile", ...
        "Fixed test file contains no tests: %s",absolute);
    if k==1
        suite = current;
    else
        suite = [suite,current]; %#ok<AGROW>
    end
    sourceFiles = [sourceFiles; ...
        repmat(relativeFiles(k),numel(current),1)]; %#ok<AGROW>
end
names = string({suite.Name}).';
inventory = table(uint32((1:numel(suite)).'),names,sourceFiles, ...
    'VariableNames',{'test_order','test_name','source_file'});
end

function runner = text_runner()
runner = matlab.unittest.TestRunner.withTextOutput( ...
    "OutputDetail",matlab.unittest.Verbosity.Detailed);
end

function result = result_table(raw)
n = numel(raw);
test_name = strings(n,1);
passed = false(n,1);
failed = false(n,1);
incomplete = false(n,1);
duration_seconds = zeros(n,1);
details = strings(n,1);
for k = 1:n
    test_name(k) = string(raw(k).Name);
    passed(k) = logical(raw(k).Passed);
    failed(k) = logical(raw(k).Failed);
    incomplete(k) = logical(raw(k).Incomplete);
    duration = raw(k).Duration;
    if isduration(duration)
        duration_seconds(k) = seconds(duration);
    else
        duration_seconds(k) = double(duration);
    end
    try
        details(k) = string(strtrim(evalc("disp(raw(k).Details)")));
    catch
        details(k) = "details unavailable";
    end
end
result = table(test_name,passed,failed,incomplete,duration_seconds,details);
end

function result = incomplete_results(inventory,message)
n = height(inventory);
result = table(string(inventory.test_name),false(n,1),false(n,1), ...
    true(n,1),zeros(n,1),repmat(string(message),n,1), ...
    'VariableNames',{'test_name','passed','failed','incomplete', ...
    'duration_seconds','details'});
end

function assert_result_identity(result,inventory)
assert(height(result)==height(inventory) && ...
    isequal(string(result.test_name),string(inventory.test_name)) && ...
    numel(unique(string(result.test_name)))==height(result), ...
    "stageA4:tests:ResultIdentity", ...
    "Test results differ from the fixed inventory identity/order.");
end

function value = make_summary(result,wall,status,errorId,errorMessage, ...
        expectedPath,suiteLabel)
value = struct( ...
    "execution_status",char(status), ...
    "suite_label",char(suiteLabel), ...
    "test_total",height(result), ...
    "test_passed",nnz(result.passed), ...
    "test_failed",nnz(result.failed), ...
    "test_incomplete",nnz(result.incomplete), ...
    "duration_seconds",sum(result.duration_seconds), ...
    "wall_clock_seconds",wall, ...
    "test_names_unique", ...
        numel(unique(string(result.test_name)))==height(result), ...
    "expected_inventory_path",char(expectedPath), ...
    "expected_inventory_sha256", ...
        char(compute_sha256_file(expectedPath)), ...
    "error_identifier",char(errorId), ...
    "error_message",char(errorMessage));
end

function paths = evidence_paths(directory)
paths = struct( ...
    "results_csv",fullfile(directory,"test_results.csv"), ...
    "results_xml",fullfile(directory,"test_results.xml"), ...
    "console_log",fullfile(directory,"matlab_test_console.log"), ...
    "command",fullfile(directory,"test_command.txt"), ...
    "summary",fullfile(directory,"test_summary.json"), ...
    "inventory",fullfile(directory,"test_inventory.csv"), ...
    "hashes",fullfile(directory,"test_evidence_sha256.csv"));
end

function paths = empty_paths()
paths = struct("results_csv","","results_xml","","console_log","", ...
    "command","","summary","","inventory","","hashes","");
end

function prepare_directory(directory,paths)
if ~isfolder(directory)
    [created,message] = mkdir(directory);
    assert(created,"stageA4:tests:EvidenceDirectory","%s",message);
end
targets = string(struct2cell(paths));
assert(~any(isfile(targets)|isfolder(targets)), ...
    "stageA4:tests:EvidenceExists", ...
    "Test evidence targets are non-overwriting.");
end

function persist_failure(paths,inventory,raw,wall,cause,expectedPath,label)
if isempty(raw)
    results = incomplete_results(inventory, ...
        string(cause.identifier)+": "+string(cause.message));
else
    results = result_table(raw);
    if height(results)~=height(inventory) || ...
            ~isequal(results.test_name,inventory.test_name)
        results = incomplete_results(inventory, ...
            "incomplete result set: "+string(cause.message));
    end
end
write_table_csv_17g_atomic(paths.results_csv,results);
write_json_file(paths.summary,make_summary(results,wall,"ERROR", ...
    cause.identifier,cause.message,expectedPath,label));
if ~junit_complete(paths.results_xml,height(inventory))
    if isfile(paths.results_xml)
        [moved,message] = movefile(paths.results_xml, ...
            paths.results_xml+".incomplete");
        assert(moved,"stageA4:tests:JUnitPreserve","%s",message);
    end
    write_failure_junit(paths.results_xml,inventory,wall,cause,label);
end
write_evidence_hashes(paths);
end

function write_failure_junit(pathValue,inventory,wall,cause,label)
lines = ["<?xml version=""1.0"" encoding=""UTF-8""?>"; ...
    "<testsuites name="""+xml_escape(label)+""" tests="""+ ...
        string(height(inventory))+""" failures=""0"" errors="""+ ...
        string(height(inventory))+""" skipped=""0"" time="""+ ...
        compose("%.17g",wall)+""">"; ...
    "<testsuite name="""+xml_escape(label)+""" tests="""+ ...
        string(height(inventory))+""" failures=""0"" errors="""+ ...
        string(height(inventory))+""" skipped=""0"" time="""+ ...
        compose("%.17g",wall)+""">"];
message = xml_escape(string(cause.identifier)+": "+string(cause.message));
for k = 1:height(inventory)
    lines = [lines; ...
        "<testcase classname="""+xml_escape(label)+""" name="""+ ...
        xml_escape(inventory.test_name(k))+""" time=""0"">"; ...
        "<error message=""execution incomplete"">"+message+"</error>"; ...
        "</testcase>"]; %#ok<AGROW>
end
lines = [lines;"</testsuite>";"</testsuites>"];
write_text(pathValue,strjoin(lines,newline)+newline);
end

function passed = junit_complete(pathValue,count)
passed = false;
if ~isfile(pathValue)
    return
end
try
    document = xmlread(pathValue);
    passed = double(document.getElementsByTagName( ...
        "testcase").getLength())==count;
catch
end
end

function write_evidence_hashes(paths)
names = ["test_inventory.csv";"test_results.csv";"test_results.xml"; ...
    "matlab_test_console.log";"test_command.txt";"test_summary.json"];
targets = [string(paths.inventory);string(paths.results_csv); ...
    string(paths.results_xml);string(paths.console_log); ...
    string(paths.command);string(paths.summary)];
sha256 = strings(numel(targets),1);
bytes = zeros(numel(targets),1);
status = repmat("PASS",numel(targets),1);
for k = 1:numel(targets)
    assert(isfile(targets(k)),"stageA4:tests:EvidenceMissing", ...
        "Test evidence is missing: %s",targets(k));
    sha256(k) = compute_sha256_file(targets(k));
    info = dir(targets(k));
    bytes(k) = info.bytes;
end
write_table_csv_17g(paths.hashes,table(names,sha256,bytes,status));
end

function write_text(pathValue,value)
[fileId,message] = fopen(pathValue,"wb","n","UTF-8");
assert(fileId>=0,"stageA4:tests:TextOpen","%s",message);
guard = onCleanup(@()close_file(fileId));
bytes = unicode2native(char(value),"UTF-8");
count = fwrite(fileId,bytes,"uint8");
assert(count==numel(bytes),"stageA4:tests:TextWrite", ...
    "Incomplete write: %s",pathValue);
status = fclose(fileId);
clear guard
assert(status==0,"stageA4:tests:TextClose","Could not close %s.",pathValue);
end

function close_diary()
try
    diary("off");
catch
end
end

function close_file(fileId)
try
    if ischar(fopen(fileId))
        fclose(fileId);
    end
catch
end
end

function value = xml_escape(value)
value = replace(string(value),"&","&amp;");
value = replace(value,"<","&lt;");
value = replace(value,">","&gt;");
value = replace(value,'"',"&quot;");
value = replace(value,"'","&apos;");
end

function value = now_text()
value = string(datetime("now","TimeZone","Asia/Shanghai", ...
    "Format","yyyy-MM-dd'T'HH:mm:ssXXX"));
end
