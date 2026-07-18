# Codex 官方实践摘要（检索日期：2026-07-18）

## AGENTS.md

Codex 在开始工作前读取 `AGENTS.md`。项目范围从 Git 根目录向当前工作目录逐层查找，每个目录至多采用一个指导文件；越靠近当前目录的内容越晚合并，因此可覆盖上层规则。默认项目指导总大小上限为 32 KiB。稳定、短小、作用域明确的规则应放入 AGENTS；大规模数学推导应放入独立文档并由 AGENTS 要求读取。

官方来源：
https://learn.chatgpt.com/docs/agent-configuration/agents-md

## 长任务

OpenAI 的长任务实践强调：清晰规格、带验收标准的里程碑计划、运行规程、持续测试/构建/验证，以及实时状态和审计日志。当前项目据此采用“模型合同 + 阶段长任务 + 验收矩阵 + 状态决策日志”。

官方来源：
https://developers.openai.com/blog/run-long-horizon-tasks-with-codex

## 本地环境

Codex App 可在项目根目录 `.codex` 中保存共享的本地环境设置、工作树初始化步骤和常用动作。本资料包只提供说明和检查脚本，不伪造未知的 App 生成配置。

官方来源：
https://developers.openai.com/codex/app/local-environments

## 网络

Codex 正式 agent 阶段默认可关闭网络。开放网络会增加提示注入、代码/秘密外泄、不可信依赖和许可证风险。正式计算建议关闭网络；确需开放时只允许必要域名和方法。

官方来源：
https://developers.openai.com/codex/cloud/internet-access
