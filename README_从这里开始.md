# 递推降阶解耦算法 Codex 启动资料包

本资料包用于把“风光水火储统一单层模型 + 原始-对偶内点法 + 递推降阶解耦 + 并行验证”交给 Codex 按阶段实施。

## Stage B 已归档的七日完整内点法入口

根目录的 `RUN_PROJECT.m` 是 Stage B-2C 递推 IPM 的统一人工入口。`config/RUN_PROJECT.yaml` 的 `day_scope` 可选择连续区间 `continuous` 或冻结的全年307日筛选集合 `screened_307`；后者自动剔除41个物理不可行日和17个数值病态日。配置中还可修改最大迭代次数、审计模式、三级缓存、断点续算，以及串行/Processes 并行、worker 数和进程池复用策略。`recursive_only` 从初值开始直接生成一个小型全局块和逐日局部块，不装配全年 `H/A/G`；只有显式 `full_kkt` 七日审计才生成完整全局矩阵。常规方向使用16维核心，日恢复优先采用 `a-Ug` 响应组合。

当前项目状态已经进入 `stage_D1 / READY`，但只开放方案讨论。用户已单独授权 Stage B-2C 统一入口重构、307日筛选预设、补充运行和普通日块并行执行优化，因此可直接点击 `RUN_PROJECT.m` 执行所配置的 Stage B-2C 日集合；它不是 D1 入口，在 `DECISION-D1-01` 关闭并完成 D1 设计前不得运行 D1。

单击入口中的唯一生产链条为：

`RUN_PROJECT.m` → `rkkt.run` → `rkkt.config.read_run_project_configuration` → `rkkt.workflows.stageB2CConfigured` → 年度数据缓存 → `recursive_only` 读取 compact structural cache 并按本次数据刷新 numerical payload（结构 HIT/MISS 均不加载 canonical index）/ `full_kkt` 读取完整 canonical index → 配置日集合递推求解或七日完整 KKT 审计 → Stage B 补充验收与中文报告

`data`、`config`、`index`、`state` 和 `linearization` 在包内逐级显式传递；索引模块不会从路径反推或重新读取配置。正式运行器在每个接受迭代保存检查点和审计证据，递推方向是正式 Newton 方向，完整稀疏 KKT 仅作独立审计；不进行兼容分派或方向失败回退。实际算法均位于 `src/+rkkt`。

每次点击都会创建不可覆盖的 `runs/<run_id>`。为避免目录视觉上杂乱，只需查看 `runs/运行索引.csv` 和 `runs/LATEST_PASS.json`：前者汇总每次运行，后者指向最近一次 PASS。运行签名由包内 MATLAB 源码、阶段、有效配置和受控输入共同确定；相同签名的后续运行标为 `REPEAT` 并指向第一次 PASS。历史运行不自动删除或覆盖。

## 最先执行

1. 将本资料包完整放入项目根目录，当前权威路径：`H:\Reproduction\Hourly_Recursive_KKT_pkg`。
2. 在 Codex 中打开该项目根目录，不要只打开某个子目录。
3. 让 Codex 先读取根目录 `AGENTS.md`。
4. 首次任务已完成；后续任务必须先读取 `CURRENT_STAGE.md` 并只执行其指定阶段。
5. 正式状态以 `CURRENT_STAGE.md` 为准，当前为 `stage_D1 / READY（仅方案讨论）`。

## 当前状态

- 已完成阶段：`stage_0 / PASS`、`stage_A1 / PASS`、`stage_A2 / PASS`、`stage_A3 / PASS`、`stage_A4 / PASS`、`stage_B / PASS`。
- Stage B 权威证据：`runs/20260811_121452_stage_B_2C_4168a6e9`；七日 30 次接受迭代后 `CONVERGED / PASS`，四项 Stage B 阻断验收和汇总 90/90 测试通过，最终水量约束最大违反量为 0。
- Stage B 30 日补充实验：`runs/20260811_155000_stage_B_2C_30day_full_final`；31 次接受迭代、8/8 实验验收通过。该结果只证明当前递推路线可扩展到 30 日，不属于 D1 并行或 365 日结论。
- `stage_C1`、`stage_C2`：用户决定暂不执行，状态为 `NOT_STARTED / USER_DEFERRED`，不是 `PASS`。
- 当前阶段：`stage_D1 / READY`，仅开放方案讨论；D1 实现与运行仍受 `DECISION-D1-01` 阻断。
- A1 通过证据：`runs/20260720_131455_stage_A1_705f17da`；完整 KKT 为 471，小时块为 27、27、29，全局核心为 16，15 项阻断性验收全部通过。
- A2 通过证据：`runs/20260720_145803_stage_A2_83e04697`；完整 KKT 为 2749，小时链为 589，24 个小时块为 22、22、22、22、22、22、22、27、27、27、27、27、27、27、27、27、27、27、26、22、22、22、22、24，fixed_zero_map 为 61 项，6 项阻断性验收全部通过。
- A3 权威通过证据：`runs/20260721_113025_stage_A3_4edc8c66`；完整 KKT 为 18836，7 个日链为 589、590、589、590、590、590、590，既约系统为 4340，全局核心为 16，fixed_zero_map 为 422 项，真实递推排列为 4340 行非恒等双射，6 项阻断验收、A3 受控测试 67/67、A2 回归 32/32 与 A1 回归 37/37 全部通过。原正式证据 `runs/20260721_080023_stage_A3_0fbd183e` 及其 ZIP 保持原样。
- 当前算法验证路线：A1 已完成第 1 日第 8–10 小时“3 小时人工闭合测试窗（仅算法测试）”的单次方向等价验证；A2 已完成第 14 日完整 24 小时单次方向等价验证；A3 已完成第 14–20 日 7 个正式日的串行单次方向等价验证；A4-3 已完成正式七日内点法收敛验证；Stage B 已完成日水量约束、全不等式消元、日内联合块、精确水量松弛二阶校正和七日收敛/物理验收。当前正式阶段为 `stage_D1 / READY（仅方案讨论）`。
- 测试窗不是物理日，不改变正式模型的每日完整 24 小时 SOC 首末 `0.5E` 闭合口径。
- 当前不实施：最小开停机时间、启动成本、停机成本、年度多目标最终组合；这些均在技术债务或待决策清单中保留。

## 资料权威顺序

1. `docs/00_用户确认的模型口径_v1.0.md`
2. `docs/02_最终模型合同_v1.0.md`
3. 当前阶段的 `stages/<stage>/阶段*_长任务.md` 和验收矩阵
4. `references/controlled/风光水火储新型递推降阶解耦算法_完整推导与验证.docx`
5. 两份 Excel 原始数据
6. 阳育德论文，仅用于核查递推降阶和精确等价思想
7. 旧双层模型文档，仅用于识别原始物理约束和候选目标，不继承已废弃的双层、按月容量、整数状态和长期 SOC 口径

## 关键入口

- 根规则：`AGENTS.md`
- 首次任务：`交给Codex的首次任务.md`
- 当前阶段：`CURRENT_STAGE.md`
- 模型冻结：`docs/00_用户确认的模型口径_v1.0.md`
- 最终模型合同：`docs/02_最终模型合同_v1.0.md`
- 算法与矩阵合同：`docs/08_矩阵分块与回代合同.md`
- 验收总则：`docs/09_验收总则.md`
- 失败与重试规则：`docs/10_停止重试阻塞与升级规则.md`
- 运行工件：`docs/11_输出工件与文件命名规范.md`
- 第一阶段：`stages/stage_0/阶段0_长任务.md`

## 原始数据保护

`inputs/raw` 和 `references/controlled` 均为只读受控资料。任何代码、测试或报告都不得修改这些文件。每次运行必须核对 SHA256。
