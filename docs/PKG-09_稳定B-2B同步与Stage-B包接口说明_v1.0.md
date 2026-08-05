# PKG-9 稳定 B-2B 同步与 Stage-B 包接口说明 v1.0

> 历史说明：本文正文记录 PKG-9 提交时的架构与验收事实。其“门面委托旧入口”和 `production_algorithm_migrated=false` 只描述当时状态。后续包内算法硬迁移已将生产实现移入 `src/+rkkt`，删除旧生产目录和动态定位逻辑；当前架构以 `README_从这里开始.md`、`PKG_REFACTOR_STAGE.md` 与 `docs/PKG-01_现有模块到包接口映射_v1.0.csv` 为准。PKG-9 的历史数值证据不因此改写。

## 1. 受控边界

- PKG-9 起点：`e96f548393ad67012835bfdc9aa37791c96eda2c`。
- 固定 merge-base：`2a70dab184ad38ad4c1b5f5ec50983c357e48397`。
- 唯一稳定上游：`90bf33cca0611154231588ac5d7ee09fd0e9c089`。
- 原工作树实施前 HEAD：`2560043a0bc085acc770a874264be3e3545933bc`，仅记录，未合并、未修改。
- 明确排除 `dd55f74`、`2560043` 及 B-2C 文件和后续实现。
- 未执行完整 IPM、优化、并行、年度计算或 Stage C1。

## 2. 三提交边界

1. LDL 中文说明保护提交：`02609b33e0b5dcf0d285b51db5046cb05477535a`。
2. 稳定 B-2B merge commit：`6bea7051d13dfae8afd83cd134823fdd8ce787c3`。
3. PKG-9 最终实现提交：见包含本文的提交；完整 SHA 在提交后最终报告中给出。

merge commit 的第二父提交严格为 `90bf33cca0611154231588ac5d7ee09fd0e9c089`。LDL 的完整中文解释保存在 `docs/code_walkthrough/solve_block_thomas_ldl_逐行说明.md`；生产源码使用稳定 B-2B 算法，仅保留仍准确的简短注释。

## 3. 两个差异来源

| 差异来源 | 变更路径数 | 处置 |
|---|---:|---|
| merge-base → `e96f548` 包分支 | 113 | `package_only=111`，`overlap=2`；PKG-1～8 证据复用 |
| merge-base → `90bf33c` 稳定算法 | 120 | 原始差异为非 overlap 118、overlap 2；稳定 B-2B 证据复用 |

固定提交路径 overlap 为：

- `main_stage_A4_3.m`
- `tests/integration/test_stage_a4_3_formal_candidate.m`

`src/solver/solve_block_thomas_ldl.m` 是独立的 `uncommitted_user_change` 覆盖层：它不属于 merge-base→`e96f548` 的提交路径，但与稳定上游修改重叠，因此单独保护并执行单日日链增量残差测试。完整逐路径分类、`required_test` 和 `reused_evidence` 见 `tests/PKG_9_delta_inventory.csv`。

最终互斥 inventory 共 260 行：`package_only=111`、`upstream_only=117`、`overlap=2`、`uncommitted_user_change=1`、`pkg9_new=29`；260/260 均为 `COVERED`，覆盖率 100%。稳定侧原始非 overlap 118 条中的 LDL 路径按更高优先级重分类为 `uncommitted_user_change`，因此最终 `upstream_only` 为 117。

## 4. 新公共接口

### 4.1 明确流程门面

- `rkkt.workflows.stageB1` → `main_stage_B_1`
- `rkkt.workflows.stageB2A` → `main_stage_B_2A`
- `rkkt.workflows.stageB2B` → `main_stage_B_2B`

三者只做生产文件定位、防遮蔽、`ProjectRoot`/`RunId` 原样传递和结果原样返回。PKG-9 增量验收不执行这些正式 workflow。

### 4.2 明确模块门面

- 水量：`rkkt.data.evaluateStageBDailyHydroWater`
- 索引：`rkkt.indexing.buildStageB2A`、`rkkt.indexing.buildStageB2B`
- 模型：`rkkt.model.initializeStageB2A`、`linearizeStageB2A`、`initializeStageB2B`、`linearizeStageB2B`
- 求解器：`rkkt.solver.assembleStageB2AFullKKT`、`solveStageB2BRecursiveDirection`、`solveStageB2BFullKKTDirection`、`verifyStageB2BDirectionEquivalence`

所有接口均为薄门面；没有复制或迁移生产算法，也没有在 A4 通用接口中加入隐式阶段分派。

## 5. 独立验证入口与固定工件

- `rkkt.data.validation.runStageB1`
  - `src/+rkkt/+data/+validation/阶段B-1水量函数验证输出.mat`
  - 同目录 `阶段B-1水量值与导数摘要.csv/.fig/.png`
- `rkkt.indexing.validation.runStageB2A`
  - `src/+rkkt/+indexing/+validation/阶段B-2A索引验证输出.mat`
  - 同目录 `阶段B-2A水量约束索引摘要.csv/.fig/.png`
- `rkkt.model.validation.runStageB2A`
  - `src/+rkkt/+model/+validation/阶段B-2A模型验证输出.mat`
  - 同目录 `阶段B-2A线性化维数摘要.csv`
  - 同目录 `阶段B-2A拉格朗日Hessian稀疏结构.fig/.png`
- `rkkt.solver.validation.runStageB2B`
  - `src/+rkkt/+solver/+validation/Stage_B2B求解器验证输出.mat`
  - 同目录 `Stage_B2B每日边框与响应维数.csv`
  - 同目录 `Stage_B2B方向误差与KKT残差.csv`
  - 同目录 `Stage_B2B_16维核心稀疏结构.fig/.png`

四个入口默认 `Interactive=false`、`WriteArtifacts=false`；人工收口时已各以 `WriteArtifacts=true` 成功执行一次，17/17 个固定工件均存在。它们未创建正式 runs，未运行 IPM，未更新状态。

## 6. 增量验收与证据复用

- 固定 PKG-9 增量测试：31/31 通过，失败 0、未完成 0；固定 expected inventory 为 31 项。
- 新增或修改 MATLAB 文件 Code Analyzer：扫描 135 个文件，0 findings。
- 纯委托对象等价：水量、B-2A index/state/linearization/full-KKT assembly、B-2B index/state/linearization 共 8 组均为 `isequaln=true`；三个 workflow 只做静态委托合同检查，未执行。
- B-2B 方向相对误差：`1.5000076826131547e-15`。
- B-2B 递推 KKT 相对残差：`4.8537829603427401e-12`；完整 KKT 审计相对残差：`1.20685804249556e-14`。
- `fixed_zero=422` 且值与方向均精确为 0；`no_full_direction_fallback=true`；`full_direction_consumed=false`。
- PKG-1～8、A4-3、B-1、B-2A、B-2B 不做全量重跑；实际来源、提交、测试结果和证据状态见 `tests/PKG_9_reused_baseline_evidence.csv`，全部决策为 `REUSED_NOT_RERUN`。

本阶段只证明稳定 B-2B 后端与 PKG-9 包接口的差异增量门禁。B-2B 的 `SB-PHY-001` 仍未运行，不得声称 Stage B 整体 PASS。

## 7. 冻结执行状态

- `stable_backend_integrated=true`
- `b2c_integrated=false`
- `production_algorithm_migrated=false`
- `full_ipm_executed=false`
- `optimization_executed=false`
- `stage_c1_entered=false`
- `formal_project_stage=stage_B / READY`
- `stage_b_overall_pass_claimed=false`
