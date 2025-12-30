#!/bin/bash
# =================================================================
#   Project IDX - 终极纯净版 (Clean Version)
#   功能：免域名 + AI解锁 + 固定隧道 + 零报错静默自启
#   修复：彻底移除不支持的 Systemd，改用 Shell 钩子
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

echo -e "${YELLOW}>>> [1/7] 正在清理旧进程与环境...${NC}"
# 彻底清理旧的进程
pkill -9 xray 2>/dev/null
pkill -9 cloudflared 2>/dev/null
rm -f config.json argo.log
# 清理之前可能产生的错误服务文件
rm -rf "$HOME/.config/systemd/user/idx-node.service"

# --- 2. 下载核心组件 ---
echo -e "${YELLOW}>>> [2/7] 检查并下载核心组件...${NC}"
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
echo -e "${YELLOW}>>> [3/7] 正在配置 WARP 密钥...${NC}"
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
echo -e "${YELLOW}>>> [4/7] 写入配置文件...${NC}"
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
echo -e "${YELLOW}>>> [5/7] 隧道配置...${NC}"

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

# --- 6. 生成启动脚本与配置静默自启 ---
echo -e "${YELLOW}>>> [6/7] 配置环境自启 (Project IDX 专用)...${NC}"

cat <<EOF > startup.sh
#!/bin/bash
export WORKDIR="$HOME/idx-final-node"
cd "\$WORKDIR"
if [ -f ".env" ]; then source ".env"; fi

# 检查进程是否已运行 (防止重复启动)
if pgrep -x "xray" > /dev/null && pgrep -f "cloudflared tunnel" > /dev/null; then
    exit 0
fi

# 启动 Xray
nohup ./xray run -c config.json > /dev/null 2>&1 &
sleep 2

# 启动 Tunnel
if [ -n "\$FIXED_TOKEN" ]; then
    nohup ./cloudflared tunnel run --token "\$FIXED_TOKEN" > argo.log 2>&1 &
else
    nohup ./cloudflared tunnel --url http://127.0.0.1:8080 --no-autoupdate > argo.log 2>&1 &
fi
EOF
chmod +x startup.sh

# 注入到 .bashrc 实现 IDX 环境加载时自动运行
# 注意：IDX 的终端初始化会自动执行 .bashrc，这是最稳妥的自启方式
if ! grep -q "idx-final-node/startup.sh" ~/.bashrc; then
    echo "bash \$HOME/idx-final-node/startup.sh" >> ~/.bashrc
fi

# 立即运行一次
./startup.sh

# --- 7. 等待并验证 ---
echo -e "${YELLOW}>>> [7/7] 正在验证服务状态...${NC}"
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

# --- 8. 输出结果 ---
VMESS_JSON="{\"v\":\"2\",\"ps\":\"IDX-AI-${ARGO_DOMAIN}\",\"add\":\"$ARGO_DOMAIN\",\"port\":\"443\",\"id\":\"$UUID\",\"aid\":\"0\",\"scy\":\"auto\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"$ARGO_DOMAIN\",\"path\":\"/argo\",\"tls\":\"tls\",\"sni\":\"$ARGO_DOMAIN\"}"
VMESS_LINK="vmess://$(echo -n $VMESS_JSON | base64 -w 0)"

echo -e "\n=================================================="
echo -e "${GREEN}🎉 部署完成！(纯净无报错版)${NC}"
echo -e "=================================================="
echo -e "🌍 域名: ${GREEN}$ARGO_DOMAIN${NC}"
echo -e "🔑 UUID: $UUID"
echo -e "⚡ 状态: \033[36m已配置环境自启 (打开 Workspace 即生效)${NC}"
echo -e "--------------------------------------------------"
echo -e "${YELLOW}$VMESS_LINK${NC}"
echo -e "--------------------------------------------------"
