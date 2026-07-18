# 测试分层与命名

- `unit`: Excel 标签解析、索引、残差、Jacobian、固定零恢复、LDL 辅助函数。
- `integration`: 单日模型、完整 KKT 装配、递推回代、运行工件生成。
- `equivalence`: A1/A2/A3 方向严格等价。
- `regression`: 每个已修复问题的永久用例。
- `performance`: D1/D2/D3 性能，不作为正确性替代。

测试 ID 使用 `S<stage>-<category>-<number>`，并与阶段验收矩阵一致。
