## 📖 项目简介

本项目是专为 **Google Project IDX**（现已整合进 Firebase Studio）设计的 AI 解锁工具。

Google Project IDX 是一个基于浏览器的全栈 AI 开发环境，但在中国大陆等地区访问 OpenAI（ChatGPT）和 Gemini 时会遇到网络限制。本脚本通过一键部署 **Cloudflare Argo Tunnel** + **WARP**，实现稳定代理，完美绕过限制，支持所有终端（包括手机 Shadowrocket）。

**优势**：
- 完全自动化，无需手动配置 Cloudflare 账号或域名。
- 稳定性高，Argo 隧道智能路由（可选择临时/固定隧道）。
- 空间重启后（无需打开终端）可自动启用原固定隧道节点。
- 专治手机端 UDP 干扰问题，确保 Shadowrocket 等工具顺畅连接 Google 服务。

## 🚨 使用注意事项

- 本脚本仅用于学习和个人研究目的，请遵守当地法律法规及服务提供商的使用条款。
- 不保证 100% 永久有效（如 Cloudflare 策略变动），建议关注仓库更新。
- 运行后会占用 Project IDX 工作空间的部分资源，建议在专用 workspace 中运行。
- 如果遇到问题，可在 Issues 中反馈（附上错误日志）。

## 🔧 高级用法（可选）

脚本默认一键安装，如果你想自定义：

- 编辑 `install.sh` 中的变量（如隧道名称）。
- 手动重启：终端运行 `supervisorctl restart argo`。

## 🙏 致谢

- Cloudflare Argo Tunnel 官方文档
- 社区相关开源项目灵感
- 所有测试反馈的用户

## ⭐ Star 与贡献

如果觉得有用，请给仓库点个 Star ⭐ 支持一下！  
欢迎提交 Pull Request 改进脚本或 README。

---

## 🛠 快速安装（Quick Start）

打开 Project IDX 的终端（Terminal），复制并运行以下命令：

```bash
bash <(curl -Ls https://raw.githubusercontent.com/kobe2423man/idx-ai-unlocker/main/install.sh | tr -d '\r')
