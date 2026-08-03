# 阶段B：四座水电每日用水上下限：状态与决策日志

- 当前状态：`READY`（仅表示允许开展下一里程碑，不表示 Stage B 整体通过）
- 最近里程碑：`B-1`
- 最近权威 run_id：`20260803_123004_stage_B_1_fcccf11d`
- 最近运行 Git commit：`fcccf11d7fa150820aa9f238a0f42c33f5efe11b`
- 阻断问题：`无记录`
- 下一动作：`B-2`——在另行授权后扩展 linearization、完整 KKT 和递推日响应。

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
