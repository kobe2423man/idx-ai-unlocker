#!/bin/bash
# =================================================================
#   Project IDX - 终极纯净版 (Token 修正 + VMess 语法修复)
#   修正内容:
#     1. [Token] 保持修正状态 (ZWZj)
#     2. [VMess] 给链接生成变量加上双引号 "$VAR"，防止 Base64 编码错误
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
pkill -9 xray 2>/dev/null
pkill -9 cloudflared 2>/dev/null
pkill -f keepalive_loop 2>/dev/null
pkill -f disk_keepalive 2>/dev/null
rm -f config.json argo.log keepalive.log
rm -rf "$HOME/.config/systemd/user/idx-node.service"

# --- 2. 下载核心组件 ---
echo -e "${YELLOW}>>> [2/7] 检查并下载核心组件...${NC}"
download() {
    if [ ! -f "$1" ]; then
        echo "正在下载下载 $1 ..."
        wget -q -O "$1" "$2"
        if [ $? -ne 0 ]; then echo -e "${RED}❌ 下载 $1 失败，请检查网络。${NC}"; exit 1; fi
        if [[ "$1" == *.zip ]]; then unzip -q -o "$1"; rm "$1"; else chmod +x "$1"; fi
    fi
}

download "xray.zip" "https://github.com/XTLS/Xray-core/releases/download/v1.8.4/Xray-linux-64.zip"
download "wgcf" "https://github.com/ViRb3/wgcf/releases/download/v2.2.22/wgcf_2.2.22_linux_amd64"
download "cloudflared" "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64"

chmod +x xray wgcf cloudflared

# --- 3. 注册 WARP ---
echo -e "${YELLOW}>>> [3/7] 正在配置 WARP 密钥...${NC}"
if [ ! -f "wgcf-account.toml" ]; then
    yes | ./wgcf register > /dev/null 2>&1
    ./wgcf generate > /dev/null 2>&1
fi

W_KEY=$(grep 'PrivateKey' wgcf-profile.conf | cut -d' ' -f3)
W_ADDR=$(grep 'Address' wgcf-profile.conf | grep ':' | cut -d' ' -f3)

if [ -z "$W_KEY" ]; then
    echo -e "${RED}❌ 致命错误：WARP 注册失败。可能是 IP 被限制。${NC}"; exit 1
fi

# --- 4. 写入 Xray 配置（YouTube 原生 QUIC 高速 + Gemini 走 WARP）---
echo -e "${YELLOW}>>> [4/7] 写入配置文件（YouTube 已优化为原生高速）...${NC}"
cat <<EOF > config.json
{
  "log": { "loglevel": "warning" },
  "inbounds": [
    {
      "port": 8080, "listen": "127.0.0.1", "protocol": "vmess",
      "settings": { "clients": [ { "id": "$UUID" } ] },
      "streamSettings": { "network": "ws", "wsSettings": { "path": "/argo" } },
      "sniffing": { "enabled": true, "destOverride": ["http", "tls", "quic"], "metadataOnly": false }
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
      { "type": "field", "domain": [
        "keyword:openai", "keyword:chatgpt",
        "keyword:gemini", "domain:gemini.google.com", "domain:generativelanguage.googleapis.com", "domain:ai.google.com",
        "keyword:telegram", "keyword:t.me", "keyword:telegra"
      ], "outboundTag": "warp" },
      { "type": "field", "outboundTag": "direct", "network": "udp,tcp" }
    ]
  }
}
EOF

# --- 5. 选择隧道模式 ---
echo -e "${YELLOW}>>> [5/7] 隧道配置...${NC}"

if [ -z "$FIXED_TOKEN" ]; then
    # Token 已更正为 ZWZj
    FIXED_TOKEN="eyJhIjoiMGM1ZjJlNjRlNDMwNDE2ZWZjN2M1MzE4ZGUyMzE5MmYiLCJ0IjoiM2E3MWY2NWUtMjMyZi00Yzk3LTg1OWEtZDIyYzlmNzRmOTM1IiwicyI6Ik4yUmlaV1EyTnpndE9UWmhOeTAwTUdWaUxXRXhZek10TVRkaE1qUTNaak5tT1dZeCJ9"
    FIXED_DOMAIN="idx.kobe24.de5.net"
fi

# 保存配置到 .env
echo "export UUID=\"$UUID\"" > "$CONFIG_FILE"
echo "export FIXED_TOKEN=\"$FIXED_TOKEN\"" >> "$CONFIG_FILE"
echo "export FIXED_DOMAIN=\"$FIXED_DOMAIN\"" >> "$CONFIG_FILE"

# --- 6. 生成启动脚本与最强保活机制 ---
echo -e "${YELLOW}>>> [6/7] 配置自启与最强保活机制...${NC}"

cat <<'EOF' > startup.sh
#!/bin/bash
export WORKDIR="$HOME/idx-final-node"
cd "$WORKDIR"
if [ -f ".env" ]; then source ".env"; fi

if pgrep -x "xray" > /dev/null && pgrep -f "cloudflared tunnel" > /dev/null; then
    if ! pgrep -f "keepalive_loop" > /dev/null; then
        nohup bash -c 'exec -a keepalive_loop bash -c "while true; do sleep 300; done"' > /dev/null 2>&1 &
    fi
    if ! pgrep -f "disk_keepalive" > /dev/null; then
        nohup bash -c 'exec -a disk_keepalive bash -c "while true; do echo $(date) > keepalive.log; sleep 180; done"' > /dev/null 2>&1 &
    fi
    exit 0
fi

nohup ./xray run -c config.json > /dev/null 2>&1 &
sleep 2

if [ -n "$FIXED_TOKEN" ]; then
    nohup ./cloudflared tunnel run --token "$FIXED_TOKEN" > argo.log 2>&1 &
else
    nohup ./cloudflared tunnel --url http://127.0.0.1:8080 --no-autoupdate > argo.log 2>&1 &
fi

nohup bash -c '
    exec -a keepalive_loop bash -c "
        sleep 15
        while true; do
            CURRENT_DOMAIN=\"$FIXED_DOMAIN\"
            if [ -z \"$CURRENT_DOMAIN\" ]; then
                CURRENT_DOMAIN=$(grep -oE \"https://.*[a-z]+.trycloudflare.com\" argo.log | head -n 1 | sed \"s/https:\/\///g\")
            fi
            if [ -n \"$CURRENT_DOMAIN\" ]; then
                curl -s -I \"https://\$CURRENT_DOMAIN/argo\" --connect-timeout 10 > /dev/null 2>&1
            fi
            sleep 180
        done
    "
' > /dev/null 2>&1 &

nohup bash -c 'exec -a disk_keepalive bash -c "while true; do echo $(date) > keepalive.log; sleep 180; done"' > /dev/null 2>&1 &
EOF
chmod +x startup.sh

if ! grep -q "idx-final-node/startup.sh" ~/.bashrc; then
    echo "bash \$HOME/idx-final-node/startup.sh" >> ~/.bashrc
fi

./startup.sh

# --- 7. 验证并输出 ---
echo -e "${YELLOW}>>> [7/7] 正在验证服务状态...${NC}"
sleep 5
ARGO_DOMAIN="$FIXED_DOMAIN"

if [ -z "$FIXED_TOKEN" ]; then
    echo "正在获取临时域名 (可能需要10-30秒)..."
    for i in {1..30}; do
        sleep 2
        ARGO_DOMAIN=$(grep -oE "https://.*[a-z]+.trycloudflare.com" argo.log | head -n 1 | sed 's/https:\/\///g')
        if [ -n "$ARGO_DOMAIN" ]; then break; fi
        echo -n "."
    done
fi

if [ -z "$ARGO_DOMAIN" ]; then
    echo -e "${RED}❌ 获取域名失败，请检查 Token 或查看 argo.log${NC}"
    exit 1
fi

VMESS_JSON="{\"v\":\"2\",\"ps\":\"🇺🇸 US-HighSpeedYT-$ARGO_DOMAIN\",\"add\":\"$ARGO_DOMAIN\",\"port\":\"443\",\"id\":\"$UUID\",\"aid\":\"0\",\"scy\":\"auto\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"$ARGO_DOMAIN\",\"path\":\"/argo\",\"tls\":\"tls\",\"sni\":\"$ARGO_DOMAIN\"}"

# [修复] 仅修改此处：给变量加上双引号，防止语法错误
VMESS_LINK="vmess://$(echo -n "$VMESS_JSON" | base64 -w 0)"

echo -e "\n=================================================="
echo -e "${GREEN}🎉 部署完成！Token 正确 + 链接生成已修复${NC}"
echo -e "=================================================="
echo -e "🌍 域名: ${GREEN}$ARGO_DOMAIN${NC}"
echo -e "🔑 UUID: $UUID"
echo -e "🇺🇸 节点图标: Shadowrocket 显示美国国旗（备注优化为 HighSpeedYT）"
echo -e "💓 保活: 最强版（网络回源 + 磁盘覆盖 + dummy loop）"
echo -e "🚀 路由优化: YouTube 走 direct + QUIC 原生（速度飞快） | Gemini/OpenAI/TG 走 WARP 解锁"
echo -e "--------------------------------------------------"
echo -e "${YELLOW}$VMESS_LINK${NC}"
echo -e "--------------------------------------------------"
