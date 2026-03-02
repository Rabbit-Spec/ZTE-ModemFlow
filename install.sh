#!/bin/bash
# ==========================================
# ZTE-ModemFlow 一键部署脚本
# 作者：https://github.com/Rabbit-Spec
# 版本：1.0.1
# ==========================================

set -e

# --- 颜色定义 ---
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\133[1;33m'
RED='\033[0;31m'
NC='\033[0m' # 重置颜色

# 定义基础 URL
RAW_URL="https://raw.githubusercontent.com/Rabbit-Spec/ZTE-ModemFlow/main"

# --- 封装日志函数 ---
log() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# --- 脚本逻辑 ---
echo -e "${BLUE}==========================================${NC}"
log "开始精准部署 ZTE-ModemFlow 项目文件..."
echo -e "${BLUE}==========================================${NC}"

# 1. 创建目录
log "创建必要目录..."
mkdir -p /config/shell /config/packages /config/themes

# 2. 精准下载指定文件
log "正在下载核心脚本: zte_monitor.sh..."
curl -sSL -o /config/shell/zte_monitor.sh "${RAW_URL}/scripts/zte_monitor.sh"

log "正在下载配置文件: zte_modemflow.yaml..."
curl -sSL -o /config/packages/zte_modemflow.yaml "${RAW_URL}/SPEC/packages/zte_modemflow.yaml"

log "正在下载主题文件: mushroom-glass.yaml..."
curl -sSL -o /config/themes/mushroom-glass.yaml "${RAW_URL}/themes/mushroom-glass.yaml"

# 3. 设置权限
chmod +x /config/shell/zte_monitor.sh
success "所有核心文件下载完成，并已授予执行权限。"

# 4. 智能注入配置
CONFIG_FILE="/config/configuration.yaml"
if ! grep -q "packages: !include_dir_named packages" "$CONFIG_FILE"; then
    warn "检测到尚未挂载 Packages，正在执行自动注入..."
    # 确保 homeassistant 节点存在并注入
    if grep -q "homeassistant:" "$CONFIG_FILE"; then
        sed -i '/homeassistant:/a \  packages: !include_dir_named packages' "$CONFIG_FILE"
        success "已成功将 Packages 挂载至现有配置。"
    else
        echo -e "homeassistant:\n  packages: !include_dir_named packages\n$(cat $CONFIG_FILE)" > "$CONFIG_FILE"
        success "已创建 homeassistant 节点并完成挂载。"
    fi
else
    log "检测到配置已存在，跳过注入步骤。"
fi

# --- 结束提示 ---
echo -e "${GREEN}==========================================${NC}"
echo -e "         🎉 ZTE-ModemFlow 部署成功！"
echo -e "${GREEN}==========================================${NC}"
echo -e "${YELLOW}👉 后续操作：${NC}"
echo -e " ${YELLOW}1.${NC} 填入光猫 ${BLUE}IP${NC} 和 ${BLUE}密码${NC}"
echo -e "    └─ 路径: ${BLUE}/config/shell/zte_monitor.sh${NC}"
echo -e ""

echo -e " ${YELLOW}2.${NC} 确保系统已安装 ${GREEN}HACS${NC} 商店"
echo -e ""

echo -e " ${YELLOW}3.${NC} 在 HACS 中下载以下前端插件:"
echo -e "    ├─ ${GREEN}Lovelace Mushroom${NC}"
echo -e "    ├─ ${GREEN}Mini-Graph-Card${NC}"
echo -e "    └─ ${GREEN}Card-mod${NC}"
echo -e ""

echo -e " ${YELLOW}4.${NC} ${RED}重启${NC} Home Assistant 以加载新配置"
echo -e ""

echo -e " ${YELLOW}5.${NC} 在概览中手动添加 ${BLUE}ZTE-ModemFlow${NC} 仪表盘卡片"
echo -e "${BLUE}==========================================${NC}"