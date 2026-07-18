# Codex 本地环境说明

Codex App 可通过项目设置生成 `.codex` 共享环境配置，用于工作树初始化和常用动作。本资料包不直接伪造具体配置格式。

建议在 Codex App 中配置：

- Setup：验证 MATLAB 可执行文件、许可证、两份输入文件和 Python（仅用于资料包校验）。
- Action：`验证资料包` -> `python scripts/validate_starter_package.py`
- Action：`运行当前阶段测试` -> 由阶段 0 实现统一 MATLAB 入口后再配置。
- 正式计算阶段网络关闭。
