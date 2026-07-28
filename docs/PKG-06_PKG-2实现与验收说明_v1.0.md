# PKG-06 PKG-2 实现与验收说明 v1.0

## 1. 阶段定位

PKG-2 只整理数据导入模块。正式项目阶段仍为 `stage_A4 / READY`；本阶段
没有执行索引、模型、KKT、Newton 方向或 IPM，也不表示正式 Stage A4
通过。

本次遵守用户“不新建目录”的明确指令：全部生产代码、人工验证代码、测试
和固定人工输出均复用现有目录；没有创建新的源码目录或正式 run 目录。

## 2. 数据薄门面

公共入口：

```matlab
data = rkkt.data.load(projectRoot);
```

该入口：

1. 临时解析并调用现有正式生产函数 `load_project_data`；
2. 调用结束后恢复调用者原 MATLAB path；
3. 对正式返回对象执行只读合同检查；
4. 原样返回生产对象，不增加包装层或字段；
5. 不裁剪、重排、归一化、补值或修改生产对象。

门面没有 `readcell`、`readtable` 或 `sheetnames` 调用，Excel 定位、读取、
哈希验证和规范化算法仍只有 `load_project_data` 一份。

## 3. 已实施的只读数据合同

合同核对：

- 顶层字段 `schemaVersion/projectRoot/meta/base/timeseries/hashes/audit/
  auditPolicy/sources`；
- 设备数 `4/4/5/5/2`；
- 完整时域 `365×24`、60 分钟、`dt=1h`；
- 风光容量因子分别为 `365×24×5`；
- 计划曲线为 `365×24` 且严格满足
  `planMW=planPerUnit×10000`；
- 水电日水量上下界、风光与计划标幺范围；
- 两份受控 Excel 的文件名、字节数和 SHA256；
- 标签驱动读取审计全部成功；
- 工作表和有效范围分别为 `基础参数/A1:P45` 与
  `Sheet1/A1:AA5492`；
- 基础参数各数值表的 MATLAB 类型、行列数、有限性和实数性。

检查失败只抛出带稳定标识的错误，不自动修复数据。

## 4. 人工验证入口

入口：

```matlab
moduleResult = rkkt.data.validation.run(string(projectRoot));
```

它分别调用旧入口与新门面，保留完整 365 日生产对象，并额外建立固定的
第 14—20 日、每天 1—24 小时观察视图。观察视图包含：

- `7×24` 计划曲线；
- `7×24×5` 风电容量因子；
- `7×24×5` 光伏容量因子；
- 168 行自然日/小时/源序号映射；
- 日小时矩阵到连续序列的往返重排；
- 新旧入口递归类型、字段顺序、维数、哈希和数值对照。

入口不读取 stage_A4 模型配置函数，不依赖 `rkkt.indexing`、
`rkkt.model`、`rkkt.solver` 或 `rkkt.ipm`。

## 5. 固定人工输出

固定输出直接位于已经存在的
`src/+rkkt/+data/+validation`：

- `数据导入模块输出.mat`；
- 五个中文 CSV；
- 五组中文 `.fig/.png`。

CSV 数值按至少 17 位有效数字写出。`moduleResult` 在保存前通过
`rkkt.contracts.validateModuleResult`；诊断仅记录客观事实，不保存人工
`PASS/FAIL` 结论。上述固定文件允许人工重复运行覆盖，不是正式阶段证据。

## 6. 自动验证结果

实际命令：

```matlab
addpath(fullfile(pwd,"tests"));
evidence = run_PKG_2_tests();
```

固定清单 `tests/PKG_2_expected_test_inventory.csv` 共 29 项：

| 范围 | 结果 |
|---|---:|
| PKG-1 合同基础设施回归 | 13/13 |
| 原数据读取回归 | 3/3 |
| PKG-2 数据接口与边界 | 13/13 |
| 合计 | 29/29 |

四个本阶段 MATLAB 文件的 Code Analyzer 结果合计为 0 项。

## 7. 实际数据与图表结果

- 正式源对象：365 日、每日 24 小时；
- 人工观察：第 14—20 日，共 168 小时；
- 新旧入口完整对象：`isequaln=true`；
- 顶层类型、尺寸和字段顺序：一致；
- 输入哈希表：严格一致；
- 数值叶节点：111 个；
- 数值最大绝对差：0；
- 所有计划、风电和光伏往返重排最大绝对差：0；
- 小时映射首末为第 14 日第 1 小时和第 20 日第 24 小时；
- 五组中文图表已检查，日边界、曲线顺序、图例和标签清晰。

## 8. 未改变内容

- 未修改两份原始 Excel 或受控输入清单；
- 未修改 `load_project_data` 及其读取算法；
- 未修改 `CURRENT_STAGE.md`、模型、索引、变量顺序或阈值；
- 未运行完整 KKT、递推 KKT、优化或并行；
- 未创建正式 run 目录；
- 未建立 PKG-3 索引接口；PKG-3 仍为 `NOT_STARTED`。
