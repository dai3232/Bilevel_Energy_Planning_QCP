# 当前阶段状态

- `stage_id`: `stage_A4`
- `status`: `READY`
- `updated_at`: `2026-07-28`
- `next_stage_when_passed`: `stage_B`
- `blocking_rule`: 当前阶段所有 `blocking=true` 的验收项必须为 `PASS`。
- `notes`: stage_0、stage_A1、stage_A2、stage_A3 已 PASS。证据修复后的权威 stage_A3 正式运行 `20260721_113025_stage_A3_4edc8c66` 已通过原有 6 项阻断验收、A3 受控测试 67/67、A2 回归 32/32 和 A1 回归 37/37；真实 4340 维递推排列、历史目录与 ZIP 预检、完整 enabled_components、非零 binding residual 回归、证据哈希及中文报告视觉门禁均已验证。A4-1 已完成一次原始-对偶内点更新闭环并通过新增测试 24/24 及 A3/A2/A1 全量回归，但没有执行完整 IPM、没有创建正式 A4 run，也不表示 A4 已通过。当前仍为 `stage_A4 / READY`，不得进入 stage_B。冻结模型和输入数据未改变；用户于 2026-07-28 明确授权当前 A4 的四项迭代收敛阈值及两项递推方向审计阈值统一改为 `1e-6`，历史阶段与历史 run 不追溯改判。
