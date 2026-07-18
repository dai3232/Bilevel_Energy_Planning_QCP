function reportPaths = generate_stage0_reports(runContext)
%GENERATE_STAGE0_REPORTS Generate the three stage_0 Word reports from run artifacts.
%   REPORTPATHS = GENERATE_STAGE0_REPORTS(RUNCONTEXT) reads only the
%   whitelisted artifacts beneath RUNCONTEXT.root plus
%   docs/03_阶段模型启用矩阵.csv. Existing reports are never overwritten.

arguments
    runContext (1, 1) struct
end

if ~isfield(runContext, 'root')
    error('stage0:report:MissingRunRoot', ...
        'runContext.root is required.');
end

runRoot = char(string(runContext.root));
if ~isfolder(runRoot)
    error('stage0:report:MissingRunRoot', ...
        'The run artifact root does not exist: %s', runRoot);
end

sourcePaths = locate_sources(runRoot, runContext);
facts = load_report_facts(sourcePaths);

if ~strcmp(facts.stageId, "stage_0")
    error('stage0:report:WrongStage', ...
        'run_manifest.json identifies stage "%s"; expected stage_0.', ...
        facts.stageId);
end

reportDir = fullfile(runRoot, 'reports');
if ~isfolder(reportDir)
    [ok, message] = mkdir(reportDir);
    if ~ok
        error('stage0:report:CreateDirectoryFailed', '%s', message);
    end
end

reportPaths = struct( ...
    'acceptance_report', fullfile(reportDir, ...
        '阶段0_环境数据与基础设施验收报告.docx'), ...
    'issue_report', fullfile(reportDir, ...
        '阶段0_问题修复与验收报告.docx'), ...
    'run_summary', fullfile(reportDir, ...
        sprintf('运行_%s_结果摘要.docx', safe_filename(facts.runId))));

finalPaths = struct2cell(reportPaths);
for index = 1:numel(finalPaths)
    if isfile(finalPaths{index})
        error('stage0:report:ArtifactExists', ...
            'Refusing to overwrite an existing report: %s', finalPaths{index});
    end
end

stagingRoot = tempname;
mkdir(stagingRoot);
stagingCleanup = onCleanup(@() remove_temp_tree(stagingRoot)); %#ok<NASGU>

stagedPaths = cellfun(@(pathValue) fullfile(stagingRoot, ...
    string_filename(pathValue)), finalPaths, 'UniformOutput', false);

write_docx_package(stagedPaths{1}, ...
    '阶段0_环境数据与基础设施验收报告', ...
    '环境、数据、索引与工件基础设施', facts, ...
    build_acceptance_body(facts));
write_docx_package(stagedPaths{2}, ...
    '阶段0_问题修复与验收报告', ...
    '问题证据、修复记录与未解决项', facts, ...
    build_issue_body(facts));
write_docx_package(stagedPaths{3}, ...
    '阶段0_单次运行结果摘要', ...
    'stage_0 运行工件摘要', facts, ...
    build_summary_body(facts));

for index = 1:numel(stagedPaths)
    [isValid, validation] = validate_docx_package(stagedPaths{index});
    if ~isValid
        error('stage0:report:InvalidDocxPackage', ...
            'Generated DOCX failed package validation: %s', ...
            strjoin(validation.errors, '; '));
    end
end

for index = 1:numel(finalPaths)
    if isfile(finalPaths{index})
        error('stage0:report:ArtifactExists', ...
            'Refusing to overwrite an existing report: %s', finalPaths{index});
    end
    [ok, message] = movefile(stagedPaths{index}, finalPaths{index});
    if ~ok
        error('stage0:report:PublishFailed', '%s', message);
    end
end
end

function paths = locate_sources(runRoot, runContext)
paths = struct;
paths.run_manifest = require_named_artifact(runRoot, ...
    'run_manifest.json', {'run_manifest.json'});
paths.environment = require_named_artifact(runRoot, ...
    'environment.csv', {'environment.csv'});
paths.input_hashes = require_named_artifact(runRoot, ...
    'input_hashes.csv', {'input_hashes.csv'});
paths.data_audit = require_named_artifact(runRoot, ...
    '数据审计.csv', {'数据审计.csv', fullfile('data', '数据审计.csv'), ...
    fullfile('audit', '数据审计.csv')});
paths.acceptance = require_named_artifact(runRoot, ...
    'acceptance_results.csv', {fullfile('acceptance', ...
    'acceptance_results.csv'), 'acceptance_results.csv'});
paths.issue_log = require_named_artifact(runRoot, ...
    'issue_log.csv', {fullfile('issues', 'issue_log.csv'), 'issue_log.csv'});
paths.indices = fullfile(runRoot, 'indices');
if ~isfolder(paths.indices)
    error('stage0:report:MissingArtifact', ...
        'Required run artifact directory is missing: indices');
end

projectRoot = infer_project_root(runRoot, runContext);
paths.stage_matrix = fullfile(projectRoot, 'docs', ...
    '03_阶段模型启用矩阵.csv');
if ~isfile(paths.stage_matrix)
    error('stage0:report:MissingStageMatrix', ...
        'Required controlled stage matrix is missing: %s', paths.stage_matrix);
end
end

function artifactPath = require_named_artifact(rootPath, fileName, preferred)
for index = 1:numel(preferred)
    candidate = fullfile(rootPath, preferred{index});
    if isfile(candidate)
        artifactPath = candidate;
        return;
    end
end

matches = dir(fullfile(rootPath, '**', fileName));
matches = matches(~[matches.isdir]);
if isempty(matches)
    error('stage0:report:MissingArtifact', ...
        'Required run artifact is missing: %s', fileName);
end
if numel(matches) > 1
    error('stage0:report:AmbiguousArtifact', ...
        'More than one %s exists beneath the run root.', fileName);
end
artifactPath = fullfile(matches(1).folder, matches(1).name);
end

function projectRoot = infer_project_root(runRoot, runContext)
candidateFields = {'project_root', 'projectRoot', 'repo_root', 'repoRoot'};
for index = 1:numel(candidateFields)
    if isfield(runContext, candidateFields{index})
        projectRoot = char(string(runContext.(candidateFields{index})));
        return;
    end
end

parentPath = fileparts(runRoot);
[grandParent, parentName] = fileparts(parentPath);
if strcmpi(parentName, 'runs')
    projectRoot = grandParent;
else
    thisFile = mfilename('fullpath');
    projectRoot = fileparts(fileparts(fileparts(thisFile)));
end
end

function facts = load_report_facts(paths)
facts = struct;
facts.paths = paths;
facts.manifest = jsondecode(fileread(paths.run_manifest));
facts.environment = read_csv_artifact(paths.environment);
facts.inputHashes = read_csv_artifact(paths.input_hashes);
facts.dataAudit = read_csv_artifact(paths.data_audit);
facts.acceptance = read_csv_artifact(paths.acceptance);
facts.issues = read_csv_artifact(paths.issue_log);
facts.stageMatrix = read_csv_artifact(paths.stage_matrix);
facts.indexSummary = summarize_indices(paths.indices);

facts.runId = require_manifest_text(facts.manifest, {'run_id', 'runId'});
facts.stageId = require_manifest_text(facts.manifest, {'stage_id', 'stageId'});
facts.manifestRows = flatten_manifest(facts.manifest);
facts.scope = summarize_stage_scope(facts.stageMatrix);
facts.acceptanceStats = summarize_acceptance(facts.acceptance);
facts.issueStats = summarize_issues(facts.issues);
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
    error('stage0:report:CsvReadFailed', ...
        'Unable to read %s: %s', filePath, exception.message);
end
end

function textValue = require_manifest_text(manifest, candidateFields)
textValue = "";
for index = 1:numel(candidateFields)
    if isfield(manifest, candidateFields{index})
        textValue = scalar_text(manifest.(candidateFields{index}));
        break;
    end
end
if strlength(strtrim(textValue)) == 0
    error('stage0:report:MissingManifestField', ...
        'run_manifest.json must contain %s.', candidateFields{1});
end
end

function rows = flatten_manifest(manifest)
names = fieldnames(manifest);
rows = strings(numel(names), 2);
for index = 1:numel(names)
    rows(index, 1) = string(names{index});
    rows(index, 2) = display_text(manifest.(names{index}));
end
end

function summary = summarize_indices(indicesPath)
files = dir(fullfile(indicesPath, '**', '*.csv'));
files = files(~[files.isdir]);
rows = strings(numel(files), 3);
for index = 1:numel(files)
    filePath = fullfile(files(index).folder, files(index).name);
    tableValue = read_csv_artifact(filePath);
    relativeName = erase(string(filePath), string(indicesPath) + filesep);
    rows(index, :) = [relativeName, string(height(tableValue)), ...
        string(width(tableValue))];
end
summary = struct('fileCount', numel(files), 'rows', rows);
end

function scope = summarize_stage_scope(stageMatrix)
idIndex = require_column(stageMatrix, {'component_id'});
typeIndex = require_column(stageMatrix, {'类型', 'type'});
nameIndex = require_column(stageMatrix, {'中文名称', 'name'});
stageIndex = require_column(stageMatrix, {'stage_0'});

allRows = table_rows(stageMatrix, [idIndex, typeIndex, nameIndex, stageIndex]);
stageValues = upper(strtrim(allRows(:, 4)));
enabledMask = stageValues == "INFRA";
if ~any(enabledMask & allRows(:, 1) == "INFRA_DATA")
    error('stage0:report:InvalidStageMatrix', ...
        'docs/03 must enable INFRA_DATA as INFRA for stage_0.');
end

scope.enabled = allRows(enabledMask, :);
scope.disabled = allRows(~enabledMask, :);
scope.headers = ["组件标识", "类型", "中文名称", "stage_0口径"];
end

function stats = summarize_acceptance(acceptance)
blockingIndex = require_column(acceptance, {'blocking', '是否阻断'});
statusIndex = require_column(acceptance, {'status', '状态'});
blockingValues = table_column_strings(acceptance, blockingIndex);
statusValues = upper(strtrim(table_column_strings(acceptance, statusIndex)));
blockingMask = is_true_text(blockingValues);
stats.total = height(acceptance);
stats.blockingTotal = sum(blockingMask);
stats.blockingPass = sum(blockingMask & statusValues == "PASS");
stats.blockingNonPass = stats.blockingTotal - stats.blockingPass;
if stats.blockingTotal == 0
    stats.conclusion = "未运行（无阻断性验收记录）";
elseif stats.blockingNonPass == 0
    stats.conclusion = ...
        "acceptance_results.csv 已记录的阻断项均为 PASS" + ...
        "（仅限现存记录，不代表验收项完整性）";
else
    stats.conclusion = "acceptance_results.csv 已记录项中存在非 PASS 阻断项";
end
end

function stats = summarize_issues(issues)
stats.total = height(issues);
stats.unresolved = NaN;
stats.hasStatus = false;
statusIndex = find_column(issues, ...
    {'status', '状态', 'issue_status', '处理状态', '终态'});
if ~isempty(statusIndex)
    stats.hasStatus = true;
    statusValues = upper(strtrim(table_column_strings(issues, statusIndex)));
    resolvedMask = is_resolved_status(statusValues);
    stats.unresolved = sum(~resolvedMask);
end
end

function body = build_acceptance_body(facts)
parts = strings(0, 1);
stats = facts.acceptanceStats;

parts(end + 1) = heading_xml('一、验收结论', 1);
parts(end + 1) = lead_callout_xml(stats.conclusion, ...
    sprintf(['阻断项 %d 项；PASS %d 项；非 PASS %d 项。结论由' ...
    ' acceptance_results.csv 自动汇总。'], stats.blockingTotal, ...
    stats.blockingPass, stats.blockingNonPass));
parts(end + 1) = paragraph_xml( ...
    'stage_0 仅启用 INFRA 基础设施口径；优化目标、物理约束、完整 KKT、递推方向与内点迭代均未运行/不适用。', ...
    'Normal');

parts(end + 1) = heading_xml('二、运行标识与清单', 1);
parts(end + 1) = table_xml(["字段", "值"], facts.manifestRows, ...
    [2200, 7160]);

parts(end + 1) = heading_xml('三、MATLAB 与并行环境证据', 1);
parts = append_table_or_note(parts, facts.environment, ...
    {'component', 'name', 'item', 'version', 'available', 'status', 'value'}, ...
    'environment.csv 无数据行；环境状态未运行。');

parts(end + 1) = heading_xml('四、输入哈希与数据审计', 1);
parts(end + 1) = heading_xml('输入文件 SHA256', 2);
parts = append_table_or_note(parts, facts.inputHashes, ...
    {'file', 'file_name', 'path', 'sha256', 'expected_sha256', ...
    'actual_sha256', 'match', 'status'}, ...
    'input_hashes.csv 无数据行；输入哈希未运行。');
parts(end + 1) = heading_xml('规范化数据审计', 2);
parts = append_table_or_note(parts, facts.dataAudit, ...
    {'metric', 'item', 'requirement', 'expected', 'actual', 'value', ...
    'unit', 'status', 'notes'}, ...
    '数据审计.csv 无数据行；数据规模和单位审计未运行。');

parts(end + 1) = heading_xml('五、stage_0 启用与未启用口径', 1);
parts(end + 1) = heading_xml('实际启用：INFRA', 2);
parts(end + 1) = table_xml(facts.scope.headers, facts.scope.enabled, ...
    [2000, 1200, 4000, 2160]);
parts(end + 1) = heading_xml('未启用目标与约束', 2);
parts(end + 1) = table_xml(facts.scope.headers, facts.scope.disabled, ...
    [2000, 1200, 4000, 2160]);

parts(end + 1) = heading_xml('六、唯一索引框架证据', 1);
if facts.indexSummary.fileCount == 0
    parts(end + 1) = paragraph_xml( ...
        'indices 目录中无 CSV 工件；索引证据未运行。', 'Normal');
else
    parts(end + 1) = table_xml(["索引文件", "数据行数", "列数"], ...
        facts.indexSummary.rows, [6160, 1600, 1600]);
end

parts(end + 1) = heading_xml('七、阻断性验收明细', 1);
parts = append_table_or_note(parts, facts.acceptance, ...
    {'test_id', 'category', 'requirement', 'blocking', 'status', ...
    'actual_value'}, ...
    'acceptance_results.csv 无数据行；验收未运行。');

parts(end + 1) = heading_xml('八、优化数值适用性', 1);
parts(end + 1) = definition_table_xml({ ...
    '优化目标值', '未运行/不适用'; ...
    '完整稀疏 KKT Newton 方向', '未运行/不适用'; ...
    '递推降阶方向', '未运行/不适用'; ...
    '原始-对偶内点迭代', '未运行/不适用'});

parts(end + 1) = heading_xml('九、证据来源', 1);
parts(end + 1) = source_table_xml(facts);
body = strjoin(parts, newline);
end

function body = build_issue_body(facts)
parts = strings(0, 1);
stats = facts.issueStats;

parts(end + 1) = heading_xml('一、问题与修复结论', 1);
if stats.total == 0
    conclusion = 'issue_log.csv 当前无问题记录。';
elseif stats.hasStatus
    conclusion = sprintf('issue_log.csv 共 %d 条记录，其中按状态字段识别的未解决项为 %d 条。', ...
        stats.total, stats.unresolved);
else
    conclusion = sprintf('issue_log.csv 共 %d 条记录，但未提供可识别的状态字段。', ...
        stats.total);
end
parts(end + 1) = lead_callout_xml(conclusion, ...
    sprintf('阻断性验收结论：%s。', facts.acceptanceStats.conclusion));

parts(end + 1) = heading_xml('二、问题日志原始记录', 1);
parts = append_table_or_note(parts, facts.issues, ...
    {'issue_id', 'test_id', 'severity', 'symptom', 'root_cause', ...
    'status', 'unresolved_item'}, ...
    'issue_log.csv 无数据行；无问题明细可列示。');

parts = append_issue_evidence_section(parts, facts.issues, ...
    '三、症状', {'symptom', '症状', '现象'}, ...
    '未记录症状；不适用。');
parts = append_issue_evidence_section(parts, facts.issues, ...
    '四、根因', {'root_cause', '根因', 'cause'}, ...
    '未记录根因；不适用。');
parts = append_issue_evidence_section(parts, facts.issues, ...
    '五、无效尝试', {'invalid_attempts', '无效尝试', 'failed_attempts'}, ...
    '未记录无效尝试；不适用。');
parts = append_issue_evidence_section(parts, facts.issues, ...
    '六、最终修复', {'final_fix', '最终修复', 'implemented_change', 'fix'}, ...
    '未记录最终修复；不适用。');
parts = append_issue_evidence_section(parts, facts.issues, ...
    '七、回归测试', {'regression_test', '回归测试', 'regression'}, ...
    '未记录回归测试；不适用。');
parts(end + 1) = heading_xml('八、未解决项', 1);
parts = append_unresolved_issue_section(parts, facts.issues);

parts(end + 1) = heading_xml('九、阻断性验收回看', 1);
parts = append_table_or_note(parts, facts.acceptance, ...
    {'test_id', 'requirement', 'blocking', 'status', 'actual_value'}, ...
    'acceptance_results.csv 无数据行；验收未运行。');

parts(end + 1) = heading_xml('十、stage_0 范围边界', 1);
parts(end + 1) = paragraph_xml( ...
    '本次仅报告 INFRA 基础设施。所有优化目标和约束均未启用；优化结果、KKT 方向、递推求解和内点迭代为未运行/不适用。', ...
    'Normal');
body = strjoin(parts, newline);
end

function parts = append_unresolved_issue_section(parts, issues)
if height(issues) == 0
    parts(end + 1) = paragraph_xml('未记录未解决项；不适用。', 'Normal');
    return;
end

itemIndex = find_column(issues, ...
    {'unresolved_item', '未解决项', 'remaining_item'});
if ~isempty(itemIndex)
    values = table_column_strings(issues, itemIndex);
    nonempty = strlength(strtrim(values)) > 0;
    if any(nonempty)
        idIndex = find_column(issues, {'issue_id', '问题编号', 'test_id'});
        if isempty(idIndex)
            ids = "记录" + string((1:height(issues))');
        else
            ids = table_column_strings(issues, idIndex);
        end
        parts(end + 1) = table_xml(["问题标识", "未解决项"], ...
            [ids(nonempty), values(nonempty)], [2200, 7160]);
        return;
    end
end

statusIndex = find_column(issues, ...
    {'status', '状态', 'issue_status', '处理状态', '终态'});
if isempty(statusIndex)
    parts(end + 1) = paragraph_xml( ...
        'issue_log.csv 未提供未解决项或状态字段；未记录。', 'Normal');
    return;
end

statuses = upper(strtrim(table_column_strings(issues, statusIndex)));
unresolvedMask = ~is_resolved_status(statuses);
if ~any(unresolvedMask)
    parts(end + 1) = paragraph_xml( ...
        '按 issue_log.csv 状态字段识别，当前未解决问题为 0 条；不适用。', ...
        'Normal');
    return;
end

idIndex = find_column(issues, {'issue_id', '问题编号', 'test_id'});
if isempty(idIndex)
    ids = "记录" + string((1:height(issues))');
else
    ids = table_column_strings(issues, idIndex);
end
detailIndex = find_column(issues, ...
    {'symptom', '症状', 'error_message', '现象'});
if isempty(detailIndex)
    details = repmat("未记录具体症状", height(issues), 1);
else
    details = table_column_strings(issues, detailIndex);
end
parts(end + 1) = table_xml(["问题标识", "状态", "未解决证据"], ...
    [ids(unresolvedMask), statuses(unresolvedMask), details(unresolvedMask)], ...
    [2100, 1600, 5660]);
end

function body = build_summary_body(facts)
parts = strings(0, 1);
stats = facts.acceptanceStats;
issueStats = facts.issueStats;
if issueStats.hasStatus
    unresolvedText = string(issueStats.unresolved);
else
    unresolvedText = "状态字段未提供";
end

parts(end + 1) = heading_xml('运行摘要', 1);
parts(end + 1) = lead_callout_xml(stats.conclusion, ...
    '摘要仅引用本次 run_id 白名单工件；不包含任何预造优化数值。');
parts(end + 1) = definition_table_xml({ ...
    'run_id', char(facts.runId); ...
    'stage_id', char(facts.stageId); ...
    '阻断性验收项', sprintf('%d', stats.blockingTotal); ...
    '阻断项 PASS', sprintf('%d', stats.blockingPass); ...
    '阻断项非 PASS', sprintf('%d', stats.blockingNonPass); ...
    '问题记录', sprintf('%d', issueStats.total); ...
    '未解决项', char(unresolvedText); ...
    '输入哈希记录', sprintf('%d', height(facts.inputHashes)); ...
    '数据审计记录', sprintf('%d', height(facts.dataAudit)); ...
    '索引 CSV 文件', sprintf('%d', facts.indexSummary.fileCount)});

parts(end + 1) = heading_xml('stage_0 模型口径', 1);
parts(end + 1) = heading_xml('启用 INFRA', 2);
parts(end + 1) = table_xml(facts.scope.headers, facts.scope.enabled, ...
    [2000, 1200, 4000, 2160]);
parts(end + 1) = paragraph_xml( ...
    sprintf('未启用目标/约束组件共 %d 项；详见环境数据与基础设施验收报告。', ...
    size(facts.scope.disabled, 1)), 'Normal');

parts(end + 1) = heading_xml('数值结果适用性', 1);
parts(end + 1) = definition_table_xml({ ...
    '投资或运行目标值', '未运行/不适用'; ...
    '模型可行性与最优性', '未运行/不适用'; ...
    '完整 KKT 与递推方向', '未运行/不适用'; ...
    '性能结果', '未运行/不适用'});

parts(end + 1) = heading_xml('证据入口', 1);
parts(end + 1) = source_table_xml(facts);
body = strjoin(parts, newline);
end

function parts = append_table_or_note(parts, tableValue, preferredColumns, note)
if height(tableValue) == 0 || width(tableValue) == 0
    parts(end + 1) = paragraph_xml(note, 'Normal');
    return;
end
[headers, rows] = selected_table_rows(tableValue, preferredColumns, 6);
parts(end + 1) = table_xml(headers, rows, ...
    content_weighted_widths(headers, rows));
end

function parts = append_issue_evidence_section(parts, issues, titleText, ...
        candidateColumns, emptyText)
parts(end + 1) = heading_xml(titleText, 1);
if height(issues) == 0
    parts(end + 1) = paragraph_xml(emptyText, 'Normal');
    return;
end
valueIndex = find_column(issues, candidateColumns);
if isempty(valueIndex)
    parts(end + 1) = paragraph_xml( ...
        'issue_log.csv 未提供对应字段；未记录。', 'Normal');
    return;
end
idIndex = find_column(issues, {'issue_id', '问题编号', 'test_id'});
if isempty(idIndex)
    ids = "记录" + string((1:height(issues))');
else
    ids = table_column_strings(issues, idIndex);
end
values = table_column_strings(issues, valueIndex);
nonempty = strlength(strtrim(values)) > 0;
if ~any(nonempty)
    parts(end + 1) = paragraph_xml(emptyText, 'Normal');
else
    parts(end + 1) = table_xml(["问题标识", "工件记录"], ...
        [ids(nonempty), values(nonempty)], [2200, 7160]);
end
end

function xml = source_table_xml(facts)
rows = [ ...
    "运行清单", "run_manifest.json"; ...
    "MATLAB 与工具箱环境", "environment.csv"; ...
    "输入哈希", "input_hashes.csv"; ...
    "数据审计", string_filename(facts.paths.data_audit); ...
    "验收结果", string_filename(facts.paths.acceptance); ...
    "问题日志", string_filename(facts.paths.issue_log); ...
    "索引框架", "indices/*.csv"; ...
    "阶段启用口径", "docs/03_阶段模型启用矩阵.csv"];
xml = table_xml(["证据类别", "白名单来源"], rows, [3200, 6160]);
end

function xml = definition_table_xml(rows)
xml = table_xml(["项目", "本次工件结论"], string(rows), [3000, 6360]);
end

function [headers, rows] = selected_table_rows(tableValue, preferred, maxColumns)
names = string(tableValue.Properties.VariableNames);
selected = zeros(1, 0);
for index = 1:numel(preferred)
    match = find(strcmpi(names, string(preferred{index})), 1);
    if ~isempty(match) && ~ismember(match, selected)
        selected(end + 1) = match; %#ok<AGROW>
    end
end
for index = 1:numel(names)
    if numel(selected) >= maxColumns
        break;
    end
    if ~ismember(index, selected)
        selected(end + 1) = index; %#ok<AGROW>
    end
end
selected = selected(1:min(maxColumns, numel(selected)));
headers = names(selected);
rows = table_rows(tableValue, selected);
end

function rows = table_rows(tableValue, columnIndices)
rows = strings(height(tableValue), numel(columnIndices));
for column = 1:numel(columnIndices)
    rows(:, column) = table_column_strings(tableValue, columnIndices(column));
end
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
elseif iscategorical(rawValues)
    values = string(rawValues);
elseif isdatetime(rawValues) || isduration(rawValues)
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

function index = require_column(tableValue, candidates)
index = find_column(tableValue, candidates);
if isempty(index)
    error('stage0:report:MissingColumn', ...
        'Required CSV column is missing: %s', strjoin(candidates, '/'));
end
end

function index = find_column(tableValue, candidates)
names = string(tableValue.Properties.VariableNames);
index = [];
for candidate = 1:numel(candidates)
    match = find(strcmpi(names, string(candidates{candidate})), 1);
    if ~isempty(match)
        index = match;
        return;
    end
end
end

function mask = is_true_text(values)
normalized = lower(strtrim(values));
mask = normalized == "true" | normalized == "1" | ...
    normalized == "yes" | normalized == "是";
end

function mask = is_resolved_status(statusValues)
resolvedValues = ["RESOLVED", "CLOSED", "FIXED", "PASS", ...
    "已解决", "已关闭", "关闭"];
mask = false(size(statusValues));
for index = 1:numel(resolvedValues)
    mask = mask | statusValues == resolvedValues(index);
end
end

function widths = content_weighted_widths(headers, rows)
columnCount = numel(headers);
weights = zeros(1, columnCount);
for column = 1:columnCount
    lengths = strlength([headers(column); rows(:, column)]);
    weights(column) = max(8, min(40, double(max(lengths, [], 'omitmissing'))));
end
weights = sqrt(weights);
minimumWidth = 900;
remaining = 9360 - minimumWidth * columnCount;
if remaining < 0
    minimumWidth = floor(9360 / columnCount * 0.65);
    remaining = 9360 - minimumWidth * columnCount;
end
widths = minimumWidth + floor(remaining * weights / sum(weights));
widths(end) = widths(end) + 9360 - sum(widths);
end

function xml = heading_xml(textValue, level)
xml = paragraph_xml(textValue, sprintf('Heading%d', level), 'keepNext', true);
end

function xml = lead_callout_xml(titleText, detailText)
rows = [string(titleText), string(detailText)];
xml = one_cell_callout_xml(rows);
end

function xml = one_cell_callout_xml(lines)
cellBody = paragraph_xml(lines(1), 'CalloutTitle');
for index = 2:numel(lines)
    cellBody = cellBody + paragraph_xml(lines(index), 'CalloutText');
end
xml = "<w:tbl>" + table_properties_xml(9360, 120, 'D9E7F5', true) + ...
    "<w:tblGrid><w:gridCol w:w=""9360""/></w:tblGrid>" + ...
    "<w:tr><w:tc><w:tcPr><w:tcW w:w=""9360"" w:type=""dxa""/>" + ...
    "<w:shd w:val=""clear"" w:fill=""F4F6F9""/>" + ...
    "<w:vAlign w:val=""center""/></w:tcPr>" + cellBody + ...
    "</w:tc></w:tr></w:tbl>" + paragraph_xml('', 'TableSpacer');
end

function xml = table_xml(headers, rows, widths)
headers = string(headers(:)');
rows = string(rows);
if size(rows, 2) ~= numel(headers)
    error('stage0:report:TableShape', ...
        'Table row width does not match its headers.');
end
if numel(widths) ~= numel(headers) || sum(widths) ~= 9360
    error('stage0:report:TableGeometry', ...
        'DOCX table widths must sum to 9360 DXA.');
end

grid = strings(1, numel(widths));
for column = 1:numel(widths)
    grid(column) = sprintf('<w:gridCol w:w="%d"/>', widths(column));
end

xml = "<w:tbl>" + table_properties_xml(9360, 120, 'D9DEE5', false) + ...
    "<w:tblGrid>" + strjoin(grid, '') + "</w:tblGrid>";
xml = xml + table_row_xml(headers, widths, true);
for row = 1:size(rows, 1)
    xml = xml + table_row_xml(rows(row, :), widths, false);
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

function xml = table_row_xml(values, widths, isHeader)
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
        paragraph_xml(values(column), styleName) + "</w:tc>";
end
xml = xml + "</w:tr>";
end

function xml = paragraph_xml(textValue, styleName, varargin)
parser = inputParser;
parser.addParameter('keepNext', false, @(value) islogical(value) && isscalar(value));
parser.parse(varargin{:});

paragraphProperties = "<w:pPr><w:pStyle w:val=""" + ...
    xml_escape(styleName) + """/>";
if parser.Results.keepNext
    paragraphProperties = paragraphProperties + '<w:keepNext/>';
end
paragraphProperties = paragraphProperties + '</w:pPr>';

xml = "<w:p>" + paragraphProperties + ...
    "<w:r><w:t xml:space=""preserve"">" + ...
    xml_escape(textValue) + "</w:t></w:r></w:p>";
end

function write_docx_package(outputPath, titleText, subtitleText, facts, bodyXml)
packageRoot = tempname;
mkdir(packageRoot);
cleanup = onCleanup(@() remove_temp_tree(packageRoot)); %#ok<NASGU>
mkdir(fullfile(packageRoot, '_rels'));
mkdir(fullfile(packageRoot, 'docProps'));
mkdir(fullfile(packageRoot, 'word'));
mkdir(fullfile(packageRoot, 'word', '_rels'));

write_utf8(fullfile(packageRoot, '[Content_Types].xml'), content_types_xml());
write_utf8(fullfile(packageRoot, '_rels', '.rels'), root_relationships_xml());
write_utf8(fullfile(packageRoot, 'docProps', 'core.xml'), ...
    core_properties_xml(titleText));
write_utf8(fullfile(packageRoot, 'docProps', 'app.xml'), app_properties_xml());
write_utf8(fullfile(packageRoot, 'word', 'styles.xml'), styles_xml());
write_utf8(fullfile(packageRoot, 'word', 'settings.xml'), settings_xml());
write_utf8(fullfile(packageRoot, 'word', 'header1.xml'), ...
    header_xml(facts.runId));
write_utf8(fullfile(packageRoot, 'word', 'footer1.xml'), ...
    footer_xml(facts.runId));
write_utf8(fullfile(packageRoot, 'word', '_rels', 'document.xml.rels'), ...
    document_relationships_xml());

titleBlock = paragraph_xml(titleText, 'Title') + ...
    paragraph_xml(subtitleText, 'Subtitle') + ...
    table_xml(["运行标识", "阶段", "验收汇总"], ...
    [facts.runId, facts.stageId, facts.acceptanceStats.conclusion], ...
    [3000, 1800, 4560]);
documentXml = document_xml(titleBlock + bodyXml);
write_utf8(fullfile(packageRoot, 'word', 'document.xml'), documentXml);

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
zipPath = fullfile(fileparts(outputPath), [char(java.util.UUID.randomUUID) '.zip']);
zip(zipPath, packageFiles, packageRoot);
[ok, message] = movefile(zipPath, outputPath);
if ~ok
    error('stage0:report:PackageWriteFailed', '%s', message);
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
xml = [ ...
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' ...
    '<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">' ...
    '<w:docDefaults><w:rPrDefault><w:rPr>' ...
    '<w:rFonts w:ascii="Arial" w:hAnsi="Arial" w:eastAsia="Microsoft YaHei"/>' ...
    '<w:sz w:val="22"/><w:szCs w:val="22"/><w:lang w:val="zh-CN" w:eastAsia="zh-CN"/>' ...
    '</w:rPr></w:rPrDefault><w:pPrDefault><w:pPr>' ...
    '<w:spacing w:after="120" w:line="264" w:lineRule="auto"/>' ...
    '</w:pPr></w:pPrDefault></w:docDefaults>' ...
    style_definition('Normal', 'Normal', '', 22, '000000', false, 0, 120, 264) ...
    style_definition('Title', 'Title', 'Normal', 46, '000000', true, 0, 80, 276) ...
    style_definition('Subtitle', 'Subtitle', 'Normal', 28, '555555', false, 0, 240, 300) ...
    style_definition('Heading1', 'Heading 1', 'Normal', 32, '2E74B5', true, 320, 160, 264) ...
    style_definition('Heading2', 'Heading 2', 'Normal', 26, '2E74B5', true, 240, 120, 264) ...
    style_definition('Heading3', 'Heading 3', 'Normal', 24, '1F4D78', true, 160, 80, 264) ...
    style_definition('TableHeader', 'Table Header', 'Normal', 19, '0B2545', true, 0, 0, 240) ...
    style_definition('TableText', 'Table Text', 'Normal', 19, '000000', false, 0, 0, 240) ...
    style_definition('TableSpacer', 'Table Spacer', 'Normal', 4, 'FFFFFF', false, 0, 80, 240) ...
    style_definition('CalloutTitle', 'Callout Title', 'Normal', 23, '1F3A5F', true, 0, 60, 264) ...
    style_definition('CalloutText', 'Callout Text', 'Normal', 21, '000000', false, 0, 0, 264) ...
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
    '<w:rFonts w:ascii="Arial" w:hAnsi="Arial" w:eastAsia="Microsoft YaHei"/>' ...
    '%s<w:color w:val="%s"/><w:sz w:val="%d"/><w:szCs w:val="%d"/>' ...
    '</w:rPr></w:style>'], styleId, styleName, basedOnXml, beforeValue, ...
    afterValue, lineValue, boldXml, colorValue, sizeValue, sizeValue);
end

function xml = header_xml(runId)
xml = "<?xml version=""1.0"" encoding=""UTF-8"" standalone=""yes""?>" + ...
    "<w:hdr xmlns:w=""http://schemas.openxmlformats.org/wordprocessingml/2006/main"">" + ...
    paragraph_xml("stage_0 · 基础设施验收 | 运行 " + runId, 'Header') + ...
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
    xml_escape(titleText) + "</dc:title><dc:creator>stage_0 报告基础设施</dc:creator>" + ...
    "</cp:coreProperties>";
end

function xml = app_properties_xml()
xml = ['<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' ...
    '<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" ' ...
    'xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">' ...
    '<Application>MATLAB stage_0 reporting</Application></Properties>'];
end

function write_utf8(filePath, content)
fileId = fopen(filePath, 'w', 'n', 'UTF-8');
if fileId < 0
    error('stage0:report:WriteFailed', 'Unable to open %s.', filePath);
end
cleanup = onCleanup(@() fclose(fileId)); %#ok<NASGU>
count = fwrite(fileId, char(content), 'char');
if count ~= numel(char(content))
    error('stage0:report:WriteFailed', 'Short write for %s.', filePath);
end
end

function textValue = display_text(value)
textValue = scalar_text(value);
if strlength(textValue) > 240
    textValue = extractBefore(textValue, 221) + "…（内容过长，报告截断）";
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
invalid = (double(escaped) < 32) & ~ismember(double(escaped), [9, 10, 13]);
escaped(invalid) = [];
escaped = strrep(escaped, '&', '&amp;');
escaped = strrep(escaped, '<', '&lt;');
escaped = strrep(escaped, '>', '&gt;');
escaped = strrep(escaped, '"', '&quot;');
escaped = strrep(escaped, '''', '&apos;');
escaped = string(escaped);
end

function name = safe_filename(value)
name = regexprep(char(string(value)), '[<>:"/\\|?*\x00-\x1F]', '_');
if isempty(name)
    error('stage0:report:InvalidRunId', ...
        'run_id cannot be converted to a safe report filename.');
end
end

function name = string_filename(filePath)
[~, base, extension] = fileparts(char(filePath));
name = string([base extension]);
end

function remove_temp_tree(folderPath)
if isfolder(folderPath)
    rmdir(folderPath, 's');
end
end
