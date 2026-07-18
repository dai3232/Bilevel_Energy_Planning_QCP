# 代码接口约定

建议的 MATLAB 接口如下，Codex 可在不改变职责的前提下优化命名：

- `data = load_project_data(modelConfig)`：读取、校验和规范化两份 Excel。
- `index = build_canonical_index(data, stageConfig, thermalMask)`：建立规范活动索引和固定零映射。
- `state = initialize_primal_dual_state(data, index, solverConfig)`：确定性初值。
- `lin = build_linearization(state, data, index, modelConfig, stageConfig)`：唯一线性化对象。
- `dirFull = solve_full_kkt_direction(lin, index)`：完整稀疏 KKT 审计方向。
- `dirRec = solve_recursive_direction(lin, index, solverConfig)`：小时递推正式方向。
- `audit = verify_direction_equivalence(dirFull, dirRec, lin, index)`：完整方向和代回残差。
- `result = solve_primal_dual_ipm(data, configs)`：完整内点迭代。
- `artifacts = export_run_artifacts(runContext, state, lin, directions, audit)`：CSV/MAT/JSON 输出。
- `generate_stage_reports(runContext)`：从工件生成中文 Word 报告。

`lin` 至少含：`H,A,G,r_dual,r_eq,r_ineq,r_comp,l,z,mu,index_version,fixed_zero_map`，以及可直接装配小时块和完整 KKT 的局部结构。
