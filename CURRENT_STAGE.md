# 当前阶段状态

- `stage_id`: `stage_D1`
- `status`: `READY`
- `updated_at`: `2026-08-27`
- `next_stage_when_passed`: `stage_D2`
- `blocking_rule`: 当前阶段所有 `blocking=true` 的验收项必须为 `PASS`。
- `execution_scope`: `DESIGN_DISCUSSION_ONLY`
- `open_decision`: `DECISION-D1-01`
- `supplemental_execution_exception`: `B-2C-365-SERIAL-RESUMABLE-AUTHORIZED`
- `supplemental_refactor_exception`: `B-2C-UNIFIED-RUNNER-REFACTOR-AUTHORIZED`
- `supplemental_numerical_refactor_exception`: `B-2C-JOINT-MICROBORDER-REFACTOR-AUTHORIZED`
- `supplemental_parallel_exception`: `B-2C-RUN-PROJECT-DAY-BLOCK-PARALLEL-AUTHORIZED`
- `supplemental_screened_scope_exception`: `B-2C-RUN-PROJECT-SCREENED307-AUTHORIZED`
- `notes`: stage_0、stage_A1、stage_A2、stage_A3、stage_A4 和 stage_B 已 `PASS`。Stage B 权威七日运行 `20260811_121452_stage_B_2C_4168a6e9` 终态为 `CONVERGED / PASS`，30 次接受迭代，`SB-DATA-001`、`SB-DER-001`、`SB-EQ-001`、`SB-PHY-001` 四项阻断验收和汇总 90/90 测试全部通过；水量约束最大违反量为 0。用户于 2026-08-12 明确决定暂不执行 stage_C1、stage_C2，并授权项目路由直接到 stage_D1。C1/C2 均保持 `NOT_STARTED / USER_DEFERRED`，不是 `PASS`，也没有生成火电掩码或执行第二次火电求解。stage_D1 当前 `READY` 仍只允许方案讨论；在 `DECISION-D1-01` 关闭前不得实现或运行 D1。Stage B-2C 的统一入口、年度数据缓存、区间 index 缓存、逐次接受迭代检查点与显式断点续算已完成；用户又于 2026-08-26 授权 `RUN_PROJECT.m` 可配置普通日块的 Processes 并行，核心求解、状态更新、检查点、审计和报告仍保持串行。该补充执行优化不改变 Stage B 的既有 PASS，不属于 D1，也不授权 D1 实现或火电第二次求解。

## 阶段路由例外

- 正常合同路线仍为 `stage_B → stage_C1 → stage_C2 → stage_D1`。
- 本次 `stage_B → stage_D1` 是用户明确授权的阶段路由例外，不追溯改写 C1/C2 的验收矩阵，也不把未运行阶段记为通过。
- `docs/03_阶段模型启用矩阵.csv` 当前仍规定 D1 使用 C2 的第二次火电口径；由于 C2 未执行，该冲突必须在 D1 方案讨论中先解决。
- `B-2C-365-SERIAL-RESUMABLE-AUTHORIZED` 只开放 `stages/stage_B/阶段B_365日串行补充实验方案.md` 冻结的 365 日串行补充实验；不得借此启动 D1、并行求解或火电第二次求解。
- `B-2C-UNIFIED-RUNNER-REFACTOR-AUTHORIZED` 只开放用户于 2026-08-12 确认的 Stage B-2C 统一入口、连续日期配置、年度数据缓存和日期区间 index 缓存重构及其 7/30 日验证；不改变 Stage B 已有 PASS，不进入 D1，不授权并行、C1/C2 或火电第二次求解。
- `B-2C-JOINT-MICROBORDER-REFACTOR-AUTHORIZED` 只开放用户于 2026-08-23 确认的 Stage B-2C 数值求解重构：正式采用 `a-Ug` 响应组合、物理 high+low 16 维基块，以及对唯一已确认联合等式—不等式近零模态的 17 维微边框；不改变模型、目标、物理约束或收敛阈值，也不开放 D1、并行、C1/C2 或火电第二次求解。
- `B-2C-RUN-PROJECT-DAY-BLOCK-PARALLEL-AUTHORIZED` 只开放用户于 2026-08-26 确认的 Stage B-2C 执行优化：`RUN_PROJECT.yaml` 可选择串行或 Processes 并行，且只并行普通日块分解与多右端回代；16/17 维核心、状态更新、检查点、审计和报告均串行。该例外不进入 D1，不改变模型、数值门槛、C1/C2 或火电口径。
- `B-2C-RUN-PROJECT-SCREENED307-AUTHORIZED` 只开放用户于 2026-08-27 确认的统一入口范围预设：`day_scope=screened_307` 精确复用既有全年筛选证据中的307日集合和58个排除日；不把排除日替换为前一日，也不改变剩余日的模型、数据或收敛门槛。
