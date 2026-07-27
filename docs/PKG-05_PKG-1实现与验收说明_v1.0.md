# PKG-05 PKG-1 实现与验收说明 v1.0

## 1. 阶段定位

PKG-1 只建立包骨架与公共合同基础设施。正式项目阶段仍为
`stage_A4 / READY`；本阶段 PASS 不表示完整 KKT 收敛问题已经解决，也不
允许进入正式 `stage_B`。

## 2. 已建立的包结构

MATLAB 只需添加 `src` 根路径即可解析：

```text
rkkt
├─ contracts
├─ data.validation
├─ indexing.validation
├─ model.validation
├─ solver.validation
├─ ipm.validation
├─ artifacts
├─ reporting
└─ workflows
```

PKG-1 中只有 `rkkt.info` 和 `rkkt.contracts.*` 含可执行实现。其余包只含
`Contents.m`，不调用现有数据、模型、KKT、IPM、工件或报告函数。

## 3. 公共合同基础设施

| 接口 | 职责 |
|---|---|
| `rkkt.info` | 返回包版本、合同版本、模块清单和单向依赖顺序 |
| `rkkt.contracts.version` | 返回合同版本 `1.0` |
| `rkkt.contracts.requiredFields` | 返回命名合同的有序必需字段 |
| `rkkt.contracts.requireStruct` | 检查标量结构体 |
| `rkkt.contracts.requireFields` | 检查缺失/多余字段，不补字段、不重排 |
| `rkkt.contracts.requireTextScalar` | 检查文本标量及空值口径 |
| `rkkt.contracts.requireNumericArray` | 检查数值类型、尺寸、有限性、实数性和稀疏性 |
| `rkkt.contracts.moduleResultTemplate` | 建立统一人工验证信封 |
| `rkkt.contracts.validateModuleMetadata` | 检查接口、来源哈希、提交号和上下文索引 |
| `rkkt.contracts.validateModuleResult` | 检查顶层结构、文件清单和无 PASS/FAIL 规则 |

所有 `require/validate` 函数只检查输入并在不满足合同时抛出带稳定标识的
错误，不归一化、不裁剪、不排序、不补字段、不改变稀疏性。

## 4. 固定测试

测试入口：

```matlab
main_PKG_1("H:\Reproduction\Hourly_Recursive_KKT_pkg")
```

固定清单为 `tests/PKG_1_expected_test_inventory.csv`，共 13 项，覆盖：

- 15 个计划包目录可解析；
- 包版本和单向依赖顺序；
- 必需字段顺序；
- 只读字段检查；
- 文本、数值、尺寸、有限性和稀疏性检查；
- `moduleResult` 顶层结构；
- 任意生产载荷保持不变；
- 元数据 SHA256、Git 提交号和合同版本；
- 人工诊断禁止 PASS/FAIL；
- 图表文件清单必须为 string 列。

实现验证运行：

```text
run_id: 20260727_170607_PKG-1_49a7c030
status: PASS
tests: 13/13
Code Analyzer: 0
optimization_executed: false
production_algorithm_migrated: false
```

测试运行保存 manifest、Git 状态、设计输入哈希、环境、固定清单、CSV、
JUnit XML、控制台日志、证据 SHA256、验收表及 `pkg1_result.mat`。

## 5. 问题闭环

两个预运行失败目录按不覆盖规则保留：

| run_id | 状态 | 原因 | 处理 |
|---|---|---|---|
| `20260727_170402_PKG-1_49a7c030` | `FAIL_RETRYABLE` | 运行器 CSV 表头容器类型错误，测试尚未开始 | 修正表头并把静态证据写入纳入异常闭环 |
| `20260727_170522_PKG-1_49a7c030` | `FAIL_RETRYABLE` | 12/13 通过，PASS/FAIL 测试夹具表头类型错误 | 修正夹具后完整重跑 13 项 |

失败没有通过删除测试或放宽合同处理。

## 6. 未改变内容

- 未修改 `CURRENT_STAGE.md`；
- 未修改数学模型、数据、索引、变量顺序或阈值；
- 未调用完整 KKT 或递推 KKT；
- 未运行 IPM；
- 未吸收原 A4 工作树的未提交诊断代码；
- 未创建 PKG-2 数据门面。

## 7. 下一阶段边界

用户确认后进入 PKG-2。PKG-2 只允许：

1. 建立 `rkkt.data.load` 薄门面；
2. 对现有 `load_project_data` 返回对象做只读数据合同检查；
3. 将已验证的数据人工运行原型迁入 `rkkt.data.validation`；
4. 固定读取全年对象并选择第14—20日观察视图；
5. 对照新旧入口的类型、字段、维数、哈希和数值。

PKG-2 不得复制 Excel 读取算法，不得建立索引或求解器接口。
