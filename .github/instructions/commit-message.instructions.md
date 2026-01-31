## Commit message 规范（语义化提交）
- 提交信息应遵循 Conventional Commits（语义化提交）规范，格式：<type>(<scope>): <subject>
- 常用 type：feat, fix, docs, style, refactor, perf, test, chore, build, ci, revert
- scope 可选，表示影响的模块（例如 core、theme、addons 等）。
- type 和 subject 使用简体中文，简洁描述变更要点，首字母小写，不以句号结尾。
- 破坏性变更请在 footer 添加 BREAKING CHANGE: 描述，以便自动化工具识别。
- PR 标题与提交信息均建议使用同样的语义化格式并以中文撰写；若自动生成提交信息，请优先使用该格式。