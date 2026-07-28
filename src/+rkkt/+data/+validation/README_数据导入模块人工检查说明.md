# 数据导入模块人工检查说明

## 边界

本入口只调用 `rkkt.data.load` 和既有正式生产函数
`load_project_data`。它不调用索引、模型、KKT、求解器或 IPM，也不输出
人工 `PASS/FAIL` 结论。

生产输出始终是完整 365 日对象。第 14—20 日、每天 1—24 小时的
`7×24=168` 小时数据只作为人工观察视图，绝不回写或裁剪全年对象。

## MATLAB 运行

在项目根目录运行：

```matlab
addpath(fullfile(pwd, "src"));
moduleResult = rkkt.data.validation.run(string(pwd));
```

非交互运行但仍生成固定图表：

```matlab
moduleResult = rkkt.data.validation.run( ...
    string(pwd), Interactive=false);
```

只做内存检查、不写文件：

```matlab
moduleResult = rkkt.data.validation.run( ...
    string(pwd), Interactive=false, WriteArtifacts=false);
```

入口只接受已经存在的 `OutputDirectory`，不会创建目录。默认固定输出直接
写在当前 `+validation` 目录，重复人工运行可以覆盖这些观察文件。

## 固定输出

- `数据导入模块输出.mat`
- `数据导入模块_输入文件哈希.csv`
- `数据导入模块_七日数据字段维数汇总.csv`
- `数据导入模块_七日小时映射表.csv`
- `数据导入模块_七日时序往返重排诊断.csv`
- `数据导入模块_新旧入口对照.csv`
- 五组中文 `.fig` 和 `.png`

这些文件不是正式 `runs/<run_id>` 阶段证据。

## 人工检查重点

1. `moduleResult.output.projectData` 仍为 365 日、每日 24 小时。
2. 七日观察视图的计划曲线为 `7×24`，风光分别为 `7×24×5`。
3. 小时映射第 1、24、25、168 行分别对应第 14 日第 1/24 小时、
   第 15 日第 1 小时和第 20 日第 24 小时。
4. 新旧入口的类型、字段顺序、维数、输入哈希和全部数值一致。
5. 时序往返重排最大绝对差为 0。
6. 图中的日边界、设备曲线顺序和中文标注正确。
