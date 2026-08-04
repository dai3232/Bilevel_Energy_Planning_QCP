# 阶段B：四座水电每日用水上下限：状态与决策日志

- 当前状态：`READY`（B-2B 为 `READY_FOR_REVIEW`；不表示 Stage B 整体通过）
- 最近里程碑：`B-2B`
- 最近权威 run_id：`20260804_022443_stage_B_2B_4bcd7504`
- 最近运行 Git commit：`4bcd7504cf737c45e2ef6c8662d83b40507b95f5`
- 阻断问题：`无记录`
- 下一动作：在另行授权后执行 `SB-PHY-001` 物理验收；当前保持 `stage_B / READY`，不得将 B-2B 解释为 Stage B 整体通过，也不得进入 Stage C1。

## B-2B 验收结论（2026-08-04）

- 正式命令：`matlab -batch "result=main_stage_B_2B(); disp(result.run_id); disp(result.status); assert(strcmp(char(result.status),'PASS'));"`
- 共享线性化：第14—20日、每天第1—24小时、4座水电站；primal `3722`、equality `618`、inequality `7304`，完整原始—对偶 KKT `18948`，`nnz=53992`。水量 Lagrangian Hessian 每次由当前正 `l/z` 状态重建；B-2B 未复用 B-2A 的固定 `1.25/0.75` 诊断乘子。
- 不等式精确消元采用 `D=diag(z./l)`、`W=H_L+G'*D*G` 及当前 residual 合同右端；回代采用 `Δl=-r_ineq-GΔx`、`Δz=(-r_comp-z·Δl)./l`。既约矩阵对称性、四类完整 KKT 方程回代和 stationarity 有限差分均为 `PASS`。
- 七日日链维数：`589/590/589/590/590/590/590`；每日日级水量边框固定为 `8`，增广维数为 `597/598/597/598/598/598/598`。每个边框行只连接同日同站24个 `PH` 变量，跨日/跨站耦合为零；每日日响应 `14×14`，全局核心 `16×16`。
- 保留原 LDL/Thomas 因子完成每日日链 `1+14+8=23` 个右端；水量 `G_w' D_w G_w` 未塞入纯小时三对角块，装配位置明确为日级增广边框。七日增广相对残差最大值为 `9.4354449641583821e-16`。
- `SB-EQ-001`：`PASS`。总体方向相对误差 `1.5000076826131547e-15`；`xi/y/l/z` 分量误差分别为 `3.88382922085894e-16`、`5.8744720386592106e-16`、`1.4856102618865775e-15`、`2.2081600048067107e-13`；递推方向代回完整 KKT 相对残差 `4.8537829603427401e-12`；完整 KKT 独立审计方向残差 `1.20685804249556e-14`。
- 固定零映射 `422` 项的值和方向均精确为零；`no_full_direction_fallback=true`，完整 KKT 只作独立审计，递推流程未消费完整方向。
- 测试汇总：B-2B `12/12 PASS`、B-2A `19/19 PASS`、B-1 `14/14 PASS`、B-1受影响回归 `5/5 PASS`、Stage-A结构回归 `5/5 PASS`，合计 `55/55 PASS`，失败 `0`、不完整 `0`；Code Analyzer `0`，禁止项与依赖闭包审计全部 `PASS`，`git diff --check` 通过。
- Manifest 终态 `PASS`，里程碑状态 `READY_FOR_REVIEW`；`full_kkt_solved=true` 仅表示独立审计，`recursive_direction_executed=true`，`full_ipm_executed=false`、`optimization_executed=false`、`state_update_executed=false`、`parallel_executed=false`、`stage_c1_entered=false`。
- `SB-PHY-001` 保持 `NOT_RUN`。Stage B 整体仍为 `READY`，未执行多日优化收敛、年度IPM、火电第二次、并行或 Stage C1。
- 中文报告由真实 run 工件生成，OOXML结构/语义验证 `PASS`，报告及73项证据SHA256独立复核全部一致。当前环境缺少 `soffice`/LibreOffice，DOCX→PNG视觉渲染无法完成；未把该外部缺失伪装成视觉 `PASS`。
- 两份Excel实际SHA256保持为：基础参数 `aebb35fa80e6ba2fb8d4534b09a141feaedcb2b9d027e9924e7a0091943c4277`，输入数据 `10baac1dc5d0b07dbbb9d2fe8f9aac82f071e43d4fb9901ff7ba0b467d05c186`。冻结模型合同、A4历史runs、B-2A历史run及 `Hourly_Recursive_KKT_pkg` 均未修改。
- 早先 run `20260804_022242_stage_B_2B_4eb2d5ac` 在方向计算前被 LDL 可用性门禁的 `exist` 类型码判断错误拦截，历史 manifest 保留为 `BLOCKED_EXTERNAL`。实际根因是实现检查器只接受错误的类型值，并非 MATLAB/许可证缺失；修复提交 `4bcd7504cf737c45e2ef6c8662d83b40507b95f5` 后重新执行形成上述权威 PASS run。失败run未删除、覆盖或改写。

## B-2A 验收结论（2026-08-03）

- 正式命令：`matlab -batch "result=main_stage_B_2A(); disp(result.run_id); assert(strcmp(char(result.status),'PASS'));"`
- 数据窗口：第14—20日、每天第1—24小时、4座水电站；新增日级水量不等式恰好56条，排序为日外层/水电站内层/upper、lower。
- 结构阻断审计：`6/6 PASS`（56行规范索引、解析导数、G/offset恒等式、z加权Lagrangian Hessian、完整KKT结构及环境边界）。
- 水量索引：`56/56 PASS`；每行恰好24个同日同站 `PH` 列，跨日/跨站耦合均为零。
- 最大梯度相对误差：`6.4977263335914302e-13`；最大 Hessian 相对误差：`2.528237812360457e-09`；线性化 identity 误差：`0`。
- 维数与稀疏结构：primal `3722`、equality `618`、inequality `7304`、完整原始—对偶 KKT `18948`，`nnz=54664`；Lagrangian Hessian `nnz=672`、对称相对误差 `0`。原始完整 KKT 按合同含 `I/Z` 互补块，整体非对称状态如实记录为合同适用而非强制对称。
- 测试汇总：B-2A 固定测试 `19/19 PASS`；B-1 固定测试 `14/14 PASS`；B-1 受影响回归 `5/5 PASS`；Stage-A结构回归 `5/5 PASS`，合计 `43/43 PASS`，失败 `0`、不完整 `0`；Code Analyzer `0`，禁止调用审计 `0`。
- `SB-EQ-001` 和 `SB-PHY-001` 保持 `NOT_RUN`；完整 KKT 仅装配，`full_kkt_solved=false`、`recursive_direction_executed=false`、`full_ipm_executed=false`、`optimization_executed=false`、`parallel_executed=false`，未进入 Stage C1。
- 报告由本 run 工件生成，OOXML结构/语义验证 `PASS`。当前环境没有可用 `soffice`/LibreOffice，无法生成 PNG 视觉复核；该限制已如实保留，不影响结构审计结论。
- 两份Excel实际SHA256保持为：基础参数 `aebb35fa80e6ba2fb8d4534b09a141feaedcb2b9d027e9924e7a0091943c4277`，输入数据 `10baac1dc5d0b07dbbb9d2fe8f9aac82f071e43d4fb9901ff7ba0b467d05c186`。B-1权威run、A4历史runs和 `Hourly_Recursive_KKT_pkg` 未修改。

## B-1 验收结论（2026-08-03）

- 正式命令：`matlab -batch "result=main_stage_B_1(); disp(result.run_id); assert(strcmp(char(result.status),'PASS'));"`
- 数据窗口：第14—20日、每天第1—24小时、4座水电站。
- `SB-DATA-001`：`PASS`，水量输入审计恰好28条，顺序为日外层/水电站内层。
- `SB-DER-001`：`PASS`，112个确定性样本；最大梯度相对误差为 `2.3632709629129663e-12`，最大 Hessian 相对误差为 `8.7557365212280878e-09`，阈值保持 `1e-7`。
- `SB-EQ-001`：`NOT_RUN`；`SB-PHY-001`：`NOT_RUN`。
- B-1固定测试：`14/14 PASS`；受影响数据/索引回归：`5/5 PASS`；Code Analyzer：`0`；`git diff --check`：通过。
- 两份Excel实际SHA256保持为：基础参数 `aebb35fa80e6ba2fb8d4534b09a141feaedcb2b9d027e9924e7a0091943c4277`，输入数据 `10baac1dc5d0b07dbbb9d2fe8f9aac82f071e43d4fb9901ff7ba0b467d05c186`。

本里程碑只实现水电日用水数据审计、单站单日水耗值/解析梯度/Hessian及独立有限差分证据。未装配完整KKT，未计算递推方向或Newton方向，未运行IPM/优化，未修改LDL/Thomas，未执行火电第二次、并行、30日、365日或Stage C1；因此 Stage B 仍为 `READY`，`CURRENT_STAGE.md` 未修改。

## 证据边界与历史运行

报告和所有数值均从 `runs/20260803_123004_stage_B_1_fcccf11d` 的持久化工件读取。早先生成的 `20260803_121909_stage_B_1_NO_COMMIT` 保留为非权威诊断证据，原因是当时 MATLAB 子进程的短SHA探测退化为 `NO_COMMIT`；其内容未覆盖、未删除。修复Git身份读取后，以上述 `fcccf11d` 命名的run作为权威B-1结果。

开发期曾误把完整 Stage-0 回归作为受影响回归执行，短暂启动并关闭1个 Processes worker；没有运行模型、KKT、IPM或生成正式run。正式B-1 run只执行5项数据/索引回归，未启动并行。该边界修正已固化在 `run_stage_B_1_affected_regressions.m` 中。

> Codex 必须在每个里程碑后更新本文件，不得用聊天上下文替代持久化状态。
