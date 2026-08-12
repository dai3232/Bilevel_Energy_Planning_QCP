# 当前阶段状态

- `stage_id`: `stage_D1`
- `status`: `READY`
- `updated_at`: `2026-08-12`
- `next_stage_when_passed`: `stage_D2`
- `blocking_rule`: 当前阶段所有 `blocking=true` 的验收项必须为 `PASS`。
- `execution_scope`: `DESIGN_DISCUSSION_ONLY`
- `open_decision`: `DECISION-D1-01`
- `notes`: stage_0、stage_A1、stage_A2、stage_A3、stage_A4 和 stage_B 已 `PASS`。Stage B 权威七日运行 `20260811_121452_stage_B_2C_4168a6e9` 终态为 `CONVERGED / PASS`，30 次接受迭代，`SB-DATA-001`、`SB-DER-001`、`SB-EQ-001`、`SB-PHY-001` 四项阻断验收和汇总 90/90 测试全部通过；水量约束最大违反量为 0。用户于 2026-08-12 明确决定暂不执行 stage_C1、stage_C2，并授权项目路由直接到 stage_D1。C1/C2 均保持 `NOT_STARTED / USER_DEFERRED`，不是 `PASS`，也没有生成火电掩码或执行第二次火电求解。stage_D1 当前 `READY` 仅表示可以讨论方案；在 `DECISION-D1-01` 明确 D1 采用的火电模型基线并同步模型合同/启用矩阵前，不得实现或运行 D1。

## 阶段路由例外

- 正常合同路线仍为 `stage_B → stage_C1 → stage_C2 → stage_D1`。
- 本次 `stage_B → stage_D1` 是用户明确授权的阶段路由例外，不追溯改写 C1/C2 的验收矩阵，也不把未运行阶段记为通过。
- `docs/03_阶段模型启用矩阵.csv` 当前仍规定 D1 使用 C2 的第二次火电口径；由于 C2 未执行，该冲突必须在 D1 方案讨论中先解决。
