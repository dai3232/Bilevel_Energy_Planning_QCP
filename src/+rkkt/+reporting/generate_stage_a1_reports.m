function reportPaths = generate_stage_a1_reports(runContext,varargin)
%GENERATE_STAGE_A1_REPORTS Generate three artifact-backed Chinese A1 reports.
% The generator reads only persisted evidence from one run plus the
% controlled stage-enablement matrix. It refuses to overwrite reports and
% structurally validates every staged DOCX before publishing any of them.

if ~isstruct(runContext) || ~isscalar(runContext)
    error('stageA1:report:InvalidRunContext','runContext must be a scalar struct.');
end
parser = inputParser;
parser.FunctionName = mfilename;
addParameter(parser,'OutputDirectory','', ...
    @(x) ischar(x) || (isstring(x) && isscalar(x)));
addParameter(parser,'FinalStatusCandidate','', ...
    @(x) ischar(x) || (isstring(x) && isscalar(x)));
parse(parser,varargin{:});

runRoot = require_run_root(runContext);
paths = locate_sources(runRoot,runContext);
facts = load_report_facts(paths,runContext);
facts = set_final_status_candidate(facts,parser.Results.FinalStatusCandidate);
validate_identity_and_contract(facts);

reportDir = char(string(parser.Results.OutputDirectory));
if isempty(reportDir)
    reportDir = fullfile(runRoot,'reports');
end
ensure_directory(reportDir);
reportPaths = struct( ...
    'model_report',fullfile(reportDir,'阶段A1_完整KKT与递推方向等价验收报告.docx'), ...
    'issue_report',fullfile(reportDir,'阶段A1_问题修复与验收报告.docx'), ...
    'run_summary',fullfile(reportDir,sprintf('运行_%s_结果摘要.docx', ...
    safe_filename(facts.runId))));
finalPaths = struct2cell(reportPaths);
assert_targets_absent(finalPaths);

stagingRoot = tempname;
mkdir(stagingRoot);
stagingCleanup = onCleanup(@() remove_temp_tree(stagingRoot));
stagedPaths = cellfun(@(pathValue) fullfile(stagingRoot, ...
    string_filename(pathValue)),finalPaths,'UniformOutput',false);

write_docx_package(stagedPaths{1},'阶段A1_单次 Newton 方向等价验收报告', ...
    '三小时人工闭合测试窗 · 完整稀疏 KKT 与递推降阶严格等价', ...
    facts,build_model_body(facts));
write_docx_package(stagedPaths{2},'阶段A1_问题修复与验收报告', ...
    '失败定位、问题证据、回归测试与阶段门禁', ...
    facts,build_issue_body(facts));
write_docx_package(stagedPaths{3},'Stage A1 单次运行结果摘要', ...
    '算法测试夹具证据摘要（不构成物理调度或经济结论）', ...
    facts,build_summary_body(facts));

for index = 1:numel(stagedPaths)
    [isValid,validation] = rkkt.reporting.validate_docx_package(stagedPaths{index});
    if ~isValid
        error('stageA1:report:InvalidDocxPackage', ...
            'Generated DOCX failed structural validation: %s', ...
            strjoin(string(validation.errors),'; '));
    end
end

assert_targets_absent(finalPaths);
for index = 1:numel(finalPaths)
    [moved,message] = movefile(stagedPaths{index},finalPaths{index});
    if ~moved
        error('stageA1:report:PublishFailed', ...
            'Could not publish %s: %s',finalPaths{index},message);
    end
end
end

function runRoot = require_run_root(runContext)
if ~isfield(runContext,'root')
    error('stageA1:report:MissingRunRoot','runContext.root is required.');
end
runRoot = char(java.io.File(char(string(runContext.root))).getCanonicalPath());
if ~isfolder(runRoot)
    error('stageA1:report:MissingRunRoot', ...
        'The run artifact root does not exist: %s',runRoot);
end
end

function paths = locate_sources(runRoot,runContext)
paths = struct();
paths.run_manifest = require_file(fullfile(runRoot,'run_manifest.json'));
paths.environment = require_file(fullfile(runRoot,'environment.csv'));
paths.input_hashes = require_file(fullfile(runRoot,'input_hashes.csv'));
paths.acceptance = require_file(fullfile(runRoot,'acceptance','acceptance_results.csv'));
paths.block_dimensions = require_one(runRoot,'block_dimensions.csv',{ ...
    fullfile('matrices','block_dimensions.csv'), ...
    fullfile('indices','block_dimensions.csv')});
paths.matrix_manifest = require_file(fullfile(runRoot,'matrices','matrix_manifest.csv'));
paths.comparison = require_one(runRoot,'direction_comparison.csv',{ ...
    fullfile('iterations','direction_comparison.csv'),'direction_comparison.csv', ...
    'comparison.csv'});
paths.residuals = require_one(runRoot,'residual_summary.csv',{ ...
    fullfile('iterations','residual_summary.csv'),'residual_summary.csv'});
paths.issue_log = require_file(fullfile(runRoot,'issues','issue_log.csv'));
paths.test_inventory = require_file(fullfile(runRoot,'tests','test_inventory.csv'));
paths.test_results = require_file(fullfile(runRoot,'tests','test_results.csv'));
paths.test_summary = require_file(fullfile(runRoot,'tests','test_summary.json'));

projectRoot = infer_project_root(runRoot,runContext);
paths.stage_matrix = require_file(fullfile(projectRoot,'docs', ...
    '03_阶段模型启用矩阵.csv'));
paths.soc_boundary = optional_file(fullfile(runRoot,'indices','soc_boundary_audit.csv'));
paths.fixed_zero = optional_file(fullfile(runRoot,'indices','fixed_zero_audit.csv'));
paths.code_scan = optional_file(fullfile(runRoot,'diagnostics','code_scan.csv'));
paths.linearization_identity = optional_file(fullfile(runRoot,'diagnostics', ...
    'linearization_identity.json'));
end

function pathValue = require_file(pathValue)
if ~isfile(pathValue)
    error('stageA1:report:MissingArtifact', ...
        'Required current-run artifact is missing: %s',pathValue);
end
end

function pathValue = optional_file(pathValue)
if ~isfile(pathValue)
    pathValue = '';
end
end

function artifactPath = require_one(runRoot,fileName,preferred)
for index = 1:numel(preferred)
    candidate = fullfile(runRoot,preferred{index});
    if isfile(candidate)
        artifactPath = candidate;
        return;
    end
end
matches = dir(fullfile(runRoot,'**',fileName));
matches = matches(~[matches.isdir]);
if isempty(matches)
    error('stageA1:report:MissingArtifact', ...
        'Required current-run artifact is missing: %s',fileName);
end
if numel(matches) ~= 1
    error('stageA1:report:AmbiguousArtifact', ...
        'Expected one %s beneath this run, found %d.',fileName,numel(matches));
end
artifactPath = fullfile(matches(1).folder,matches(1).name);
end

function projectRoot = infer_project_root(runRoot,runContext)
if isfield(runContext,'project_root')
    projectRoot = char(java.io.File(char(string( ...
        runContext.project_root))).getCanonicalPath());
    return;
end
[runsRoot,runsName] = fileparts(fileparts(runRoot));
if strcmpi(runsName,'runs')
    projectRoot = runsRoot;
else
    projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
end
end

function facts = load_report_facts(paths,runContext)
facts = struct();
facts.paths = paths;
facts.manifest = read_json(paths.run_manifest);
facts.environment = read_csv(paths.environment);
facts.inputHashes = read_csv(paths.input_hashes);
facts.acceptance = read_csv(paths.acceptance);
facts.blockDimensions = read_csv(paths.block_dimensions);
facts.matrixManifest = read_csv(paths.matrix_manifest);
facts.comparison = read_csv(paths.comparison);
facts.residuals = read_csv(paths.residuals);
facts.issues = read_csv(paths.issue_log);
facts.testInventory = read_csv(paths.test_inventory);
facts.testResults = read_csv(paths.test_results);
facts.testSummary = read_json(paths.test_summary);
facts.stageMatrix = read_csv(paths.stage_matrix);
facts.socBoundary = read_optional_csv(paths.soc_boundary);
facts.fixedZero = read_optional_csv(paths.fixed_zero);
facts.codeScan = read_optional_csv(paths.code_scan);
facts.linearizationIdentity = read_optional_json(paths.linearization_identity);
facts.runRoot = char(string(runContext.root));

facts.runId = require_manifest_text(facts.manifest,'run_id');
facts.stageId = require_manifest_text(facts.manifest,'stage_id');
facts.gitCommit = require_manifest_text(facts.manifest,'git_commit');
facts.manifestStatus = require_manifest_text(facts.manifest,'status');
facts.candidateStatus = "";
facts.window = struct( ...
    'type',require_manifest_text(facts.manifest,'window_type'), ...
    'startHour',require_manifest_number(facts.manifest,'start_hour'), ...
    'terminalHour',require_manifest_number(facts.manifest,'terminal_hour'), ...
    'boundaryMode',require_manifest_text(facts.manifest,'soc_boundary_mode'));
facts.flags = struct( ...
    'newtonCount',require_manifest_number(facts.manifest,'newton_direction_count'), ...
    'fullIpm',require_manifest_boolean(facts.manifest,'full_ipm_executed'), ...
    'parallel',require_manifest_boolean(facts.manifest,'parallel_executed'), ...
    'optimization',require_manifest_boolean(facts.manifest,'optimization_executed'), ...
    'a1Solver',require_manifest_boolean(facts.manifest,'a1_solver_executed'), ...
    'physicalInterpretation',require_manifest_boolean(facts.manifest, ...
    'physical_dispatch_interpretation'));

facts.acceptanceStats = summarize_acceptance(facts.acceptance);
facts.testStats = summarize_tests(facts.testInventory,facts.testResults, ...
    facts.testSummary);
facts.issueStats = summarize_issues(facts.issues);
facts.dimensions = summarize_dimensions(facts.blockDimensions,facts.matrixManifest);
facts.scope = summarize_scope(facts.stageMatrix);
facts.sourceRows = source_rows(paths);
facts.manifestRows = selected_manifest_rows(facts.manifest);
end

function facts = set_final_status_candidate(facts,requestedCandidate)
computed = aggregate_terminal_status(facts.acceptance);
requested = upper(strtrim(string(requestedCandidate)));
if strlength(requested) == 0
    requested = computed;
end
allowed = ["PASS","FAIL_RETRYABLE","BLOCKED_EXTERNAL", ...
    "NEEDS_MODEL_DECISION"];
if ~ismember(requested,allowed)
    error('stageA1:report:InvalidFinalStatusCandidate', ...
        'Invalid FinalStatusCandidate: %s',requested);
end
if requested ~= computed
    error('stageA1:report:FinalStatusCandidateMismatch', ...
        ['FinalStatusCandidate %s conflicts with the status computed from ' ...
        'the complete blocking acceptance inventory (%s).'],requested,computed);
end
facts.candidateStatus = requested;
end

function status = aggregate_terminal_status(acceptance)
require_columns(acceptance,{'test_id','status','blocking'}, ...
    'acceptance_results.csv');
blocking = parse_boolean(acceptance.blocking,'blocking');
if ~any(blocking)
    error('stageA1:report:EmptyBlockingInventory', ...
        'At least one blocking acceptance row is required.');
end
statuses = upper(strtrim(string(acceptance.status(blocking))));
if any(statuses == "NOT_RUN" | statuses == "")
    error('stageA1:report:IncompleteBlockingInventory', ...
        'Every blocking acceptance row must be completed before report generation.');
end
if all(statuses == "PASS")
    status = "PASS";
elseif any(statuses(ismember(string(acceptance.test_id(blocking)), ...
        ["SA1-ENV-001","SA1-DATA-001"])) == "BLOCKED")
    status = "BLOCKED_EXTERNAL";
elseif any(statuses == "NEEDS_MODEL_DECISION")
    status = "NEEDS_MODEL_DECISION";
else
    status = "FAIL_RETRYABLE";
end
end

function validate_identity_and_contract(facts)
if facts.stageId ~= "stage_A1"
    error('stageA1:report:WrongStage', ...
        'run_manifest.json identifies %s; expected stage_A1.',facts.stageId);
end
if upper(facts.manifestStatus) ~= "RUNNING"
    error('stageA1:report:ManifestNotRunning', ...
        ['Reports must be staged and validated while run_manifest.json is ' ...
        'still RUNNING; actual status is %s.'],facts.manifestStatus);
end
if facts.window.type ~= "synthetic_closed_test_window" || ...
        facts.window.startHour ~= 8 || facts.window.terminalHour ~= 10 || ...
        facts.window.boundaryMode ~= "fixed_half_energy"
    error('stageA1:report:WindowIdentityMismatch', ...
        'The persisted run does not identify the frozen 8-10 synthetic closed test window.');
end
if ~ismember(facts.flags.newtonCount,[0,1]) || facts.flags.fullIpm || ...
        facts.flags.parallel || facts.flags.optimization || ...
        facts.flags.physicalInterpretation
    error('stageA1:report:ExecutionScopeMismatch', ...
        ['A1 reports require exactly one direction and false ' ...
        'IPM/parallel/optimization/physical-interpretation flags.']);
end

declaredPass = upper(facts.candidateStatus) == "PASS";
if declaredPass
    problems = strings(0,1);
    if ~facts.acceptanceStats.allBlockingPassed
        problems(end+1) = "not every persisted blocking acceptance row is PASS";
    end
    if ~facts.flags.a1Solver
        problems(end+1) = "the A1 direction solver was not executed";
    end
    if facts.flags.newtonCount ~= 1
        problems(end+1) = "the persisted Newton-direction count is not exactly one";
    end
    if ~facts.testStats.valid || facts.testStats.failed ~= 0 || ...
            facts.testStats.incomplete ~= 0
        problems(end+1) = "the persisted test evidence is incomplete or not all passing";
    end
    if ~facts.dimensions.fullPass || ~facts.dimensions.blocksPass || ...
            ~facts.dimensions.corePass
        problems(end+1) = "persisted matrix dimensions do not equal 471 / 27,27,29 / 16";
    end
    if ~table_has_all_pass(facts.comparison) || ...
            ~table_has_all_pass(facts.residuals)
        problems(end+1) = "comparison or residual evidence contains a non-PASS row";
    end
    if ~isempty(problems)
        error('stageA1:report:FalsePassEvidence', ...
            'Refusing to render a PASS report from inconsistent evidence: %s', ...
            strjoin(problems,'; '));
    end
end
end

function stats = summarize_acceptance(acceptance)
require_columns(acceptance,{'test_id','status','blocking'},'acceptance_results.csv');
blocking = parse_boolean(table_column(acceptance,'blocking'),'blocking');
statuses = upper(strtrim(table_column(acceptance,'status')));
stats.total = height(acceptance);
stats.blockingTotal = sum(blocking);
stats.blockingPassed = sum(blocking & statuses == "PASS");
stats.blockingNonPass = stats.blockingTotal-stats.blockingPassed;
stats.allBlockingPassed = stats.blockingTotal > 0 && stats.blockingNonPass == 0;
if stats.allBlockingPassed
    stats.conclusion = "全部阻断性验收通过";
elseif stats.blockingTotal == 0
    stats.conclusion = "未形成有效阻断性验收清单";
else
    stats.conclusion = "存在未通过或未运行的阻断性验收";
end
end

function stats = summarize_tests(inventory,results,summary)
require_columns(inventory,{'test_name'},'test_inventory.csv');
require_columns(results,{'test_name','passed','failed','incomplete', ...
    'duration_seconds'},'test_results.csv');
inventoryNames = string(inventory.test_name);
resultNames = string(results.test_name);
passed = parse_boolean(results.passed,'passed');
failed = parse_boolean(results.failed,'failed');
incomplete = parse_boolean(results.incomplete,'incomplete');
durations = parse_numeric(results.duration_seconds,'duration_seconds');
stats.total = height(results);
stats.passed = sum(passed);
stats.failed = sum(failed);
stats.incomplete = sum(incomplete);
stats.duration = sum(durations);
stats.inventoryUnique = numel(unique(inventoryNames)) == numel(inventoryNames);
stats.namesMatch = isequal(inventoryNames,resultNames);
stats.summaryMatches = json_number(summary,'test_total') == stats.total && ...
    json_number(summary,'test_passed') == stats.passed && ...
    json_number(summary,'test_failed') == stats.failed && ...
    json_number(summary,'test_incomplete') == stats.incomplete;
stats.valid = stats.total > 0 && height(inventory) == stats.total && ...
    stats.inventoryUnique && stats.namesMatch && stats.summaryMatches && ...
    all(isfinite(durations) & durations >= 0);
end

function stats = summarize_issues(issues)
stats.total = height(issues);
stats.unresolved = stats.total;
if stats.total == 0
    stats.unresolved = 0;
    return;
end
statusName = find_column(issues,{'status'});
if strlength(statusName) == 0
    return;
end
statuses = upper(strtrim(string(issues.(statusName))));
resolved = ismember(statuses,["FIXED","RESOLVED","CLOSED","PASS"]);
stats.unresolved = sum(~resolved);
end

function dimensions = summarize_dimensions(blocks,matrices)
require_columns(blocks,{'hour','kkt_dimension','expected_dimension','status'}, ...
    'block_dimensions.csv');
require_columns(matrices,{'matrix_name','rows','columns','nnz','is_sparse', ...
    'sha256','path'},'matrix_manifest.csv');
hours = parse_numeric(blocks.hour,'hour');
actual = parse_numeric(blocks.kkt_dimension,'kkt_dimension');
expected = parse_numeric(blocks.expected_dimension,'expected_dimension');
statuses = upper(strtrim(string(blocks.status)));
requested = [8;9;10];
blockActual = nan(3,1);
blockExpected = nan(3,1);
blockStatus = strings(3,1);
for index = 1:3
    mask = hours == requested(index);
    if nnz(mask) ~= 1
        error('stageA1:report:BlockIdentity', ...
            'block_dimensions.csv must contain exactly one row for hour %d.', ...
            requested(index));
    end
    blockActual(index) = actual(mask);
    blockExpected(index) = expected(mask);
    blockStatus(index) = statuses(mask);
end
dimensions.hours = requested;
dimensions.blockActual = blockActual;
dimensions.blockExpected = blockExpected;
dimensions.blocksPass = isequal(blockActual,[27;27;29]) && ...
    isequal(blockExpected,[27;27;29]) && all(blockStatus == "PASS");

names = lower(strtrim(string(matrices.matrix_name)));
fullMask = ismember(names,["full_kkt","k_full","full_kkt_matrix"]);
coreMask = ismember(names,["global_core","core16","global_core_16"]);
if nnz(fullMask) ~= 1 || nnz(coreMask) ~= 1
    error('stageA1:report:MatrixIdentity', ...
        'matrix_manifest.csv must identify exactly one full KKT and one global core.');
end
rows = parse_numeric(matrices.rows,'rows');
columns = parse_numeric(matrices.columns,'columns');
sparseFlag = parse_boolean(matrices.is_sparse,'is_sparse');
dimensions.fullRows = rows(fullMask);
dimensions.fullColumns = columns(fullMask);
dimensions.fullSparse = sparseFlag(fullMask);
dimensions.coreRows = rows(coreMask);
dimensions.coreColumns = columns(coreMask);
dimensions.fullPass = dimensions.fullRows == 471 && ...
    dimensions.fullColumns == 471 && dimensions.fullSparse;
dimensions.corePass = dimensions.coreRows == 16 && dimensions.coreColumns == 16;
end

function scope = summarize_scope(stageMatrix)
require_columns(stageMatrix,{'component_id','类型','中文名称','stage_A1'}, ...
    'docs/03_阶段模型启用矩阵.csv');
ids = string(stageMatrix.component_id);
types = string(stageMatrix.('类型'));
names = string(stageMatrix.('中文名称'));
values = upper(strtrim(string(stageMatrix.stage_A1)));
enabled = values == "1";
scope.headers = ["组件标识","类型","中文名称","A1状态"];
allRows = [ids,types,names,values];
scope.enabled = allRows(enabled,:);
scope.disabled = allRows(~enabled,:);
if isempty(scope.enabled)
    error('stageA1:report:EmptyScope', ...
        'The controlled stage matrix contains no enabled A1 components.');
end
end

function passed = table_has_all_pass(tableValue)
statusName = find_column(tableValue,{'status'});
passed = height(tableValue) > 0 && strlength(statusName) > 0 && ...
    all(upper(strtrim(string(tableValue.(statusName)))) == "PASS");
end

function data = read_json(filePath)
try
    data = jsondecode(fileread(filePath));
catch exception
    error('stageA1:report:JsonReadFailed', ...
        'Could not decode %s: %s',filePath,exception.message);
end
end

function data = read_optional_json(filePath)
if isempty(filePath)
    data = struct();
else
    data = read_json(filePath);
end
end

function tableValue = read_csv(filePath)
try
    options = detectImportOptions(filePath,'Delimiter',',', ...
        'VariableNamingRule','preserve','Encoding','UTF-8');
    % Evidence CSV contracts always use row 1 as the header and row 2 as
    % the first data record. Explicit lines prevent MATLAB's metadata
    % heuristics from silently consuming leading ENV/DATA acceptance rows.
    options.VariableNamesLine = 1;
    options.DataLines = [2,Inf];
    if ~isempty(options.VariableNames)
        options = setvartype(options,options.VariableNames,'string');
    end
    tableValue = readtable(filePath,options);
catch exception
    error('stageA1:report:CsvReadFailed', ...
        'Could not read %s: %s',filePath,exception.message);
end
end

function tableValue = read_optional_csv(filePath)
if isempty(filePath)
    tableValue = table();
else
    tableValue = read_csv(filePath);
end
end

function require_columns(tableValue,names,label)
actual = string(tableValue.Properties.VariableNames);
missing = string(names(~ismember(names,actual)));
if ~isempty(missing)
    error('stageA1:report:MissingColumn', ...
        '%s is missing required column(s): %s',label,strjoin(missing,', '));
end
end

function values = table_column(tableValue,name)
if ~ismember(name,tableValue.Properties.VariableNames)
    error('stageA1:report:MissingColumn','Missing column %s.',name);
end
values = string(tableValue.(name));
values = values(:);
end

function name = find_column(tableValue,candidates)
actual = string(tableValue.Properties.VariableNames);
name = "";
for candidate = string(candidates)
    match = find(strcmpi(actual,candidate),1);
    if ~isempty(match)
        name = actual(match);
        return;
    end
end
end

function values = parse_boolean(raw,label)
if islogical(raw)
    values = raw(:);
    return;
end
textValues = lower(strtrim(string(raw)));
if any(~ismember(textValues,["true","false","1","0","yes","no","是","否"]))
    error('stageA1:report:InvalidBoolean', ...
        'Column %s contains a non-boolean value.',label);
end
values = ismember(textValues,["true","1","yes","是"]);
values = values(:);
end

function values = parse_numeric(raw,label)
if isnumeric(raw)
    values = double(raw(:));
else
    values = str2double(string(raw(:)));
end
if any(~isfinite(values))
    error('stageA1:report:InvalidNumber', ...
        'Column %s contains a non-finite or non-numeric value.',label);
end
end

function value = json_number(object,fieldName)
if ~isfield(object,fieldName)
    error('stageA1:report:MissingJsonField','Missing JSON field %s.',fieldName);
end
value = object.(fieldName);
if ~(isnumeric(value) && isscalar(value) && isfinite(value))
    value = str2double(string(value));
end
if ~isscalar(value) || ~isfinite(value)
    error('stageA1:report:InvalidJsonNumber', ...
        'JSON field %s is not a finite scalar.',fieldName);
end
value = double(value);
end

function value = require_manifest_text(manifest,fieldName)
if ~isfield(manifest,fieldName)
    error('stageA1:report:MissingManifestField', ...
        'run_manifest.json must contain %s.',fieldName);
end
value = scalar_text(manifest.(fieldName));
if strlength(strtrim(value)) == 0
    error('stageA1:report:EmptyManifestField', ...
        'run_manifest.json field %s must not be empty.',fieldName);
end
end

function value = require_manifest_number(manifest,fieldName)
if ~isfield(manifest,fieldName)
    error('stageA1:report:MissingManifestField', ...
        'run_manifest.json must contain %s.',fieldName);
end
raw = manifest.(fieldName);
if isnumeric(raw) && isscalar(raw)
    value = double(raw);
else
    value = str2double(string(raw));
end
if ~isscalar(value) || ~isfinite(value)
    error('stageA1:report:InvalidManifestNumber', ...
        'run_manifest.json field %s must be a finite scalar.',fieldName);
end
end

function value = require_manifest_boolean(manifest,fieldName)
if ~isfield(manifest,fieldName)
    error('stageA1:report:MissingManifestField', ...
        'run_manifest.json must contain %s.',fieldName);
end
raw = manifest.(fieldName);
if islogical(raw) && isscalar(raw)
    value = raw;
elseif isnumeric(raw) && isscalar(raw) && ismember(raw,[0,1])
    value = logical(raw);
else
    normalized = lower(strtrim(string(raw)));
    if normalized == "true" || normalized == "1"
        value = true;
    elseif normalized == "false" || normalized == "0"
        value = false;
    else
        error('stageA1:report:InvalidManifestBoolean', ...
            'run_manifest.json field %s must be boolean.',fieldName);
    end
end
end

function rows = selected_manifest_rows(manifest)
fields = ["run_id","stage_id","status","candidate_terminal_status", ...
    "git_commit","started_at","ended_at","model_contract_version", ...
    "window_type","start_hour","terminal_hour","soc_boundary_mode", ...
    "newton_direction_count","full_ipm_executed","parallel_executed", ...
    "optimization_executed","a1_solver_executed", ...
    "physical_dispatch_interpretation"];
rows = strings(0,2);
for field = fields
    if isfield(manifest,char(field))
        rows(end+1,:) = [field,display_text(manifest.(char(field)))]; %#ok<AGROW>
    end
end
end

function rows = source_rows(paths)
labels = ["运行清单";"环境";"输入哈希";"验收结果";"小时块维数"; ...
    "矩阵清单";"方向比较";"残差汇总";"问题日志";"测试清单"; ...
    "测试结果";"测试汇总";"阶段启用矩阵"];
values = [string(paths.run_manifest);string(paths.environment); ...
    string(paths.input_hashes);string(paths.acceptance); ...
    string(paths.block_dimensions);string(paths.matrix_manifest); ...
    string(paths.comparison);string(paths.residuals);string(paths.issue_log); ...
    string(paths.test_inventory);string(paths.test_results); ...
    string(paths.test_summary);string(paths.stage_matrix)];
sourceValues = strings(size(values));
for index = 1:numel(values)
    sourceValues(index) = short_source(values(index));
end
rows = [labels,sourceValues];
end

function value = short_source(pathValue)
pathValue = replace(string(pathValue),'\','/');
marker = "/runs/";
if contains(lower(pathValue),marker)
    value = extractAfter(pathValue,marker);
elseif contains(pathValue,"/docs/")
    value = "docs/"+extractAfter(pathValue,"/docs/");
else
    [~,base,extension] = fileparts(char(pathValue));
    value = string([base,extension]);
end
end

function body = build_model_body(facts)
parts = strings(0,1);
parts(end+1) = heading_xml('一、验收结论',1);
parts(end+1) = lead_callout_xml(facts.acceptanceStats.conclusion, ...
    sprintf(['阻断项 %d 项；PASS %d 项；非 PASS %d 项。' ...
    '依据全部阻断项计算的终态：%s。结论仅来自本 run 的 acceptance_results.csv。'], ...
    facts.acceptanceStats.blockingTotal,facts.acceptanceStats.blockingPassed, ...
    facts.acceptanceStats.blockingNonPass,facts.candidateStatus));
parts(end+1) = paragraph_xml([ ...
    '本次仅使用第 1 日第 8—10 小时真实数据构造“3 小时人工闭合测试窗（仅算法测试）”，' ...
    '验证一次 Newton 方向。该窗口不是正式物理日，不改变每日完整 24 小时首末 SOC=0.5E、' ...
    '日期之间无 SOC 连接的正式模型。'], 'Normal');

parts(end+1) = heading_xml('二、运行身份与执行边界',1);
parts(end+1) = table_xml(["字段","真实工件值"],facts.manifestRows,[2800,6560]);
parts(end+1) = definition_table_xml([ ...
    "完整内点迭代",executed_text(facts.flags.fullIpm); ...
    "并行计算",executed_text(facts.flags.parallel); ...
    "完整优化",executed_text(facts.flags.optimization); ...
    "A1 单次方向求解",executed_text(facts.flags.a1Solver); ...
    "物理调度解释",executed_text(facts.flags.physicalInterpretation)]);
parts(end+1) = note_callout_xml('解释限制', ...
    '本报告不输出最优容量、物理调度、经济运行、投资收益或正式 24 小时运行结论。');

parts(end+1) = heading_xml('三、人工闭合测试窗边界',1);
windowRows = [ ...
    "窗口类型",facts.window.type; ...
    "开始小时",format_number(facts.window.startHour); ...
    "末端小时",format_number(facts.window.terminalHour); ...
    "SOC 边界模式",facts.window.boundaryMode; ...
    "第 8 小时前", "SOC=0.5E，不连接第 7 小时"; ...
    "第 9—10 小时", "只连接测试窗内部前一小时"; ...
    "第 10 小时后", "两座储能分别增加末端 SOC=0.5E 等式"];
parts(end+1) = table_xml(["边界项目","工件口径"],windowRows,[2600,6760]);
if ~isempty(facts.socBoundary)
    parts(end+1) = heading_xml('SOC 边界审计明细',2);
    parts(end+1) = selected_table_xml(facts.socBoundary, ...
        {'check_id','hour','storage','equation_id','expected','actual','status'},6);
end

parts(end+1) = heading_xml('四、矩阵与块维数证据',1);
dimensionRows = [ ...
    "完整稀疏 KKT",sprintf('%d × %d',facts.dimensions.fullRows, ...
    facts.dimensions.fullColumns),"471 × 471",pass_fail(facts.dimensions.fullPass); ...
    "第 8 小时块",format_number(facts.dimensions.blockActual(1)), ...
    format_number(facts.dimensions.blockExpected(1)), ...
    pass_fail(facts.dimensions.blockActual(1)==facts.dimensions.blockExpected(1)); ...
    "第 9 小时块",format_number(facts.dimensions.blockActual(2)), ...
    format_number(facts.dimensions.blockExpected(2)), ...
    pass_fail(facts.dimensions.blockActual(2)==facts.dimensions.blockExpected(2)); ...
    "第 10 小时块",format_number(facts.dimensions.blockActual(3)), ...
    format_number(facts.dimensions.blockExpected(3)), ...
    pass_fail(facts.dimensions.blockActual(3)==facts.dimensions.blockExpected(3)); ...
    "全局核心",sprintf('%d × %d',facts.dimensions.coreRows, ...
    facts.dimensions.coreColumns),"16 × 16",pass_fail(facts.dimensions.corePass)];
parts(end+1) = table_xml(["对象","实际维数","合同维数","状态"], ...
    dimensionRows,[2700,2100,2100,2460]);
parts(end+1) = heading_xml('矩阵清单',2);
parts(end+1) = selected_table_xml(facts.matrixManifest, ...
    {'matrix_name','rows','columns','nnz','is_sparse','sha256','path'},6);

parts(end+1) = heading_xml('五、方向等价与完整 KKT 残差',1);
parts(end+1) = paragraph_xml( ...
    '方向误差、分量误差和阈值直接读取 iterations/direction_comparison.csv。', ...
    'TableCitation');
parts(end+1) = selected_table_xml(facts.comparison, ...
    {'metric_id','actual_value','threshold','status'},4);
parts(end+1) = paragraph_xml( ...
    '直接路线和递推路线的残差直接读取 iterations/residual_summary.csv。', ...
    'TableCitation');
parts(end+1) = selected_table_xml(facts.residuals, ...
    {'route','absolute_residual_2norm','rhs_2norm', ...
    'relative_residual_2norm','threshold','status'},6);

parts(end+1) = heading_xml('六、环境、输入与测试证据',1);
parts(end+1) = heading_xml('MATLAB 与稀疏线性代数环境',2);
parts(end+1) = selected_table_xml(facts.environment, ...
    {'check_id','component','blocking','actual','status','details'},6);
parts(end+1) = heading_xml('受控输入 SHA256',2);
parts(end+1) = selected_table_xml(facts.inputHashes, ...
    {'relative_path','expectedSHA256','expected_sha256', ...
    'actualSHA256','actual_sha256','status'},4);
parts(end+1) = heading_xml('测试汇总',2);
testRows = [ ...
    "测试总数",format_number(facts.testStats.total); ...
    "通过",format_number(facts.testStats.passed); ...
    "失败",format_number(facts.testStats.failed); ...
    "不完整",format_number(facts.testStats.incomplete); ...
    "累计耗时（秒）",format_number(facts.testStats.duration); ...
    "清单/结果/汇总一致",pass_fail(facts.testStats.valid)];
parts(end+1) = table_xml(["指标","真实工件值"],testRows,[3600,5760]);

parts(end+1) = heading_xml('七、实际启用与未启用模型组件',1);
parts(end+1) = heading_xml('A1 启用组件',2);
parts(end+1) = table_xml(facts.scope.headers,facts.scope.enabled, ...
    [1900,1300,4200,1960]);
parts(end+1) = heading_xml('A1 未启用组件',2);
parts(end+1) = table_xml(facts.scope.headers,facts.scope.disabled, ...
    [1900,1300,4200,1960]);

parts(end+1) = heading_xml('八、证据来源',1);
parts(end+1) = table_xml(["证据类别","路径"],facts.sourceRows,[2600,6760]);
body = strjoin(parts,newline);
end

function body = build_issue_body(facts)
parts = strings(0,1);
parts(end+1) = heading_xml('一、问题与门禁结论',1);
parts(end+1) = lead_callout_xml(facts.acceptanceStats.conclusion, ...
    sprintf('问题记录 %d 条；未解决 %d 条。', ...
    facts.issueStats.total,facts.issueStats.unresolved));
parts(end+1) = paragraph_xml( ...
    '任一阻断项非 PASS 时，Stage A1 必须停留在当前阶段；不得用完整 KKT 方向替代递推失败结果。', ...
    'Normal');

parts(end+1) = heading_xml('二、问题日志与首个失败位置',1);
if height(facts.issues) == 0
    parts(end+1) = note_callout_xml('当前工件记录', ...
        'issue_log.csv 无数据行；未记录问题。');
else
    parts(end+1) = selected_table_xml(facts.issues, ...
        {'issue_id','test_id','symptom','error_message','root_cause', ...
        'status','evidence_path'},6);
end
parts(end+1) = paragraph_xml([ ...
    '若方向或代回残差失败，对应变量/方程位置应由 direction_comparison.csv、' ...
    'residual_summary.csv 及 issue_log.csv 的证据路径联合定位。'], 'Normal');

parts(end+1) = heading_xml('三、阻断性验收明细',1);
parts(end+1) = selected_table_xml(facts.acceptance, ...
    {'test_id','requirement','threshold','actual_value','status','evidence_path'},6);

parts(end+1) = heading_xml('四、数值守卫与共享线性化证据',1);
if ~isempty(facts.codeScan)
    parts(end+1) = selected_table_xml(facts.codeScan, ...
        {'check_id','files_scanned','match_count','status','details'},5);
else
    parts(end+1) = paragraph_xml('code_scan.csv 未作为独立工件提供；请以验收结果中的对应证据为准。','Normal');
end
if ~isempty(fieldnames(facts.linearizationIdentity))
    parts(end+1) = heading_xml('共享 linearization 身份',2);
    parts(end+1) = table_xml(["字段","值"], ...
        flatten_struct(facts.linearizationIdentity),[3000,6360]);
end
if ~isempty(facts.fixedZero)
    parts(end+1) = heading_xml('固定零恢复审计',2);
    parts(end+1) = selected_table_xml(facts.fixedZero, ...
        {'check_id','count','maximum_absolute_value', ...
        'maximum_absolute_direction','status','details'},6);
end

parts(end+1) = heading_xml('五、回归测试',1);
parts(end+1) = selected_table_xml(facts.testResults, ...
    {'test_name','passed','failed','incomplete','duration_seconds','details'},6);

parts(end+1) = heading_xml('六、阶段边界声明',1);
parts(end+1) = note_callout_xml('未执行范围', ...
    '未执行完整 IPM、并行、容量规划、经济性分析或正式 24 小时调度；正式模型口径未改变。');
body = strjoin(parts,newline);
end

function body = build_summary_body(facts)
parts = strings(0,1);
parts(end+1) = heading_xml('一、运行结论',1);
parts(end+1) = lead_callout_xml(facts.acceptanceStats.conclusion, ...
    sprintf(['run_id=%s；报告生成时 manifest 生命周期状态=%s；' ...
    '依据全部阻断项计算的终态=%s。'], ...
    facts.runId,facts.manifestStatus,facts.candidateStatus));

parts(end+1) = heading_xml('二、关键事实',1);
rows = [ ...
    "Git commit",facts.gitCommit; ...
    "测试窗",sprintf('%s，小时 %d—%d',facts.window.type, ...
    facts.window.startHour,facts.window.terminalHour); ...
    "完整 KKT",sprintf('%d × %d（sparse=%s）',facts.dimensions.fullRows, ...
    facts.dimensions.fullColumns,lower(pass_fail(facts.dimensions.fullSparse))); ...
    "小时块",strjoin(string(facts.dimensions.blockActual'),', '); ...
    "全局核心",sprintf('%d × %d',facts.dimensions.coreRows, ...
    facts.dimensions.coreColumns); ...
    "测试",sprintf('%d passed / %d failed / %d incomplete', ...
    facts.testStats.passed,facts.testStats.failed,facts.testStats.incomplete); ...
    "未解决问题",format_number(facts.issueStats.unresolved)];
parts(end+1) = table_xml(["项目","真实工件值"],rows,[3000,6360]);

parts(end+1) = heading_xml('三、方向与残差摘要',1);
parts(end+1) = selected_table_xml(facts.comparison, ...
    {'metric_id','actual_value','threshold','status'},4);
parts(end+1) = selected_table_xml(facts.residuals, ...
    {'route','relative_residual_2norm','threshold','status'},4);

parts(end+1) = heading_xml('四、适用性声明',1);
parts(end+1) = note_callout_xml('仅算法测试', ...
    '本结果不能解释为正式 24 小时运行、实际日调度、最优容量或经济性结论。');
parts(end+1) = heading_xml('五、主要证据',1);
parts(end+1) = table_xml(["证据类别","路径"],facts.sourceRows,[2600,6760]);
body = strjoin(parts,newline);
end

function xml = selected_table_xml(tableValue,preferred,maxColumns)
if width(tableValue) == 0
    xml = paragraph_xml('工件无可显示列。','Normal');
    return;
end
actual = string(tableValue.Properties.VariableNames);
selected = strings(0,1);
for candidate = string(preferred)
    match = actual(strcmpi(actual,candidate));
    if ~isempty(match) && ~ismember(match(1),selected)
        selected(end+1) = match(1); %#ok<AGROW>
    end
    if numel(selected) == maxColumns
        break;
    end
end
if isempty(selected)
    selected = actual(1:min(maxColumns,numel(actual)));
end
rows = table_rows(tableValue,selected);
if height(tableValue) == 0
    rows = strings(0,numel(selected));
end
headers = display_headers(selected);
widths = content_weighted_widths(headers,rows);
xml = table_xml(headers,rows,widths);
end

function rows = table_rows(tableValue,columns)
rows = strings(height(tableValue),numel(columns));
for column = 1:numel(columns)
    values = string(tableValue.(columns(column)));
    for row = 1:numel(values)
        rows(row,column) = display_text(values(row));
    end
end
end

function headers = display_headers(columns)
headers = strings(size(columns));
for index = 1:numel(columns)
    name = lower(columns(index));
    switch name
        case 'test_id', headers(index) = '验收项';
        case 'requirement', headers(index) = '要求';
        case 'threshold', headers(index) = '阈值';
        case 'actual_value', headers(index) = '实际值';
        case 'status', headers(index) = '状态';
        case 'evidence_path', headers(index) = '证据路径';
        case 'metric_id', headers(index) = '指标';
        case 'route', headers(index) = '求解路线';
        case 'relative_residual_2norm', headers(index) = '相对残差';
        case 'absolute_residual_2norm', headers(index) = '绝对残差';
        case 'rhs_2norm', headers(index) = '右端 2-范数';
        case 'matrix_name', headers(index) = '矩阵';
        case 'rows', headers(index) = '行';
        case 'columns', headers(index) = '列';
        case 'nnz', headers(index) = '非零元';
        case 'is_sparse', headers(index) = '稀疏';
        case 'sha256', headers(index) = 'SHA256';
        case 'path', headers(index) = '路径';
        case 'test_name', headers(index) = '测试名称';
        case 'passed', headers(index) = '通过';
        case 'failed', headers(index) = '失败';
        case 'incomplete', headers(index) = '不完整';
        case 'duration_seconds', headers(index) = '耗时（秒）';
        case 'details', headers(index) = '明细';
        case {'expectedsha256','expected_sha256'}, headers(index) = '期望 SHA256';
        case {'actualsha256','actual_sha256'}, headers(index) = '实际 SHA256';
        case 'files_scanned', headers(index) = '扫描文件数';
        case 'match_count', headers(index) = '命中数';
        case 'count', headers(index) = '变量数';
        case 'maximum_absolute_value', headers(index) = '最大绝对值';
        case 'maximum_absolute_direction', headers(index) = '方向最大绝对值';
        case 'blocking', headers(index) = '阻断';
        case 'check_id', headers(index) = '检查项';
        case 'component', headers(index) = '组件';
        case 'actual', headers(index) = '实际';
        case 'issue_id', headers(index) = '问题编号';
        case 'symptom', headers(index) = '症状';
        case 'error_message', headers(index) = '原始错误';
        case 'root_cause', headers(index) = '根因';
        otherwise, headers(index) = columns(index);
    end
end
end

function widths = content_weighted_widths(headers,rows)
columnCount = numel(headers);
minimumWidth = max(650,floor(9360/columnCount*0.42));
weights = zeros(1,columnCount);
for column = 1:columnCount
    values = [headers(column);rows(:,column)];
    lengths = double(strlength(values));
    if isempty(lengths)
        lengths = 8;
    end
    weights(column) = sqrt(max(8,min(56,max(lengths))));
end
remaining = 9360-minimumWidth*columnCount;
if remaining < 0
    minimumWidth = floor(9360/columnCount*0.65);
    remaining = 9360-minimumWidth*columnCount;
end
widths = minimumWidth+floor(remaining*weights/sum(weights));
widths(end) = widths(end)+9360-sum(widths);
end

function rows = flatten_struct(value)
names = fieldnames(value);
rows = strings(numel(names),2);
for index = 1:numel(names)
    rows(index,:) = [string(names{index}),display_text(value.(names{index}))];
end
end

function textValue = executed_text(flag)
if flag
    textValue = "已执行";
else
    textValue = "未执行";
end
end

function value = pass_fail(flag)
if flag
    value = "PASS";
else
    value = "FAIL";
end
end

function textValue = format_number(value)
if ~isscalar(value) || ~isnumeric(value) || ~isfinite(value)
    textValue = display_text(value);
else
    textValue = string(sprintf('%.17g',double(value)));
end
end

function xml = definition_table_xml(rows)
xml = table_xml(["项目","状态"],string(rows),[3400,5960]);
end

function xml = heading_xml(textValue,level)
xml = paragraph_xml(textValue,sprintf('Heading%d',level),'keepNext',true);
end

function xml = lead_callout_xml(titleText,detailText)
xml = callout_xml(titleText,detailText,'E8EEF5','1F3A5F');
end

function xml = note_callout_xml(titleText,detailText)
xml = callout_xml(titleText,detailText,'F4F6F9','7A5A00');
end

function xml = callout_xml(titleText,detailText,fill,titleColor)
cellBody = paragraph_xml(titleText,'CalloutTitle','color',titleColor) + ...
    paragraph_xml(detailText,'CalloutText');
xml = "<w:tbl>"+table_properties_xml(9360,120,'D9DEE5',true)+ ...
    "<w:tblGrid><w:gridCol w:w=""9360""/></w:tblGrid>"+ ...
    "<w:tr><w:trPr><w:cantSplit/></w:trPr><w:tc><w:tcPr>"+ ...
    "<w:tcW w:w=""9360"" w:type=""dxa""/>"+ ...
    "<w:shd w:val=""clear"" w:fill="""+fill+"""/>"+ ...
    "<w:vAlign w:val=""center""/></w:tcPr>"+cellBody+ ...
    "</w:tc></w:tr></w:tbl>"+paragraph_xml('', 'TableSpacer');
end

function xml = table_xml(headers,rows,widths)
headers = string(headers(:)');
rows = string(rows);
if isempty(rows)
    rows = strings(0,numel(headers));
end
if size(rows,2) ~= numel(headers)
    error('stageA1:report:TableShape','Table width does not match its headers.');
end
if numel(widths) ~= numel(headers) || sum(widths) ~= 9360
    error('stageA1:report:TableGeometry', ...
        'DOCX table widths must sum to exactly 9360 DXA.');
end
alignments = infer_alignments(headers);
grid = strings(1,numel(widths));
for column = 1:numel(widths)
    grid(column) = sprintf('<w:gridCol w:w="%d"/>',widths(column));
end
xml = "<w:tbl>"+table_properties_xml(9360,120,'D9DEE5',false)+ ...
    "<w:tblGrid>"+strjoin(grid,'')+"</w:tblGrid>"+ ...
    table_row_xml(headers,widths,true,repmat("center",size(headers)));
for row = 1:size(rows,1)
    xml = xml+table_row_xml(rows(row,:),widths,false,alignments);
end
xml = xml+"</w:tbl>"+paragraph_xml('', 'TableSpacer');
end

function alignments = infer_alignments(headers)
alignments = repmat("left",size(headers));
lowerHeaders = lower(headers);
centerMarkers = ["状态","通过","失败","不完整","阻断","稀疏", ...
    "小时","验收项","检查项","问题编号"];
rightMarkers = ["行","列","非零元","耗时（秒）","相对残差", ...
    "绝对残差","右端 2-范数","实际维数","合同维数"];
for index = 1:numel(headers)
    if any(contains(lowerHeaders(index),lower(centerMarkers)))
        alignments(index) = "center";
    elseif any(contains(lowerHeaders(index),lower(rightMarkers)))
        alignments(index) = "right";
    end
end
end

function xml = table_properties_xml(totalWidth,indent,borderColor,callout)
insideColor = borderColor;
if callout
    insideColor = 'F4F6F9';
end
xml = string(sprintf([ ...
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
    totalWidth,indent,borderColor,borderColor,borderColor,borderColor, ...
    insideColor,insideColor));
end

function xml = table_row_xml(values,widths,isHeader,alignments)
if isHeader
    rowProperties = '<w:trPr><w:tblHeader/><w:cantSplit/></w:trPr>';
    styleName = 'TableHeader';
    shading = '<w:shd w:val="clear" w:fill="F2F4F7"/>';
else
    rowProperties = '<w:trPr><w:cantSplit/></w:trPr>';
    styleName = 'TableText';
    shading = '';
end
xml = "<w:tr>"+string(rowProperties);
for column = 1:numel(widths)
    xml = xml+sprintf([ ...
        '<w:tc><w:tcPr><w:tcW w:w="%d" w:type="dxa"/>%s' ...
        '<w:vAlign w:val="center"/></w:tcPr>'],widths(column),shading)+ ...
        paragraph_xml(values(column),styleName, ...
        'alignment',alignments(column),'keepNext',isHeader)+ ...
        "</w:tc>";
end
xml = xml+"</w:tr>";
end

function xml = paragraph_xml(textValue,styleName,varargin)
parser = inputParser;
addParameter(parser,'keepNext',false,@(x) islogical(x) && isscalar(x));
addParameter(parser,'alignment','left',@(x) ischar(x) || (isstring(x) && isscalar(x)));
addParameter(parser,'color','',@(x) ischar(x) || (isstring(x) && isscalar(x)));
parse(parser,varargin{:});
properties = "<w:pPr><w:pStyle w:val="""+xml_escape(styleName)+"""/>";
if parser.Results.keepNext
    properties = properties+"<w:keepNext/>";
end
alignment = lower(string(parser.Results.alignment));
if alignment ~= "left"
    properties = properties+"<w:jc w:val="""+xml_escape(alignment)+"""/>";
end
properties = properties+"</w:pPr>";
runProperties = "";
if strlength(string(parser.Results.color)) > 0
    runProperties = "<w:rPr><w:color w:val="""+ ...
        xml_escape(parser.Results.color)+"""/></w:rPr>";
end
xml = "<w:p>"+properties+"<w:r>"+runProperties+ ...
    "<w:t xml:space=""preserve"">"+xml_escape(textValue)+ ...
    "</w:t></w:r></w:p>";
end

function write_docx_package(outputPath,titleText,subtitleText,facts,bodyXml)
if isfile(outputPath) || isfolder(outputPath)
    error('stageA1:report:ArtifactExists', ...
        'Refusing to overwrite an existing report: %s',outputPath);
end
packageRoot = tempname;
mkdir(packageRoot);
cleanup = onCleanup(@() remove_temp_tree(packageRoot));
mkdir(fullfile(packageRoot,'_rels'));
mkdir(fullfile(packageRoot,'docProps'));
mkdir(fullfile(packageRoot,'word'));
mkdir(fullfile(packageRoot,'word','_rels'));

write_utf8(fullfile(packageRoot,'[Content_Types].xml'),content_types_xml());
write_utf8(fullfile(packageRoot,'_rels','.rels'),root_relationships_xml());
write_utf8(fullfile(packageRoot,'docProps','core.xml'), ...
    core_properties_xml(titleText));
write_utf8(fullfile(packageRoot,'docProps','app.xml'),app_properties_xml());
write_utf8(fullfile(packageRoot,'word','styles.xml'),styles_xml());
write_utf8(fullfile(packageRoot,'word','settings.xml'),settings_xml());
write_utf8(fullfile(packageRoot,'word','header1.xml'),header_xml(facts.runId));
write_utf8(fullfile(packageRoot,'word','footer1.xml'),footer_xml(facts.runId));
write_utf8(fullfile(packageRoot,'word','_rels','document.xml.rels'), ...
    document_relationships_xml());

titleBlock = paragraph_xml('STAGE A1 · 算法验收备忘','MastheadKicker')+ ...
    paragraph_xml(titleText,'Title')+paragraph_xml(subtitleText,'Subtitle')+ ...
    metadata_paragraph_xml('运行标识',facts.runId)+ ...
    metadata_paragraph_xml('阶段',facts.stageId)+ ...
    metadata_paragraph_xml('Git 提交',facts.gitCommit)+ ...
    metadata_paragraph_xml('清单生命周期状态',facts.manifestStatus)+ ...
    metadata_paragraph_xml('依据阻断项计算终态',facts.candidateStatus)+ ...
    paragraph_xml('','MastheadSpacer');
write_utf8(fullfile(packageRoot,'word','document.xml'), ...
    document_xml(titleBlock+bodyXml));

packageFiles = { ...
    '[Content_Types].xml',fullfile('_rels','.rels'), ...
    fullfile('docProps','core.xml'),fullfile('docProps','app.xml'), ...
    fullfile('word','document.xml'),fullfile('word','styles.xml'), ...
    fullfile('word','settings.xml'),fullfile('word','header1.xml'), ...
    fullfile('word','footer1.xml'), ...
    fullfile('word','_rels','document.xml.rels')};
zipPath = [tempname(fileparts(outputPath)),'.zip'];
zipCleanup = onCleanup(@() delete_if_exists(zipPath));
zip(zipPath,packageFiles,packageRoot);
[moved,message] = movefile(zipPath,outputPath);
if ~moved
    error('stageA1:report:PackageWriteFailed', ...
        'Could not finalize DOCX package: %s',message);
end
end

function xml = metadata_paragraph_xml(label,value)
xml = "<w:p><w:pPr><w:pStyle w:val=""MastheadMetadata""/></w:pPr>"+ ...
    "<w:r><w:rPr><w:b/><w:bCs/></w:rPr><w:t xml:space=""preserve"">"+ ...
    xml_escape(label)+"： </w:t></w:r><w:r><w:t xml:space=""preserve"">"+ ...
    xml_escape(display_text(value))+"</w:t></w:r></w:p>";
end

function xml = document_xml(bodyXml)
xml = "<?xml version=""1.0"" encoding=""UTF-8"" standalone=""yes""?>"+ ...
    "<w:document xmlns:w=""http://schemas.openxmlformats.org/wordprocessingml/2006/main"" "+ ...
    "xmlns:r=""http://schemas.openxmlformats.org/officeDocument/2006/relationships"">"+ ...
    "<w:body>"+bodyXml+ ...
    "<w:sectPr><w:headerReference w:type=""default"" r:id=""rId3""/>"+ ...
    "<w:footerReference w:type=""default"" r:id=""rId4""/>"+ ...
    "<w:pgSz w:w=""12240"" w:h=""15840""/>"+ ...
    "<w:pgMar w:top=""1440"" w:right=""1440"" w:bottom=""1440"" "+ ...
    "w:left=""1440"" w:header=""708"" w:footer=""708"" w:gutter=""0""/>"+ ...
    "<w:cols w:space=""720""/><w:docGrid w:linePitch=""312""/>"+ ...
    "</w:sectPr></w:body></w:document>";
end

function xml = styles_xml()
xml = string([ ...
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' ...
    '<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">' ...
    '<w:docDefaults><w:rPrDefault><w:rPr>' ...
    '<w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:eastAsia="Microsoft YaHei"/>' ...
    '<w:sz w:val="22"/><w:szCs w:val="22"/><w:lang w:val="zh-CN" w:eastAsia="zh-CN"/>' ...
    '</w:rPr></w:rPrDefault><w:pPrDefault><w:pPr>' ...
    '<w:spacing w:after="120" w:line="264" w:lineRule="auto"/>' ...
    '</w:pPr></w:pPrDefault></w:docDefaults>' ...
    style_definition('Normal','Normal','',22,'000000',false,0,120,264) ...
    style_definition('Title','Title','Normal',46,'000000',true,0,80,276) ...
    style_definition('Subtitle','Subtitle','Normal',28,'555555',false,0,240,300) ...
    style_definition('MastheadKicker','Masthead Kicker','Normal',19,'2E74B5',true,0,60,240) ...
    style_definition('MastheadMetadata','Masthead Metadata','Normal',21,'000000',false,0,40,252) ...
    style_definition('MastheadSpacer','Masthead Spacer','Normal',4,'FFFFFF',false,0,160,240) ...
    style_definition('Heading1','Heading 1','Normal',32,'2E74B5',true,320,160,264) ...
    style_definition('Heading2','Heading 2','Normal',26,'2E74B5',true,240,120,264) ...
    style_definition('Heading3','Heading 3','Normal',24,'1F4D78',true,160,80,264) ...
    style_definition('TableHeader','Table Header','Normal',19,'0B2545',true,0,0,240) ...
    style_definition('TableText','Table Text','Normal',19,'000000',false,0,0,240) ...
    style_definition('TableCitation','Table Citation','Normal',19,'555555',false,80,80,240) ...
    style_definition('TableSpacer','Table Spacer','Normal',4,'FFFFFF',false,0,80,240) ...
    style_definition('CalloutTitle','Callout Title','Normal',23,'1F3A5F',true,0,60,264) ...
    style_definition('CalloutText','Callout Text','Normal',21,'000000',false,0,0,264) ...
    style_definition('Header','Header','Normal',18,'666666',false,0,0,240) ...
    style_definition('Footer','Footer','Normal',18,'777777',false,0,0,240) ...
    '</w:styles>']);
end

function xml = style_definition(styleId,styleName,basedOn,sizeValue, ...
        colorValue,boldValue,beforeValue,afterValue,lineValue)
basedOnXml = '';
if ~isempty(basedOn)
    basedOnXml = sprintf('<w:basedOn w:val="%s"/>',basedOn);
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
    '</w:rPr></w:style>'],styleId,styleName,basedOnXml,beforeValue, ...
    afterValue,lineValue,boldXml,colorValue,sizeValue,sizeValue);
end

function xml = header_xml(runId)
xml = "<?xml version=""1.0"" encoding=""UTF-8"" standalone=""yes""?>"+ ...
    "<w:hdr xmlns:w=""http://schemas.openxmlformats.org/wordprocessingml/2006/main"">"+ ...
    paragraph_xml("STAGE A1 · 单次 Newton 方向验收 | 运行 "+runId,'Header')+ ...
    "</w:hdr>";
end

function xml = footer_xml(runId)
xml = "<?xml version=""1.0"" encoding=""UTF-8"" standalone=""yes""?>"+ ...
    "<w:ftr xmlns:w=""http://schemas.openxmlformats.org/wordprocessingml/2006/main"">"+ ...
    "<w:p><w:pPr><w:pStyle w:val=""Footer""/><w:jc w:val=""right""/></w:pPr>"+ ...
    "<w:r><w:t xml:space=""preserve"">运行 "+xml_escape(runId)+ ...
    " | 第 </w:t></w:r><w:fldSimple w:instr="" PAGE "">"+ ...
    "<w:r><w:t>1</w:t></w:r></w:fldSimple><w:r><w:t> 页</w:t></w:r></w:p></w:ftr>";
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
xml = "<?xml version=""1.0"" encoding=""UTF-8"" standalone=""yes""?>"+ ...
    "<cp:coreProperties xmlns:cp=""http://schemas.openxmlformats.org/package/2006/metadata/core-properties"" "+ ...
    "xmlns:dc=""http://purl.org/dc/elements/1.1/""><dc:title>"+ ...
    xml_escape(titleText)+"</dc:title><dc:creator>MATLAB stage_A1 reporting</dc:creator>"+ ...
    "</cp:coreProperties>";
end

function xml = app_properties_xml()
xml = ['<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' ...
    '<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" ' ...
    'xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">' ...
    '<Application>MATLAB stage_A1 reporting</Application></Properties>'];
end

function write_utf8(filePath,content)
[fileId,message] = fopen(filePath,'wb','n','UTF-8');
if fileId < 0
    error('stageA1:report:WriteFailed','Could not open %s: %s',filePath,message);
end
cleanup = onCleanup(@() close_file(fileId));
bytes = unicode2native(char(content),'UTF-8');
count = fwrite(fileId,bytes,'uint8');
if count ~= numel(bytes)
    error('stageA1:report:WriteFailed','Short write for %s.',filePath);
end
status = fclose(fileId);
clear cleanup;
if status ~= 0
    error('stageA1:report:WriteFailed','Could not close %s.',filePath);
end
end

function close_file(fileId)
try
    name = fopen(fileId);
    if ischar(name) && ~isempty(name)
        fclose(fileId);
    end
catch
end
end

function textValue = display_text(value)
textValue = scalar_text(value);
if strlength(textValue) > 220
    textValue = extractBefore(textValue,201)+"…（详见工件）";
end
end

function textValue = scalar_text(value)
if isstring(value)
    if isempty(value)
        textValue = "";
    else
        textValue = strjoin(value(:)',', ');
    end
elseif ischar(value)
    textValue = string(value);
elseif isnumeric(value) || islogical(value)
    if isscalar(value)
        if isnumeric(value) && isfinite(double(value))
            textValue = string(sprintf('%.17g',double(value)));
        else
            textValue = string(value);
        end
    else
        textValue = string(jsonencode(value));
    end
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
invalid = (double(escaped)<32) & ~ismember(double(escaped),[9,10,13]);
escaped(invalid) = [];
escaped = strrep(escaped,'&','&amp;');
escaped = strrep(escaped,'<','&lt;');
escaped = strrep(escaped,'>','&gt;');
escaped = strrep(escaped,'"','&quot;');
escaped = strrep(escaped,'''','&apos;');
escaped = string(escaped);
end

function ensure_directory(pathValue)
if isfolder(pathValue)
    return;
end
if exist(pathValue,'file')
    error('stageA1:report:PathConflict', ...
        'A file exists where a directory is required: %s',pathValue);
end
[created,message] = mkdir(pathValue);
if ~created
    error('stageA1:report:CreateDirectoryFailed','%s',message);
end
end

function assert_targets_absent(paths)
for index = 1:numel(paths)
    if isfile(paths{index}) || isfolder(paths{index})
        error('stageA1:report:ArtifactExists', ...
            'Refusing to overwrite an existing report: %s',paths{index});
    end
end
end

function name = safe_filename(value)
name = regexprep(char(string(value)),'[<>:"/\\|?*\x00-\x1F]','_');
if isempty(name)
    error('stageA1:report:InvalidRunId','run_id is not safe for a filename.');
end
end

function name = string_filename(filePath)
[~,base,extension] = fileparts(char(filePath));
name = string([base,extension]);
end

function delete_if_exists(pathValue)
if isfile(pathValue)
    delete(pathValue);
end
end

function remove_temp_tree(folderPath)
if isfolder(folderPath)
    rmdir(folderPath,'s');
end
end
