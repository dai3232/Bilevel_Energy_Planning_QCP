function report = generate_stage_b2c_configured_report(runRoot,options)
%GENERATE_STAGE_B2C_CONFIGURED_REPORT Build the common Chinese run report.

arguments
    runRoot (1,1) string
    options.OutputFileName (1,1) string = ...
        "阶段B-2C_统一连续区间递推IPM运行报告.docx"
end
manifest = jsondecode(fileread(fullfile(runRoot,"run_manifest.json")));
iterations = read_csv(fullfile(runRoot,"diagnostics","iteration_history.csv"));
timing = read_csv(fullfile(runRoot,"diagnostics","timing_history.csv"));
dimensions = read_csv(fullfile(runRoot,"diagnostics","dimension_summary.csv"));
caches = read_csv(fullfile(runRoot,"diagnostics","cache_summary.csv"));
capacity = read_csv(fullfile(runRoot,"results","capacity_results.csv"));
daily = read_csv(fullfile(runRoot,"results","daily_generation_summary.csv"));
acceptance = read_csv(fullfile(runRoot,"acceptance","acceptance_results.csv"));
dayCount = double(manifest.day_count);
assert(height(timing)==height(iterations) && height(capacity)==14 && ...
    height(daily)==dayCount && height(acceptance)==8 && height(caches)==3, ...
    "stageB2C:configured:ReportEvidence", ...
    "The configured run report evidence is incomplete.");

converged = logical_value(manifest.convergence_achieved);
auditMode = string(manifest.audit_mode);
parallelExecuted = isfield(manifest,"parallel_executed") && ...
    logical_value(manifest.parallel_executed);
if parallelExecuted
    executionText = compose( ...
        "%d个日内联合块由%d个Processes worker并行求解；16维全局核心、状态更新、检查点和审计仍保持串行顺序。", ...
        dayCount,double(manifest.parallel_worker_count));
else
    executionText = compose("%d个日内联合块按日期串行求解。",dayCount);
end
explicitDaySet = isfield(manifest,"explicit_day_set") && ...
    logical_value(manifest.explicit_day_set);
scopeText = compose("第%d—%d日",manifest.day_start,manifest.day_end);
scopeKind = "统一连续区间";
scopeNote = "所选连续区间";
outputFileName = options.OutputFileName;
if explicitDaySet
    daySequence = reshape(double(manifest.day_sequence),1,[]);
    excluded = setdiff(manifest.day_start:manifest.day_end,daySequence);
    scopeText = compose("第%d—%d日中排除第%s日（共%d日）", ...
        manifest.day_start,manifest.day_end, ...
        strjoin(string(excluded),"、"),numel(daySequence));
    scopeKind = "显式选定日集合";
    scopeNote = "显式选定日集合";
    if outputFileName=="阶段B-2C_统一连续区间递推IPM运行报告.docx"
        outputFileName = "阶段B-2C_显式选定日集合递推IPM运行报告.docx";
    end
end
if converged
    conclusion = scopeText+"递推原始—对偶IPM已满足四项停止判据，并完成最终物理审计。";
else
    conclusion = scopeText+"已完成限定迭代，但尚未同时满足四项停止判据，不应解释为收敛解。";
end
if auditMode=="full_kkt"
    routeText = "每次迭代执行独立完整KKT方向审计；递推方向仍是正式方向。递推重构KKT相对残差门槛为1e-8，递推/完整方向相对误差和完整KKT审计方向自身残差仍为1e-10。";
else
    routeText = "未装配或求解完整KKT；方向由1e-8重构KKT相对残差门禁验证，日块和16维核心局部LDL求解目标保持1e-10。";
end
metadata = struct("run_id",string(manifest.run_id), ...
    "stage_id","stage_B / B-2C "+scopeKind, ...
    "git_commit",string(manifest.git_commit), ...
    "manifest_status",string(manifest.milestone_status), ...
    "candidate_status",conditional_text(converged,"已收敛","限定迭代"), ...
    "report_kicker","STAGE B-2C · 统一递推IPM", ...
    "header_label","STAGE B-2C · "+scopeText);

blocks = repmat(block_template(),0,1);
blocks(end+1) = callout_block("运行结论",conclusion+routeText);
blocks(end+1) = heading_block(1,"1. 运行边界与算法口径");
blocks(end+1) = paragraph_block(scopeText+ ...
    "，每日24小时；各日储能初末SOC均为0.5E，日期之间不连接SOC。火电采用第一次连续口径0≤Pf≤Pmax。采用全不等式消元、"+ ...
    executionText+"全局保留16维核心，并保留水量约束精确二阶松弛校正。审计模式为 "+auditMode+ ...
    "。本次运行不进入C1/C2或D1，也不执行火电第二次求解。");

blocks(end+1) = heading_block(1,"2. 规模与缓存");
blocks(end+1) = table_block(["规模项目","实际值"], ...
    select_rows(dimensions,["metric","actual_value"]),[4400,4960]);
blocks(end+1) = table_block(["缓存类型","状态","命中","读取秒","构建秒","写入秒"], ...
    select_rows(caches,["cache_type","status","hit","load_seconds", ...
    "build_seconds","write_seconds"]),[1700,1500,1100,1600,1660,1800]);

blocks(end+1) = heading_block(1,"3. 收敛轨迹（最后10次迭代）");
if isempty(iterations)
    tailRows = strings(0,8);
else
    tail = iterations(max(1,height(iterations)-9):height(iterations),:);
    tailRows = select_rows(tail,["iteration","primal_equality_inf", ...
        "primal_inequality_inf","dual_scaled_inf","mean_lz_scaled", ...
        "alpha_primal","alpha_dual", ...
        "recursive_final_kkt_relative_residual"]);
end
blocks(end+1) = table_block( ...
    ["迭代","等式残差","不等式残差","对偶残差","平均互补隙", ...
    "原始步长","对偶步长","重构KKT残差"],tailRows, ...
    [650,1300,1300,1250,1250,1000,1000,1610]);

blocks(end+1) = heading_block(1,"4. 求解耗时");
timingRows = [ ...
    "接受迭代次数",number_text(height(iterations)); ...
    "纯IPM数值计算秒数",number_text(sum_numeric(timing.total_seconds)); ...
    "递推方向累计秒数",number_text(sum_numeric(timing.recursive_seconds)); ...
    "日块响应累计计算秒数",number_text(field_or_default( ...
        manifest,"daily_response_compute_seconds",NaN)); ...
    "进程池启动秒数",number_text(field_or_default( ...
        manifest,"parallel_pool_startup_seconds",0)); ...
    "完整KKT审计累计秒数", ...
        number_text(sum_numeric(timing.full_kkt_audit_seconds)); ...
    "迭代内线性化装配累计秒数",number_text( ...
        sum_numeric(timing.linearization_before_seconds)+ ...
        sum_numeric(timing.linearization_after_seconds))];
blocks(end+1) = table_block(["项目","实际值"],timingRows,[4400,4960]);

blocks(end+1) = heading_block(1,"5. 容量规划结果");
blocks(end+1) = table_block(["序号","容量变量","值"], ...
    select_rows(capacity,["capacity_index","capacity_name","value"]), ...
    [900,4300,4160]);
blocks(end+1) = heading_block(1,"6. 各类电源每日发电量");
blocks(end+1) = table_block( ...
    ["日","风电MWh","光伏MWh","水电MWh","火电MWh", ...
    "充电MWh","放电MWh","总发电MWh"], ...
    select_rows(daily,["day","wind_mwh","solar_mwh","hydro_mwh", ...
    "thermal_mwh","storage_charge_mwh","storage_discharge_mwh", ...
    "total_generation_mwh"]), ...
    [500,1200,1200,1200,1200,1200,1200,1660]);
blocks(end+1) = heading_block(1,"7. 本次运行验收");
blocks(end+1) = table_block(["检查项","要求","实际值","状态"], ...
    select_rows(acceptance,["test_id","requirement","actual_value", ...
    "status"]),[1900,3000,2860,1600]);
blocks(end+1) = paragraph_block( ...
    "本报告只说明"+scopeNote+"的本次运行状态；不改写Stage B既有正式验收结论。" );

outputPath = fullfile(runRoot,"reports",outputFileName);
rkkt.reporting.write_stage_b2c_docx(outputPath, ...
    "阶段B-2C："+scopeKind+"递推IPM运行报告", ...
    scopeText+" · "+auditMode,metadata,blocks);
report = struct("path",string(outputPath), ...
    "run_id",string(manifest.run_id),"status","GENERATED", ...
    "design_preset","standard_business_brief", ...
    "header_pattern","memo_masthead");
end

function value = read_csv(pathValue)
options = detectImportOptions(pathValue,"Delimiter",",", ...
    "TextType","string","VariableNamingRule","preserve");
options.VariableNamesLine = 1; options.VariableUnitsLine = 0;
options.VariableDescriptionsLine = 0; options.DataLines = [2,Inf];
options = setvartype(options,options.VariableNames,"string");
value = readtable(pathValue,options);
end

function rows = select_rows(source,names)
rows = strings(height(source),numel(names));
for column = 1:numel(names), rows(:,column) = string(source.(names(column))); end
end

function value = sum_numeric(raw)
value = sum(str2double(string(raw)),"omitnan");
end

function value = number_text(number)
value = compose("%.17g",double(number));
end

function value = field_or_default(source,name,defaultValue)
if isfield(source,name)
    value = source.(name);
else
    value = defaultValue;
end
end

function value = logical_value(raw)
if islogical(raw), value = raw; else, value = lower(string(raw))=="true"; end
end

function value = conditional_text(condition,whenTrue,whenFalse)
if condition, value = string(whenTrue); else, value = string(whenFalse); end
end

function value = block_template()
value = struct("type","","level",0,"text","","title","", ...
    "headers",strings(1,0),"rows",strings(0,0),"widths",zeros(1,0));
end

function value = heading_block(level,textValue)
value = block_template(); value.type = "heading";
value.level = level; value.text = string(textValue);
end

function value = paragraph_block(textValue)
value = block_template(); value.type = "paragraph";
value.text = string(textValue);
end

function value = callout_block(titleValue,textValue)
value = block_template(); value.type = "callout";
value.title = string(titleValue); value.text = string(textValue);
end

function value = table_block(headers,rows,widths)
value = block_template(); value.type = "table";
value.headers = reshape(string(headers),1,[]);
value.rows = string(rows); value.widths = reshape(double(widths),1,[]);
assert(size(value.rows,2)==numel(value.headers) && ...
    numel(value.widths)==numel(value.headers) && ...
    sum(value.widths)==9360,"stageB2C:configured:ReportTable", ...
    "Report table geometry must total 9360 DXA.");
end
