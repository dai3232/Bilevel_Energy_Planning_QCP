function pathValue = generate_stage_a3_failure_report(runContext,exception,issues,acceptance)
%GENERATE_STAGE_A3_FAILURE_REPORT Persist a minimal Chinese failure report.

arguments
    runContext (1,1) struct
    exception (1,1) MException
    issues table = new_stage_a3_issue_log()
    acceptance table = table()
end
pathValue=string(fullfile(runContext.reports_dir, ...
    "阶段A3_失败与首层定位报告.docx"));
assert(~isfile(pathValue)&&~isfolder(pathValue), ...
    "stageA3:failureReport:ArtifactExists", ...
    "Refusing to overwrite failure report %s.",pathValue);
manifest=jsondecode(fileread(runContext.run_manifest_path));
metadata=struct("run_id",string(runContext.run_id), ...
    "stage_id",string(runContext.stage_id), ...
    "git_commit",string(manifest.git_commit), ...
    "manifest_status",string(manifest.status), ...
    "candidate_status",failure_status(exception));
blocks=repmat(block_template(),0,1);
blocks(end+1)=callout_block('失败结论', ...
    '本报告记录首个失败层级；不宣告 Stage A3 通过，也不允许进入 A4。');
blocks(end+1)=heading_block('一、首个失败',1);
blocks(end+1)=table_block(["字段","实际记录"],[ ...
    "异常标识",string(exception.identifier); ...
    "异常消息",string(exception.message); ...
    "首个失败层级",first_layer(exception); ...
    "运行标识",string(runContext.run_id)],[2500 6860]);
blocks(end+1)=heading_block('二、验收状态',1);
if isempty(acceptance)
    blocks(end+1)=paragraph_block('验收表尚未形成；请以当前 run 中已持久化文件为准。');
else
    rows=strings(height(acceptance),3);
    rows(:,1)=string(acceptance.test_id); rows(:,2)=string(acceptance.actual_value);
    rows(:,3)=string(acceptance.status);
    blocks(end+1)=table_block(["test id","actual value","status"],rows, ...
        [2200 5360 1800]);
end
blocks(end+1)=heading_block('三、问题日志',1);
if height(issues)==0
    blocks(end+1)=paragraph_block('尚无结构化问题行；异常本身已保存在 run manifest。');
else
    rows=[string(issues.issue_id),string(issues.test_id), ...
        string(issues.elimination_layer),string(issues.status)];
    blocks(end+1)=table_block(["issue id","test id","layer","status"], ...
        rows,[1800 1700 4060 1800]);
end
blocks(end+1)=heading_block('四、范围边界',1);
blocks(end+1)=paragraph_block( ...
    '失败运行仍为不可覆盖证据。未执行完整IPM、优化、并行、容量规划、调度或经济性解释。修复后必须创建新的唯一run。');
write_stage_a3_docx(pathValue,'阶段A3_失败与首层定位报告', ...
    '失败运行证据 · 停留在 Stage A3',metadata,blocks);
[valid,details]=validate_docx_package(pathValue);
assert(valid,'stageA3:failureReport:InvalidDocxPackage','%s', ...
    strjoin(string(details.errors),'; '));
end

function value=first_layer(exception)
token=regexp(string(exception.message),"layer '([^']+)'",'tokens','once');
if isempty(token), value=string(exception.identifier); else, value=string(token{1}); end
end
function value=failure_status(exception)
if startsWith(string(exception.identifier),"stageA3:external:")
    value="BLOCKED_EXTERNAL";
else
    value="FAIL_RETRYABLE";
end
end
function value=block_template()
value=struct("type","","level",0,"title","","text","", ...
    "headers",strings(1,0),"rows",strings(0,0),"widths",zeros(1,0));
end
function block=heading_block(textValue,level)
block=block_template(); block.type="heading"; block.text=string(textValue); block.level=level;
end
function block=paragraph_block(textValue)
block=block_template(); block.type="paragraph"; block.text=string(textValue);
end
function block=callout_block(titleText,textValue)
block=block_template(); block.type="callout"; block.title=string(titleText);
block.text=string(textValue);
end
function block=table_block(headers,rows,widths)
block=block_template(); block.type="table"; block.headers=string(headers);
block.rows=string(rows); block.widths=double(widths);
end
