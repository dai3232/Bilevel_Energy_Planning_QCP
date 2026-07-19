function reportPath = generate_stage0_test_evidence_report(runContext)
%GENERATE_STAGE0_TEST_EVIDENCE_REPORT Build the stage_0 test addendum report.
%   REPORTPATH = GENERATE_STAGE0_TEST_EVIDENCE_REPORT(RUNCONTEXT) reads the
%   finalized test artifacts beneath RUNCONTEXT.root and creates a Chinese
%   DOCX report. The function refuses to overwrite an existing report and
%   validates the staged DOCX package before publishing it.

arguments
    runContext (1, 1) struct
end

if ~isfield(runContext, 'root')
    error('stage0:testEvidenceReport:MissingRunRoot', ...
        'runContext.root is required.');
end

runRoot = char(string(runContext.root));
if ~isfolder(runRoot)
    error('stage0:testEvidenceReport:MissingRunRoot', ...
        'The run artifact root does not exist: %s', runRoot);
end

paths = locate_sources(runRoot, runContext);
facts = load_report_facts(paths, runRoot);
validate_report_facts(facts);

reportDir = fullfile(runRoot, 'reports');
if ~isfolder(reportDir)
    [ok, message] = mkdir(reportDir);
    if ~ok
        error('stage0:testEvidenceReport:CreateDirectoryFailed', ...
            '%s', message);
    end
end

reportPath = fullfile(reportDir, ...
    '阶段0_测试执行证据补充报告.docx');
if isfile(reportPath)
    error('stage0:testEvidenceReport:ArtifactExists', ...
        'Refusing to overwrite an existing report: %s', reportPath);
end

stagingRoot = tempname;
mkdir(stagingRoot);
stagingCleanup = onCleanup(@() remove_temp_tree(stagingRoot)); %#ok<NASGU>
stagedPath = fullfile(stagingRoot, ...
    '阶段0_测试执行证据补充报告.docx');

write_docx_package(stagedPath, facts, build_report_body(facts));
[isValid, validation] = validate_docx_package(stagedPath);
if ~isValid
    error('stage0:testEvidenceReport:InvalidDocxPackage', ...
        'Generated DOCX failed package validation: %s', ...
        strjoin(validation.errors, '; '));
end

if isfile(reportPath)
    error('stage0:testEvidenceReport:ArtifactExists', ...
        'Refusing to overwrite an existing report: %s', reportPath);
end
[ok, message] = movefile(stagedPath, reportPath);
if ~ok
    error('stage0:testEvidenceReport:PublishFailed', '%s', message);
end
end

function paths = locate_sources(runRoot, runContext)
if isfield(runContext, 'tests_dir')
    testsDir = char(string(runContext.tests_dir));
elseif isfield(runContext, 'testsDir')
    testsDir = char(string(runContext.testsDir));
else
    testsDir = fullfile(runRoot, 'tests');
end
canonicalRunRoot = char(java.io.File(runRoot).getCanonicalPath());
canonicalTestsDir = char(java.io.File(testsDir).getCanonicalPath());
expectedTestsDir = char(java.io.File(fullfile( ...
    canonicalRunRoot, 'tests')).getCanonicalPath());
if ~strcmpi(canonicalTestsDir, expectedTestsDir)
    error('stage0:testEvidenceReport:TestsOutsideRun', ...
        'Test evidence must come from the current run tests directory.');
end
testsDir = canonicalTestsDir;
if ~isfolder(testsDir)
    error('stage0:testEvidenceReport:MissingTestsDirectory', ...
        'The test evidence directory does not exist: %s', testsDir);
end

paths = struct;
paths.run_manifest = require_file(fullfile(runRoot, 'run_manifest.json'));
paths.environment = require_file(fullfile(runRoot, 'environment.csv'));
paths.input_hashes = require_file(fullfile(runRoot, 'input_hashes.csv'));
paths.test_inventory = require_file(fullfile(testsDir, ...
    'test_inventory.csv'));
paths.test_results = require_file(fullfile(testsDir, 'test_results.csv'));
paths.junit = require_file(fullfile(testsDir, 'test_results.xml'));
paths.console_log = require_file(fullfile(testsDir, ...
    'matlab_test_console.log'));
paths.test_command = require_file(fullfile(testsDir, 'test_command.txt'));
paths.test_summary = require_file(fullfile(testsDir, 'test_summary.json'));

evidenceCandidates = { ...
    fullfile(testsDir, 'test_evidence_manifest.csv'), ...
    fullfile(runRoot, 'test_evidence_manifest.csv'), ...
    fullfile(runRoot, 'evidence_manifest.csv')};
paths.evidence_manifest = '';
for index = 1:numel(evidenceCandidates)
    if isfile(evidenceCandidates{index})
        paths.evidence_manifest = evidenceCandidates{index};
        break;
    end
end
if isempty(paths.evidence_manifest)
    error('stage0:testEvidenceReport:MissingEvidenceManifest', ...
        'test_evidence_manifest.csv is required before report generation.');
end
end

function filePath = require_file(filePath)
if ~isfile(filePath)
    error('stage0:testEvidenceReport:MissingArtifact', ...
        'Required run artifact is missing: %s', filePath);
end
end

function facts = load_report_facts(paths, runRoot)
facts = struct;
facts.paths = paths;
facts.runRoot = string(runRoot);
facts.manifest = read_json_artifact(paths.run_manifest);
facts.summary = read_json_artifact(paths.test_summary);
facts.environment = read_csv_artifact(paths.environment);
facts.inputHashes = read_csv_artifact(paths.input_hashes);
facts.inventory = read_csv_artifact(paths.test_inventory);
facts.results = read_csv_artifact(paths.test_results);
facts.evidenceManifest = read_csv_artifact(paths.evidence_manifest);
facts.command = strtrim(string(fileread(paths.test_command)));

facts.runId = require_manifest_text(facts.manifest, {'run_id', 'runId'});
facts.stageId = optional_manifest_text(facts.manifest, ...
    {'stage_id', 'stageId'}, 'stage_0');
facts.runPurpose = require_manifest_text(facts.manifest, {'run_purpose'});
facts.parentRunId = require_manifest_text(facts.manifest, {'parent_run_id'});
facts.historicalBaselineCommit = require_manifest_text(facts.manifest, ...
    {'historical_baseline_commit'});
facts.gitCommit = require_manifest_text(facts.manifest, ...
    {'git_commit', 'current_git_commit'});
facts.manifestStatus = optional_manifest_text(facts.manifest, ...
    {'status'}, '未记录');
facts.candidateTerminalStatus = optional_manifest_text(facts.manifest, ...
    {'candidate_terminal_status'}, '未记录');
facts.manifestTestCommand = require_manifest_text(facts.manifest, ...
    {'actual_test_command', 'test_command'});

inventoryNameIndex = require_column(facts.inventory, {'test_name'});
resultNameIndex = require_column(facts.results, {'test_name'});
passedIndex = require_column(facts.results, {'passed'});
failedIndex = require_column(facts.results, {'failed'});
incompleteIndex = require_column(facts.results, {'incomplete'});
durationIndex = require_column(facts.results, {'duration_seconds'});

inventoryNames = strtrim(table_column_strings(facts.inventory, ...
    inventoryNameIndex));
resultNames = strtrim(table_column_strings(facts.results, resultNameIndex));
passed = parse_boolean_column(facts.results, passedIndex, 'passed');
failed = parse_boolean_column(facts.results, failedIndex, 'failed');
incomplete = parse_boolean_column(facts.results, incompleteIndex, ...
    'incomplete');
durations = parse_nonnegative_numbers(facts.results, durationIndex, ...
    'duration_seconds');

if numel(inventoryNames) ~= 14 || numel(resultNames) ~= 14
    error('stage0:testEvidenceReport:WrongTestCount', ...
        'Both inventory and results must contain exactly 14 tests.');
end
if any(strlength(inventoryNames) == 0) || ...
        numel(unique(inventoryNames)) ~= 14
    error('stage0:testEvidenceReport:InvalidInventory', ...
        'The 14 inventory test names must be nonempty and unique.');
end
if any(strlength(resultNames) == 0) || numel(unique(resultNames)) ~= 14
    error('stage0:testEvidenceReport:InvalidResults', ...
        'The 14 result test names must be nonempty and unique.');
end
[found, resultOrder] = ismember(inventoryNames, resultNames);
if ~all(found)
    error('stage0:testEvidenceReport:InventoryMismatch', ...
        'test_inventory.csv and test_results.csv contain different tests.');
end

passed = passed(resultOrder);
failed = failed(resultOrder);
incomplete = incomplete(resultOrder);
durations = durations(resultOrder);
validOutcome = (double(passed) + double(failed) + ...
    double(incomplete)) == 1;
if ~all(validOutcome)
    error('stage0:testEvidenceReport:InvalidOutcome', ...
        'Every test must have exactly one true outcome flag.');
end

facts.testNames = inventoryNames;
facts.testPassed = passed;
facts.testFailed = failed;
facts.testIncomplete = incomplete;
facts.testDurations = durations;
facts.testTotal = numel(inventoryNames);
facts.testPassedCount = sum(passed);
facts.testFailedCount = sum(failed);
facts.testIncompleteCount = sum(incomplete);
facts.totalDuration = sum(durations);
facts.testStatuses = repmat("INCOMPLETE", facts.testTotal, 1);
facts.testStatuses(failed) = "FAIL";
facts.testStatuses(passed) = "PASS";

summaryTotal = require_json_number(facts.summary, ...
    {'test_total', 'total'});
summaryPassed = require_json_number(facts.summary, ...
    {'test_passed', 'passed'});
summaryFailed = require_json_number(facts.summary, ...
    {'test_failed', 'failed'});
summaryIncomplete = require_json_number(facts.summary, ...
    {'test_incomplete', 'incomplete'});
summaryDuration = require_json_number(facts.summary, ...
    {'total_duration_seconds', 'duration_seconds', 'total_duration'});

if summaryTotal ~= facts.testTotal || ...
        summaryPassed ~= facts.testPassedCount || ...
        summaryFailed ~= facts.testFailedCount || ...
        summaryIncomplete ~= facts.testIncompleteCount
    error('stage0:testEvidenceReport:SummaryMismatch', ...
        'test_summary.json does not match the per-test result flags.');
end
if ~isfinite(summaryDuration) || summaryDuration < 0
    error('stage0:testEvidenceReport:InvalidSummaryDuration', ...
        'test_summary.json contains an invalid total duration.');
end
facts.totalDuration = summaryDuration;

manifestTotal = require_json_number(facts.manifest, {'test_total'});
manifestPassed = require_json_number(facts.manifest, {'test_passed'});
manifestFailed = require_json_number(facts.manifest, {'test_failed'});
manifestIncomplete = require_json_number(facts.manifest, ...
    {'test_incomplete'});
if manifestTotal ~= facts.testTotal || ...
        manifestPassed ~= facts.testPassedCount || ...
        manifestFailed ~= facts.testFailedCount || ...
        manifestIncomplete ~= facts.testIncompleteCount
    error('stage0:testEvidenceReport:ManifestCountMismatch', ...
        'run_manifest.json test counts do not match test_results.csv.');
end

facts.optimizationExecuted = require_manifest_boolean(facts.manifest, ...
    {'optimization_executed'});
facts.a1SolverExecuted = require_manifest_boolean(facts.manifest, ...
    {'a1_solver_executed'});
facts.environmentRows = summarize_environment(facts.environment);
facts.environmentAllPassed = all(upper(facts.environmentRows(:,3)) == "PASS");
validate_environment_manifest(facts.manifest,paths.environment, ...
    facts.environmentAllPassed);
facts.inputRows = summarize_and_validate_input_hashes(facts.inputHashes);
facts.evidenceRows = summarize_and_validate_evidence_hashes( ...
    facts.evidenceManifest, paths, runRoot);

facts.isPassingEvidence = facts.testTotal == 14 && ...
    facts.testPassedCount == 14 && facts.testFailedCount == 0 && ...
    facts.testIncompleteCount == 0;
if facts.isPassingEvidence
    derivedTerminalStatus = "PASS";
    allowedCandidateStatuses = "PASS";
else
    derivedTerminalStatus = "FAIL_RETRYABLE";
    % A completed test suite can truthfully be externally blocked (for
    % example, unavailable MATLAB/PCT licensing) or retryably fail.
    allowedCandidateStatuses = ["FAIL_RETRYABLE", "BLOCKED_EXTERNAL"];
end
if facts.candidateTerminalStatus ~= "未记录" && ...
        ~ismember(upper(facts.candidateTerminalStatus), ...
        allowedCandidateStatuses)
    error('stage0:testEvidenceReport:CandidateStatusMismatch', ...
        ['candidate_terminal_status conflicts with the result-derived ' ...
        'terminal status.']);
end
if facts.candidateTerminalStatus == "未记录"
    conclusionStatus = derivedTerminalStatus;
else
    conclusionStatus = upper(facts.candidateTerminalStatus);
end
facts.conclusion = conclusionStatus + ...
    "（Stage 0 测试补充证据）";
end

function validate_report_facts(facts)
if facts.runPurpose ~= "stage_0_test_evidence_addendum"
    error('stage0:testEvidenceReport:WrongRunPurpose', ...
        'run_purpose must be stage_0_test_evidence_addendum.');
end
if facts.parentRunId ~= "20260718_163832_stage_0_9e12222e"
    error('stage0:testEvidenceReport:WrongParentRun', ...
        'The report must reference the approved parent run.');
end
if ~startsWith(lower(facts.historicalBaselineCommit), 'b74a2ac')
    error('stage0:testEvidenceReport:WrongHistoricalBaseline', ...
        'historical_baseline_commit must identify b74a2ac.');
end
if facts.optimizationExecuted || facts.a1SolverExecuted
    error('stage0:testEvidenceReport:ForbiddenExecution', ...
        ['This addendum must record optimization_executed=false and ' ...
        'a1_solver_executed=false.']);
end
if facts.isPassingEvidence && ~facts.environmentAllPassed
    error('stage0:testEvidenceReport:EnvironmentNotPassing', ...
        'A PASS addendum report requires all structured environment checks to pass.');
end
if strlength(facts.command) == 0
    error('stage0:testEvidenceReport:MissingCommand', ...
        'test_command.txt must contain the actual MATLAB command.');
end
if facts.command ~= strtrim(facts.manifestTestCommand)
    error('stage0:testEvidenceReport:CommandMismatch', ...
        ['actual_test_command in run_manifest.json must exactly match ' ...
        'test_command.txt after trimming.']);
end
end

function rows = summarize_environment(environment)
if isempty(environment)
    error('stage0:testEvidenceReport:MissingEnvironmentRows', ...
        'environment.csv must contain observed environment checks.');
end
idIndex = require_column(environment, {'check_id'});
actualIndex = require_column(environment, {'actual', 'value'});
statusIndex = require_column(environment, {'status'});
ids = strtrim(table_column_strings(environment,idIndex));
actual = strtrim(table_column_strings(environment,actualIndex));
statuses = upper(strtrim(table_column_strings(environment,statusIndex)));
requiredIds = ["MATLAB_RELEASE", "SPARSE_MLDIVIDE", "SPARSE_LDL", ...
    "PCT_INSTALLED", "PCT_LICENSE", "PCT_WORKER"];
if any(strlength(ids) == 0) || numel(unique(ids)) ~= numel(ids) || ...
        ~all(ismember(requiredIds,ids)) || ...
        any(~ismember(statuses,["PASS","FAIL","BLOCKED"]))
    error('stage0:testEvidenceReport:InvalidEnvironmentEvidence', ...
        'environment.csv does not contain the required unique environment checks.');
end
rows = [ids,actual,statuses];
end

function validate_environment_manifest(manifest,environmentPath,allPassed)
if ~isfield(manifest,'environment') || ...
        ~isstruct(manifest.environment) || ...
        ~isfield(manifest.environment,'sha256') || ...
        ~isfield(manifest.environment,'all_checks_passed')
    error('stage0:testEvidenceReport:MissingEnvironmentManifest', ...
        'run_manifest.json must record the environment evidence SHA256.');
end
expectedSha = lower(strtrim(scalar_text(manifest.environment.sha256)));
if ~is_sha256(expectedSha) || ...
        ~strcmpi(expectedSha,sha256_file(environmentPath))
    error('stage0:testEvidenceReport:EnvironmentHashMismatch', ...
        'environment.csv SHA256 does not match run_manifest.json.');
end
manifestPassed = parse_scalar_boolean( ...
    manifest.environment.all_checks_passed,'environment.all_checks_passed');
if manifestPassed ~= allPassed
    error('stage0:testEvidenceReport:EnvironmentStatusMismatch', ...
        'Environment pass status conflicts with run_manifest.json.');
end
end

function rows = summarize_and_validate_input_hashes(inputHashes)
if height(inputHashes) ~= 2
    error('stage0:testEvidenceReport:WrongInputHashCount', ...
        'input_hashes.csv must contain exactly two controlled inputs.');
end
pathIndex = require_column(inputHashes, ...
    {'relative_path', 'file_name', 'path', 'file'});
actualIndex = require_column(inputHashes, {'actual_sha256', 'sha256'});
expectedIndex = require_column(inputHashes, {'expected_sha256'});
statusIndex = require_column(inputHashes, {'status', 'match'});

paths = strtrim(table_column_strings(inputHashes, pathIndex));
actual = lower(strtrim(table_column_strings(inputHashes, actualIndex)));
expected = lower(strtrim(table_column_strings(inputHashes, expectedIndex)));
statuses = upper(strtrim(table_column_strings(inputHashes, statusIndex)));
if ~all(actual == expected) || ~all(statuses == "PASS") || ...
        ~all(is_sha256(actual))
    error('stage0:testEvidenceReport:InputHashMismatch', ...
        'The controlled input hash checks must both be PASS.');
end
if ~any(contains(paths, '基础参数.xlsx')) || ...
        ~any(contains(paths, '输入数据.xlsx'))
    error('stage0:testEvidenceReport:WrongInputs', ...
        'The two controlled Excel input names are not both present.');
end
rows = [paths, actual, statuses];
end

function rows = summarize_and_validate_evidence_hashes(evidence, paths, runRoot)
pathIndex = require_column(evidence, ...
    {'relative_path', 'artifact_path', 'file_path', 'path', 'file'});
hashIndex = require_column(evidence, {'sha256'});
listedPaths = replace(strtrim(table_column_strings(evidence, pathIndex)), ...
    '\', '/');
listedHashes = lower(strtrim(table_column_strings(evidence, hashIndex)));

requiredPaths = [ ...
    string(paths.test_results); ...
    string(paths.junit); ...
    string(paths.console_log); ...
    string(paths.test_command); ...
    string(paths.test_summary); ...
    string(paths.test_inventory)];
requiredNames = [ ...
    "test_results.csv"; ...
    "test_results.xml"; ...
    "matlab_test_console.log"; ...
    "test_command.txt"; ...
    "test_summary.json"; ...
    "test_inventory.csv"];

rows = strings(numel(requiredNames), 2);
for index = 1:numel(requiredNames)
    normalizedName = lower(requiredNames(index));
    matches = lower(listedPaths) == normalizedName | ...
        endsWith(lower(listedPaths), "/" + normalizedName);
    if sum(matches) ~= 1
        error('stage0:testEvidenceReport:EvidenceHashMissing', ...
            'Evidence manifest must list %s exactly once.', ...
            requiredNames(index));
    end
    listedHash = listedHashes(find(matches, 1));
    if ~is_sha256(listedHash)
        error('stage0:testEvidenceReport:InvalidEvidenceHash', ...
            'Evidence manifest contains an invalid SHA256 for %s.', ...
            requiredNames(index));
    end
    actualHash = sha256_file(requiredPaths(index));
    if ~strcmpi(listedHash, actualHash)
        error('stage0:testEvidenceReport:EvidenceHashMismatch', ...
            'Evidence SHA256 does not match %s.', requiredNames(index));
    end
    rows(index, :) = [relative_to_run(requiredPaths(index), runRoot), ...
        listedHash];
end
end

function body = build_report_body(facts)
parts = strings(0, 1);

parts(end + 1) = heading_xml('一、报告性质与结论边界', 1);
parts(end + 1) = lead_callout_xml(facts.conclusion, sprintf( ...
    ['测试总数 %d；通过 %d；失败 %d；不完整 %d；总耗时 %s 秒。' ...
    '结论由 test_results.csv 与 test_summary.json 自动交叉汇总。'], ...
    facts.testTotal, facts.testPassedCount, facts.testFailedCount, ...
    facts.testIncompleteCount, format_number(facts.totalDuration)));
parts(end + 1) = paragraph_xml( ...
    ['本报告是对原有 14 项 Stage 0 测试的后续补充重跑证据。' ...
    '父历史 run 未被本报告生成流程修改；本次结果不能反向证明历史 run ' ...
    '当时的控制台输出。'], 'Normal');
parts(end + 1) = paragraph_xml( ...
    ['本报告只证明当前实际代码提交在本次唯一 run 中执行所列测试后的结果，' ...
    '不伪装为原 10 项 Stage 0 阻断性验收的重新执行。'], 'Normal');

parts(end + 1) = heading_xml('二、补充运行身份', 1);
identityRows = [ ...
    "run_id", facts.runId; ...
    "run_purpose", facts.runPurpose; ...
    "parent_run_id", facts.parentRunId; ...
    "历史基线提交", facts.historicalBaselineCommit; ...
    "本次实际代码提交", facts.gitCommit; ...
    "报告生成时 manifest 状态", facts.manifestStatus; ...
    "候选终态", facts.candidateTerminalStatus; ...
    "实际 MATLAB 测试命令", facts.command];
parts(end + 1) = table_xml(["项目", "工件记录"], identityRows, ...
    [2500, 6860], ["left", "left"]);
parts(end + 1) = paragraph_xml( ...
    ['说明：报告生成时 manifest 可能仍为 RUNNING；报告中的测试结论' ...
    '直接来自测试结果与摘要，最终 run 状态由后续完整性检查统一最终化。'], ...
    'Note');

parts(end + 1) = heading_xml('三、运行环境证据', 1);
parts(end + 1) = paragraph_xml( ...
    ['下表来自本次 run 的 environment.csv，并由 run_manifest.json ' ...
    '中的 SHA256 记录锁定。该采集不增加或替代原有 14 项测试。'], ...
    'Normal');
parts(end + 1) = table_xml(["检查项", "实际值", "状态"], ...
    facts.environmentRows, [2500, 5500, 1360], ...
    ["left", "left", "center"]);

parts(end + 1) = heading_xml('四、14 项测试执行结果', 1);
summaryRows = [ ...
    "测试总数", string(facts.testTotal); ...
    "通过", string(facts.testPassedCount); ...
    "失败", string(facts.testFailedCount); ...
    "不完整", string(facts.testIncompleteCount); ...
    "总耗时（秒）", format_number(facts.totalDuration)];
parts(end + 1) = table_xml(["汇总项目", "实际值"], summaryRows, ...
    [6000, 3360], ["left", "center"]);

sequence = string((1:facts.testTotal)');
durations = strings(facts.testTotal, 1);
for index = 1:facts.testTotal
    durations(index) = format_number(facts.testDurations(index));
end
testRows = [sequence, facts.testNames, facts.testStatuses, durations];
parts(end + 1) = table_xml( ...
    ["序号", "测试名称", "结果", "耗时（秒）"], testRows, ...
    [720, 5680, 1280, 1680], ...
    ["center", "left", "center", "right"]);

parts(end + 1) = heading_xml('五、受控输入 SHA256', 1);
parts(end + 1) = paragraph_xml( ...
    ['下表直接读取 input_hashes.csv；报告生成器要求两份受控 Excel 的' ...
    '实际哈希与期望哈希一致且状态均为 PASS。'], 'Normal');
parts(end + 1) = table_xml( ...
    ["受控输入", "实际 SHA256", "状态"], facts.inputRows, ...
    [2600, 5400, 1360], ["left", "left", "center"]);

parts(end + 1) = heading_xml('六、测试证据文件与 SHA256', 1);
parts(end + 1) = paragraph_xml( ...
    ['下表读取报告生成前已经写入的 test_evidence_manifest.csv。' ...
    '生成器逐文件重算 SHA256 并与清单比对；报告自身哈希在报告生成后追加。'], ...
    'Normal');
parts(end + 1) = table_xml(["测试证据", "SHA256"], ...
    facts.evidenceRows, [3200, 6160], ["left", "left"]);

parts(end + 1) = heading_xml('七、本次未执行事项', 1);
scopeRows = [ ...
    "优化计算", boolean_not_run_text(facts.optimizationExecuted); ...
    "正式优化目标", "全部未启用/未求值"; ...
    "正式物理与经济约束", "全部未组装/未求解"; ...
    "完整稀疏 KKT 方向", "未执行/不适用"; ...
    "递推求解器", "未执行/不适用"; ...
    "stage_A1 求解器", boolean_not_run_text(facts.a1SolverExecuted); ...
    "完整内点迭代", "未执行/不适用"; ...
    "物理调度或经济结论", "不得据此生成/不适用"];
parts(end + 1) = table_xml(["范围项目", "本次工件结论"], ...
    scopeRows, [3600, 5760], ["left", "left"]);
parts(end + 1) = paragraph_xml( ...
    ['本次仅执行 Stage 0 回归测试证据补充；未执行优化、完整 KKT、' ...
    '递推求解器、完整内点迭代或 stage_A1，也不形成物理调度、' ...
    '经济性或 A1 通过结论。'], 'Normal');

parts(end + 1) = heading_xml('八、报告证据入口', 1);
sourceRows = [ ...
    "运行身份与执行标志", "run_manifest.json"; ...
    "结构化运行环境", "environment.csv"; ...
    "受控输入哈希", "input_hashes.csv"; ...
    "运行前测试清单", "tests/test_inventory.csv"; ...
    "逐项测试结果", "tests/test_results.csv"; ...
    "JUnit 结果", "tests/test_results.xml"; ...
    "完整控制台日志", "tests/matlab_test_console.log"; ...
    "实际执行命令", "tests/test_command.txt"; ...
    "测试汇总", "tests/test_summary.json"; ...
    "证据哈希清单", relative_to_run( ...
        facts.paths.evidence_manifest, facts.runRoot)];
parts(end + 1) = table_xml(["证据类别", "当前 run 工件"], ...
    sourceRows, [3500, 5860], ["left", "left"]);

body = strjoin(parts, newline);
end

function textValue = boolean_not_run_text(executed)
if executed
    textValue = "已执行（与本报告用途冲突）";
else
    textValue = "false：未执行/不适用";
end
end

function data = read_json_artifact(filePath)
try
    data = jsondecode(fileread(filePath));
catch exception
    error('stage0:testEvidenceReport:JsonReadFailed', ...
        'Unable to read %s: %s', filePath, exception.message);
end
if ~isstruct(data) || ~isscalar(data)
    error('stage0:testEvidenceReport:InvalidJson', ...
        '%s must contain one JSON object.', filePath);
end
end

function tableValue = read_csv_artifact(filePath)
try
    options = detectImportOptions(filePath, 'Delimiter', ',', ...
        'VariableNamingRule', 'preserve', 'Encoding', 'UTF-8');
    if ~isempty(options.VariableNames)
        options = setvartype(options, options.VariableNames, 'string');
    end
    tableValue = readtable(filePath, options);
catch exception
    error('stage0:testEvidenceReport:CsvReadFailed', ...
        'Unable to read %s: %s', filePath, exception.message);
end
end

function textValue = require_manifest_text(manifest, candidateFields)
textValue = optional_manifest_text(manifest, candidateFields, '');
if strlength(strtrim(textValue)) == 0
    error('stage0:testEvidenceReport:MissingManifestField', ...
        'run_manifest.json must contain %s.', candidateFields{1});
end
end

function textValue = optional_manifest_text(manifest, candidateFields, default)
textValue = string(default);
for index = 1:numel(candidateFields)
    if isfield(manifest, candidateFields{index})
        textValue = scalar_text(manifest.(candidateFields{index}));
        return;
    end
end
end

function value = require_manifest_boolean(manifest, candidateFields)
for index = 1:numel(candidateFields)
    if isfield(manifest, candidateFields{index})
        value = parse_scalar_boolean(manifest.(candidateFields{index}), ...
            candidateFields{index});
        return;
    end
end
error('stage0:testEvidenceReport:MissingManifestField', ...
    'run_manifest.json must contain %s.', candidateFields{1});
end

function value = require_json_number(data, candidateFields)
for index = 1:numel(candidateFields)
    if isfield(data, candidateFields{index})
        raw = data.(candidateFields{index});
        if isnumeric(raw) && isscalar(raw)
            value = double(raw);
        else
            value = str2double(scalar_text(raw));
        end
        if isfinite(value)
            return;
        end
        break;
    end
end
error('stage0:testEvidenceReport:MissingNumericField', ...
    'JSON artifact must contain numeric field %s.', candidateFields{1});
end

function index = require_column(tableValue, candidates)
names = string(tableValue.Properties.VariableNames);
index = [];
for candidate = 1:numel(candidates)
    match = find(strcmpi(names, string(candidates{candidate})), 1);
    if ~isempty(match)
        index = match;
        return;
    end
end
error('stage0:testEvidenceReport:MissingColumn', ...
    'Required CSV column is missing: %s', strjoin(candidates, '/'));
end

function values = table_column_strings(tableValue, columnIndex)
rawValues = tableValue{:, columnIndex};
if iscell(rawValues)
    values = strings(numel(rawValues), 1);
    for index = 1:numel(rawValues)
        values(index) = scalar_text(rawValues{index});
    end
elseif isstring(rawValues)
    values = rawValues;
elseif ischar(rawValues)
    values = string(cellstr(rawValues));
elseif iscategorical(rawValues) || isdatetime(rawValues) || ...
        isduration(rawValues)
    values = string(rawValues);
elseif isnumeric(rawValues) || islogical(rawValues)
    values = string(rawValues);
else
    values = strings(size(rawValues, 1), 1);
    for index = 1:size(rawValues, 1)
        values(index) = scalar_text(rawValues(index));
    end
end
values = values(:);
values(ismissing(values)) = "";
end

function values = parse_boolean_column(tableValue, columnIndex, label)
texts = lower(strtrim(table_column_strings(tableValue, columnIndex)));
trueMask = texts == "true" | texts == "1" | texts == "yes" | ...
    texts == "是";
falseMask = texts == "false" | texts == "0" | texts == "no" | ...
    texts == "否";
if ~all(trueMask | falseMask)
    error('stage0:testEvidenceReport:InvalidBooleanColumn', ...
        'Column %s contains a non-boolean value.', label);
end
values = trueMask;
end

function value = parse_scalar_boolean(raw, label)
if islogical(raw) && isscalar(raw)
    value = raw;
    return;
end
if isnumeric(raw) && isscalar(raw) && any(raw == [0, 1])
    value = logical(raw);
    return;
end
textValue = lower(strtrim(scalar_text(raw)));
if any(textValue == ["true", "1", "yes", "是"])
    value = true;
elseif any(textValue == ["false", "0", "no", "否"])
    value = false;
else
    error('stage0:testEvidenceReport:InvalidManifestBoolean', ...
        'Manifest field %s is not boolean.', label);
end
end

function values = parse_nonnegative_numbers(tableValue, columnIndex, label)
texts = table_column_strings(tableValue, columnIndex);
values = str2double(texts);
if any(~isfinite(values) | values < 0)
    error('stage0:testEvidenceReport:InvalidNumericColumn', ...
        'Column %s contains an invalid nonnegative number.', label);
end
end

function mask = is_sha256(values)
values = string(values);
mask = false(size(values));
for index = 1:numel(values)
    mask(index) = ~isempty(regexp(char(values(index)), ...
        '^[0-9a-fA-F]{64}$', 'once'));
end
end

function digest = sha256_file(filePath)
[fileId, message] = fopen(filePath, 'rb');
if fileId < 0
    error('stage0:testEvidenceReport:HashReadFailed', ...
        'Unable to open %s for SHA256: %s', filePath, message);
end
cleanup = onCleanup(@() fclose(fileId)); %#ok<NASGU>
fileBytes = fread(fileId, Inf, '*uint8');
messageDigest = java.security.MessageDigest.getInstance('SHA-256');
messageDigest.update(typecast(fileBytes, 'int8'));
digestBytes = mod(double(messageDigest.digest()), 256);
digest = lower(join(compose('%02x', digestBytes), ''));
digest = reshape(digest, 1, 1);
end

function relative = relative_to_run(filePath, runRoot)
fileValue = replace(string(filePath), '\', '/');
rootValue = strip(replace(string(runRoot), '\', '/'), 'right', '/');
prefix = rootValue + "/";
if startsWith(lower(fileValue), lower(prefix))
    relative = extractAfter(fileValue, strlength(prefix));
else
    relative = fileValue;
end
end

function textValue = format_number(value)
textValue = string(sprintf('%.17g', double(value)));
end

function xml = heading_xml(textValue, level)
xml = paragraph_xml(textValue, sprintf('Heading%d', level), ...
    'keepNext', true);
end

function xml = lead_callout_xml(titleText, detailText)
cellBody = paragraph_xml(titleText, 'CalloutTitle') + ...
    paragraph_xml(detailText, 'CalloutText');
xml = "<w:tbl>" + table_properties_xml(9360, 120, 'D9E7F5', true) + ...
    "<w:tblGrid><w:gridCol w:w=""9360""/></w:tblGrid>" + ...
    "<w:tr><w:tc><w:tcPr><w:tcW w:w=""9360"" w:type=""dxa""/>" + ...
    "<w:shd w:val=""clear"" w:fill=""F4F6F9""/>" + ...
    "<w:vAlign w:val=""center""/></w:tcPr>" + cellBody + ...
    "</w:tc></w:tr></w:tbl>" + paragraph_xml('', 'TableSpacer');
end

function xml = table_xml(headers, rows, widths, alignments)
headers = string(headers(:)');
rows = string(rows);
alignments = string(alignments(:)');
if size(rows, 2) ~= numel(headers)
    error('stage0:testEvidenceReport:TableShape', ...
        'Table row width does not match its headers.');
end
if numel(widths) ~= numel(headers) || sum(widths) ~= 9360
    error('stage0:testEvidenceReport:TableGeometry', ...
        'DOCX table widths must sum to 9360 DXA.');
end
if numel(alignments) ~= numel(headers)
    error('stage0:testEvidenceReport:TableAlignment', ...
        'One table alignment is required per column.');
end

grid = strings(1, numel(widths));
for column = 1:numel(widths)
    grid(column) = sprintf('<w:gridCol w:w="%d"/>', widths(column));
end
xml = "<w:tbl>" + table_properties_xml(9360, 120, 'D9DEE5', false) + ...
    "<w:tblGrid>" + strjoin(grid, '') + "</w:tblGrid>";
xml = xml + table_row_xml(headers, widths, true, alignments);
for row = 1:size(rows, 1)
    xml = xml + table_row_xml(rows(row, :), widths, false, alignments);
end
xml = xml + "</w:tbl>" + paragraph_xml('', 'TableSpacer');
end

function xml = table_properties_xml(totalWidth, indent, borderColor, callout)
if callout
    insideColor = 'F4F6F9';
else
    insideColor = borderColor;
end
xml = sprintf([ ...
    '<w:tblPr><w:tblW w:w="%d" w:type="dxa"/>' ...
    '<w:tblInd w:w="%d" w:type="dxa"/><w:tblLayout w:type="fixed"/>' ...
    '<w:tblBorders><w:top w:val="single" w:sz="4" w:color="%s"/>' ...
    '<w:left w:val="single" w:sz="4" w:color="%s"/>' ...
    '<w:bottom w:val="single" w:sz="4" w:color="%s"/>' ...
    '<w:right w:val="single" w:sz="4" w:color="%s"/>' ...
    '<w:insideH w:val="single" w:sz="4" w:color="%s"/>' ...
    '<w:insideV w:val="single" w:sz="4" w:color="%s"/></w:tblBorders>' ...
    '<w:tblCellMar><w:top w:w="80" w:type="dxa"/>' ...
    '<w:start w:w="120" w:type="dxa"/><w:bottom w:w="80" w:type="dxa"/>' ...
    '<w:end w:w="120" w:type="dxa"/></w:tblCellMar></w:tblPr>'], ...
    totalWidth, indent, borderColor, borderColor, borderColor, borderColor, ...
    insideColor, insideColor);
xml = string(xml);
end

function xml = table_row_xml(values, widths, isHeader, alignments)
if isHeader
    rowProperties = '<w:trPr><w:tblHeader/></w:trPr>';
    styleName = 'TableHeader';
    shading = '<w:shd w:val="clear" w:fill="F2F4F7"/>';
else
    rowProperties = '';
    styleName = 'TableText';
    shading = '';
end
xml = "<w:tr>" + string(rowProperties);
for column = 1:numel(widths)
    xml = xml + sprintf([ ...
        '<w:tc><w:tcPr><w:tcW w:w="%d" w:type="dxa"/>%s' ...
        '<w:vAlign w:val="center"/></w:tcPr>'], widths(column), shading) + ...
        paragraph_xml(values(column), styleName, ...
        'justification', alignments(column)) + "</w:tc>";
end
xml = xml + "</w:tr>";
end

function xml = paragraph_xml(textValue, styleName, varargin)
parser = inputParser;
parser.addParameter('keepNext', false, ...
    @(value) islogical(value) && isscalar(value));
parser.addParameter('justification', "", ...
    @(value) ischar(value) || (isstring(value) && isscalar(value)));
parser.parse(varargin{:});

paragraphProperties = "<w:pPr><w:pStyle w:val=""" + ...
    xml_escape(styleName) + """/>";
if parser.Results.keepNext
    paragraphProperties = paragraphProperties + '<w:keepNext/>';
end
justification = string(parser.Results.justification);
if strlength(justification) > 0
    paragraphProperties = paragraphProperties + ...
        "<w:jc w:val=""" + xml_escape(justification) + """/>";
end
paragraphProperties = paragraphProperties + '</w:pPr>';

xml = "<w:p>" + paragraphProperties + ...
    "<w:r><w:t xml:space=""preserve"">" + ...
    xml_escape(textValue) + "</w:t></w:r></w:p>";
end

function write_docx_package(outputPath, facts, bodyXml)
packageRoot = tempname;
mkdir(packageRoot);
cleanup = onCleanup(@() remove_temp_tree(packageRoot)); %#ok<NASGU>
mkdir(fullfile(packageRoot, '_rels'));
mkdir(fullfile(packageRoot, 'docProps'));
mkdir(fullfile(packageRoot, 'word'));
mkdir(fullfile(packageRoot, 'word', '_rels'));

titleText = '阶段0_测试执行证据补充报告';
write_utf8(fullfile(packageRoot, '[Content_Types].xml'), ...
    content_types_xml());
write_utf8(fullfile(packageRoot, '_rels', '.rels'), ...
    root_relationships_xml());
write_utf8(fullfile(packageRoot, 'docProps', 'core.xml'), ...
    core_properties_xml(titleText));
write_utf8(fullfile(packageRoot, 'docProps', 'app.xml'), ...
    app_properties_xml());
write_utf8(fullfile(packageRoot, 'word', 'styles.xml'), styles_xml());
write_utf8(fullfile(packageRoot, 'word', 'settings.xml'), settings_xml());
write_utf8(fullfile(packageRoot, 'word', 'header1.xml'), ...
    header_xml(facts.runId));
write_utf8(fullfile(packageRoot, 'word', 'footer1.xml'), ...
    footer_xml(facts.runId));
write_utf8(fullfile(packageRoot, 'word', '_rels', ...
    'document.xml.rels'), document_relationships_xml());

titleBlock = paragraph_xml(titleText, 'Title') + ...
    paragraph_xml('原有 14 项 Stage 0 回归测试的后续补充重跑证据', ...
    'Subtitle') + ...
    table_xml(["运行标识", "父运行", "测试结论"], ...
    [facts.runId, facts.parentRunId, facts.conclusion], ...
    [3000, 3300, 3060], ["left", "left", "center"]);
write_utf8(fullfile(packageRoot, 'word', 'document.xml'), ...
    document_xml(titleBlock + bodyXml));

packageFiles = { ...
    '[Content_Types].xml', ...
    fullfile('_rels', '.rels'), ...
    fullfile('docProps', 'core.xml'), ...
    fullfile('docProps', 'app.xml'), ...
    fullfile('word', 'document.xml'), ...
    fullfile('word', 'styles.xml'), ...
    fullfile('word', 'settings.xml'), ...
    fullfile('word', 'header1.xml'), ...
    fullfile('word', 'footer1.xml'), ...
    fullfile('word', '_rels', 'document.xml.rels')};
zipPath = fullfile(fileparts(outputPath), ...
    [char(java.util.UUID.randomUUID) '.zip']);
zip(zipPath, packageFiles, packageRoot);
[ok, message] = movefile(zipPath, outputPath);
if ~ok
    error('stage0:testEvidenceReport:PackageWriteFailed', '%s', message);
end
end

function xml = document_xml(bodyXml)
xml = "<?xml version=""1.0"" encoding=""UTF-8"" standalone=""yes""?>" + ...
    "<w:document xmlns:w=""http://schemas.openxmlformats.org/wordprocessingml/2006/main"" " + ...
    "xmlns:r=""http://schemas.openxmlformats.org/officeDocument/2006/relationships"">" + ...
    "<w:body>" + bodyXml + ...
    "<w:sectPr><w:headerReference w:type=""default"" r:id=""rId3""/>" + ...
    "<w:footerReference w:type=""default"" r:id=""rId4""/>" + ...
    "<w:pgSz w:w=""12240"" w:h=""15840""/>" + ...
    "<w:pgMar w:top=""1440"" w:right=""1440"" w:bottom=""1440"" " + ...
    "w:left=""1440"" w:header=""708"" w:footer=""708"" w:gutter=""0""/>" + ...
    "<w:cols w:space=""720""/><w:docGrid w:linePitch=""312""/>" + ...
    "</w:sectPr></w:body></w:document>";
end

function xml = styles_xml()
% standard_business_brief preset with a memo-masthead title override.
xml = [ ...
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' ...
    '<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">' ...
    '<w:docDefaults><w:rPrDefault><w:rPr>' ...
    '<w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:eastAsia="Microsoft YaHei"/>' ...
    '<w:sz w:val="22"/><w:szCs w:val="22"/><w:lang w:val="zh-CN" w:eastAsia="zh-CN"/>' ...
    '</w:rPr></w:rPrDefault><w:pPrDefault><w:pPr>' ...
    '<w:spacing w:before="0" w:after="120" w:line="264" w:lineRule="auto"/>' ...
    '</w:pPr></w:pPrDefault></w:docDefaults>' ...
    style_definition('Normal', 'Normal', '', 22, '000000', false, 0, 120, 264) ...
    style_definition('Title', 'Title', 'Normal', 46, '000000', true, 0, 80, 264) ...
    style_definition('Subtitle', 'Subtitle', 'Normal', 28, '555555', false, 0, 240, 264) ...
    style_definition('Heading1', 'Heading 1', 'Normal', 32, '2E74B5', true, 320, 160, 264) ...
    style_definition('Heading2', 'Heading 2', 'Normal', 26, '2E74B5', true, 240, 120, 264) ...
    style_definition('Heading3', 'Heading 3', 'Normal', 24, '1F4D78', true, 160, 80, 264) ...
    style_definition('TableHeader', 'Table Header', 'Normal', 19, '0B2545', true, 0, 0, 240) ...
    style_definition('TableText', 'Table Text', 'Normal', 19, '000000', false, 0, 0, 240) ...
    style_definition('TableSpacer', 'Table Spacer', 'Normal', 4, 'FFFFFF', false, 0, 80, 240) ...
    style_definition('CalloutTitle', 'Callout Title', 'Normal', 23, '1F3A5F', true, 0, 60, 264) ...
    style_definition('CalloutText', 'Callout Text', 'Normal', 21, '000000', false, 0, 0, 264) ...
    style_definition('Note', 'Note', 'Normal', 20, '555555', false, 0, 120, 264) ...
    style_definition('Header', 'Header', 'Normal', 18, '666666', false, 0, 0, 240) ...
    style_definition('Footer', 'Footer', 'Normal', 18, '777777', false, 0, 0, 240) ...
    '</w:styles>'];
xml = string(xml);
end

function xml = style_definition(styleId, styleName, basedOn, sizeValue, ...
        colorValue, boldValue, beforeValue, afterValue, lineValue)
basedOnXml = '';
if ~isempty(basedOn)
    basedOnXml = sprintf('<w:basedOn w:val="%s"/>', basedOn);
end
boldXml = '';
if boldValue
    boldXml = '<w:b/><w:bCs/>';
end
xml = sprintf([ ...
    '<w:style w:type="paragraph" w:styleId="%s"><w:name w:val="%s"/>%s' ...
    '<w:qFormat/><w:pPr><w:spacing w:before="%d" w:after="%d" ' ...
    'w:line="%d" w:lineRule="auto"/></w:pPr><w:rPr>' ...
    '<w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:eastAsia="Microsoft YaHei"/>' ...
    '%s<w:color w:val="%s"/><w:sz w:val="%d"/><w:szCs w:val="%d"/>' ...
    '</w:rPr></w:style>'], styleId, styleName, basedOnXml, beforeValue, ...
    afterValue, lineValue, boldXml, colorValue, sizeValue, sizeValue);
end

function xml = header_xml(runId)
xml = "<?xml version=""1.0"" encoding=""UTF-8"" standalone=""yes""?>" + ...
    "<w:hdr xmlns:w=""http://schemas.openxmlformats.org/wordprocessingml/2006/main"">" + ...
    paragraph_xml("Stage 0 · 测试证据补充 | 运行 " + runId, 'Header') + ...
    "</w:hdr>";
end

function xml = footer_xml(runId)
xml = "<?xml version=""1.0"" encoding=""UTF-8"" standalone=""yes""?>" + ...
    "<w:ftr xmlns:w=""http://schemas.openxmlformats.org/wordprocessingml/2006/main"">" + ...
    "<w:p><w:pPr><w:pStyle w:val=""Footer""/><w:jc w:val=""right""/></w:pPr>" + ...
    "<w:r><w:t xml:space=""preserve"">运行 " + xml_escape(runId) + ...
    " | 第 </w:t></w:r><w:fldSimple w:instr="" PAGE ""><w:r><w:t>1</w:t></w:r></w:fldSimple>" + ...
    "<w:r><w:t> 页</w:t></w:r></w:p></w:ftr>";
end

function xml = settings_xml()
xml = ['<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' ...
    '<w:settings xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">' ...
    '<w:zoom w:percent="100"/><w:defaultTabStop w:val="720"/>' ...
    '<w:updateFields w:val="true"/></w:settings>'];
end

function xml = content_types_xml()
xml = ['<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' ...
    '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">' ...
    '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>' ...
    '<Default Extension="xml" ContentType="application/xml"/>' ...
    '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>' ...
    '<Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>' ...
    '<Override PartName="/word/settings.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.settings+xml"/>' ...
    '<Override PartName="/word/header1.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.header+xml"/>' ...
    '<Override PartName="/word/footer1.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.footer+xml"/>' ...
    '<Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>' ...
    '<Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>' ...
    '</Types>'];
end

function xml = root_relationships_xml()
xml = ['<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' ...
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">' ...
    '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>' ...
    '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>' ...
    '<Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>' ...
    '</Relationships>'];
end

function xml = document_relationships_xml()
xml = ['<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' ...
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">' ...
    '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>' ...
    '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/settings" Target="settings.xml"/>' ...
    '<Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/header" Target="header1.xml"/>' ...
    '<Relationship Id="rId4" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/footer" Target="footer1.xml"/>' ...
    '</Relationships>'];
end

function xml = core_properties_xml(titleText)
xml = "<?xml version=""1.0"" encoding=""UTF-8"" standalone=""yes""?>" + ...
    "<cp:coreProperties xmlns:cp=""http://schemas.openxmlformats.org/package/2006/metadata/core-properties"" " + ...
    "xmlns:dc=""http://purl.org/dc/elements/1.1/""><dc:title>" + ...
    xml_escape(titleText) + ...
    "</dc:title><dc:creator>Stage 0 测试证据报告基础设施</dc:creator>" + ...
    "</cp:coreProperties>";
end

function xml = app_properties_xml()
xml = ['<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' ...
    '<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" ' ...
    'xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">' ...
    '<Application>MATLAB Stage 0 test evidence reporting</Application></Properties>'];
end

function write_utf8(filePath, content)
fileId = fopen(filePath, 'w', 'n', 'UTF-8');
if fileId < 0
    error('stage0:testEvidenceReport:WriteFailed', ...
        'Unable to open %s.', filePath);
end
cleanup = onCleanup(@() fclose(fileId)); %#ok<NASGU>
characters = char(content);
count = fwrite(fileId, characters, 'char');
if count ~= numel(characters)
    error('stage0:testEvidenceReport:WriteFailed', ...
        'Short write for %s.', filePath);
end
end

function textValue = scalar_text(value)
if isstring(value)
    if isempty(value)
        textValue = "";
    else
        textValue = strjoin(value(:)', ', ');
    end
elseif ischar(value)
    textValue = string(value);
elseif isnumeric(value) || islogical(value)
    if isscalar(value)
        textValue = string(value);
    else
        textValue = string(jsonencode(value));
    end
elseif isdatetime(value) || isduration(value) || iscategorical(value)
    textValue = string(value);
elseif isempty(value)
    textValue = "";
else
    try
        textValue = string(jsonencode(value));
    catch
        textValue = "（无法显示的结构化值）";
    end
end
if ismissing(textValue)
    textValue = "";
end
end

function escaped = xml_escape(value)
escaped = char(scalar_text(value));
invalid = (double(escaped) < 32) & ...
    ~ismember(double(escaped), [9, 10, 13]);
escaped(invalid) = [];
escaped = strrep(escaped, '&', '&amp;');
escaped = strrep(escaped, '<', '&lt;');
escaped = strrep(escaped, '>', '&gt;');
escaped = strrep(escaped, '"', '&quot;');
escaped = strrep(escaped, '''', '&apos;');
escaped = string(escaped);
end

function remove_temp_tree(folderPath)
if isfolder(folderPath)
    rmdir(folderPath, 's');
end
end
