<div align="center">

<img src="assets/logo.png" alt="CursorTip" width="128" height="128">

# CursorTip

**轻量 · Windows 桌面状态提示工具** · [了解更多](https://cursortip-website.pages.dev/)

在屏幕上实时显示键盘大小写 + 输入法提示和剪贴板操作反馈，帮助你准确感知输入环境。

[![Release](https://img.shields.io/github/v/release/zeno528/CursorTip?style=flat&logo=github&labelColor=1e293b&color=3b82f6)](https://github.com/zeno528/CursorTip/releases)
[![License](https://img.shields.io/github/license/zeno528/CursorTip?style=flat&labelColor=1e293b&color=3e82f6)](LICENSE)
[![Website](https://img.shields.io/badge/Website-cursortip--website.pages.dev-8b5cf6?style=flat&logo=cloudflare-pages&labelColor=1e293b)](https://cursortip-website.pages.dev/)
[![AutoHotkey](https://img.shields.io/badge/AutoHotkey-v2-334455?style=flat&logo=autohotkey&labelColor=1e293b&color=4a5568)](https://www.autohotkey.com/)
[![Windows](https://img.shields.io/badge/Windows-10%2F11-0078D6?style=flat&logo=windows&labelColor=1e293b)](https://github.com/zeno528/CursorTip)

简体中文 | [English](README_EN.md)

</div>

## 效果展示

| 大小写 + 输入法提示 | 复制提示 |
|:-------------------:|:--------:|
| ![](images/preview-caps-ime-light.cn.png)![](images/preview-caps-ime-dark.cn.png) | ![](images/preview-copy-tip-light.cn.png)![](images/preview-copy-tip-dark.cn.png) |

## 功能

| 功能 | 触发方式 | 提示内容 |
|:-----|:---------|:---------|
| 大小写状态 | CapsLock 切换；或**单独**按下并释放 Shift | 🔒 大写 / 🔓 小写 |
| 输入法状态 | 随大小写提示一同显示 | 中 / 英 |
| 复制反馈 | 剪贴板内容变化 | 已复制：N 字符 / N 图片 / N 文件 |

提示以浮动气泡形式出现在屏幕上，自动消失，不打断当前操作。提示位置可选**跟随鼠标 / 屏幕顶部 / 屏幕底部 / 屏幕中央**，外观支持 **浅色 / 深色主题**，可跟随系统自动切换，也能手动选择。

> **关于 Shift 触发**：只有 Shift 被**独立**按下时才提示——按住 Shift 的过程中如果按了其他键、鼠标键或修饰键，松开时不弹气泡（避免 `Shift+A` 这类组合键误触发）。所以长按 Shift 打字时不会一直闪气泡。

## 复制检测

| 复制方式 | 检测结果 |
|:---------|:---------|
| 文本 | N 字符 |
| 图片文件 | N 张图片 |
| 其他文件 | N 个文件 |

复制图片文件时按扩展名识别，支持：`png / jpg / jpeg / gif / bmp / webp / ico / cur / svg / tif / tiff / heic / heif / avif / jfif / jpe / dib`

## 安装

1. 前往 [Releases](https://github.com/zeno528/CursorTip/releases) 下载最新版 `CursorTip_vX.X.X.zip`
2. 解压后双击运行 `CursorTip_vX.X.X.exe`，无需安装 AutoHotkey

> 建议解压到固定目录（如 `D:\Tools\CursorTip`）再运行，exe 的名称含版本号，升级时会被替换成新版本号。

### 开机自启

右键托盘图标 → 设置 → 勾选「开机启动」，或将 exe 放入启动文件夹（`Win+R` 输入 `shell:startup`）

## 设置

托盘图标右键 → 设置。所有改动即时预览，点「保存」才写入配置。

| 分组 | 选项 |
|:-----|:-----|
| **功能开关** | 开机启动 · 大小写提示 · 显示中/英状态 · 复制提示 |
| **显示时长** | 大小写提示、复制提示各自独立调节（100–3000 ms） |
| **提示位置** | 跟随鼠标（可再分右上 / 右下）· 屏幕顶部 · 屏幕底部 · 屏幕中央，各带偏移量滑块 |
| **外观样式** | 跟随系统 / 浅色 / 深色 · 字号 · 加粗 |
| **语言** | 跟随系统 / 简体中文 / English |
| **版本** | 版本号 · 检查更新 |

托盘菜单另有「重启」和「退出」。

## 自动更新

内置更新检查与自升级，无需手动去 Releases 下载：

- **静默检查** — 启动 10 秒后自动检查一次，24 小时节流；有新版时弹托盘气泡提示
- **手动检查** — 设置 → 「检查更新」按钮，状态文本实时显示检查中 / 已是最新 / 发现新版本 / 下载进度 / 失败
- **应用内升级** — 点「立即升级」后静默下载新版 exe，重启自动完成替换并启动新版

几个实现细节：检查走 GitHub Releases 的 Atom feed（无 API 频率限制）；下载跟随系统静态代理；exe 若被改名或移动过，开机自启的注册表路径会自动修正。升级失败时旧版照常运行，不会留下坏状态。

## 编译

需要 [AutoHotkey v2](https://www.autohotkey.com/) 和 Ahk2Exe 编译器（v2 安装包自带）。

```bash
"C:\Program Files\AutoHotkey\Compiler\Ahk2Exe.exe" \
  /in CursorTip.ahk \
  /out CursorTip_v1.3.8.exe \
  /base "C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe"
```

脚本内置 `;@Ahk2Exe-SetMainIcon` 指令指定图标，无需命令行传入。

版本号只在 `VERSION.ahk` 里改，改动会触发 GitHub Actions 自动编译并生成 Draft Release（变更日志从 git history 提取，review 后 publish 即成正式版）。

## 系统要求

- Windows 10 / 11
- 内存占用轻量（常驻主程序约 2.6 MB）

## 项目结构

```
CursorTip/
├── CursorTip.ahk               # 主脚本（所有开发与 Bug 修复均针对此文件）
├── VERSION.ahk                 # 版本号单一真源
├── config.ini                  # 用户配置（运行时生成，不入库）
├── LICENSE                     # MIT 许可证
├── README.md / README_EN.md    # 中英文说明
│
├── .github/workflows/          # CI 语法检查 + 自动编译发行
├── assets/                     # 图标与品牌资源
├── images/                     # README 预览图
└── docs/                       # AHK v2 开发文档
```

## 许可证

[MIT](LICENSE)

## 社区

欢迎任何形式的参与 🎉

- 🐛 遇到问题？提个 [Issue](https://github.com/zeno528/CursorTip/issues/new)
- 💡 有改进想法？提 [Issue](https://github.com/zeno528/CursorTip/issues/new) 聊聊，或直接开 [PR](https://github.com/zeno528/CursorTip/pulls)
- ⭐ 觉得好用？点个 Star 支持一下

