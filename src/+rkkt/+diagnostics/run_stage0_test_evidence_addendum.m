function result = run_stage0_test_evidence_addendum(runContext,testCommand)
%RUN_STAGE0_TEST_EVIDENCE_ADDENDUM Execute and finalize one evidence-only run.
%
% The controlled Stage 0 acceptance matrix is deliberately not loaded.
% acceptance_results.csv contains only S0-TEST-EVIDENCE-001 and therefore
% cannot be confused with a rerun of the historical ten blocking items.

validate_inputs(runContext,testCommand);
issues = rkkt.diagnostics.new_stage0_issue_log();
acceptance = make_acceptance('NOT_RUN','waiting for observed evidence', ...
    'supplementary evidence only','tests');
rkkt.artifacts.write_table_csv_17g(runContext.acceptance_results_path,acceptance);
rkkt.artifacts.write_table_csv_17g(runContext.issue_log_path,issues);

environmentPass = false;
environmentException = [];
environmentDetails = "not inspected";
try
    environment = rkkt.diagnostics.inspect_stage0_environment();
    environment = addvars(environment,repmat(string(runContext.run_id), ...
        height(environment),1),'Before',1,'NewVariableNames','run_id');
    rkkt.artifacts.write_table_csv_17g(runContext.environment_csv_path,environment);
    environmentPass = all(upper(string(environment.status)) == "PASS");
    environmentDetails = strjoin(string(environment.check_id)+"="+ ...
        string(environment.status),'; ');
catch exception
    environmentException = exception;
    environmentDetails = string(exception.message);
end
environmentEvidence = environment_manifest_evidence( ...
    runContext.environment_csv_path,environmentPass);

inputHashObject = struct();
inputHashesPass = false;
inputException = [];
try
    [inputHashes,inputHashesPass] = rkkt.data.verify_input_hashes(runContext.project_root);
    rkkt.artifacts.write_table_csv_17g(runContext.input_hashes_csv_path, ...
        input_hash_artifact(inputHashes,runContext.run_id));
    inputHashObject = input_hash_object(inputHashes);
catch exception
    inputException = exception;
end

testException = [];
if inputHashesPass
    try
        run_stage_0_tests('EvidenceDirectory',runContext.tests_dir, ...
            'TestCommand',testCommand);
    catch exception
        testException = exception;
        % The test runner writes all evidence available before rethrowing.
    end
end

[evidenceManifest,evidenceFilesPresent] = collect_test_evidence(runContext);
rkkt.artifacts.write_table_csv_17g(runContext.test_evidence_manifest_path,evidenceManifest);
evidenceManifestSha = rkkt.data.compute_sha256_file( ...
    string(runContext.test_evidence_manifest_path));
[facts,testEvidenceValid,testValidationDetails] = ...
    inspect_test_evidence(runContext,testCommand,evidenceFilesPresent);

if ~environmentPass
    if isempty(environmentException) || ...
            is_external_exception(environmentException)
        candidateStatus = "BLOCKED_EXTERNAL";
        rowStatus = "BLOCKED";
        issueStatus = 'BLOCKED';
        rootCause = 'MATLAB、稀疏线性代数、PCT或许可证环境不可用';
    else
        candidateStatus = "FAIL_RETRYABLE";
        rowStatus = "FAIL";
        issueStatus = 'OPEN';
        rootCause = '环境证据采集代码发生可修复错误';
    end
    problem = environmentDetails;
    issues = rkkt.diagnostics.append_stage0_issue(issues,runContext, ...
        'S0-TEST-EVIDENCE-001','补充run环境证据未通过',problem, ...
        rootCause,'恢复环境或修复后创建新run并重试',issueStatus, ...
        'environment.csv');
elseif ~isempty(inputException)
    if is_external_input_exception(inputException)
        candidateStatus = "BLOCKED_EXTERNAL";
        rowStatus = "BLOCKED";
        issueStatus = 'BLOCKED';
        rootCause = '输入文件、受控哈希清单或访问权限不可用';
    else
        candidateStatus = "FAIL_RETRYABLE";
        rowStatus = "FAIL";
        issueStatus = 'OPEN';
        rootCause = '输入哈希校验或证据写入代码发生可修复错误';
    end
    problem = string(inputException.message);
    issues = rkkt.diagnostics.append_stage0_issue(issues,runContext, ...
        'S0-TEST-EVIDENCE-001','补充run无法校验受控输入哈希', ...
        problem,rootCause,'恢复输入/权限或修复后创建新run重试', ...
        issueStatus,'input_hashes.csv');
elseif ~inputHashesPass
    candidateStatus = "BLOCKED_EXTERNAL";
    rowStatus = "BLOCKED";
    problem = "controlled input SHA256 did not match";
    issues = rkkt.diagnostics.append_stage0_issue(issues,runContext, ...
        'S0-TEST-EVIDENCE-001','受控输入哈希不一致',problem, ...
        '输入文件与受控清单不一致','恢复受控输入，不得修改清单或阈值', ...
        'BLOCKED','input_hashes.csv');
elseif ~testEvidenceValid || ~isempty(testException)
    if is_external_test_failure(testException,runContext)
        candidateStatus = "BLOCKED_EXTERNAL";
        rowStatus = "BLOCKED";
        issueStatus = 'BLOCKED';
        rootCause = 'MATLAB、许可证、工具箱或文件权限不可用';
    else
        candidateStatus = "FAIL_RETRYABLE";
        rowStatus = "FAIL";
        issueStatus = 'OPEN';
        rootCause = '测试失败或证据持久化实现不满足合同';
    end
    problem = testValidationDetails;
    if ~isempty(testException)
        problem = strjoin([problem;string(testException.message)],'; ');
    end
    issues = rkkt.diagnostics.append_stage0_issue(issues,runContext, ...
        'S0-TEST-EVIDENCE-001','14项测试或证据合同未通过',problem, ...
        rootCause,'修复后创建新run并重新执行全部14项测试', ...
        issueStatus,'tests');
else
    candidateStatus = "PASS";
    rowStatus = "PASS";
    problem = "all observed test and input evidence passed";
end

preReportRowStatus = rowStatus;
if candidateStatus == "PASS"
    % Do not persist PASS until the Chinese report and final evidence
    % stability checks have both completed.
    preReportRowStatus = "NOT_RUN";
end
acceptance = make_acceptance(preReportRowStatus, ...
    format_actual(facts,environmentPass,inputHashesPass, ...
    evidenceFilesPresent,false), ...
    '补充重跑证据；不代表重新执行历史10项Stage 0阻断性验收', ...
    'tests/test_results.csv; tests/test_evidence_manifest.csv');
rkkt.artifacts.write_table_csv_17g(runContext.acceptance_results_path,acceptance);
rkkt.artifacts.write_table_csv_17g(runContext.issue_log_path,issues);

updates = manifest_updates(facts,environmentEvidence,inputHashObject, ...
    evidenceManifest, ...
    evidenceManifestSha,candidateStatus,false,"","");
rkkt.artifacts.update_running_run_manifest(runContext,updates);

reportPath = fullfile(runContext.reports_dir, ...
    '阶段0_测试执行证据补充报告.docx');
reportSha = "";
reportException = [];
try
    generatedPath = rkkt.reporting.generate_stage0_test_evidence_report(runContext);
    if isstruct(generatedPath)
        names = fieldnames(generatedPath);
        if isempty(names)
            error('stage0:addendum:ReportPathMissing', ...
                'The report generator returned an empty structure.');
        end
        generatedPath = generatedPath.(names{1});
    end
    generatedPath = char(string(generatedPath));
    if ~isempty(generatedPath)
        reportPath = generatedPath;
    end
    [reportValid,validation] = rkkt.reporting.validate_docx_package(reportPath);
    if ~reportValid
        error('stage0:addendum:ReportValidationFailed','%s', ...
            strjoin(string(validation.errors),'; '));
    end
    reportSha = rkkt.data.compute_sha256_file(string(reportPath));
catch exception
    reportException = exception;
    reportValid = false;
end

[evidenceAfterReport,evidenceFilesStillPresent] = ...
    collect_test_evidence(runContext);
evidenceStable = evidenceFilesStillPresent && ...
    evidence_rows_equal(evidenceManifest,evidenceAfterReport) && ...
    rkkt.data.compute_sha256_file(string(runContext.test_evidence_manifest_path)) == ...
    evidenceManifestSha;

if candidateStatus == "PASS" && ~evidenceStable
    candidateStatus = "FAIL_RETRYABLE";
    rowStatus = "FAIL";
    problem = "test evidence or its SHA256 manifest changed during report generation";
    issueSymptom = '测试证据在报告生成期间发生变化';
    issueRootCause = '证据文件未在验收前保持不可变';
    issueEvidence = 'tests/test_evidence_manifest.csv';
    issueStatus = 'OPEN';
    issues = rkkt.diagnostics.append_stage0_issue(issues,runContext, ...
        'S0-TEST-EVIDENCE-001',issueSymptom,problem,issueRootCause, ...
        '修复后创建新run并重跑',issueStatus,issueEvidence);
elseif candidateStatus == "PASS" && ~reportValid
    if is_external_exception(reportException)
        candidateStatus = "BLOCKED_EXTERNAL";
        rowStatus = "BLOCKED";
        issueStatus = 'BLOCKED';
        issueRootCause = '报告目录或DOCX写入权限不可用';
    else
        candidateStatus = "FAIL_RETRYABLE";
        rowStatus = "FAIL";
        issueStatus = 'OPEN';
        issueRootCause = '报告生成或DOCX结构不满足合同';
    end
    problem = "Chinese DOCX generation or structural validation failed";
    if ~isempty(reportException)
        problem = string(reportException.message);
    end
    issueSymptom = '中文补充证据报告生成或验证失败';
    issueEvidence = 'reports';
    issues = rkkt.diagnostics.append_stage0_issue(issues,runContext, ...
        'S0-TEST-EVIDENCE-001',issueSymptom,problem,issueRootCause, ...
        '恢复权限或修复后创建新run并重跑',issueStatus,issueEvidence);
end

acceptance = make_acceptance(rowStatus,format_actual(facts,environmentPass, ...
    inputHashesPass, ...
    evidenceFilesPresent && evidenceStable,reportValid), ...
    '补充重跑证据；不反向证明父run当时的控制台输出', ...
    'tests/test_results.csv; tests/test_evidence_manifest.csv; reports');
rkkt.artifacts.write_table_csv_17g(runContext.acceptance_results_path,acceptance);
rkkt.artifacts.write_table_csv_17g(runContext.issue_log_path,issues);

reportRelativePath = "";
if isfile(reportPath)
    reportRelativePath = relative_run_path(runContext.root,reportPath);
end
updates = manifest_updates(facts,environmentEvidence,inputHashObject, ...
    evidenceManifest, ...
    evidenceManifestSha,candidateStatus,reportValid,reportRelativePath,reportSha);
manifest = rkkt.artifacts.finalize_run_manifest(runContext,char(candidateStatus),updates);

result = struct('run_id',string(runContext.run_id), ...
    'status',string(candidateStatus),'run_context',runContext, ...
    'acceptance',acceptance,'issues',issues,'test_summary',facts, ...
    'test_evidence_manifest',evidenceManifest, ...
    'report_path',string(reportPath),'report_valid',reportValid, ...
    'manifest',manifest,'diagnostic',string(problem));
end

function validate_inputs(runContext,testCommand)
required = {'project_root','root','run_id','stage_id','tests_dir', ...
    'acceptance_results_path','issue_log_path','input_hashes_csv_path', ...
    'test_evidence_manifest_path','reports_dir','run_manifest_path'};
if ~isstruct(runContext) || ~isscalar(runContext) || ...
        ~all(isfield(runContext,required)) || ~isfolder(runContext.root)
    error('stage0:addendum:InvalidRunContext','Invalid addendum run context.');
end
assert_context_paths(runContext);
if ~(ischar(testCommand) || (isstring(testCommand) && isscalar(testCommand))) || ...
        strlength(strtrim(string(testCommand))) == 0
    error('stage0:addendum:InvalidTestCommand', ...
        'The actual test command must be a nonempty text scalar.');
end
end

function assert_context_paths(runContext)
runRoot = canonical_path(runContext.root);
projectRoot = canonical_path(runContext.project_root);
expectedRunsRoot = canonical_path(fullfile(projectRoot,'runs'));
if ~startsWith(lower(string(runRoot)), ...
        lower(string(expectedRunsRoot)+string(filesep)))
    error('stage0:addendum:RunOutsideProject', ...
        'The addendum run root must be beneath project_root/runs.');
end
checks = { ...
    runContext.tests_dir, fullfile(runRoot,'tests'); ...
    runContext.acceptance_results_path, ...
        fullfile(runRoot,'acceptance','acceptance_results.csv'); ...
    runContext.issue_log_path, fullfile(runRoot,'issues','issue_log.csv'); ...
    runContext.input_hashes_csv_path, fullfile(runRoot,'input_hashes.csv'); ...
    runContext.test_evidence_manifest_path, ...
        fullfile(runRoot,'tests','test_evidence_manifest.csv'); ...
    runContext.reports_dir, fullfile(runRoot,'reports'); ...
    runContext.run_manifest_path, fullfile(runRoot,'run_manifest.json')};
for k = 1:size(checks,1)
    if ~strcmpi(canonical_path(checks{k,1}),canonical_path(checks{k,2}))
        error('stage0:addendum:RunContextPathMismatch', ...
            'A run context path does not belong to the current run root.');
    end
end
end

function pathValue = canonical_path(pathValue)
pathValue = char(java.io.File(char(string(pathValue))).getCanonicalPath());
end

function artifact = input_hash_artifact(hashes,runId)
n = height(hashes);
artifact = table(repmat(string(runId),n,1), ...
    "inputs/raw/"+string(hashes.fileName),string(hashes.expectedSHA256), ...
    string(hashes.actualSHA256),string(hashes.status), ...
    double(hashes.actualBytes),repmat(now_text(),n,1), ...
    'VariableNames',{'run_id','relative_path','expected_sha256', ...
    'actual_sha256','status','bytes','checked_at'});
end

function object = input_hash_object(hashes)
object = struct();
for k = 1:height(hashes)
    name = string(hashes.fileName(k));
    if name == "基础参数.xlsx"
        field = 'base_parameters';
    elseif name == "输入数据.xlsx"
        field = 'timeseries';
    else
        field = matlab.lang.makeValidName(char(name));
    end
    object.(field) = char(string(hashes.actualSHA256(k)));
end
end

function [manifest,allPresent] = collect_test_evidence(runContext)
names = ["test_inventory.csv";"test_results.csv";"test_results.xml"; ...
    "matlab_test_console.log";"test_command.txt";"test_summary.json"];
types = ["inventory";"csv_results";"junit";"console_log"; ...
    "command";"summary"];
n = numel(names);
existsFlag = false(n,1);
bytes = nan(n,1);
sha = strings(n,1);
for k = 1:n
    pathValue = fullfile(runContext.tests_dir,char(names(k)));
    existsFlag(k) = isfile(pathValue);
    if existsFlag(k)
        info = dir(pathValue);
        bytes(k) = double(info.bytes);
        sha(k) = rkkt.data.compute_sha256_file(string(pathValue));
    end
end
relativePath = "tests/"+names;
manifest = table(relativePath,types,existsFlag,bytes,sha, ...
    repmat(now_text(),n,1),'VariableNames',{'relative_path', ...
    'evidence_type','exists','bytes','sha256','recorded_at'});
allPresent = all(existsFlag & bytes > 0 & strlength(sha)==64);
end

function [facts,valid,details] = inspect_test_evidence(runContext, ...
        testCommand,allPresent)
facts = struct('test_total',0,'test_passed',0,'test_failed',0, ...
    'test_incomplete',0,'duration_seconds',0);
problems = strings(0,1);
if ~allPresent
    problems(end+1,1) = "one or more required evidence files are missing or empty";
end

inventoryPath = fullfile(runContext.tests_dir,'test_inventory.csv');
resultPath = fullfile(runContext.tests_dir,'test_results.csv');
if isfile(inventoryPath)
    try
        inventory = readtable(inventoryPath,'TextType','string', ...
            'VariableNamingRule','preserve','Encoding','UTF-8');
        if ~ismember('test_name',inventory.Properties.VariableNames)
            problems(end+1,1) = "test_inventory.csv lacks test_name";
            inventoryNames = strings(0,1);
        else
            inventoryNames = string(inventory.test_name);
            if height(inventory) ~= 14
                problems(end+1,1) = "test inventory count is not 14";
            end
            if numel(unique(inventoryNames)) ~= numel(inventoryNames)
                problems(end+1,1) = "test inventory names are not unique";
            end
        end
    catch exception
        inventoryNames = strings(0,1);
        problems(end+1,1) = "inventory read failed: "+string(exception.message);
    end
else
    inventoryNames = strings(0,1);
end

if isfile(resultPath)
    try
        testResults = readtable(resultPath,'TextType','string', ...
            'VariableNamingRule','preserve','Encoding','UTF-8');
        required = {'test_name','passed','failed','incomplete', ...
            'duration_seconds','details'};
        if ~all(ismember(required,testResults.Properties.VariableNames))
            problems(end+1,1) = "test_results.csv lacks required columns";
        else
            resultNames = string(testResults.test_name);
            passed = logical_column(testResults.passed);
            failed = logical_column(testResults.failed);
            incomplete = logical_column(testResults.incomplete);
            durations = double_column(testResults.duration_seconds);
            facts.test_total = height(testResults);
            facts.test_passed = sum(passed);
            facts.test_failed = sum(failed);
            facts.test_incomplete = sum(incomplete);
            facts.duration_seconds = sum(durations);
            if height(testResults) ~= 14
                problems(end+1,1) = "test result count is not 14";
            end
            if numel(unique(resultNames)) ~= numel(resultNames)
                problems(end+1,1) = "test result names are not unique";
            end
            if ~isempty(inventoryNames) && ...
                    ~isequal(sort(resultNames),sort(inventoryNames))
                problems(end+1,1) = "inventory and result names differ";
            end
            if any(~isfinite(durations) | durations < 0)
                problems(end+1,1) = "test durations contain invalid values";
            end
        end
    catch exception
        problems(end+1,1) = "result CSV read failed: "+string(exception.message);
    end
end

summaryPath = fullfile(runContext.tests_dir,'test_summary.json');
if isfile(summaryPath)
    try
        summary = jsondecode(fileread(summaryPath));
        [summaryFacts,summaryOk] = normalize_summary(summary);
        if ~summaryOk || ~counts_equal(summaryFacts,facts)
            problems(end+1,1) = "test summary does not match result CSV";
        end
        if ~isfield(summary,'execution_status') || ...
                upper(strip(string(summary.execution_status))) ~= "COMPLETE"
            problems(end+1,1) = "test summary execution_status is not COMPLETE";
        end
    catch exception
        problems(end+1,1) = "summary read failed: "+string(exception.message);
    end
end

commandPath = fullfile(runContext.tests_dir,'test_command.txt');
if isfile(commandPath)
    persistedCommand = strip(string(fileread(commandPath)));
    if persistedCommand ~= strip(string(testCommand))
        problems(end+1,1) = "persisted test command differs from actual command";
    end
end

consolePath = fullfile(runContext.tests_dir,'matlab_test_console.log');
if isfile(consolePath)
    try
        consoleText = string(fileread(consolePath));
        if ~contains(consoleText,'Fixed stage-0 test inventory (14 tests)') || ...
                ~contains(consoleText,'Stage-0 test summary: total=14')
            problems(end+1,1) = ...
                "MATLAB console log lacks the inventory or final summary marker";
        end
    catch exception
        problems(end+1,1) = "console log read failed: "+ ...
            string(exception.message);
    end
end

xmlPath = fullfile(runContext.tests_dir,'test_results.xml');
if isfile(xmlPath)
    try
        document = xmlread(xmlPath);
        caseCount = document.getElementsByTagName('testcase').getLength();
        if double(caseCount) ~= 14
            problems(end+1,1) = "JUnit testcase count is not 14";
        else
            caseNodes = document.getElementsByTagName('testcase');
            junitNames = strings(14,1);
            for caseIndex = 1:14
                junitNames(caseIndex) = string(char( ...
                    caseNodes.item(caseIndex-1).getAttribute('name')));
            end
            expectedJunitNames = extractAfter(inventoryNames,'/');
            if numel(unique(expectedJunitNames)) ~= 14 || ...
                    ~isequal(sort(junitNames),sort(expectedJunitNames))
                problems(end+1,1) = ...
                    "JUnit testcase names do not match the fixed inventory";
            end
        end
        if double(document.getElementsByTagName('failure').getLength()) ~= 0 || ...
                double(document.getElementsByTagName('error').getLength()) ~= 0 || ...
                double(document.getElementsByTagName('skipped').getLength()) ~= 0
            problems(end+1,1) = ...
                "JUnit contains a failure, error, or skipped testcase";
        end
    catch exception
        problems(end+1,1) = "JUnit XML is invalid: "+string(exception.message);
    end
end

if facts.test_total ~= 14 || facts.test_passed ~= 14 || ...
        facts.test_failed ~= 0 || facts.test_incomplete ~= 0
    problems(end+1,1) = "required result is 14 passed, 0 failed, 0 incomplete";
end
valid = isempty(problems);
if valid
    details = "PASS";
else
    details = strjoin(unique(problems,'stable'),'; ');
end
end

function logicalValues = logical_column(values)
if islogical(values)
    logicalValues = values;
elseif isnumeric(values)
    logicalValues = values ~= 0;
else
    textValues = lower(strip(string(values)));
    if any(~ismember(textValues,["true","false","1","0"]))
        error('stage0:addendum:InvalidLogicalCsv', ...
            'A logical evidence column contains an invalid value.');
    end
    logicalValues = textValues == "true" | textValues == "1";
end
logicalValues = logicalValues(:);
end

function numericValues = double_column(values)
if isnumeric(values)
    numericValues = double(values);
else
    numericValues = str2double(string(values));
end
numericValues = numericValues(:);
end

function [facts,ok] = normalize_summary(summary)
facts = struct('test_total',read_summary_number(summary, ...
    {'test_total','total'}),'test_passed',read_summary_number(summary, ...
    {'test_passed','passed'}),'test_failed',read_summary_number(summary, ...
    {'test_failed','failed'}),'test_incomplete',read_summary_number(summary, ...
    {'test_incomplete','incomplete'}),'duration_seconds', ...
    read_summary_number(summary,{'duration_seconds','total_duration_seconds'}));
values = [facts.test_total,facts.test_passed,facts.test_failed, ...
    facts.test_incomplete,facts.duration_seconds];
ok = all(isfinite(values));
end

function value = read_summary_number(summary,candidates)
value = NaN;
for k = 1:numel(candidates)
    if isfield(summary,candidates{k})
        candidate = summary.(candidates{k});
        if isnumeric(candidate) && isscalar(candidate)
            value = double(candidate);
        else
            value = str2double(string(candidate));
        end
        return
    end
end
end

function equal = counts_equal(first,second)
equal = first.test_total == second.test_total && ...
    first.test_passed == second.test_passed && ...
    first.test_failed == second.test_failed && ...
    first.test_incomplete == second.test_incomplete && ...
    abs(first.duration_seconds-second.duration_seconds) <= ...
    max(1e-12,eps(max(first.duration_seconds,second.duration_seconds))*8);
end

function external = is_external_test_failure(testException,runContext)
texts = strings(0,1);
failedNames = strings(0,1);
if ~isempty(testException)
    texts(end+1,1) = string(testException.identifier)+" "+ ...
        string(testException.message);
end
resultPath = fullfile(runContext.tests_dir,'test_results.csv');
if isfile(resultPath)
    try
        results = readtable(resultPath,'TextType','string', ...
            'VariableNamingRule','preserve','Encoding','UTF-8');
        failed = logical_column(results.failed) | logical_column(results.incomplete);
        if ismember('details',results.Properties.VariableNames)
            texts = [texts; string(results.details(failed))]; %#ok<AGROW>
        end
        if ismember('test_name',results.Properties.VariableNames)
            failedNames = string(results.test_name(failed));
            texts = [texts; failedNames]; %#ok<AGROW>
        end
    catch
    end
end
combined = lower(strjoin(texts," "));
markers = ["license","parallel computing toolbox","matlab r2024a", ...
    "permission denied","access is denied","许可证","工具箱", ...
    "权限"];
environmentExternal = false;
if any(contains(failedNames,'test_stage0_environment'))
    try
        environment = rkkt.diagnostics.inspect_stage0_environment();
        environmentExternal = any(upper(string(environment.status)) ~= "PASS");
    catch
        % If the independent environment probe itself breaks without an
        % external diagnostic marker, retain FAIL_RETRYABLE classification.
    end
end
external = any(contains(combined,markers)) || environmentExternal;
end

function external = is_external_exception(exception)
if isempty(exception)
    external = false;
    return;
end
diagnostic = lower(string(exception.identifier)+" "+ ...
    string(exception.message));
markers = ["license", "parallel computing toolbox", ...
    "permission denied", "access is denied", "license manager", ...
    "许可证", "工具箱", "权限"];
external = any(contains(diagnostic,markers));
end

function external = is_external_input_exception(exception)
identifier = string(exception.identifier);
externalIdentifiers = [ ...
    "stage0:HashManifestMissing", ...
    "stage0:RawInputDirectoryMissing", ...
    "stage0:InputFileMissing", ...
    "stage0:InputFileOpenFailed", ...
    "stage0:InvalidHashManifest", ...
    "stage0:DuplicateManifestFile", ...
    "stage0:InvalidManifestPath"];
external = ismember(identifier,externalIdentifiers) || ...
    is_external_exception(exception);
end

function equal = evidence_rows_equal(first,second)
equal = height(first) == height(second) && ...
    isequal(string(first.relative_path),string(second.relative_path)) && ...
    isequal(logical(first.exists),logical(second.exists)) && ...
    isequaln(double(first.bytes),double(second.bytes)) && ...
    isequal(lower(string(first.sha256)),lower(string(second.sha256)));
end

function acceptance = make_acceptance(status,actual,comparison,evidence)
acceptance = table("S0-TEST-EVIDENCE-001", ...
    "原有14项Stage 0测试补充重跑证据完整且全部通过", ...
    "total=14; passed=14; failed=0; incomplete=0; 输入哈希、六类测试证据、证据SHA256及中文报告均有效", ...
    string(actual),string(comparison),string(status),true,string(evidence), ...
    now_text(),'VariableNames',{'test_id','requirement','threshold', ...
    'actual_value','comparison','status','blocking','evidence_path','checked_at'});
end

function text = format_actual(facts,environmentPass,inputHashesPass, ...
        evidencePresent,reportValid)
text = string(sprintf(['total=%d; passed=%d; failed=%d; incomplete=%d; ' ...
    'duration_seconds=%.17g; environment=%s; input_hashes=%s; ' ...
    'evidence_files=%s; report=%s'], ...
    facts.test_total,facts.test_passed,facts.test_failed, ...
    facts.test_incomplete,facts.duration_seconds,pass_fail(environmentPass), ...
    pass_fail(inputHashesPass), ...
    pass_fail(evidencePresent),pass_fail(reportValid)));
end

function value = pass_fail(flag)
if flag
    value = 'PASS';
else
    value = 'FAIL';
end
end

function updates = manifest_updates(facts,environmentEvidence,inputHashes, ...
        evidenceManifest, ...
        evidenceManifestSha,candidateStatus,reportValid,reportPath,reportSha)
evidenceFiles = table2struct(evidenceManifest);
updates = struct('input_hashes',inputHashes, ...
    'environment',environmentEvidence, ...
    'test_total',facts.test_total,'test_passed',facts.test_passed, ...
    'test_failed',facts.test_failed,'test_incomplete',facts.test_incomplete, ...
    'test_duration_seconds',facts.duration_seconds, ...
    'test_evidence_files',evidenceFiles, ...
    'test_evidence_manifest','tests/test_evidence_manifest.csv', ...
    'test_evidence_manifest_sha256',char(evidenceManifestSha), ...
    'candidate_terminal_status',char(candidateStatus), ...
    'report',struct('relative_path',char(reportPath), ...
    'sha256',char(reportSha),'structure_valid',logical(reportValid)));
end

function evidence = environment_manifest_evidence(filePath,allPassed)
evidence = struct('relative_path','environment.csv','sha256','', ...
    'all_checks_passed',logical(allPassed));
if isfile(filePath)
    evidence.sha256 = char(rkkt.data.compute_sha256_file(string(filePath)));
end
end

function relative = relative_run_path(runRoot,filePath)
rootText = string(char(java.io.File(runRoot).getCanonicalPath()));
fileText = string(char(java.io.File(filePath).getCanonicalPath()));
prefix = rootText + string(filesep);
if ~startsWith(fileText,prefix)
    error('stage0:addendum:ReportOutsideRun', ...
        'The report path is outside the current run: %s',fileText);
end
relative = replace(extractAfter(fileText,strlength(prefix)),'\','/');
end

function value = now_text()
value = string(datetime('now','TimeZone','Asia/Shanghai', ...
    'Format','yyyy-MM-dd''T''HH:mm:ssXXX'));
end
