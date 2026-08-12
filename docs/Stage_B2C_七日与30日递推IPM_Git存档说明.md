# Stage B-2C 七日与 30 日递推 IPM Git 存档说明

## 存档范围

本文件所在 Git 提交保存以下内容：

- Stage B-2C 七日正式递推 IPM 生产链、配置、诊断、测试与报告代码；
- 第 17 日零模态定位、日内联合块以及水量二阶松弛校正相关代码；
- 30 日递推 IPM 实验入口、配置、报告代码；
- 下列两个最终 `PASS` 运行目录中的轻量、可审阅结果证据；
- 为上述代码所必需的 Stage A / B-2B 共享索引、线性化与递推求解改动。

本提交不更新 `CURRENT_STAGE.md`，不声称已获准进入 Stage C1。

## 七日正式结果

- `run_id`：`20260811_121452_stage_B_2C_4168a6e9`
- 状态：`PASS`
- 数据范围：第 14–20 日，每日 24 小时
- 接受迭代数：30
- 最终等式残差无穷范数：`4.5474735088646412e-12`
- 最终不等式残差无穷范数：`4.5474735088646412e-13`
- 最终统一尺度对偶残差无穷范数：`8.822001967612324e-11`
- 最终统一尺度平均互补间隙：`1.1255616063014672e-7`
- 每日水量最大违反量：0
- 最终递推 KKT 相对残差：`5.0435480551957201e-12`
- 正式 B-2C 固定测试：18/18 通过；该 run 内其余受影响回归与审计证据一并保存。

主要结果：

- `runs/20260811_121452_stage_B_2C_4168a6e9/results/capacity_results.csv`
- `runs/20260811_121452_stage_B_2C_4168a6e9/results/hourly_dispatch_results.csv`
- `runs/20260811_121452_stage_B_2C_4168a6e9/results/final_state_and_physical.mat`
- `runs/20260811_121452_stage_B_2C_4168a6e9/reports/阶段B-2C_七日递推IPM收敛与水量物理验收报告.docx`

## 30 日实验结果

- `run_id`：`20260811_155000_stage_B_2C_30day_full_final`
- 状态：`PASS`
- 数据范围：连续 30 日，每日 24 小时
- 接受迭代数：31
- 最终等式残差无穷范数：`4.5474735088646412e-12`
- 最终不等式残差无穷范数：`9.0949470177292824e-13`
- 最终统一尺度对偶残差无穷范数：`1.2245016681823929e-10`
- 最终统一尺度平均互补间隙：`2.5941858921630775e-7`
- 每日水量最大违反量：0
- 最终递推 KKT 相对残差：`1.1752538128386851e-11`
- 8/8 实验验收项通过。
- 纯 IPM 优化计算时间：`473.2153738 s`。该值为 `diagnostics/timing_history.csv` 的逐轮 `total_seconds` 之和，不含工作流装配、报告、审计和其他外围耗时。

主要结果：

- `runs/20260811_155000_stage_B_2C_30day_full_final/results/capacity_results.csv`
- `runs/20260811_155000_stage_B_2C_30day_full_final/results/daily_generation_summary.csv`
- `runs/20260811_155000_stage_B_2C_30day_full_final/results/hourly_dispatch_results.csv`
- `runs/20260811_155000_stage_B_2C_30day_full_final/results/final_state_and_physical.mat`
- `runs/20260811_155000_stage_B_2C_30day_full_final/reports/阶段B-2C_30日递推IPM实验报告_纯计算口径修订版.docx`

## 未纳入 Git 的大型工件

以下文件仍保留在本机原运行目录，但不进入 Git：

- 两个 run 的逐轮 `checkpoints/*.mat`；
- 7 日 run 的 `matrices/final_linearization.mat` 和 `matrices/final_direction_audit.mat`；
- 30 日 run 的 `matrices/final_recursive_operators.mat`；
- 7 日 run 的 `diagnostics/nonzero_water_hessian_gate.mat`（约 235.69 MB）。

这些大型文件均有对应清单、CSV/JSON 摘要或可由存档代码重新生成。两个小型 `results/final_state_and_physical.mat` 被纳入 Git，用于保留最终状态和物理数组。

## 回档方式

查看本存档提交：

```powershell
git show --stat <存档提交哈希>
```

从存档提交建立恢复分支：

```powershell
git switch -c restore/stage-b2c-7d-30d <存档提交哈希>
```

原始 Excel、受控参考文档和其他历史运行目录均不属于本次提交。
