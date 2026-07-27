# PKG-02 公共接口数据合同 v1.0

## 1. 合同原则

PKG-1 至 PKG-7 的包函数是现有正式函数的薄门面。门面返回值必须与现有
生产函数保持相同的 MATLAB 类型、字段、维数、稀疏性和数值，不额外包裹
一层结果结构，也不向生产对象注入新字段。

接口合同版本保存在合同函数和人工验证 `moduleResult.meta` 中，不通过
修改生产对象实现。

合同函数只允许：

- 检查必需字段；
- 检查类型、形状、有限性和稀疏性；
- 检查对象之间的维数闭合；
- 给出包含模块、字段、实际值和期望值的错误。

合同函数禁止补字段、重排、裁剪、归一化、正则化或自动修正。

## 2. 数据合同 `rkkt.data.load`

输入：

```matlab
projectRoot (1,1) string
```

输出保持现有 `load_project_data` 结构，至少包含：

```text
schemaVersion
projectRoot
meta
base
timeseries
hashes
audit
auditPolicy
sources
```

冻结事实：

- 全年365日；
- 每日24小时；
- 步长60分钟、`dt=1h`；
- 风/光可用率分别为 `365x24x5`；
- 计划曲线为 `365x24`；
- 七日验证选择第14—20日，不把全年对象裁成伪365日对象。

## 3. 索引合同 `rkkt.indexing.build`

输出保持现有索引结构，至少包含：

```text
version
model_contract_version
scope
variable_index
constraint_index
block_index
fixed_zero_map
permutation_map
soc_link_map
counts
expected
```

合同必须核查索引唯一性、覆盖性、范围、日期/小时语义和固定零恢复语义，
但不得为了通过检查自动排序或去重。

## 4. 状态合同 `rkkt.model.initialize`

至少包含：

```text
xi
y
l
z
mu
capacity_midpoint
stage_id
initialization_version
newton_direction_number
```

`xi/y/z` 维数必须和索引闭合；进入线性化与 Newton 求解前，`l/z` 必须
符合当前阶段的严格正性合同。合同不得裁剪或替换小值。

## 5. 统一线性化合同 `rkkt.model.linearize`

至少包含：

```text
identity
version
stage_id
state
objective
constraints
jacobian
hessian
H
A
G
r_dual
r_eq
r_ineq
r_comp
l
z
mu
index
maps
layout
fixed_zero_map
permutation
capacity_parameters
model_contract_version
index_version
counts
```

残差、Jacobian、Hessian、完整 KKT 和递推路线必须消费同一个对象实例
及同一 `identity`。残差/Jacobian/Hessian 的独立验证入口只能读取该对象
并生成观察视图，不能分别重新装配。

## 6. 完整 KKT 与递推方向合同

完整 KKT 装配对象必须包含矩阵、右端、分块范围和线性化身份。完整方向
只作为审计结果。

递推恢复结果至少包含：

```text
stage_id
linearization_identity
direction
components
fixed_zero
diagnostics
```

规范方向顺序必须与完整 KKT 审计方向一致。任何内部置换都必须在返回前
逆置换，且固定零物理变量保持精确零。

## 7. 人工验证 `moduleResult` 合同

每个模块固定保存：

```text
moduleResult.meta
moduleResult.input
moduleResult.output
moduleResult.intermediate
moduleResult.diagnostics
moduleResult.indexDescription
moduleResult.tableFiles
moduleResult.figureFiles
```

`meta` 还必须记录：

- 包接口名称；
- 实际生产函数；
- 上一级固定输入路径及 SHA256；
- Git commit；
- stage、day、hour、iteration、revision（适用时）；
- MATLAB 版本和生成时间。

人工验证 `diagnostics` 只保存客观事实，不保存 `PASS/FAIL`。
