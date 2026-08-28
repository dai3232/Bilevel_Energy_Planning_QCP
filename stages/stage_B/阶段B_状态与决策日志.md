# 阶段B：四座水电每日用水上下限：状态与决策日志

- 当前状态：`PASS`
- 最终里程碑：`B-2C`
- 权威七日 run_id：`20260811_121452_stage_B_2C_4168a6e9`
- 运行记录 Git commit：`4168a6e9fd8b7f6984f40001b1cf004fcee950e6`
- Stage B 实现与七日/30日结果归档 commit：`f77f87aeb376631891c550b10493f89a4b796e3d`
- 阻断问题：`无`
- 收口日期：`2026-08-12`
- 下一动作：按用户决定暂不执行 C1/C2；项目路由到 `stage_D1 / READY`，仅讨论方案，D1 实现和运行仍等待 `DECISION-D1-01`。

## Stage B-2C 重构 KKT 门槛调整（2026-08-13）

- 用户授权后续 7/30/60/365 日递推运行把方向代回共享线性化完整 KKT
  的相对残差门槛统一设为 `1e-8`。
- 日块与 16 维核心局部 LDL 求解目标、七日递推/完整方向相对误差和
  独立完整 KKT 方向自身残差继续保持 `1e-10`。
- 四项 IPM 收敛阈值仍为 `1e-6`，物理违反量阈值仍为 `1e-8`；模型、
  目标函数、约束、Newton 方程及步长均未改变。
- 新门槛只适用于修改后的新运行；既有权威七日/30日运行和失败运行不
  追溯改判。代码签名改变后，旧检查点不作为新运行的正式续算起点。

## Stage B-2C 对称性门槛调整（2026-08-13）

- 用户授权后续 7/30/60/365 日运行将日内降阶块、日级边界块和拉格朗日
  Hessian 三类相对对称性门槛统一由 `1e-12` 调整为 `1e-10`。
- 保留原矩阵直接审计，不做自动对称化；模型、Newton 方程、稀疏 LDL、
  局部线性求解目标、重构 KKT 门槛和四项正式收敛判据均不改变。
- 触发本决策的 60 日运行 `B2C_60DAY_FORMAL_KKT1E8_20260813` 在第 30 次
  已接受更新后的 16 维核心块相对非对称误差为
  `1.0528023313357445e-12`，仅因旧 `1e-12` 门槛停止；该历史运行保持
  `FAIL_RETRYABLE`，不追溯改判。

## Stage B-2C 直接回代与核心一致性校正（2026-08-14）

- 用户授权把第60日病态方向的数值修复接入统一主流程；不改变目标函数、物理约束、输入数据、Newton 方程、步长或收敛门槛。
- 每日块仍对 `[r|B]` 只分解一次，最终日方向使用 `r_d-B_d*Delta q_d` 复用保留的 LDL 因子直接回代。每日回代精化上限仍为3次。
- 16维核心一致性校正独立于每日回代精化，默认最多10次、核心相对残差达到 `1e-10` 即提前停止；核心装配和逐日核心残差均按固定日期顺序使用补偿求和。校正只做保留因子回代，不增加日块或核心分解。

## Stage B-2C 响应组合与联合微边框重构（2026-08-23）

- 用户明确授权把已通过隔离实验的数值路线接入正式递推主流程，并要求先回归 checkpoint13→direction14，再连续验证 direction14–18。
- 正式日恢复改为递推响应组合 `u=a-Ug`；逐日用原算子/目标算子 high+low 残差审计，只有失败时才复用同一日块 LDL 做残差校正。该决定替代 2026-08-14 的“最终右端必须直接回代”口径，但不改变 Newton 方程。
- 16维全局基础块由当前 `H/A/G/l/z` 和残差按物理消元式重建 high+low 数对；正常路径仍为 16 维。
- 对模型标签给出的精确 `A_d'*a+G_J,d'*b=0` 联合关系，主流程在日块分解前按归一化 `d=b'*diag(l./z)*b<=1e-12` 自动选择唯一候选，不硬编码日期和小时。确认后用 `alpha=sqrt(d)*gamma` 构造 17 维微边框，问题日仍只做一次 LDL，多右端与最终恢复均复用该因子。
- 隔离证据为 `runs/B2C_90DAY_A_MINUS_UG_RECOVERY_CP13_DIR14_20260823_011657`：完整重构 KKT 相对残差 `3.8448e-13`，最大绝对残差 `1.4832e-9`，最坏日残差 `8.3270e-13`，实际恢复核心残差 `6.6896e-24`；第62日 `a-Ug` 在 pass0 通过且未做最终因子回代。
- 当前正式接入不使用秩截断、正则化、伪逆、完整 KKT 回退，不修改目标函数、物理约束、输入数据或既有 `1e-10/1e-8` 门槛。Stage B 权威既有 PASS 与 D1 状态均不改写。
- 对 `B2C_60DAY_DIRECT_BACKSOLVE_20260813_1843/checkpoints/iteration_031.mat` 的重放中，核心残差从 `9.2480e-7` 依次降至第3次的 `1.6191e-8`、第4次的 `4.6407e-9` 和第7次的 `8.1998e-11`；最终完整重构 KKT 残差为 `2.7328e-10`，低于正式 `1e-8` 门槛，额外分解次数为0。
- `RUN_PROJECT.yaml` 显式记录核心校正上限与补偿求和开关；两项均进入运行清单和检查点身份。旧运行不追溯改判，正式连续60日结果仍需新运行验证。

## RUN_PROJECT 普通日块并行执行授权（2026-08-26）

- 用户授权统一入口通过 `RUN_PROJECT.yaml` 选择串行或 Processes 并行；示例配置默认并行、4 个 worker、worker 数不一致时自动重建进程池，并在运行结束后保留进程池供同一 MATLAB 会话复用。
- 并行范围只包含每次递推方向中的普通日块分解与多右端回代；16/17 维核心、状态更新、检查点写入、审计和报告仍串行。index 缓存不依赖执行模式，因此串并行切换复用同一日期区间 index，不改变模型或数值轨迹。
- 30 日串行基准 `B2C_30DAY_SERIAL_BASELINE_20260826_005047` 与 4-worker 并行实验 `B2C_30DAY_PARALLEL4_EXPERIMENT_20260826_005047` 均接受 31 次迭代；最终状态、方向、容量和逐小时出力逐项差异均为 0。日块响应累计耗时由 `5.4124599 s` 降至 `3.1414693 s`（`1.722907×`），纯 IPM 总时间由 `32.3812716 s` 降至 `30.2229351 s`（`1.071414×`）；进程池首次启动 `16.4568 s` 单独记录，不计入纯 IPM。
- 该执行优化属于 Stage B-2C 补充路线，不进入 D1，不修改既有 Stage B PASS、目标函数、约束、收敛阈值、C1/C2 状态或火电口径。

## RUN_PROJECT 全年307日筛选预设（2026-08-27）

- 用户授权 `RUN_PROJECT.yaml` 增加 `day_scope=screened_307` 并设为默认。该预设精确复用 `B2C_FULL365_SCREENED_307DAY_20260825_105011` 已通过算例的58个排除日：41个物理不可行日和17个数值病态日；其余307日按原始日编号参加同一个容量优化。
- 预设只改变参与优化的日集合，不拿前一日替代、不修改输入数据、模型、物理约束、目标函数或数值门槛；`continuous` 仍保留用于普通连续区间。

## 365 日串行补充实验授权（2026-08-12）

- 用户授权在 Stage B 已 PASS、当前阶段仍为 `stage_D1 / READY（仅方案讨论）` 的情况下，实现和运行独立的 Stage B-2C 365 日串行递推 IPM 补充实验。
- 该实验严格沿用第一次火电 `0 <= Pf <= Pmax`、每日独立 `0.5E` SOC 首末闭合、水量二阶松弛校正和既定四项 `1e-6` 收敛阈值；不执行 C1/C2、火电第二次、完整 KKT 或并行。
- 断点续算必须由用户显式指定原 `runs/<run_id>` 目录，在同一个 run_id 内读取最新有效的已接受迭代检查点并继续追加；禁止自动搜索或跨运行目录恢复。
- 本补充实验不改写 Stage B 权威七日 PASS，不进入 D1 验收，也不关闭 `DECISION-D1-01`。完整执行口径见 `阶段B_365日串行补充实验方案.md`。
- 实现状态（2026-08-12）：365 日串行配置、显式原运行目录恢复入口、canonical index 复用、接受迭代检查点链、恢复事件/累计计时和中文报告生成器已完成；断点续算定向单元测试 `9/9 PASS`，既有七日 PASS 运行的 0—30 号检查点链兼容加载通过。365 日正式求解尚未启动，因此尚无 365 日容量、出力、收敛或性能结论。

## 统一连续区间运行器重构（2026-08-12）

- `RUN_PROJECT.m` 保持唯一人工入口；日期首尾、最大迭代次数、收敛要求、审计模式、两级缓存开关和显式断点续算目录集中在 `config/RUN_PROJECT.yaml`。
- 7/30/365 日入口现均为薄包装，共同使用 `stageB2CConfigured`。年度输入解析缓存按受控输入哈希失效；连续日期 index 缓存按日期区间、输入哈希和 index 构造代码哈希失效。不同区间分别缓存，不再复制三套装配与结果收口代码。
- 七日 `full_kkt` 路线与七日 `recursive_only` 路线各完成一次接受迭代的里程碑验证，均为 8/8 `PASS`；前者记录 `18948×18948` 完整 KKT 审计矩阵，后者确认不装配完整 KKT。两次均为 `require_convergence=false` 的有限迭代结构验证，不替代既有 30 次收敛权威运行。
- 断点续算通过真实两次求解器调用验证：第 1 次提交 revision 1，第 2 次从同一检查点链继续到 revision 2；CSV 中逻辑列按原类型恢复，避免 `true/false` 被错误读取为 `NaN`。
- 365 日完整串行求解在本次重构收口中未重新启动；旧版 365 日检查点不兼容统一入口，符合用户“不保留兼容”的决定。

## Stage B 正式收口结论（2026-08-12）

- 权威七日运行 manifest 为 `PASS`，求解终态为 `CONVERGED`，接受迭代 `30` 次；`stage_b_complete=true`。
- 四项阻断验收全部通过：`SB-DATA-001` 为 28/28 水量输入行通过；`SB-DER-001` 由 B-1 梯度/Hessian 有限差分测试和 B-2C 当前状态驻点 Hessian 有限差分测试共同给出正式证据，非零水量 Hessian 与二阶校正门禁作为补充数值证据（`nnz=672`、最小校正比例 `0.14372960534441986`、最终校正比例 `1`、最大闭合误差 `3.879563337250147e-12`）；`SB-EQ-001` 的最坏方向相对误差 `1.3596442370269145e-11`、最坏递推 KKT 残差 `5.0435480551951611e-12`；`SB-PHY-001` 为 28/28 水量物理审计通过且最大违反量为 `0`。
- 最终四项停止指标分别为：等式残差 `4.547473508864641e-12`、不等式残差 `4.547473508864641e-13`、统一尺度对偶残差 `8.822001967612324e-11`、统一尺度平均互补间隙 `1.1255616063014672e-7`，均低于既定 `1e-6` 阈值。
- 汇总测试为 `90/90 PASS`，失败 `0`、不完整 `0`；其中 B-2C 固定测试为 `18/18 PASS`。Code Analyzer 阻断项为 `0`，禁止项审计为 `PASS`。
- `SB-DER-001` 的正式文件指针为权威运行下的 `tests/b1_regression/test_results.csv` 与 `tests/test_results.csv`。该不可变历史运行的 `acceptance/acceptance_results.csv` 使用同一编号记录了 B-2C 非零 Hessian/二阶校正子门禁；该行作为补充证据保留，不再将其误作有限差分检查的唯一证据。后续新运行由工作流输出复合口径。
- 递推方向是正式 Newton 方向；完整稀疏 KKT 仅用于逐轮独立审计，没有完整方向回退。固定零映射 `422` 项的物理值和方向保持精确零。
- 两份中文 Word 阶段报告均由真实运行工件生成：七日模型结果与物理验收报告位于 `runs/20260811_121452_stage_B_2C_4168a6e9/reports/阶段B-2C_七日递推IPM收敛与水量物理验收报告.docx`；问题修复验收报告位于 `runs/20260811_101510_stage_B_WATER2_4168a6e9/reports/阶段B-2C_水量二阶松弛校正实验报告.docx`。
- 七日报告 OOXML 结构验证为 `PASS`。正式 manifest 保留了当时 LibreOffice 不可用的 `NOT_RUN_LIBREOFFICE_UNAVAILABLE` 原始记录；随后使用 Microsoft Word `ExportAsFixedFormat` 与 Poppler 对 7 页逐页补充复核，`report_word_visual_qa.csv` 为 7/7 `PASS`。水量校正报告同样完成 5 页 Word/PDF/PNG 视觉复核并为 `PASS`。
- 30 日补充实验 `20260811_155000_stage_B_2C_30day_full_final` 为 `PASS`：接受迭代 `31` 次、8/8 实验验收通过、纯 IPM 优化计算时间 `473.2153738 s`、最终水量违反量 `0`。该时间为 `diagnostics/timing_history.csv` 逐轮 `total_seconds` 之和，不含工作流装配、报告和外围审计；manifest 中历史字段 `recursive_ipm_seconds=542.5847488` 是迭代循环墙钟口径，不作为纯优化时间。该实验只作为规模扩展证据，不构成 D1 并行、365 日或火电第二次结论。
- 权威七日运行是在 commit `4168a6e9...` 所记录的工作树代码上执行；对应实现以及七日/30日结果随后归档于 commit `f77f87ae...`。两者用途不同，均如实保留。
- 问题日志没有未解释的阻断项；输入 Excel、冻结水量模型口径和验收阈值没有为了通过验收而修改。

## 阶段路由决定

- 用户于 2026-08-12 明确决定暂不执行 `stage_C1` 和 `stage_C2`，并授权在 Stage B 收口后将 `CURRENT_STAGE.md` 指向 `stage_D1 / READY`。
- C1/C2 的状态是 `NOT_STARTED / USER_DEFERRED`，不是 `PASS`；没有生成 `thermal_mask.csv`，也没有执行固定停机和原始 `Pmin` 的第二次求解。
- 现行 `docs/03_阶段模型启用矩阵.csv` 规定 D1 使用 C2 的第二次火电口径，因此 D1 当前只开放方案讨论。必须先关闭 `DECISION-D1-01`，再修改合同或实现 D1。

> 以下 B-2B、B-2A、B-1 内容是当时里程碑的历史快照；其中“Stage B 仍为 READY”等表述只在相应日期有效，不覆盖上述 2026-08-12 正式收口结论。

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
