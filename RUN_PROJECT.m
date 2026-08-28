% 点击“运行”后，所有可修改参数均从 config/RUN_PROJECT.yaml 读取。

projectRoot = string(fileparts(mfilename("fullpath")));
addpath(fullfile(projectRoot,"src"));
runSettings = rkkt.config.read_run_project_configuration(projectRoot);
if runSettings.day_scope=="screened_307"
    fprintf("\n准备计算：全年 screened_307 筛选集合，共 %d 天（覆盖第 1—365 日，剔除 %d 天）。\n", ...
        numel(runSettings.days),numel(runSettings.excluded_days));
else
    fprintf("\n准备计算：第 %d 日至第 %d 日，共 %d 天。\n", ...
        runSettings.day_start,runSettings.day_end,numel(runSettings.days));
end
projectResult = rkkt.run();

if isfield(projectResult,"parallel_pool")
    pool = projectResult.parallel_pool;
    fprintf("\n日块执行方式：%s\n",pool.mode);
    if pool.enabled
        fprintf("并行进程数：%d\n",pool.worker_count);
        fprintf("进程池动作：%s\n",pool.action);
        fprintf("进程池启动时间：%.3f 秒\n",pool.startup_seconds);
    end
end

if isfield(projectResult,"ipm") && ...
        isfield(projectResult.ipm,"final_metrics")
    fprintf("\n求解状态：%s\n",projectResult.ipm.run_terminal_state);
    fprintf("内点法迭代数：%d\n",projectResult.ipm.accepted_iteration_count);
    metrics = projectResult.ipm.final_metrics;
    fprintf("等式残差无穷范数：%.17g\n",metrics.primal_equality_inf);
    fprintf("不等式残差无穷范数：%.17g\n",metrics.primal_inequality_inf);
    fprintf("对偶残差无穷范数（统一尺度）：%.17g\n",metrics.dual_scaled_inf);
    fprintf("平均互补间隙（统一尺度）：%.17g\n",metrics.mean_lz_scaled);
    fprintf("每日水量约束最大违反量：%.17g\n",metrics.maximum_water_violation);
end
fprintf("正式运行状态：%s\n",projectResult.status);
fprintf("运行目录：%s\n",projectResult.run_path);

if projectResult.status~="PASS"
    error("rkkt:run:StageB2CFailed","%s",projectResult.error_message);
end

capacityPath = fullfile(projectResult.run_path,"results", ...
    "capacity_results.csv");
capacityResults = readtable(capacityPath,"Delimiter",",", ...
    "TextType","string", ...
    "VariableNamingRule","preserve");
fprintf("\n十四个容量决策结果：\n");
disp(capacityResults(:,["capacity_index","capacity_name","value"]));
fprintf("纯 IPM 优化求解总时长：%.3f 秒（%.3f 分钟）。\n", ...
    projectResult.recursive_ipm_seconds, ...
    projectResult.recursive_ipm_seconds/60);
