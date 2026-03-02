#!/bin/sh
# ==========================================
# 脚本：中兴 ZX279133 光猫数据查询脚本
# 功能：中兴光猫自动化数据采集与监控工具。
# 作者：https://github.com/Rabbit-Spec
# 版本：1.0.0
# ==========================================

# ---------------------------------------------------------
# 1. 环境自检查
# ---------------------------------------------------------
echo ">> [1/5] 正在检查环境依赖..."
LOCK_FILE="/tmp/zte_env_checked"
if [ ! -f "$LOCK_FILE" ]; then
    if ! command -v expect &> /dev/null; then
        echo "   (首次运行) 正在安装组件..."
        apk update && apk add expect busybox-extras curl jq > /dev/null 2>&1
    fi
    touch "$LOCK_FILE"
fi

# ---------------------------------------------------------
# 2. 确认光猫Telnet登陆信息
# ---------------------------------------------------------
IP="192.168.1.1"
USER="root"
PASS="Zte521"

# ---------------------------------------------------------
# 3. 光猫物理延迟探测
# ---------------------------------------------------------
echo ">> [2/5] 正在测试光猫物理延迟..."
PING_LATENCY=$(ping -c 1 $IP | grep 'time=' | awk -F'time=' '{print $2}' | awk '{print $1}')
[ -z "$PING_LATENCY" ] && PING_LATENCY=0
echo "   结果: $PING_LATENCY ms"

# ---------------------------------------------------------
# 4. 抓取原始快照 (单次会话)
# ---------------------------------------------------------
echo ">> [3/5] 正在抓取 /proc 原始快照..."
RAW_RESULT=$(expect -c "
set timeout 15
spawn telnet $IP
expect \"Login:\" { send \"$USER\r\" }
expect \"Password:\" { send \"$PASS\r\" }
expect \"/ # \"
send \"cat /proc/uptime; cat /proc/cpuusage; cat /proc/tempsensor; cat /proc/net/dev; cat /proc/meminfo\r\"
expect \"/ # \"
send \"exit\r\"
expect eof
" 2>/dev/null)

# ---------------------------------------------------------
# 5. 【核心修复】数据拼图逻辑：合并被切断的行
# ---------------------------------------------------------
echo ">> [4/5] 正在进行数据拼图与变量解析..."
# 逻辑：如果一行以空格+数字开头，说明它是上一行的延续，将其拼接到上一行 
RESULT=$(echo "$RAW_RESULT" | tr -d '\r' | awk '{
    if (NR > 1 && /^[[:space:]]+[0-9]/) {
        printf " %s", $0
    } else {
        if (NR > 1) printf "\n"
        printf "%s", $0
    }
} END { printf "\n" }')

# 变量初始化兜底
UPTIME_RAW=0; CPU=0; TEMP=0; PON_ERRORS=0; PON_RX=0; PON_TX=0; MEM_AVAIL=0; ETH_RX=0; ETH_TX=0

# 解析基础数据
UPTIME_RAW=$(echo "$RESULT" | grep -E "^[0-9]+\.[0-9]+" | head -n 1 | awk '{print $1}' | cut -d. -f1 | tr -cd '0-9')
CPU=$(echo "$RESULT" | grep -i "average:" | head -n 1 | awk '{print $2}' | tr -cd '0-9.')
TEMP=$(echo "$RESULT" | grep -i "temper value" | grep -oE "[0-9]+" | head -n 1)

# 解析 PON 数据
PON_LINE=$(echo "$RESULT" | grep "pon0:" | head -n 1)
PON_ERRORS=$(echo "$PON_LINE" | awk '{print $4}' | tr -cd '0-9')
PON_RX=$(echo "$PON_LINE" | awk '{print $3}' | tr -cd '0-9')
PON_TX=$(echo "$PON_LINE" | awk '{print $11}' | tr -cd '0-9')

# 解析 LAN (eth0) 数据 
ETH_LINE=$(echo "$RESULT" | grep "eth0:" | head -n 1)
ETH_RX=$(echo "$ETH_LINE" | awk '{print $3}' | tr -cd '0-9')
ETH_TX=$(echo "$ETH_LINE" | awk '{print $11}' | tr -cd '0-9')

# 解析内存
MEM_TOTAL=$(echo "$RESULT" | grep "MemTotal:" | head -n 1 | awk '{print $2}' | tr -cd '0-9')
MEM_AVAIL=$(echo "$RESULT" | grep "MemAvailable:" | head -n 1 | awk '{print $2}' | tr -cd '0-9')

LAST_UPDATE=$(TZ='Asia/Shanghai' date "+%H:%M:%S")

# ---------------------------------------------------------
# 6. 生成 JSON 导出
# ---------------------------------------------------------
echo ">> [5/5] 正在导出 JSON 数据..."
JSON_FILE="/config/shell/zte_data.json"

printf '{"last_update": "%s", "uptime": %s, "cpu": %s, "temp": %s, "ping": %s, "pon_rx": %s, "pon_tx": %s, "pon_err": %s, "mem_total": %s, "mem_avail": %s, "eth_rx": %s, "eth_tx": %s}' \
"$LAST_UPDATE" "${UPTIME_RAW:-0}" "${CPU:-0}" "${TEMP:-0}" "${PING_LATENCY:-0}" \
"${PON_RX:-0}" "${PON_TX:-0}" "${PON_ERRORS:-0}" \
"${MEM_TOTAL:-524288}" "${MEM_AVAIL:-0}" "${ETH_RX:-0}" "${ETH_TX:-0}" > "$JSON_FILE"

chmod 666 "$JSON_FILE"

# ---------------------------------------------------------
# 7. 全数据看板
# ---------------------------------------------------------
echo "------------------------------------------------------------"
echo " ✅ 数据解析成功！光猫数据看板 ($LAST_UPDATE)"
echo "------------------------------------------------------------"
echo " [核心硬件] 温度: ${TEMP:-0} °C | CPU: ${CPU:-0} % | 内存可用: ${MEM_AVAIL:-0}"
echo " [链路质量] 延迟: ${PING_LATENCY:-0} ms | 物理错误(FEC): ${PON_ERRORS:-0} pkts"
echo " [PON 网络] 接收: ${PON_RX:-0} 包 | 发送: ${PON_TX:-0} 包"
echo " [LAN 端口] 接收: ${ETH_RX:-0} 包 | 发送: ${ETH_TX:-0} 包"
echo " [系统运行] 累计时长: ${UPTIME_RAW:-0} 秒"
echo "------------------------------------------------------------"