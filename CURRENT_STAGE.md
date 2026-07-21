# 当前阶段状态

- `stage_id`: `stage_A4`
- `status`: `READY`
- `updated_at`: `2026-07-21`
- `next_stage_when_passed`: `stage_B`
- `blocking_rule`: 当前阶段所有 `blocking=true` 的验收项必须为 `PASS`。
- `notes`: stage_0、stage_A1、stage_A2、stage_A3 已 PASS。stage_A3 正式运行 `20260721_080023_stage_A3_0fbd183e` 的 6 项阻断性验收全部 PASS，A3 固定测试 38/38 PASS、A2 回归 32/32 PASS、A1 回归 37/37 PASS；完整 KKT 为 `18836`，7 个日链为 `589, 590, 589, 590, 590, 590, 590`，既约系统为 `4340`，全局核心为 `16`，fixed_zero_map 为 `422` 项（光伏 420、风电 2），总体方向相对误差为 `4.2409105899819932e-16`，递推方向代回完整 KKT 相对残差为 `8.5770365872166353e-15`，直接求解相对残差为 `9.8384999783262683e-15`。当前仅将 stage_A4 置为 READY，尚未执行或通过 A4；正式模型仍为完整 24 小时每日 SOC 闭合。
