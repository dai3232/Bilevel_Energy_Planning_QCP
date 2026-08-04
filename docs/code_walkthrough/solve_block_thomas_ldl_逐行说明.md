# `solve_block_thomas_ldl` 逐行说明（PKG-9 合并前保护快照）

## 1. 文档目的与冻结点

本文档保存 `src/solver/solve_block_thomas_ldl.m` 在 PKG-9 同步稳定 B-2B 后端之前由用户补充的中文解释。冻结源码基线为包分支提交 `e96f548393ad67012835bfdc9aa37791c96eda2c` 加该文件的未提交注释修改；保护性提交同时保存带注释源码和本文档。

后续生产代码必须以稳定上游提交 `90bf33cca0611154231588ac5d7ee09fd0e9c089` 的算法实现为准。本文档是讲解存档，不是新的算法合同；凡与稳定实现的参数、字段或诊断结构不一致的说明，合并后必须按稳定实现理解。

## 2. 算法流程说明

### 2.1 输入、输出与参数检查

- 输入是小时链分块 `partition` 和名称值选项 `options`，输出统一放入 `result`。
- `arguments` 块验证 `partition` 为标量结构体。
- `SymmetryTolerance` 是有限、非负的对称性容差，合并前默认值为 `1e-12`。
- `ResidualRefinementMaxPasses` 是非负整数；默认 `0` 表示关闭残差精化，并且代码限制最多三次。
- `nHours = numel(partition.hour)` 读取小时块数量，小时链至少包含一个块。

### 2.2 工作区初始化

- `schur`：保存每小时的有效 Schur 主元 `S_t`。
- `multipliers`：保存前向消元乘子 `L_t`。
- `forwardRhs`：保存前向消元后的多右端 `G_t`。
- `solutions`：保存每小时最终解 `X_t`。
- `factors`：保存每个 `S_t` 的 LDL 分解和相关信息。
- `factorDiagnostics`：保存去掉大型矩阵后的因子诊断，避免诊断结构重复存储矩阵。
- `multiplierSolveDiagnostics`、`backSolveDiagnostics` 和 `hourBlockDiagnostics` 分别保存接口乘子求解、反向回代和小时块诊断。

### 2.3 前向消元

算法从第一个小时开始遍历：

1. `block = partition.hour(t)` 取得当前小时结构体。
2. 将一列 `r` 和十四列 `B` 横向拼成 `currentF=[r,B]`，一次处理十五个右端。
3. 链首没有前驱块，因此 `S_1=D_1`，消元乘子使用 `0×0` 稀疏矩阵占位，且 `G_1=F_1`。
4. 对其余小时，复用上一小时的 LDL 因子求解接口乘子；物理小时编号来自 `partition.hour(t-1).hour`，因此人工测试窗不必从第 1 小时开始。
5. 乘子由转置求解结果转回：`multipliers{t}=solvedTranspose.'`。
6. 更新有效主元和右端：

   ```text
   S_t = D_t - L_t E_t'
   G_t = F_t - L_t G_(t-1)
   ```

7. 对 `S_t` 做对称 LDL 分解，并记录因子及小时诊断。

### 2.4 反向回代

从最后一个小时倒序到第一个小时：

- 链尾直接使用 `forwardRhs{t}`。
- 其余小时扣除后继块贡献 `E_(t+1)' * X_(t+1)`。
- 复用当前小时已保存的 LDL 因子，一次求解十五个右端。

### 2.5 残差精化与结果

- 将各小时解纵向拼接成 `initialStackedSolution`。
- `refine_block_thomas_solution` 在配置允许时复用保留因子做有限次精化。
- 用 `partition.M * stackedSolution - [partition.r_v,partition.B]` 计算链残差和相对残差。
- 若解中出现 `NaN` 或 `Inf`，立即报错。
- `result` 保存线性化标识、右端数量、Schur 块、消元乘子、前向右端、逐小时解、堆叠解、因子和诊断。

## 3. 变量和矩阵含义

| 名称 | 含义 |
|---|---|
| `partition.hour(t).D` | 第 `t` 个小时的对角块 |
| `partition.hour(t).E` | 当前小时与前一小时之间的接口耦合块 |
| `partition.hour(t).r` | 当前小时的基础右端列 |
| `partition.hour(t).B` | 十四个容量方向的右端列 |
| `currentF` | `[r,B]`，共十五个右端 |
| `schur{t}` | 前向消元后的有效 Schur 主元 `S_t` |
| `multipliers{t}` | 前向消元乘子 `L_t` |
| `forwardRhs{t}` | 消元后的右端 `G_t` |
| `solutions{t}` | 当前小时的十五右端解 `X_t` |
| `factors{t}` | `S_t` 的 LDL 因子及诊断 |
| `partition.M` | 完整小时链稀疏算子 |
| `stackedSolution` | 按小时纵向拼接的链解 |
| `chainResidual` | 完整小时链方程残差 |

`build_hour_block_diagnostics` 会把单个小时的小矩阵 `D` 转为稠密矩阵以计算秩和条件数；该操作仅限小小时块诊断，不适用于整日链或完整 KKT。

## 4. 与旧实现绑定、合并后可能需要更新的说明

以下说明准确描述了合并前文件，但与旧实现结构绑定，不能用来覆盖稳定 B-2B 算法：

- 合并前参数块只有 `SymmetryTolerance` 和 `ResidualRefinementMaxPasses`。稳定 `90bf33c` 版本还包含 `UseCongruenceScaling` 和 `EquilibrationPasses`，合并后必须保留这些参数和行为。
- 合并前 `factor_symmetric_ldl` 只接收对称性容差。稳定版本还原样传递 congruence scaling 与 equilibration 参数。
- 合并前小时诊断没有缩放相关字段。稳定版本增加 `schur_scaling_used`、`schur_equilibration_passes`、原矩阵秩/条件数/奇异值以及因子化矩阵误差字段。
- 合并前 `strip_factor_matrices` 删除 `matrix`、`factorized_operator`、`L`、`D`。稳定版本还删除 `factorized_operator_original` 和 `factorization_matrix`。
- 原注释“AI写的诊断报告，可以不用看，只是生成字段而已”仅保存为用户原话。诊断字段是数值审计证据，合并后仍应按生产合同读取，不能据此跳过诊断。
- 原注释中的 `Schru` 是对 `Schur` 的拼写说明，不改变矩阵含义。
- 原循环注释末尾的字符 `v` 没有算法含义。

## 5. 用户原中文解释逐条存档

下列文字按合并前源码原意保存，便于后续对照：

- “输入是小时链分块 partition 和名称值选项 options，输出统一放进 result。”
- “参数验证块；partition 是一个标量结构体。”
- “定义对称性容差，必须是有限、非负标量，默认 1e-12。”
- “要求精化次数是非负整数，默认关闭，即 0 次。”
- “若断言失败，则弹出下面这一行的错误日志。”
- “读取 partition.hour 中的小时块数量；断言至少有一个小时块。”
- “先创建一个小时×1的列向量，为每个小时的有效 Schur 主元 `S_t` 创建 cell 数组。”
- “为前向消元乘子 `L_t`、前向右端 `G_t`、每小时最终解 `X_t` 和 LDL 因子创建 cell 数组。”
- “保存去掉大型矩阵后的因子诊断信息。”
- “从第一个小时开始执行前向消元；取出当前小时结构体，后续用 block 简化访问。”
- “把一列 r 和十四列 B 横向拼接成 currentF，所以一次求 15 个右端。”
- “判断当前是不是链首小时；首小时没有前驱块，所以有效主元直接是 `S_1=D_1`。”
- “首小时没有消元乘子，用 `0×0` 稀疏矩阵作明确占位；首小时的前向右端不需要修正，即 `G_1=F_1`。”
- “其余小时进入一般前向消元分支。”
- “取前一个块的物理小时编号，用于诊断标签；它比直接使用 `t-1` 更可靠，因为测试窗小时不一定从 1 开始。”
- “调用 `solve_with_ldl_factor`，复用上一小时已经得到的 LDL 因子。”
- “把求得的 Y 转置，得到消元乘子；保存这次多右端 LDL 求解的残差和警告诊断。”
- “计算当前有效 Schur 主元；同步消去前一小时未知量，得到新右端。”
- “调用 `factor_symmetric_ldl` 分解 `S_t`，同时执行对称性、秩、条件数、惯性和非有限值检查。”
- “复制因子诊断信息，但删掉原矩阵和 L/D 等大型字段，避免诊断结构重复存储矩阵。”
- “结束前向小时循环；此时所有 `S_t`、`L_t` 和 `G_t` 都已得到。”
- “执行反向回代；从最后一个小时倒序回代到第一个小时。”
- “AI写的诊断报告，可以不用看，只是生成字段而已。”（仅作为原注释存档；见第 4 节的适用性说明。）
