# 🚀 Project IDX AI Unlocker

专为 **Google Project IDX** 环境打造的一键网络修复与 AI 解锁工具。
只需一行命令，即可自动部署 Cloudflare Argo 隧道，完美解锁 **ChatGPT**、**Gemini**，并修复手机端 Shadowrocket 连接 Google 失败的问题。

## ✨ 核心功能

- 🌍 **免配置**：自动集成 Cloudflare Tunnel，无需购买域名，无需手动设置 SNI。
- 🔓 **AI 全解锁**：集成 WARP 能够完美解锁 ChatGPT、OpenAI、Gemini (解除地区限制)。
- 📱 **手机端修复**：服务端强制屏蔽 UDP，彻底解决 iOS/Shadowrocket 连不上 Google 的问题。
- 🛡️ **防风控**：全量 Google 流量走 WARP，防止账号因 IP 跳变被封。
- ⚡ **自动维护**：内置 MTU 修正与守护进程，确保连接稳定。

## 🛠 快速开始 (Quick Start)

在 Project IDX 的终端 (Terminal) 中，复制并运行以下命令：

```bash
bash <(curl -Ls [https://raw.githubusercontent.com/kobe2423man/idx-ai-unlocker/refs/heads/main/install.sh](https://raw.githubusercontent.com/kobe2423man/idx-ai-unlocker/refs/heads/main/install.sh))
