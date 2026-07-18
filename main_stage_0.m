function result = main_stage_0()
%MAIN_STAGE_0 Execute only stage_0 and persist all acceptance evidence.

projectRoot = fileparts(mfilename('fullpath'));
addpath(genpath(fullfile(projectRoot,'src')));
assert_stage0_ready(projectRoot);

runContext = create_run_context(projectRoot,'stage_0', ...
    'ModelContractVersion','1.0', ...
    'EffectiveConfigPath',fullfile(projectRoot,'config','stage_0.yaml'));
try
    result = run_stage0_acceptance(runContext);
catch ME
    preserve_catastrophic_failure(runContext,ME);
    rethrow(ME);
end
end

function assert_stage0_ready(projectRoot)
statePath = fullfile(projectRoot,'CURRENT_STAGE.md');
textValue = string(fileread(statePath));
if ~contains(textValue,'`stage_id`: `stage_0`') || ...
        ~contains(textValue,'`status`: `READY`')
    error('stage0:gate:NotReady', ...
        'CURRENT_STAGE.md must identify stage_0 / READY before execution.');
end
end

function preserve_catastrophic_failure(runContext,exception)
try
    issuePath = runContext.issue_log_path;
    if isfile(issuePath)
        issues = readtable(issuePath,'TextType','string', ...
            'VariableNamingRule','preserve','Encoding','UTF-8');
        if width(issues) ~= 14
            issues = new_stage0_issue_log();
        end
    else
        issues = new_stage0_issue_log();
    end
    issues = append_stage0_issue(issues,runContext,'S0-RUNNER', ...
        '阶段0执行器发生未捕获异常',exception.message, ...
        '执行器未能完成受控验收闭环', ...
        '修复代码后创建新 run_id 并重新运行全部受影响测试', ...
        'OPEN','run_manifest.json');
    write_table_csv_17g(issuePath,issues);
catch
    % Do not mask the original exception.
end
try
    manifest = jsondecode(fileread(runContext.run_manifest_path));
    if isfield(manifest,'status') && strcmp(manifest.status,'RUNNING')
        finalize_run_manifest(runContext,'FAIL_RETRYABLE', ...
            struct('fatal_error',exception.message));
    end
catch
    % Preserve the original exception even if finalization also fails.
end
end
