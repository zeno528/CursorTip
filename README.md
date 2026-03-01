# AllInOneNotification

AutoHotkey v2 脚本，合并显示大小写、输入法和复制状态提示。

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

## 使用方法

1. 安装 [AutoHotkey v2](https://www.autohotkey.com/)
2. 双击运行 `AllInOneNotification.ahk`
3. 开机自启：将脚本放入启动文件夹 (`shell:startup`)

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
