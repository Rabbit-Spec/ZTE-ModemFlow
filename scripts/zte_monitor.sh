#!/bin/sh
# ==========================================
# 脚本：中兴 ZX279133 光猫数据查询脚本
# 功能：中兴光猫自动化数据采集与监控工具
# 作者：https://github.com/Rabbit-Spec
# 版本：1.3.1
# 日期：2026.03.16
# ==========================================

# ---------------------------------------------------------
# 1. 环境自检查
# ---------------------------------------------------------
echo ">> [1/6] 正在检查环境依赖..."
LOCK_FILE="/tmp/zte_env_checked"
if [ ! -f "$LOCK_FILE" ]; then
    if ! command -v expect > /dev/null 2>&1; then
        echo "   (首次运行) 正在安装组件..."
        apk update && apk add expect busybox-extras curl jq > /dev/null 2>&1
    fi
    touch "$LOCK_FILE"
fi

# ---------------------------------------------------------
# 2. 准备基础参数
# ---------------------------------------------------------
echo ">> [2/6] 正在准备时间与环境参数..."
IP="192.168.1.1"
USER="root"
PASS="Zte521"
JSON_FILE="/config/shell/zte_data.json"
SYNC_TIME=$(TZ='Asia/Shanghai' date "+%Y-%m-%d %H:%M:%S")

# ---------------------------------------------------------
# 3. 光猫物理延迟探测
# ---------------------------------------------------------
echo ">> [3/6] 正在测试光猫物理延迟..."
PING_LATENCY=$(ping -c 1 $IP | grep 'time=' | awk -F'time=' '{print $2}' | awk '{print $1}')
[ -z "$PING_LATENCY" ] && PING_LATENCY=0
echo "   结果: ${PING_LATENCY} ms"

# ---------------------------------------------------------
# 4. 核心抓取逻辑 (注入 opticaltst 命令)
# ---------------------------------------------------------
echo ">> [4/6] 正在执行远程指令获取数据..."
RAW_RESULT=$(expect -c "
set timeout 15
spawn telnet $IP
expect \"Login:\" { send \"$USER\r\" }
expect \"Password:\" { send \"$PASS\r\" }
expect \"/ # \"
send \"cat /proc/uptime; cat /proc/cpuusage; cat /proc/tempsensor; cat /proc/net/dev; cat /proc/meminfo; opticaltst -getpara\r\"
expect \"/ # \"
send \"exit\r\"
expect eof
" 2>/dev/null)

# ---------------------------------------------------------
# 5. 数据解析与智能对时判断
# ---------------------------------------------------------
echo ">> [5/6] 正在进行数据拼图与智能判断对时..."
RESULT=$(echo "$RAW_RESULT" | tr -d '\r')

# --- 系统运行时间 ---
UPTIME_RAW=$(echo "$RESULT" | grep -oE "[0-9]+\.[0-9]+[[:space:]]+[0-9]+\.[0-9]+" | head -n 1 | awk '{print $1}' | cut -d. -f1)
[ -z "$UPTIME_RAW" ] && UPTIME_RAW=0

# --- CPU与温度 ---
CPU=$(echo "$RESULT" | grep -iE "average|usage" | grep -v "cat" | grep -oE "[0-9.]+" | head -n 1)
TEMP=$(echo "$RESULT" | grep -iE "temper|temp" | grep -viE "cat|optical" | grep -oE "[0-9]{2,3}" | head -n 1)

# --- 内存处理 ---
MEM_TOTAL=$(echo "$RESULT" | grep "MemTotal:" | awk '{print $2}' | tr -cd '0-9')
MEM_FREE=$(echo "$RESULT" | grep "MemFree:" | awk '{print $2}' | tr -cd '0-9')
MEM_BUFF=$(echo "$RESULT" | grep "Buffers:" | awk '{print $2}' | tr -cd '0-9')
MEM_CACH=$(echo "$RESULT" | grep "Cached:" | awk '{print $2}' | tr -cd '0-9')
MEM_AVAIL_RAW=$(echo "$RESULT" | grep "MemAvailable:" | awk '{print $2}' | tr -cd '0-9')
if [ -z "$MEM_AVAIL_RAW" ] || [ "$MEM_AVAIL_RAW" -eq 0 ]; then
    MEM_AVAIL=$(expr ${MEM_FREE:-0} + ${MEM_BUFF:-0} + ${MEM_CACH:-0})
else
    MEM_AVAIL=$MEM_AVAIL_RAW
fi

# --- 网络数据 (PON & LAN) ---
PON_LINE=$(echo "$RESULT" | grep "pon0:" | head -n 1)
PON_RX=$(echo "$PON_LINE" | awk '{print $3}' | tr -cd '0-9')
PON_TX=$(echo "$PON_LINE" | awk '{print $11}' | tr -cd '0-9')
PON_ERR=$(echo "$PON_LINE" | awk '{print $4}' | tr -cd '0-9')

ETH_LINE=$(echo "$RESULT" | grep "eth0:" | head -n 1)
ETH_RX=$(echo "$ETH_LINE" | awk '{print $3}' | tr -cd '0-9')
ETH_TX=$(echo "$ETH_LINE" | awk '{print $11}' | tr -cd '0-9')

# --- 接收光功率解析 ---
OPTICAL_RX_RAW=$(echo "$RESULT" | grep "optical RXPower=" | awk -F'=' '{print $2}' | tr -cd '0-9')
if [ -n "$OPTICAL_RX_RAW" ] && [ "$OPTICAL_RX_RAW" -gt 0 ]; then
    OPTICAL_RX=$(awk -v raw="$OPTICAL_RX_RAW" 'BEGIN {printf "%.2f", (10 * log(raw / 10000) / log(10)) + 0.5}')
else
    OPTICAL_RX=0
fi

# --- 智能对时逻辑 ---
SYNC_STATUS="已跳过 (运行稳定)"
if [ "$UPTIME_RAW" -gt 0 ] && [ "$UPTIME_RAW" -lt 600 ]; then
    echo "   -> 检测到系统刚启动 ($UPTIME_RAW s)，执行强制对时..."
    expect -c "
    set timeout 10
    spawn telnet $IP
    expect \"Login:\" { send \"$USER\r\" }
    expect \"Password:\" { send \"$PASS\r\" }
    expect \"/ # \"
    send \"date -s \\\"$SYNC_TIME\\\"\r\"
    expect \"/ # \"
    send \"exit\r\"
    expect eof
    " > /dev/null 2>&1
    SYNC_STATUS="已执行同步"
fi

# ---------------------------------------------------------
# 6. 导出 JSON 并设置权限
# ---------------------------------------------------------
echo ">> [6/6] 正在写入 JSON 缓存并修正权限..."
LAST_UPDATE=$(TZ='Asia/Shanghai' date "+%H:%M:%S")

printf '{"last_update": "%s", "uptime": %s, "cpu": %s, "temp": %s, "ping": %s, "pon_rx": %s, "pon_tx": %s, "pon_err": %s, "mem_total": %s, "mem_avail": %s, "eth_rx": %s, "eth_tx": %s, "optical_rx": %s, "sync_status": "%s"}' \
"$LAST_UPDATE" "${UPTIME_RAW:-0}" "${CPU:-0}" "${TEMP:-0}" "${PING_LATENCY:-0}" \
"${PON_RX:-0}" "${PON_TX:-0}" "${PON_ERR:-0}" \
"${MEM_TOTAL:-524288}" "${MEM_AVAIL:-0}" "${ETH_RX:-0}" "${ETH_TX:-0}" \
"${OPTICAL_RX:-0}" "$SYNC_STATUS" > "${JSON_FILE}.tmp"

chmod 666 "${JSON_FILE}.tmp"
mv "${JSON_FILE}.tmp" "$JSON_FILE"

# ---------------------------------------------------------
# 7. 全数据看板
# ---------------------------------------------------------
echo "------------------------------------------------------------"
echo " ✅ 数据采集完成！光猫数据看板 ($LAST_UPDATE)"
echo "------------------------------------------------------------"
echo " [时间状态] 同步状态: $SYNC_STATUS"
echo " [核心硬件] 温度: ${TEMP:-0} °C | CPU: ${CPU:-0} % | 内存可用: ${MEM_AVAIL:-0} KB"
echo " [链路质量] 延迟: ${PING_LATENCY:-0} ms | 物理错误(FEC): ${PON_ERR:-0} pkts"
echo " [PON 网络] 接收: ${PON_RX:-0} 包 | 发送: ${PON_TX:-0} 包"
echo " [LAN 端口] 接收: ${ETH_RX:-0} 包 | 发送: ${ETH_TX:-0} 包"
echo " [系统运行] 累计时长: ${UPTIME_RAW:-0} 秒"
echo "------------------------------------------------------------"