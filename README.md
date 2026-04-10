# CursorTip

[![Release](https://img.shields.io/github/v/release/zeno528/CursorTip?style=flat-square&logo=github)](https://github.com/zeno528/CursorTip/releases)
[![Stars](https://img.shields.io/github/stars/zeno528/CursorTip?style=flat-square&logo=github)](https://github.com/zeno528/CursorTip/stargazers)
[![Issues](https://img.shields.io/github/issues/zeno528/CursorTip?style=flat-square&logo=github)](https://github.com/zeno528/CursorTip/issues)
[![License](https://img.shields.io/github/license/zeno528/CursorTip?style=flat-square)](LICENSE)
[![AutoHotkey](https://img.shields.io/badge/AutoHotkey-v2-334455?style=flat-square&logo=autohotkey)](https://www.autohotkey.com/)
[![Windows](https://img.shields.io/badge/Windows-10%2F11-0078D6?style=flat-square&logo=windows)](https://github.com/zeno528/CursorTip)

一款 Windows 桌面状态提示工具，基于 AutoHotkey v2 开发。在屏幕上实时显示键盘状态和剪贴板操作反馈，帮助你准确感知输入环境。

## 功能

| 功能 | 触发方式 | 提示内容 |
|:-----|:---------|:---------|
| 大小写状态 | CapsLock 切换 / Shift 释放 | 🔒 大写 / 🔓 小写 |
| 输入法状态 | 随大小写提示一同显示 | 中 / 英 |
| 复制反馈 | 剪贴板内容变化 | 已复制：N 字符 / 图片 / N 个文件 |

提示以浮动气泡形式出现在屏幕上，数秒后自动消失，不打断当前操作。

## 复制检测

| 复制方式 | 检测结果 |
|:---------|:---------|
| 文本 | N 字符 |
| 截图 (Win+Shift+S) | 图片 |
| 画图 / PS / 微信复制图片 | 图片 |
| 文件管理器复制文件 | N 个文件 |

## 安装

1. 前往 [Releases](https://github.com/zeno528/CursorTip/releases) 下载最新版 `CursorTip_vX.X.X.exe`
2. 双击运行，无需安装 AutoHotkey

### 开机自启

右键托盘图标 → 设置 → 勾选「开机启动」，或将 exe 放入启动文件夹（`Win+R` 输入 `shell:startup`）

## 设置

右键托盘图标打开设置窗口，支持配置：

- 功能开关（大小写提示 / 输入法显示 / 复制提示）
- 显示时长
- 提示位置（跟随鼠标 / 屏幕中央 / 顶部 / 底部）
- 外观样式（深色 / 浅色 / 字号 / 加粗）

## 效果展示

| 大小写 + 输入法提示 | 复制提示 | 设置界面 |
|:-------------------:|:--------:|:--------:|
| ![](images/preview-copy-tip.png) | ![](images/preview-caps-ime.png) | ![](images/preview-settings.png) |

## 系统要求

- Windows 10 / 11
- 无需安装 AutoHotkey

## 许可证

[MIT](LICENSE)
