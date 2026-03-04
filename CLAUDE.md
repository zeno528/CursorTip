# CapsCopyTip 项目规则

## 项目概述

AutoHotkey v2 脚本，合并大小写提示 + 复制提示功能。

**功能**：
- 大小写/输入法：🔒 大写 | 中 / 🔓 小写 | 英
- 复制提示：显示复制的字符数/图片/文件数
- 右键托盘图标可打开设置窗口

**文件结构**：
```
CapsCopyTip.ahk  - 主脚本
CapsCopyTip.exe  - 编译后的可执行文件
config.ini       - 用户配置（自动生成）
```

---

## 编译命令

```bash
rm -f /d/Desktop/test/CapsCopyTip.exe && \
"/c/Program Files/AutoHotkey/Compiler/Ahk2Exe.exe" \
  //in "D:\\Desktop\\test\\CapsCopyTip.ahk" \
  //out "D:\\Desktop\\test\\CapsCopyTip.exe" \
  //base "C:\\Program Files\\AutoHotkey\\v2\\AutoHotkey64.exe" \
  //compress 0
```

> ⚠️ 在 Git Bash 下必须用 `//` 双斜杠，单斜杠会被吃掉

**编译流程**：
1. 修改代码后，先让用户测试 `.ahk` 脚本
2. 用户确认没问题后，再执行编译
3. 不要自作主张提前编译

---

## 版本命名规范

采用 **二十进制版本号**，每位最大为 19：

```
v1.0.9 → v1.0.10 → v1.0.11 → ... → v1.0.18 → v1.0.19 → v1.1.0
                                              ↑ PATCH 到 19 进位
v1.19.19 → v2.0.0
    ↑ MINOR 到 19 也进位
```

- **MAJOR（第一位）**：重大重构、不兼容变更
- **MINOR（第二位）**：新功能，达到 19 时进位到 MAJOR
- **PATCH（第三位）**：每次更新递增 1，达到 19 时进位到 MINOR

### 规则

1. 每次发布只递增 PATCH 位（第三位）
2. 每位数字范围 0-19，不存在 20、21 等两位数
3. PATCH 到 19 后下一个版本是 MINOR+1, PATCH=0
4. MINOR 到 19 后下一个版本是 MAJOR+1, MINOR=0, PATCH=0

### 当前版本

| 版本 | 内容 |
|:-----|:-----|
| v1.0.10 | 二十进制版本规范 |
| v1.0.9 | UI 优化微调 |
| v1.0.8 | DefaultConfig + UI 重构 |
| v1.0.7 | 内存泄漏修复 |
| v1.0.6 | 内置光标指示器 |
| v1.0.5 | Bug 修复 |
| v1.0.4 | 浅色模式 + 偏移设置 |
| v1.0.3 | 项目重命名 |
| v1.0.2 | 配置持久化 + 开机启动 |
| v1.0.1 | 托盘菜单 + 设置窗口 |
| v1.0.0 | 初始版本 |

---

## 开发笔记

### SendMessage 权限问题

访问某些窗口的 IME 状态时会报"拒绝访问"，需要 try-catch 保护：

```autohotkey
try {
    result := SendMessage(0x283, 0x005, 0, , "ahk_id " . hIMEWnd)
} catch {
    return "?"
}
```

### GUI 输入框验证时机

不要在 `OnEvent("Change")` 中实时验证，会导致退格键无法正常删除。

**错误做法**：
```autohotkey
capsEdit.OnEvent("Change", (*) => capsEdit.Value := Max(100, capsEdit.Value))
```

**正确做法**：在保存时验证
```autohotkey
SaveAndClose(*) {
    capsShowDuration := Max(100, Integer(capsEdit.Value || 800))
}
```

### GUI 控件初始值设置

`Gui.Add()` 不支持第四个参数设置初始值，需要先创建再设置 `.Value`：

**错误做法**：
```autohotkey
capsCheck := settingsGui.Add("CheckBox", "x20 y30", "大小写提示", enableCapsTip)
```

**正确做法**：
```autohotkey
capsCheck := settingsGui.Add("CheckBox", "x20 y30", "大小写提示")
capsCheck.Value := enableCapsTip
```

### GUI 窗口位置更新（避免闪烁和偏移）

更新 GUI 窗口位置时，不能用 `Show("NA AutoSize")` + `Move()`，会导致位置累积偏移。

**错误做法**：
```autohotkey
tipGui.Show("NA AutoSize")  ; 先显示
tipGui.GetPos(,, &gw, &gh)
tipGui.Move(gx, gy)         ; 再移动 - 会累积偏移！
```

**正确做法**：用 WM_SETREDRAW 禁用重绘，隐藏获取尺寸，直接定位显示
```autohotkey
SendMessage(0xB, 0, 0, , "ahk_id " . tipGui.Hwnd)  ; 禁用重绘
tipGui.Show("Hide AutoSize")                        ; 隐藏状态下获取尺寸
tipGui.GetPos(,, &gw, &gh)
tipGui.Show("x" . gx . " y" . gy . " NA")           ; 直接定位显示
SendMessage(0xB, 1, 0, , "ahk_id " . tipGui.Hwnd)  ; 启用重绘
```

### GUI 窗口有效性检查

`IsObject(tipGui)` 在 GUI 销毁后仍返回 true，需要同时检查窗口是否存在：

**错误做法**：
```autohotkey
if (IsObject(tipGui)) {  ; GUI 销毁后仍为 true！
```

**正确做法**：
```autohotkey
if (IsObject(tipGui) && WinExist("ahk_id " . tipGui.Hwnd)) {
```

### GUI 设置即时生效

修改字体等设置后，需要销毁旧的 GUI 才能在下次显示时应用新设置：

```autohotkey
ApplySettings() {
    ; ... 其他设置 ...

    ; 销毁旧的提示窗口，让下次显示时重新创建
    if (IsObject(tipGui)) {
        tipGui.Destroy()
        tipGui := ""
    }
}
```

### static 控件引用问题

`static tipText` 保留的是控件引用，GUI 销毁后引用失效。配合窗口有效性检查使用，或在重建 GUI 时重新赋值。

### 嵌套函数中的全局变量声明

嵌套函数（函数内定义的函数）中使用 `global` 声明可能无法正确修改脚本级全局变量。

**错误做法**：
```autohotkey
ShowSettings(*) {
    global

    SaveAndClose(*) {
        global  ; 可能无法正确修改脚本级变量！
        tipPosition := 2
    }
}
```

**正确做法**：显式声明需要修改的全局变量
```autohotkey
ShowSettings(*) {
    global

    SaveAndClose(*) {
        global tipPosition, tipFontSize, tipFontBold  ; 显式声明
        tipPosition := 2
    }
}
```

### GUI GroupBox 布局宽度

GroupBox 宽度应与窗口宽度协调，确保左右边距一致：

- 窗口宽度：`340`
- 左右边距：各 `10`
- GroupBox 宽度：`320`（340 - 10 - 10）

```autohotkey
settingsGui.Show("w340 h545")
settingsGui.Add("GroupBox", "x10 y10 w320 h110", "功能开关")
```

---

## 待修复 Bug

### 设置保存后立即切换大小写显示异常 设置保存后立即切换大小写显示异常

**现象**：点击保存后出现保存提示，提示还未消失时立即切换大小写，会显示 `大写 | `（缺少输入法状态），正常应显示 `大写 | 中`

**可能原因**：保存提示和大小写提示共用同一个 GUI 窗口，存在状态竞争

**状态**：待修复

