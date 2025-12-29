#!/bin/bash

# =================================================================
#   Project IDX - 终极完美版 (Final Version)
#   功能：免域名 + AI解锁 + 手机端强制TCP修复 + 登录防风控
# =================================================================

# --- 1. 初始化环境 ---
export WORKDIR="$HOME/idx-final-node"
export UUID=$(uuidgen 2>/dev/null || cat /proc/sys/kernel/random/uuid)
mkdir -p "$WORKDIR"
cd "$WORKDIR"

# 颜色
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}>>> [1/6] 正在清理旧进程与环境...${NC}"
pkill -9 xray 2>/dev/null
pkill -9 cloudflared 2>/dev/null
rm -f config.json argo.log

# --- 2. 下载核心组件 (Xray, WGCF, Cloudflared) ---
echo -e "${YELLOW}>>> [2/6] 检查并下载核心组件...${NC}"

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

# --- 3. 注册 WARP (解锁 AI 的关键) ---
echo -e "${YELLOW}>>> [3/6] 正在配置 WARP 密钥...${NC}"
if [ ! -f "wgcf-account.toml" ]; then
    yes | ./wgcf register > /dev/null 2>&1
    ./wgcf generate > /dev/null 2>&1
fi
W_KEY=$(grep 'PrivateKey' wgcf-profile.conf | cut -d' ' -f3)
W_ADDR=$(grep 'Address' wgcf-profile.conf | grep ':' | cut -d' ' -f3)

if [ -z "$W_KEY" ]; then
    echo -e "${RED}❌ 致命错误：WARP 注册失败。Google 可能会封锁注册接口。${NC}"
    echo "建议稍后重试，或检查 IDX 网络。"
    exit 1
fi

# --- 4. 生成终极配置 (集成所有修复补丁) ---
echo -e "${YELLOW}>>> [4/6] 写入终极配置文件 (强制TCP + MTU修复)...${NC}"

cat <<EOF > config.json
{
  "log": { "loglevel": "warning" },
  "inbounds": [
    {
      "port": 8080, "listen": "127.0.0.1",
      "protocol": "vmess",
      "settings": { "clients": [ { "id": "$UUID" } ] },
      "streamSettings": {
        "network": "ws",
        "wsSettings": { "path": "/argo" }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls"],
        "metadataOnly": false
      }
    }
  ],
  "outbounds": [
    { "tag": "direct", "protocol": "freedom" },
    { "tag": "block", "protocol": "blackhole" },
    {
      "tag": "warp",
      "protocol": "wireguard",
      "settings": {
        "secretKey": "$W_KEY",
        "peers": [ { "publicKey": "bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=", "endpoint": "162.159.192.1:2408" } ],
        "address": [ "$W_ADDR" ],
        "kernelMode": false,
        "mtu": 1280
      }
    }
  ],
  "routing": {
    "domainStrategy": "IPIfNonMatch",
    "rules": [
      {
        "type": "field",
        "network": "udp",
        "domain": ["google", "youtube", "gemini", "gstatic", "googleapis", "googlevideo"],
        "outboundTag": "block"
      },
      {
        "type": "field",
        "domain": [
          "openai", "chatgpt", "ai.com", "auth0",
          "google", "youtube", "gemini", "bard", "gstatic", "googleapis", "googlevideo", "android", "appspot", "accounts.google.com"
        ],
        "outboundTag": "warp"
      },
      { "type": "field", "outboundTag": "direct", "network": "udp,tcp" }
    ]
  }
}
EOF

# --- 5. 启动服务 ---
echo -e "${YELLOW}>>> [5/6] 启动 Xray 和 隧道...${NC}"
nohup ./xray run -c config.json > /dev/null 2>&1 &
sleep 2
if ! pgrep -x "xray" > /dev/null; then echo -e "${RED}❌ Xray 启动失败！${NC}"; exit 1; fi

# 启动隧道
nohup ./cloudflared tunnel --url http://127.0.0.1:8080 --no-autoupdate > argo.log 2>&1 &

echo -e "${YELLOW}>>> [6/6] 正在获取域名 (请等待 10 秒)...${NC}"
for i in {1..10}; do
    sleep 2
    ARGO_DOMAIN=$(grep -oE "https://.*[a-z]+.trycloudflare.com" argo.log | head -n 1 | sed 's/https:\/\///')
    if [ ! -z "$ARGO_DOMAIN" ]; then break; fi
    echo -n "."
done
echo ""

if [ -z "$ARGO_DOMAIN" ]; then
    echo -e "${RED}❌ 获取域名失败，请重试。${NC}"; cat argo.log; exit 1
fi

# --- 6. 输出结果 ---
VMESS_JSON="{\"v\":\"2\",\"ps\":\"IDX-Final-AI\",\"add\":\"$ARGO_DOMAIN\",\"port\":\"443\",\"id\":\"$UUID\",\"aid\":\"0\",\"scy\":\"auto\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"$ARGO_DOMAIN\",\"path\":\"/argo\",\"tls\":\"tls\",\"sni\":\"$ARGO_DOMAIN\"}"
VMESS_LINK="vmess://$(echo -n $VMESS_JSON | base64 -w 0)"

echo -e "\n=================================================="
echo -e "${GREEN}🎉 部署完成！这是你的完美节点链接：${NC}"
echo -e "=================================================="
echo -e "🌍 域名: ${GREEN}$ARGO_DOMAIN${NC}"
echo -e "🔑 UUID: $UUID"
echo -e "🛡️ 策略: \033[36mGoogle全系 + OpenAI -> 强制走WARP (TCP稳定版)\033[0m"
echo -e "--------------------------------------------------"
echo -e "${YELLOW}$VMESS_LINK${NC}"
echo -e "--------------------------------------------------"
echo -e "👉 复制上方 vmess:// 链接，导入软件即可使用。"
echo -e "⚠️  导入后，请务必【断开】之前的连接，再重新连接！"
echo -e "⚠️  手机端无需任何特殊设置，直接用即可解锁。"
echo -e "=================================================="