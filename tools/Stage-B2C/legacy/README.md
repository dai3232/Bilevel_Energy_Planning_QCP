# Stage B-2C legacy audit tools

本目录只保留 canonical index → compact baseline 的历史审计能力，用于
新旧初值、残差、Newton 方向、16 维 core 与最终结果的精确等价验证。

- `load_or_build_stage_b2c_legacy_runtime_audit_baseline` 是唯一入口。
- canonical bootstrap 默认关闭；只有显式传入
  `BootstrapCanonicalIndexAllowed=true` 才能访问 canonical index。
- `RUN_PROJECT.m` 和 `src/+rkkt` 不得添加本目录到 MATLAB path，也不得调用
  本目录函数。
- 本目录不属于 `recursive_only` 正式生产路线。
