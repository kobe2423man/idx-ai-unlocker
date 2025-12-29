# 🚀 Project IDX AI Unlocker

这是一个专为 **Google Project IDX** 环境设计的全能修复脚本。
一键解决 IDX 无法访问 **ChatGPT** / **Gemini** 的问题，并完美修复手机端 Shadowrocket 连接 Google 失败的痛点。

## ✨ 核心功能
- 🌍 **免域名配置**：自动集成 Cloudflare Argo 隧道，无需手动设置域名/SNI。
- 🔓 **AI 全解锁**：集成 WARP，完美解锁 ChatGPT、OpenAI、Gemini (解除地区限制)。
- 📱 **手机端修复**：服务端强制屏蔽 UDP，彻底解决 iOS/Shadowrocket 连不上 Google 的问题。
- 🛡️ **防风控**：全量 Google 流量走 WARP，防止账号因 IP 跳变被封。
- ⚡ **自动维护**：内置 MTU 修正与守护进程。

## 🛠 使用方法 (Usage)

打开 Project IDX 的终端 (Terminal)，复制并运行以下命令即可：

```bash
bash <(curl -Ls [https://raw.githubusercontent.com/kobe2423man/idx-ai-unlocker/refs/heads/main/install.sh](https://raw.githubusercontent.com/kobe2423man/idx-ai-unlocker/refs/heads/main/install.sh))
