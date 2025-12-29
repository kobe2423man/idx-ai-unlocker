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
📱 客户端连接教程
脚本运行结束后，终端屏幕上会生成一个以 vmess:// 开头的长链接。

1. Windows / Mac 用户 (v2rayN, V2RayU 等)
复制 终端里生成的 vmess:// 链接。

打开软件，在界面空白处 Ctrl+V (粘贴) 或点击 “从剪贴板导入”。

直接连接 即可使用 (所有配置已自动生成，无需修改)。

2. iOS / Android 用户 (Shadowrocket, v2rayNG 等)
复制 vmess:// 链接发送到手机。

打开 Shadowrocket (小火箭)，它会自动检测剪贴板并提示导入。

连接节点。

⚠️ 避坑指南：

手机端无需开启全局模式，使用默认配置即可。

如果遇到 Google/Gemini 打不开，请在小火箭中断开连接，等待 3 秒后重新连接即可（这是为了强制刷新 TCP 链路）。

⚠️ 免责声明 (Disclaimer)
仅供学习研究：本项目仅供网络技术研究、学习和交流使用，旨在提高网络安全意识和技术水平。

合法合规：请用户在使用本项目时，严格遵守当地法律法规。在中国大陆地区，请勿利用本项目进行任何违反《中华人民共和国网络安全法》及相关法律法规的行为。

无担保：作者不对脚本的安全性、稳定性或因使用本脚本导致的任何数据丢失、设备损坏或其他损失承担责任。

禁止滥用：严禁将本项目用于非法用途（如网络攻击、黑产等）。

使用即同意：您下载、复制或使用本项目，即表示您已阅读并同意上述所有条款。

如果觉得好用，请点击右上角的 Star ⭐️ 支持一下！
