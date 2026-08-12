% Click Run to solve, validate and preserve one formal seven-day run.

projectRoot = string(fileparts(mfilename("fullpath")));
addpath(fullfile(projectRoot,"src"));
projectResult = rkkt.run();%.run输出的是一个project对象

if isfield(projectResult,"ipm")
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
capacityResults = readtable(capacityPath,"TextType","string", ...
    "VariableNamingRule","preserve");
fprintf("\n十四个容量决策结果：\n");
disp(capacityResults(:,["capacity_name","value","unit","status"]));
