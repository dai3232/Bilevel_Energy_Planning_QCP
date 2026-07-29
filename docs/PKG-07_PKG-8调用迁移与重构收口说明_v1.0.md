# PKG-07 PKG-8 调用迁移与重构收口说明 v1.0

## 1. 本轮范围与边界

PKG-8 只完成包接口重构轨道的调用迁移和工程收口，不迁移或修改数学
生产算法。正式项目阶段继续为 `stage_A4 / READY`，本轮不进入 Stage B，
不执行完整正式 IPM，不创建正式 A4 run，也不授权自动合并、rebase、
cherry-pick 或删除工作树。

本轮保留现有 `addpath(genpath(...))` 兼容路径。后处理、诊断和历史阶段
入口尚未形成完整的包路径闭包，因此不得以 PKG-8 为由强行收窄该路径。

## 2. 正式 A4-3 顶层调用迁移

仅迁移 `main_stage_A4_3.m` 中已有冻结公共接口的四个直接调用：

| 原直接调用 | 迁移后的公共接口 |
|---|---|
| `load_project_data(projectRoot)` | `rkkt.data.load(projectRoot)` |
| `build_stage_a4_index(data,"RunId",runContext.run_id)` | `rkkt.indexing.build(data,"RunId",runContext.run_id)` |
| `run_stage_a4_full_ipm(...)` | `rkkt.ipm.solve(...)` |
| `export_stage_a4_result_artifacts(...)` | `rkkt.artifacts.export(...)` |

迁移不改变 `ResumeRunId`、checkpoint、恢复分支、`run_id`、manifest
状态机、最大迭代次数、后处理恢复、返回字段、异常标识、正式执行命令或
数值求解配置。

`create_run_context` 继续作为明确允许保留的运行基础设施调用。它没有冻结
的包公共接口，也不是 `rkkt.artifacts.export` 的后端；不得把创建上下文
与导出结果合并成一个接口。

## 3. 冻结公共接口补齐

### 3.1 `rkkt.indexing.build`

索引门面继续只委托 `build_stage_a4_index`，并补齐与旧正式入口一致的
可选参数：

- `RunId`，默认值保持 `"STAGE_A4_INDEX"`；
- `ConfigPath`，默认空字符串。

两个参数原样透传。门面不排序、不去重、不修正索引，不改变变量、约束、
固定零或 SOC 映射语义；无参数、显式 `RunId` 以及显式
`ConfigPath + RunId` 的新旧一致性均由 PKG-8 固定测试核验。

### 3.2 `rkkt.artifacts.export`

`rkkt.artifacts.export` 是
`export_stage_a4_result_artifacts` 的薄门面，完整镜像生产入口的输入、
单输出和 name-value 参数。门面不创建 run context、不修改工件语义、
不吞掉生产异常，也不复制导出实现。

### 3.3 `rkkt.reporting.generate`

`rkkt.reporting.generate` 是 `generate_stage_a4_reports` 的薄门面，
完整镜像生产入口的输入、双输出和 name-value 参数。正式
`main_stage_A4_3` 当前没有报告生成调用，PKG-8 不为使用新门面而增加
报告执行步骤。

### 3.4 `rkkt.workflows`

`rkkt.workflows` 继续保留命名空间，但尚无冻结的生产工作流公共函数。
任何包接口不得反向依赖 `main_stage_A4_3`，本轮也不自行发明新的工作流
API。

## 4. Legacy 入口分类退役

固定清单为
`docs/PKG-08_旧入口调用与处置清单_v1.0.csv`。清单按实际 `.m`
直接调用及 `ValidationSupport.callProduction` 动态委托记录，共 164 条
数据行、覆盖 23 个真实 legacy 函数；
映射表中的“统一线性化对象字段”是观察字段占位，不是可调用的 legacy
函数。非预期 legacy 调用者数量为 0。

本轮“退役”只表示正式顶层调用者改用 `rkkt.*`，旧生产函数继续保留为
兼容后端。清单区分：

- `active_formal_orchestration`；
- `package_compatibility_backend`；
- `historical_stage_or_diagnostic`；
- `regression_test`；
- `deletion_candidate`。

任何旧文件均未删除、移动或改名，也未改成反向调用包门面。未来只有同时
满足以下五项条件后，才可另行评估物理删除：

1. 对应旧入口调用者清零；
2. 人工验证结果保持严格一致；
3. 相关回归全部通过；
4. Stage A4 基线保持不变；
5. 用户另行明确批准删除。

PKG-8 没有物理删除授权，清单中所有 `deletion_eligible` 均为 `false`。

## 5. 验证状态

本轮内部测试和静态分析结果如下：

| 验证项 | 状态 |
|---|---|
| PKG-8 固定测试 | `22/22 PASS` |
| PKG-1～PKG-7 各固定 runner | `13/13；29/29；8/8；10/10；10/10；14/14；14/14 PASS` |
| `test_stage_a4_3_formal_candidate.m` | `6/6 PASS` |
| Stage A4 artifacts/reporting 相关测试 | `4/4；7/7 PASS` |
| 新增或修改 MATLAB 文件 Code Analyzer | `17 files；0 findings` |

重复测试必须按各 runner 分别报告，不得把重复条目冒充独立测试数量。
这些结果证明的是以 `91d31035ec6edd928a84a4c50b0bdaa23838a632`
为提交基线、叠加本轮 PKG-8 修改的 `refactor/pkg-interface` 工作树自身
通过。PKG-1～PKG-7、A4-3、artifacts 和 reporting 回归均在该分支状态
执行；它们尚未证明 PKG-8 与 `f1251f74a8e56073a846048fe26ee4564723fba9`
的联合状态通过。

artifacts 对照严格比较所有确定性返回字段、非 MAT 工件哈希及 MAT
载荷；reporting 对照严格比较路径、确定性验证字段和 DOCX
`document.xml`。MAT v7.3 与 DOCX 容器自身含非确定性元数据，因此两次
独立写入的容器 SHA 不作为载荷一致性结论；不得把该结果表述为含容器
SHA 的两次原始返回对象完全 `isequaln`。

## 6. 正式运行与收敛声明

PKG-8 只允许临时目录中的安全接口夹具和既有受控单步/三轮轨迹回归：

- `full_ipm_executed = false`；
- `formal_run_context_created = false`；
- `convergence_evaluated = false`；
- `convergence_claimed = false`。

本轮不运行 `main_stage_A4_3`，不创建正式 A4 run、manifest 或新的正式
报告。PKG 工作树的 `runs/` 递归项目数保持 259，两份受控 Excel 和
PKG 工作树的 `CURRENT_STAGE.md` 均未修改，冻结模型口径未修改。

非权威原工作树发生外部并发变化：实施前 HEAD 为
`1f3836ca629f5fc8a1de1f5ea5b783d114e1586b`，终检时变为
`f1251f74a8e56073a846048fe26ee4564723fba9`；reflog 显示
2026-07-28 22:41:16 新增提交
`chore: freeze A4 numerical repair factors`。PKG-8 对该目录的访问均为
只读。用户已经接受 `f1251f74a8e56073a846048fe26ee4564723fba9`
作为后续受控集成目标基线，但该基线尚未集成，联合状态也尚未验证。

两个 `CURRENT_STAGE.md` 必须分别记录：

- PKG 工作树 SHA256：
  `b1e39ca150759631b524cb2dc98158296db581757355b47b97f8f912b2fad5b7`；
- 原 stage_A4 工作树 SHA256：
  `c779f93ec2892b6357125e8646cbff5d76cb51c76b17e68ca2cad6e13a855237`。

二者都为 `stage_A4 / READY`，但内容不完全相同。原工作树已经包含用户
批准的 `1e-6` 阈值说明，不得将两份 `CURRENT_STAGE.md` 表述为完全一致。

## 7. 未解决的 Stage A4 数值任务

现有受控轨迹中 gap 上升和步长极小的问题仍未解决。它们属于受控合并后
继续开展的正式 Stage A4 收敛任务，不是 PKG-8 工程调用迁移的失败，
也不得标记为已经解决或据此声称 A4 已收敛。

## 8. 收口与下一步

用户已确认接受 `f1251f74a8e56073a846048fe26ee4564723fba9`
作为后续受控集成目标，因此外部门禁解除，PKG-8 状态为
`READY_FOR_USER_REVIEW`，包重构轨道收口完成。

这不表示 `merge-ready`：`external_baseline_integrated = false`、
`combined_state_validated = false`、`integration_validation_pending = true`
且 `merge_authorized = false`。后续受控集成必须完整保留 `f1251f74`，
重点检查两个重叠文件：

- `main_stage_A4_3.m`；
- `tests/integration/test_stage_a4_3_formal_candidate.m`。

集成后必须重新运行 PKG-8、A4-3 formal candidate、artifacts、reporting
及相关回归。当前不得声称已经 merge-ready、A4 已收敛或 Stage B 已获
授权。下一步仅为用户审查后执行
`USER_REVIEW_THEN_CONTROLLED_INTEGRATION_WITH_F125`；任何代理不得自行
merge、rebase、cherry-pick、删除工作树或修改原工作树。
