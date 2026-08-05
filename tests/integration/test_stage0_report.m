function tests = test_stage0_report
%TEST_STAGE0_REPORT Integration tests for artifact-backed stage_0 DOCX reports.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
testFile = mfilename('fullpath');
projectRoot = fileparts(fileparts(fileparts(testFile)));
addpath(fullfile(projectRoot, 'src', '+rkkt', '+reporting'));
testCase.TestData.ProjectRoot = projectRoot;
end

function testGeneratesThreeArtifactBackedDocxPackages(testCase)
fixture = create_fixture(testCase.TestData.ProjectRoot);
cleanup = onCleanup(@() remove_fixture(fixture.container)); %#ok<NASGU>

paths = rkkt.reporting.generate_stage0_reports(struct( ...
    'root', fixture.runRoot, 'project_root', fixture.projectRoot));

verifyTrue(testCase, isfile(paths.acceptance_report));
verifyTrue(testCase, isfile(paths.issue_report));
verifyTrue(testCase, isfile(paths.run_summary));

pathValues = struct2cell(paths);
for index = 1:numel(pathValues)
    [isValid, details] = rkkt.reporting.validate_docx_package(pathValues{index});
    verifyTrue(testCase, isValid, strjoin(details.errors, '; '));
    verifyNotEmpty(testCase, details.document_text);
    verifySubstring(testCase, details.document_xml, ...
        '<w:tblLayout w:type="fixed"/>');
    verifySubstring(testCase, details.styles_xml, ...
        'w:eastAsia="Microsoft YaHei"');
    verifyEmpty(testCase, details.errors);
end

[~, acceptanceDetails] = rkkt.reporting.validate_docx_package(paths.acceptance_report);
verifySubstring(testCase, acceptanceDetails.document_text, ...
    '阶段0_环境数据与基础设施验收报告');
verifySubstring(testCase, acceptanceDetails.document_text, 'INFRA_DATA');
verifySubstring(testCase, acceptanceDetails.document_text, 'OBJ_INVEST');
verifySubstring(testCase, acceptanceDetails.document_text, '未运行/不适用');
verifySubstring(testCase, acceptanceDetails.document_text, ...
    'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855');

[~, issueDetails] = rkkt.reporting.validate_docx_package(paths.issue_report);
verifySubstring(testCase, issueDetails.document_text, '症状');
verifySubstring(testCase, issueDetails.document_text, '根因');
verifySubstring(testCase, issueDetails.document_text, '无效尝试');
verifySubstring(testCase, issueDetails.document_text, '最终修复');
verifySubstring(testCase, issueDetails.document_text, '回归测试');
verifySubstring(testCase, issueDetails.document_text, '未解决项');

[~, summaryDetails] = rkkt.reporting.validate_docx_package(paths.run_summary);
verifySubstring(testCase, summaryDetails.document_text, ...
    '阶段0_单次运行结果摘要');
end

function testNeverOverwritesExistingReports(testCase)
fixture = create_fixture(testCase.TestData.ProjectRoot);
cleanup = onCleanup(@() remove_fixture(fixture.container)); %#ok<NASGU>
context = struct('root', fixture.runRoot, ...
    'project_root', fixture.projectRoot);

rkkt.reporting.generate_stage0_reports(context);
verifyError(testCase, @() rkkt.reporting.generate_stage0_reports(context), ...
    'stage0:report:ArtifactExists');
end

function testIssueEvidenceComesFromIssueLog(testCase)
fixture = create_fixture(testCase.TestData.ProjectRoot);
cleanup = onCleanup(@() remove_fixture(fixture.container)); %#ok<NASGU>
write_text(fullfile(fixture.runRoot, 'issues', 'issue_log.csv'), strjoin([ ...
    "issue_id,test_id,severity,symptom,root_cause,invalid_attempts,final_fix,regression_test,status,unresolved_item" ...
    "S0-RPT-FIXTURE-001,S0-RPT-001,medium,DOCX包缺少页脚关系,生成器未声明footer关系,仅校验ZIP存在,补充关系并添加结构验证,test_stage0_report,RESOLVED,"], newline));

paths = rkkt.reporting.generate_stage0_reports(struct( ...
    'root', fixture.runRoot, 'project_root', fixture.projectRoot));
[isValid, details] = rkkt.reporting.validate_docx_package(paths.issue_report);
verifyTrue(testCase, isValid, strjoin(details.errors, '; '));
verifySubstring(testCase, details.document_text, 'S0-RPT-FIXTURE-001');
verifySubstring(testCase, details.document_text, 'DOCX包缺少页脚关系');
verifySubstring(testCase, details.document_text, '生成器未声明footer关系');
verifySubstring(testCase, details.document_text, '仅校验ZIP存在');
verifySubstring(testCase, details.document_text, '补充关系并添加结构验证');
verifySubstring(testCase, details.document_text, 'test_stage0_report');
end

function testValidatorRejectsNonDocx(testCase)
container = tempname;
mkdir(container);
cleanup = onCleanup(@() remove_fixture(container)); %#ok<NASGU>
badPath = fullfile(container, 'not_a_docx.docx');
write_text(badPath, 'plain text is not a ZIP package');

[isValid, details] = rkkt.reporting.validate_docx_package(badPath);
verifyFalse(testCase, isValid);
verifyNotEmpty(testCase, details.errors);
end

function fixture = create_fixture(projectRoot)
container = tempname;
runRoot = fullfile(container, 'runs', 'fixture_stage0_run');
mkdir(fullfile(runRoot, 'acceptance'));
mkdir(fullfile(runRoot, 'issues'));
mkdir(fullfile(runRoot, 'indices'));

manifest = struct( ...
    'run_id', 'fixture_stage0_run', ...
    'stage_id', 'stage_0', ...
    'status', 'PASS', ...
    'git_commit', '0123456789abcdef0123456789abcdef01234567', ...
    'configuration', struct('calendar_days', 365, ...
    'periods_per_day', 24, 'interval_minutes', 60));
write_text(fullfile(runRoot, 'run_manifest.json'), jsonencode(manifest));

write_text(fullfile(runRoot, 'environment.csv'), strjoin([ ...
    "component,version,available,status" ...
    "MATLAB,R2024a,true,PASS" ...
    "Sparse linear algebra,builtin,true,PASS" ...
    "Parallel Computing Toolbox,24.1,true,PASS"], newline));

write_text(fullfile(runRoot, 'input_hashes.csv'), strjoin([ ...
    "file_name,sha256,status" ...
    "基础参数.xlsx,e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855,PASS" ...
    "输入数据.xlsx,ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad,PASS"], newline));

write_text(fullfile(runRoot, '数据审计.csv'), strjoin([ ...
    "metric,expected,actual,unit,status" ...
    "device_counts,4/4/5/5/2,4/4/5/5/2,count,PASS" ...
    "calendar,365x24,365x24,period,PASS" ...
    "interval_minutes,60,60,minute,PASS" ...
    "plan_scale,10000,10000,MW,PASS"], newline));

write_text(fullfile(runRoot, 'acceptance', 'acceptance_results.csv'), strjoin([ ...
    "test_id,category,requirement,blocking,status,actual_value" ...
    "S0-ENV-001,环境,MATLAB R2024a可启动,true,PASS,R2024a" ...
    "S0-RPT-001,报告,可从样例证据生成中文Word,true,PASS,PASS"], newline));

write_text(fullfile(runRoot, 'issues', 'issue_log.csv'), ...
    'issue_id,test_id,severity,symptom,root_cause,invalid_attempts,final_fix,regression_test,status,unresolved_item');

write_text(fullfile(runRoot, 'indices', 'variable_index.csv'), strjoin([ ...
    "variable_family,start_index,end_index,count" ...
    "Pf,1,4,4" ...
    "Ph,5,8,4"], newline));

fixture = struct('container', container, 'runRoot', runRoot, ...
    'projectRoot', projectRoot);
end

function write_text(filePath, content)
fileId = fopen(filePath, 'w', 'n', 'UTF-8');
assert(fileId >= 0, 'Unable to create test fixture file.');
cleanup = onCleanup(@() fclose(fileId)); %#ok<NASGU>
fwrite(fileId, char(content), 'char');
end

function remove_fixture(folderPath)
if isfolder(folderPath)
    rmdir(folderPath, 's');
end
end
