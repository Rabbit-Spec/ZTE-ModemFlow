#!/bin/sh
# ==========================================
# 脚本：中兴 ZX279133 光猫专属重启脚本
# 作用：通过 HomeAssistant 快速重启光猫
# 作者：https://github.com/Rabbit-Spec
# 版本：1.3.1
# 日期：2026.03.16
# ==========================================

MODEM_IP="192.168.1.1"   # 替换为你的光猫 IP
MODEM_USER="root"        # 光猫 Telnet 用户名
MODEM_PASS="Zte521"      # 光猫 Telnet 密码

echo "[HA_LOG] 正在准备发送重启指令至光猫 ($MODEM_IP)..."

# 使用 expect 自动交互并发送重启命令
/usr/bin/expect <<-EOF
    # 超时时间设短一点，因为只需要发一个指令
    set timeout 5
    spawn telnet $MODEM_IP
    
    # 登录流程
    expect "Login:"
    send "$MODEM_USER\r"
    expect "Password:"
    send "$MODEM_PASS\r"
    expect "#"

    # 发送系统重启指令
    # 注意：中兴底层通常是 reboot，极个别旧版本可能是 reset
    send "reboot\r"
    
    # 指令发送后，光猫网口会迅速掉线，Telnet 进程会抛出 EOF
    # 所以直接捕获 eof 退出即可，不需要等它返回 #
    expect eof
EOF

echo "[HA_LOG] 光猫重启指令已发送完毕，预计 3 分钟后网络恢复。"