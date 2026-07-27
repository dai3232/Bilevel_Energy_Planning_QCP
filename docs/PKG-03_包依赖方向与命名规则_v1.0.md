# PKG-03 包依赖方向与命名规则 v1.0

## 1. 计划包结构

```text
src/+rkkt/
├─ +contracts/
├─ +data/
│  └─ +validation/
├─ +indexing/
│  └─ +validation/
├─ +model/
│  └─ +validation/
├─ +solver/
│  └─ +validation/
├─ +ipm/
│  └─ +validation/
├─ +artifacts/
├─ +reporting/
└─ +workflows/
```

PKG-1 只建立骨架和公共基础设施；生产算法仍留在现有目录。

## 2. 单向依赖

```text
contracts
    ↑
data
    ↑
indexing
    ↑
model
    ↑
solver
    ↑
ipm
    ↑
workflows
```

`artifacts` 和 `reporting` 消费工作流结果及正式 run 工件，不得被
`data/indexing/model/solver/ipm` 反向调用。

人工 `validation` 入口可以调用本模块公共接口和通用验证工具，但生产
接口不得调用 `validation`。

禁止环形依赖。

## 3. 公共与内部边界

- `rkkt.<module>.<verb>` 是稳定公共接口；
- 包内 `private/` 保存不允许跨模块调用的实现细节；
- 阶段特定配置由工作流传入，核心模块不得读取 `CURRENT_STAGE.md`；
- A1/A2/A3/A4 包装入口可以调用公共接口，公共接口不得依赖阶段包装；
- 不把测试夹具、run 路径或报告字段写进求解器核心。

## 4. 命名

公共函数使用职责型动词：

```text
load
build
initialize
linearize
assembleFullKKT
solveFullKKT
eliminateInequalities
partitionRecursiveSystem
buildDayResponse
aggregateDayResponses
solveGlobalCore
recoverDirection
verifyEquivalence
step
solve
```

人工验证入口统一使用 `run` 或 `run<职责>`，只在模块的
`+validation` 子包出现。

不得在公共接口名中加入临时里程碑标识，如 `2D2A`、`RNS1`、`3F1`。

## 5. MATLAB 路径

包调用只需把 `src` 根加入路径：

```matlab
addpath(fullfile(projectRoot, "src"));
```

不得单独把 `+rkkt` 或其子包加入路径。逐步停止依赖无边界的
`addpath(genpath(...))`，但旧测试迁移前保持兼容。

## 6. 向后兼容

旧函数在迁移期继续存在。包门面先调用旧函数并进行只读合同核查。
任何旧入口的移动、改名或删除必须满足：

1. 仓库调用者已迁移；
2. 人工模块验证结果一致；
3. 相关自动回归通过；
4. A4 方向和状态基线未改变；
5. 用户单独批准清理。
