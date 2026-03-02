[![Support on Afdian](https://img.shields.io/badge/Support-爱发电-orange.svg?style=flat-square&logo=afdian)](https://afdian.com/a/Rabbit-Spec)
<h1 align="center">ZTE-ModemFlow</h1>

<p align="center">
  专为中兴 ZX279133 光猫设计的高级 Home Assistant 监控方案
</p>
<p align="center">
通过底层 Telnet 自动化脚本，将光猫的硬件状态、链路质量及网络流量解析并同步至 HomeAssistant 仪表盘。
</p>

<p align="center">
<img src="https://raw.githubusercontent.com/Rabbit-Spec/ZTE-ModemFlow/main/IMG/1.PNG" width="300"></img>
<img src="https://raw.githubusercontent.com/Rabbit-Spec/ZTE-ModemFlow/main/IMG/2.PNG" width="300"></img>
</p>

## ✨ 核心亮点

* **极致采集效率**：采用“单次登录、批量读取”逻辑，只需建立一个 Telnet 会话即可抓取全部 `/proc` 快照，避免频繁登录光猫增加负载。
* **高性能的解析**：内置智能“数据拼图”算法，利用 `awk` 自动识别并修复因中兴终端宽度限制导致的断行数据，确保解析精度。
* **视觉巅峰体验**：配套 **Mushroom Glass** 主题，实现高斯模糊（冰霜玻璃）效果，专为手机小屏幕体验优化排版。
* **全维度监控**：涵盖 CPU 占用、实时温度、内存占用（总/可用）、运行时间、PON 网络 FEC 物理错误及 LAN 端口收发包统计。

## 📂 仓库结构

```text
├── conf/
│   └── configuration.yaml    # 包含命令行传感器、模板传感器及数据库优化配置
├── dashboards/
│   └── dashboard.yaml       # 基于 Mushroom 和 Mini-graph-card 的仪表盘代码
├── scripts/
│   ├── zte_monitor.sh       # 数据采集核心脚本（含拼图算法与 JSON 导出）
│   └── reboot_modem.sh      # 远程重启触发脚本
└── themes/
    └── mushroom-glass.yaml   # 适配明暗模式的毛玻璃主题文件
```

## 🧩 依赖插件 (HACS)

在导入本项目配置前，请确保已在 **HACS 商店** 安装以下前端组件：
1. **Mushroom Cards**：基础 UI 架构。
2. **Mini Graph Card**：用于显示趋势曲线。
3. **Card-mod**：核心视觉依赖，用于实现模糊效果。

## 🚀 安装与配置

### 1. 部署脚本 (Scripts)
将 `scripts/` 目录下的文件上传至 `/config/shell/` 文件夹下，并赋予执行权限：
```bash
chmod +x /config/shell/zte_monitor.sh
chmod +x /config/shell/reboot_modem.sh
```
> **注意**：脚本默认 Telnet 登录信息为 `root` / `Zte521`，如不同请自行修改。

### 2. 配置光猫数据传感器 (Conf)
将 `conf/configuration.yaml` 内容合并至你的 HA `configuration.yaml` 配置。

脚本会生成 `zte_data.json` 文件由 `command_line` 传感器读取。

### 3. 应用主题 (Themes)
将 `themes/mushroom-glass.yaml` 放入 HA 的 `themes` 目录并启用该主题。

### 4. 导入仪表盘 (Dashboards)
新建仪表盘面板，将 `dashboards/dashboard.yaml` 内容粘贴至代码编辑器。

## 📊 监控指标说明

| 传感器名称 | 物理意义 | 技术细节 |
| :--- | :--- | :--- |
| **CPU 负载** | 实时系统占用百分比 | 抓取自 `/proc/cpuusage` |
| **内存占用** | (Total - Avail) / Total | 自动计算百分比，预防内存泄漏 |
| **PON 物理错误** | 前向纠错 (FEC) 计数 | 物理链路质量的核心指标 |
| **内网延迟** | HA 到光猫的物理响应 | 基于 ICMP Ping 探测 |

## ⚠️ 免责声明
* 请确保你的光猫已开启 Telnet 权限。
* 本脚本涉及模拟登录操作，请勿在公网环境下暴露 Telnet 端口。

---

## ☕ 赞助与支持

如果你觉得 **Rabbit-Spec** 的「Surge自用配置以及模块和脚本」项目对你有帮助，欢迎请我喝杯咖啡。

👉 [点击前往爱发电支持我](https://afdian.com/a/Rabbit-Spec)

---

## 我用的机场
**我用着好用不代表你用着也好用，如果想要入手的话，建议先买一个月体验一下。任何机场都有跑路的可能。**<br>
> **「Nexitally」:** [佩奇家主站，一家全线中转线路的高端机场，延迟低速度快。](https://naiixi.com/signupbyemail.aspx?MemberCode=0b532ff85dda43e595fb1ae17843ae6d20211110231626) <br>

> **「TAG」:** [目前共有90+个国家地区节点，覆盖范围目前是机场里最广的。](https://482469.dedicated-afflink.com) <br>

---
