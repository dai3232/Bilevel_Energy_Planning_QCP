# 交给 Codex 的首次任务：只执行阶段 0

请在当前仓库中执行 `stage_0`，不得提前实现 `stage_A1` 或任何求解器算法。

## 开始前必须读取

1. 根目录 `AGENTS.md`
2. `README_从这里开始.md`
3. `CURRENT_STAGE.md`
4. `docs/00_用户确认的模型口径_v1.0.md`
5. `docs/02_最终模型合同_v1.0.md`
6. `docs/05_资料优先级与冲突处理规则.md`
7. `docs/06_数据字典与单位合同.md`
8. `docs/09_验收总则.md`
9. `docs/10_停止重试阻塞与升级规则.md`
10. `stages/stage_0/AGENTS.md`
11. `stages/stage_0/阶段0_长任务.md`
12. `stages/stage_0/阶段0_验收矩阵.csv`

## 本次必须完成

- 检查 MATLAB R2024a、稀疏线性代数和 Parallel Computing Toolbox 的可用性；无法访问 MATLAB 时必须进入 `BLOCKED_EXTERNAL`，不得伪造通过。
- 校验 `inputs/raw/基础参数.xlsx` 和 `inputs/raw/输入数据.xlsx` 的 SHA256。
- 编写以“工作表名称、区段标签、表头”为依据的数据读取器；禁止把 Excel 行号当成唯一读取逻辑。
- 读取并验证：火电 4、水电 4、风电 5、光伏 5、储能 2；365 日、24 时段、60 分钟；计划曲线乘 10000 MW。
- 建立规范化数据结构、唯一变量/约束索引框架、固定零变量映射框架。
- 建立不可覆盖的 `runs/<run_id>` 工件目录创建逻辑。
- 建立 CSV、MAT、JSON 和中文 Word 报告的输出框架；报告数值只能来自真实运行工件。
- 建立阶段状态机和验收执行器。
- 运行阶段 0 的全部阻断性测试，并生成：
  - `runs/<run_id>/acceptance/acceptance_results.csv`
  - `runs/<run_id>/issues/issue_log.csv`
  - `runs/<run_id>/reports/阶段0_环境数据与基础设施验收报告.docx`
  - `runs/<run_id>/reports/阶段0_问题修复与验收报告.docx`
- 只有全部阻断性验收为 `PASS`，才可把 `CURRENT_STAGE.md` 更新为 `stage_A1 / READY`。

## 严禁

- 不得修改两份 Excel 或受控参考文档。
- 不得用随机矩阵替代真实模型。
- 不得预造 MATLAB 数值结果。
- 不得跳过失败测试、降低阈值或删除验收项。
- 不得在本次任务中实现完整 KKT、递推求解器或内点迭代。

完成后，请只报告：实际完成内容、测试命令、验收状态、生成工件路径、未解决阻塞。不要声称未运行的事项已经通过。
