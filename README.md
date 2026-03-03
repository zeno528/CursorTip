# CapsCopyTip

AutoHotkey v2 脚本，合并显示大小写、输入法和复制状态提示。

## 解决的痛点

### 键盘状态盲区
很多笔记本/机械键盘没有 CapsLock 指示灯，或者灯在角落看不清。切换大小写后经常盲打，输了才发现错了，得删除重输。

### 输入法状态混乱
Windows 输入法状态栏有时不显示或位置不明显。切换窗口后输入法状态可能变化，打字时才发现是错的模式。

### 复制操作无反馈
Ctrl+C 没有任何提示，不确定是否复制成功，也不知道复制了多少内容，要粘贴确认才知道。

**核心价值**：给"盲操作"提供即时视觉反馈，减少误操作和重复确认的时间。

## 功能

| 功能 | 触发方式 | 显示内容 |
|:-----|:---------|:---------|
| 大小写 + 输入法 | CapsLock 切换 / Shift 释放 | 🔒 大写 \| 中 / 🔓 小写 \| 英 |
| 复制提示 | 剪贴板变化 | 已复制：N 字符 / 图片 / N 个文件 |

### 复制检测逻辑说明

| 复制方式 | 检测结果 | 说明 |
|:---------|:---------|:-----|
| 复制文本 | N 字符 | 任意文本内容 |
| 截图 (Win+Shift+S) | 图片 | 系统截图工具 |
| 画图/PS/微信复制图片 | 图片 | 图片编辑软件复制的图片内容 |
| 文件管理器复制图片文件 | N 个文件 | 复制的是图片**文件**，不是图片内容 |
| 文件管理器复制任意文件 | N 个文件 | 复制的是文件 |

## 下载安装

### 方式一：直接下载 exe（推荐）

1. 前往 [Releases](https://github.com/Ekko7778/AllInOneNotification/releases) 页面
2. 下载 `AllInOneNotification.exe`
3. 双击运行即可，**无需安装 AutoHotkey**
4. 开机自启：将 exe 放入启动文件夹（Win+R 输入 `shell:startup`）

### 方式二：下载完整包

1. 下载 [AllInOneNotification_v1.0.zip](AllInOneNotification_v1.0.zip)
2. 解压到任意目录
3. 双击 `AutoHotkey_2.0.21_setup.exe` 安装 AutoHotkey v2
4. 双击 `AllInOneNotification.ahk` 运行脚本

### 方式三：仅下载脚本

1. 安装 [AutoHotkey v2](https://www.autohotkey.com/)
2. 下载 `AllInOneNotification.ahk`
3. 双击运行

## 效果展示

提示会在鼠标位置附近显示，自动消失。

| 小写 + 中文 | 大写 + 英文 | 复制提示 |
|:-----------:|:-----------:|:--------:|
| ![](preview-lowercase-cn.png) | ![](preview-uppercase-en.png) | ![](preview-copy.jpg) |

## 文件说明

| 文件 | 说明 |
|:-----|:-----|
| `AllInOneNotification.ahk` | 合并版脚本（推荐） |
| `CapsLockNotificationPro.ahk` | 大小写 + 输入法提示（独立版） |
| `CopyNotification.ahk` | 复制提示（独立版） |

## 自定义

编辑脚本顶部的全局设置：

```ahk
global capsShowDuration := 800    ; 大小写提示显示时间 (ms)
global copyShowDuration := 800    ; 复制提示显示时间 (ms)
```

## 系统要求

- Windows 10/11
- AutoHotkey v2.0+
