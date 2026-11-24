# Hush 项目规则

- 从 `README.md` 确认产品行为、兼容范围和构建入口。共享逻辑在 HushCore，修改尽量沿用现有测试。
- 根据改动运行 `scripts/build.sh` 或 `scripts/test.sh`。涉及真实启动、窗口或焦点时，按 `docs/validation.md` 选择合适的检查，分别记录自动化与实际系统覆盖。
- macOS 版本、处理器和真实登录体验按实测报告。
