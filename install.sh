#!/bin/bash
# =================================================================
#   Project IDX - 终极完美版 (Final Version)
#   功能：免域名 + AI解锁 + 手机端强制TCP修复 + 登录防风控
#   更新：支持固定隧道 + 纯后台静默自启 (Systemd)
# =================================================================

# --- 1. 初始化环境与持久化配置 ---
export WORKDIR="$HOME/idx-final-node"
CONFIG_FILE="$WORKDIR/.env"

mkdir -p "$WORKDIR"

# 颜色
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

# 检查是否已存在配置，存在则读取（保持 UUID 不变）
if [ -f "$CONFIG_FILE" ]; then
    echo -e "${YELLOW}>>> 检测到历史配置，正在恢复 UUID 和设置...${NC}"
    source "$CONFIG_FILE"
fi

# 如果没有 UUID (第一次安装)，则生成
if [ -z "$UUID" ]; then
    export UUID=$(uuidgen 2>/dev/null || cat /proc/sys/kernel/random/uuid)
fi

cd "$WORKDIR"

echo -e "${YELLOW}>>> [1/8] 正在清理旧进程与环境...${NC}"
# 停止 systemd 服务（如果存在）
systemctl --user stop idx-node 2>/dev/null
systemctl --user disable idx-node 2>/dev/null
pkill -9 xray 2>/dev/null
pkill -9 cloudflared 2>/dev/null
rm -f config.json argo.log

# --- 2. 下载核心组件 ---
echo -e "${YELLOW}>>> [2/8] 检查并下载核心组件...${NC}"
download() {
    if [ ! -f "$1" ]; then
        echo "正在下载 $1 ..."
        wget -q -O "$1" "$2"
        if [ $? -ne 0 ]; then echo -e "${RED}❌ 下载 $1 失败，请检查网络。${NC}"; exit 1; fi
        if [[ "$1" == *.zip ]]; then unzip -q -o "$1"; rm "$1"; else chmod +x "$1"; fi
    fi
}

download "xray.zip" "https://github.com/XTLS/Xray-core/releases/download/v1.8.4/Xray-linux-64.zip"
download "wgcf" "https://github.com/ViRb3/wgcf/releases/download/v2.2.22/wgcf_2.2.22_linux_amd64"
download "cloudflared" "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64"

chmod +x xray

# --- 3. 注册 WARP ---
echo -e "${YELLOW}>>> [3/8] 正在配置 WARP 密钥...${NC}"
if [ ! -f "wgcf-account.toml" ]; then
    yes | ./wgcf register > /dev/null 2>&1
    ./wgcf generate > /dev/null 2>&1
fi

W_KEY=$(grep 'PrivateKey' wgcf-profile.conf | cut -d' ' -f3)
W_ADDR=$(grep 'Address' wgcf-profile.conf | grep ':' | cut -d' ' -f3)

if [ -z "$W_KEY" ]; then
    echo -e "${RED}❌ 致命错误：WARP 注册失败。${NC}"; exit 1
fi

# --- 4. 写入 Xray 配置 ---
echo -e "${YELLOW}>>> [4/8] 写入配置文件...${NC}"
cat <<EOF > config.json
{
  "log": { "loglevel": "warning" },
  "inbounds": [
    {
      "port": 8080, "listen": "127.0.0.1",
      "protocol": "vmess",
      "settings": { "clients": [ { "id": "$UUID" } ] },
      "streamSettings": { "network": "ws", "wsSettings": { "path": "/argo" } },
      "sniffing": { "enabled": true, "destOverride": ["http", "tls"], "metadataOnly": false }
    }
  ],
  "outbounds": [
    { "tag": "direct", "protocol": "freedom" },
    { "tag": "block", "protocol": "blackhole" },
    {
      "tag": "warp", "protocol": "wireguard",
      "settings": {
        "secretKey": "$W_KEY",
        "peers": [ { "publicKey": "bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=", "endpoint": "162.159.192.1:2408" } ],
        "address": [ "$W_ADDR" ], "mtu": 1280
      }
    }
  ],
  "routing": {
    "domainStrategy": "IPIfNonMatch",
    "rules": [
      { "type": "field", "network": "udp", "domain": ["google", "youtube", "gemini"], "outboundTag": "block" },
      { "type": "field", "domain": ["openai", "chatgpt", "google", "youtube", "gemini"], "outboundTag": "warp" },
      { "type": "field", "outboundTag": "direct", "network": "udp,tcp" }
    ]
  }
}
EOF

# --- 5. 选择隧道模式 (保存配置到 .env) ---
echo -e "${YELLOW}>>> [5/8] 隧道配置...${NC}"

if [ -z "$FIXED_TOKEN" ]; then
    read -p "是否使用固定 Cloudflare Tunnel Token? [y/n] (默认n): " USE_FIXED
    if [[ "${USE_FIXED,,}" == "y" ]]; then
        echo -e "\n请在下方粘贴您的 Tunnel Token:"
        read -r FIXED_TOKEN
        echo -e "请输入该 Tunnel 绑定的域名:"
        read -r FIXED_DOMAIN
    else
        FIXED_TOKEN=""
        FIXED_DOMAIN=""
    fi
fi

# 保存配置到 .env 文件
echo "export UUID=\"$UUID\"" > "$CONFIG_FILE"
echo "export FIXED_TOKEN=\"$FIXED_TOKEN\"" >> "$CONFIG_FILE"
echo "export FIXED_DOMAIN=\"$FIXED_DOMAIN\"" >> "$CONFIG_FILE"

# --- 6. 生成启动脚本 (Startup Script) ---
cat <<EOF > startup.sh
#!/bin/bash
export WORKDIR="$HOME/idx-final-node"
cd "\$WORKDIR"
if [ -f ".env" ]; then source ".env"; fi

# 检查是否重复运行
if pgrep -x "xray" > /dev/null && pgrep -f "cloudflared tunnel" > /dev/null; then
    exit 0
fi

# 启动 Xray
./xray run -c config.json > /dev/null 2>&1 &
sleep 2

# 启动 Tunnel
if [ -n "\$FIXED_TOKEN" ]; then
    ./cloudflared tunnel run --token "\$FIXED_TOKEN" > argo.log 2>&1 &
else
    ./cloudflared tunnel --url http://127.0.0.1:8080 --no-autoupdate > argo.log 2>&1 &
fi
EOF
chmod +x startup.sh

# --- 7. 配置 Systemd 开机自启 (关键步骤) ---
echo -e "${YELLOW}>>> [6/8] 配置后台自动服务 (Systemd)...${NC}"
mkdir -p "$HOME/.config/systemd/user"
cat <<EOF > "$HOME/.config/systemd/user/idx-node.service"
[Unit]
Description=IDX AI Unlocker Service
After=network.target

[Service]
Type=forking
ExecStart=$HOME/idx-final-node/startup.sh
Restart=always
RestartSec=10

[Install]
WantedBy=default.target
EOF

# 启用服务
systemctl --user daemon-reload
systemctl --user enable idx-node > /dev/null 2>&1
systemctl --user start idx-node > /dev/null 2>&1

# 只有当 Systemd 失败时，才注入 .bashrc 作为备用
if ! systemctl --user is-active --quiet idx-node; then
    echo -e "${RED}⚠️ Systemd 启动异常，切换回终端自启模式...${NC}"
    if ! grep -q "idx-final-node/startup.sh" ~/.bashrc; then
        echo "bash \$HOME/idx-final-node/startup.sh" >> ~/.bashrc
    fi
else 
    echo -e "${GREEN}✅ Systemd 服务配置成功！空间启动即自动运行。${NC}"
fi

# --- 8. 等待并验证 ---
echo -e "${YELLOW}>>> [7/8] 正在验证服务状态...${NC}"
sleep 3
ARGO_DOMAIN="$FIXED_DOMAIN"

# 如果是临时模式，获取域名
if [ -z "$FIXED_TOKEN" ]; then
    for i in {1..10}; do
        sleep 2
        ARGO_DOMAIN=$(grep -oE "https://.*[a-z]+.trycloudflare.com" argo.log | head -n 1 | sed 's/https:\/\///')
        if [ ! -z "$ARGO_DOMAIN" ]; then break; fi
        echo -n "."
    done
fi

if [ -z "$ARGO_DOMAIN" ]; then
    echo -e "${RED}❌ 获取域名失败或服务未启动，请检查 Token。${NC}"; exit 1
fi

# --- 9. 输出结果 ---
VMESS_JSON="{\"v\":\"2\",\"ps\":\"IDX-AI-${ARGO_DOMAIN}\",\"add\":\"$ARGO_DOMAIN\",\"port\":\"443\",\"id\":\"$UUID\",\"aid\":\"0\",\"scy\":\"auto\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"$ARGO_DOMAIN\",\"path\":\"/argo\",\"tls\":\"tls\",\"sni\":\"$ARGO_DOMAIN\"}"
VMESS_LINK="vmess://$(echo -n $VMESS_JSON | base64 -w 0)"

echo -e "\n=================================================="
echo -e "${GREEN}🎉 部署完成！${NC}"
echo -e "=================================================="
echo -e "🌍 域名: ${GREEN}$ARGO_DOMAIN${NC}"
echo -e "🔑 UUID: $UUID"
echo -e "⚡ 状态: \033[36m已配置后台静默启动${NC}"
echo -e "📌 说明: 只要 IDX 空间是 Running 状态，节点即可连接 (无需打开网页终端)"
echo -e "--------------------------------------------------"
echo -e "${YELLOW}$VMESS_LINK${NC}"
echo -e "--------------------------------------------------"
