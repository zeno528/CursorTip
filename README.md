# AllInOneNotification

AutoHotkey v2 脚本，合并显示大小写、输入法和复制状态提示。

## 功能

| 功能 | 触发方式 | 显示内容 |
|:-----|:---------|:---------|
| 大小写 + 输入法 | CapsLock 切换 / Shift 释放 | 🔒 大写 \| 中 / 🔓 小写 \| 英 |
| 复制提示 | 剪贴板变化 | 已复制：N 字符 / 图片 / N 个文件 |

## 使用方法

1. 安装 [AutoHotkey v2](https://www.autohotkey.com/)
2. 双击运行 `AllInOneNotification.ahk`
3. 开机自启：将脚本放入启动文件夹 (`shell:startup`)

## 效果展示

提示会在鼠标位置附近显示，自动消失。

| 小写 + 中文 | 大写 + 英文 |
|:-----------:|:-----------:|
| ![](preview-lowercase-cn.png) | ![](preview-uppercase-en.png) |

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
