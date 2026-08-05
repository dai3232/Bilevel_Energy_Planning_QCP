% Click Run to solve, validate and preserve one formal seven-day run.

projectRoot = string(fileparts(mfilename("fullpath")));
addpath(fullfile(projectRoot,"src"));
projectResult = rkkt.run();

fprintf("\n求解状态：%s\n",projectResult.solution.run_terminal_state);
fprintf("正式运行状态：%s\n",projectResult.status);
fprintf("内点法迭代数：%d\n",projectResult.solution.iteration_count);
metrics = projectResult.solution.final_metrics;
fprintf("等式残差无穷范数：%.17g\n",metrics.r_eq_inf);
fprintf("不等式残差无穷范数：%.17g\n",metrics.r_ineq_inf);
fprintf("对偶残差无穷范数（统一尺度）：%.17g\n", ...
    metrics.r_dual_scaled_inf);
fprintf("平均互补间隙（统一尺度）：%.17g\n",metrics.mean_lz_scaled);
fprintf("物理不等式最大违反量：%.17g\n", ...
    metrics.physical_inequality_violation);
fprintf("运行目录：%s\n",projectResult.run_path);
fprintf("历史索引：%s\n",fullfile(projectRoot,"runs","运行索引.csv"));
fprintf("最新 PASS：%s\n",fullfile(projectRoot,"runs","LATEST_PASS.json"));

capacityPath = fullfile(projectResult.run_path,"results", ...
    "capacity_results.csv");
capacityResults = readtable(capacityPath,"TextType","string", ...
    "VariableNamingRule","preserve");
fprintf("\n十四个容量决策结果：\n");
disp(capacityResults(:,["capacity_name","value","unit","status"]));
