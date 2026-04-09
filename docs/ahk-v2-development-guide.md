# AutoHotkey v2 开发参考手册

> 本文档为 CapsCopyTip 项目维护而编写，记录了实际开发中遇到的 AHK v2 语法要点、陷阱和最佳实践。

---

## 1. 作用域与变量

### 1.1 assume-local 原则

AHK v2 中函数默认是 **assume-local**：函数内使用的变量默认为局部变量，不会修改脚本级全局变量。

```autohotkey
global counter := 0

Increment() {
    counter := counter + 1  ; ❌ 这只修改了局部变量！全局 counter 不变
}

Increment2() {
    global counter           ; ✅ 显式声明，才能修改全局变量
    counter := counter + 1
}
```

**规则**：任何需要修改全局变量的函数，必须用 `global` 声明。

### 1.2 global 的两种形式

```autohotkey
; 形式1：声明特定变量
MyFunc() {
    global tipGui, settingsGui
    tipGui := ""  ; 修改全局变量
}

; 形式2：声明所有变量为全局（不推荐，容易误操作）
MyFunc() {
    global  ; 后续所有变量都指向全局
    tipGui := ""
}
```

**本项目规范**：优先使用形式1，显式列出需要修改的全局变量。

### 1.3 读取全局变量不需要 global

```autohotkey
global enableCapsTip := true

Check() {
    if (!enableCapsTip)  ; ✅ 读取不需要 global
        return
    enableCapsTip := false  ; ❌ 但赋值需要！这会创建局部变量
}
```

### 1.4 static 变量

函数内的 `static` 变量在函数调用间保持值：

```autohotkey
GetIMEStatus(forceRefresh := false) {
    static lastResult := "英"        ; 首次调用初始化，之后保持
    static lastCheckTime := 0
    static lastWindowHash := 0

    if (!forceRefresh) {
        if (A_TickCount - lastCheckTime < 150)
            return lastResult
    }
    ; ...
}
```

### 1.5 类的静态属性不需要 global

```autohotkey
class Config {
    static enableCapsTip := true
}

; 任何位置都可以直接访问 Config.enableCapsTip，不需要 global
Check() {
    if (Config.enableCapsTip)  ; ✅ 类的静态属性始终可访问
        return
}
```

### 1.6 类方法内用 `c := Config` 简化访问

```autohotkey
class Config {
    static enableCapsTip := true

    static Load() {
        c := Config                    ; 别名，避免重复写 Config
        c.enableCapsTip := IniRead(Config.Path, "Settings", "EnableCapsTip", 1) = 1
    }
}
```

---

## 2. GUI 开发

### 2.1 Gui.OnEvent 回调参数

**关键**：`Gui.OnEvent("Close", callback)` 和 `GuiCtrl.OnEvent("Click", callback)` 的第一个参数类型不同。

| 事件 | 回调第一个参数 | 说明 |
|:-----|:-------------|:-----|
| `Gui.OnEvent("Close", fn)` | `Gui` 对象 | 窗口本身 |
| `GuiCtrl.OnEvent("Click", fn)` | `GuiControl` 对象 | 被点击的控件，有 `.Gui` 属性 |

```autohotkey
; Close 事件 → 第一个参数是 Gui
MyGui.OnEvent("Close", OnClose)
OnClose(guiObj) {
    guiObj.Destroy()
}

; Click 事件 → 第一个参数是 GuiControl（Button 等）
btn.OnEvent("Click", OnBtnClick)
OnBtnClick(ctrl) {
    g := ctrl.Gui  ; 通过 .Gui 获取父窗口
    g.Destroy()
}
```

### 2.2 区分 Gui 和 GuiControl

当同一个函数同时作为 Close 和 Click 的回调时，需要区分参数类型：

```autohotkey
; 方法1：用 HasProp（推荐）
SettingsClose(ctrlOrGui, *) {
    g := ctrlOrGui.HasProp("Gui") ? ctrlOrGui.Gui : ctrlOrGui
    g.Destroy()
}

; 方法2：用 is 运算符
SettingsClose(ctrlOrGui, *) {
    if ctrlOrGui is Gui
        ctrlOrGui.Destroy()
    else
        ctrlOrGui.Gui.Destroy()
}
```

**不要用 try-catch**，虽然能工作但语义不清晰且隐藏了真正的异常。

### 2.3 GUI 窗口有效性检查

`IsObject(tipGui)` 在 GUI 调用 `Destroy()` 后仍然返回 `true`！必须同时检查窗口是否存在：

```autohotkey
; ❌ 错误：GUI 销毁后仍为 true
if (IsObject(tipGui)) {
    tipGui.Show()  ; 可能报错！
}

; ✅ 正确：双重检查
if (IsObject(tipGui) && WinExist("ahk_id " . tipGui.Hwnd)) {
    tipGui.Show()
}
```

### 2.4 控件初始值设置

`Gui.Add()` 不支持第四个参数设置初始值，必须先创建再设置 `.Value`：

```autohotkey
; ❌ 错误：第四个参数是文本内容，不是初始值
g.Add("CheckBox", "x20 y30", "标签", true)

; ✅ 正确：先创建，再设置
cb := g.Add("CheckBox", "x20 y30", "标签")
cb.Value := true
```

### 2.5 输入框验证时机

不要在 `OnEvent("Change")` 中实时验证，会导致退格键等输入异常：

```autohotkey
; ❌ 错误：实时验证会破坏正常输入
edit.OnEvent("Change", (*) => edit.Value := Max(100, edit.Value))

; ✅ 正确：在保存时统一验证
SettingsSave(ctrl, *) {
    duration := Max(100, Integer(g.ctl_capsDur.Value || 800))
}
```

### 2.6 GUI 窗口位置更新（防闪烁）

更新窗口文本后重新计算位置时，用 WM_SETREDRAW 禁用重绘：

```autohotkey
SendMessage(0xB, 0, 0, , "ahk_id " . tipGui.Hwnd)  ; 禁用重绘
tipGui.Show("Hide AutoSize")                        ; 隐藏状态下获取新尺寸
tipGui.GetPos(,, &gw, &gh)
; 计算新位置 gx, gy ...
tipGui.Show("x" . gx . " y" . gy . " NA")           ; 直接定位显示
SendMessage(0xB, 1, 0, , "ahk_id " . tipGui.Hwnd)  ; 启用重绘
```

不要用 `Show("NA AutoSize")` + `Move()`，会导致位置累积偏移。

### 2.7 Radio 控件的分组

Radio 控件需要 `+Group` 来标识组的第一项：

```autohotkey
; 第一个 Radio 加 +Group，后续同组的不加
g.ctl_pos2 := g.Add("Radio", "x20 y239 w280 +Group" . (pos = 2 ? " Checked" : ""), "屏幕中央")
g.ctl_pos1 := g.Add("Radio", "x20 y266 w100" . (pos = 1 ? " Checked" : ""), "跟随鼠标")
g.ctl_pos3 := g.Add("Radio", "x20 y293 w100" . (pos = 3 ? " Checked" : ""), "屏幕顶部")
g.ctl_pos4 := g.Add("Radio", "x20 y320 w100" . (pos = 4 ? " Checked" : ""), "屏幕底部")
```

### 2.8 Windows 11 圆角

```autohotkey
; DWMWA_WINDOW_CORNER_PREFERENCE = 33, DWMWCP_ROUND = 2
DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", gui.Hwnd, "Int", 33, "Int*", 2, "Int", 4)
```

---

## 3. OnMessage 与托盘图标

### 3.1 托盘点击消息

托盘图标的消息 ID 是 `0x404`（WM_TRAYICON），通过 `lParam` 区分事件：

| lParam | 事件 |
|:-------|:-----|
| `0x200` | 鼠标移动 |
| `0x201` | 左键按下 |
| `0x202` | 左键释放 |
| `0x203` | 左键双击 |
| `0x204` | 右键按下 |
| `0x205` | 右键释放 |
| `0x206` | 中键按下 |

### 3.2 OnMessage 回调返回值

```autohotkey
OnMessage(0x404, TrayClickHandler)

TrayClickHandler(wParam, lParam, msg, hwnd) {
    if (lParam = 0x201 || lParam = 0x203) {  ; 左键单击或双击
        ShowSettings()
        return 0  ; 返回 0 表示已处理
    }
    ; ⚠️ 右键不要 return！让 AHK 默认处理弹出菜单
}
```

**关键**：右键消息不能拦截或返回值，否则 AHK 默认的右键菜单不会弹出。

### 3.3 OnMessage 回调必须是独立函数

```autohotkey
; ❌ 错误：多行 fat-arrow 在 OnMessage 中不支持
OnMessage(0x404, (wParam, lParam, msg, hwnd) {
    if (lParam = 0x201)
        ShowSettings()
})

; ✅ 正确：使用独立函数名
OnMessage(0x404, TrayClickHandler)
TrayClickHandler(wParam, lParam, msg, hwnd) {
    if (lParam = 0x201)
        ShowSettings()
}
```

---

## 4. 热键

### 4.1 多热键共享代码块

```autohotkey
; LShift 和 RShift 释放时都执行同一段代码
~*LShift up::
~*RShift up:: {
    global lastCapsChangeTime
    if (!Config.enableCapsTip)
        return
    ; ...
}
```

修饰符含义：
- `~` = 不屏蔽按键原始功能
- `*` = 任意修饰键组合都触发
- `up` = 按键释放时触发

### 4.2 热键中读取按键状态

```autohotkey
; "P" = physical，检查物理按键状态（不受 Send 模拟影响）
if (GetKeyState("Ctrl", "P") || GetKeyState("Alt", "P"))
    return  ; 组合键不触发
```

---

## 5. 类

### 5.1 静态属性和静态方法

```autohotkey
class Config {
    static Path := A_ScriptDir . "\config.ini"

    ; 静态属性（带默认值）
    static enableCapsTip := true
    static capsShowDuration := 800

    ; 静态方法
    static Load() {
        c := Config
        c.enableCapsTip := IniRead(Config.Path, "Settings", "EnableCapsTip", 1) = 1
    }
}

; 访问
Config.Load()
val := Config.enableCapsTip
```

### 5.2 不能用 static := 批量赋值

```autohotkey
class Config {
    ; ❌ 错误：static 后面不能跟 := 表达式
    static := SomeObject.Clone()

    ; ✅ 正确：逐个声明静态属性
    static enableCapsTip := true
    static capsShowDuration := 800
}
```

### 5.3 遍历对象的属性

```autohotkey
; Config.Defaults 是普通对象，用 OwnProps() 遍历
static Reset() {
    for k, v in Config.Defaults.OwnProps()
        Config.%k% := v  ; 动态属性名用 %k%
}
```

---

## 6. DllCall

### 6.1 IME 检测 — ImmGetConversionStatus

```autohotkey
DetectIMEViaConversionStatus(hWnd) {
    hIMC := DllCall("imm32\ImmGetContext", "Ptr", hWnd, "UPtr")
    if (!hIMC)
        return ""

    ; fdwConversion & 0x0001 = 1 → 中文输入模式, 0 → 英文模式
    DllCall("imm32\ImmGetConversionStatus", "Ptr", hIMC,
        "UInt*", &fdwConversion := 0, "UInt*", &fdwSentence := 0, "Int")
    DllCall("imm32\ImmReleaseContext", "Ptr", hWnd, "UPtr", hIMC)
    return (fdwConversion & 0x0001) ? "中" : "英"
}
```

### 6.2 IME 检测 — ImmGetDefaultIMEWnd 回退

```autohotkey
DetectIMEViaMessage(hWnd) {
    saved := A_DetectHiddenWindows
    try {
        DetectHiddenWindows(true)
        hIMEWnd := DllCall("imm32\ImmGetDefaultIMEWnd", "UInt", hWnd, "UInt")
        if (hIMEWnd) {
            ; IMC_GETOPENSTATUS (0x005)：返回 1 = IME 打开 = 中文模式
            result := SendMessage(0x283, 0x005, 0, , "ahk_id " . hIMEWnd)
            DetectHiddenWindows(saved)
            return result ? "中" : "英"
        }
        DetectHiddenWindows(saved)
    } catch {
        DetectHiddenWindows(saved)  ; 异常时也要恢复
    }
    return ""
}
```

### 6.3 剪贴板格式检测

```autohotkey
isFile := DllCall("IsClipboardFormatAvailable", "UInt", 15)  ; CF_HDROP
isImage := DllCall("IsClipboardFormatAvailable", "UInt", 2)  ; CF_BITMAP
      || DllCall("IsClipboardFormatAvailable", "UInt", 8)    ; CF_DIB
      || DllCall("IsClipboardFormatAvailable", "UInt", 17)   ; CF_DIBV5
```

### 6.4 注意事项

- `DllCall` 中 `"Ptr"` 对应窗口句柄，`"UPtr"` 对应无符号指针
- 输出参数用 `"UInt*", &var := 0` 形式
- 访问 IME 的 SendMessage 可能对某些窗口报"拒绝访问"，必须 try-catch

---

## 7. 定时器

### 7.1 SetTimer 的用法

```autohotkey
; 启动周期定时器（每 50ms 执行一次）
SetTimer(CheckCapsLock, 50)

; 停止定时器
SetTimer(CheckCapsLock, 0)

; 单次延迟执行（负值 = 只执行一次）
SetTimer(HideTip, -800)  ; 800ms 后执行一次 HideTip

; 先取消旧的，再设置新的（防止累积）
SetTimer(HideTip, 0)
SetTimer(HideTip, -duration)
```

### 7.2 OnClipboardChange

```autohotkey
; 注册剪贴板变化回调
OnClipboardChange(ClipChanged)

; 取消注册
OnClipboardChange(ClipChanged, 0)

; 回调函数接收 dataType 参数：
; 0 = 无内容（剪贴板被清空）
; 1 = 文本
; 2 = 其他（图片等）
ClipChanged(dataType) {
    ; ...
}
```

---

## 8. 注册表操作

### 8.1 开机启动

```autohotkey
; 读取
regValue := RegRead("HKCU\Software\Microsoft\Windows\CurrentVersion\Run", "CapsCopyTip", "")

; 写入
RegWrite(exePath, "REG_SZ", "HKCU\Software\Microsoft\Windows\CurrentVersion\Run", "CapsCopyTip")

; 删除
RegDelete("HKCU\Software\Microsoft\Windows\CurrentVersion\Run", "CapsCopyTip")
```

### 8.2 路径注意

脚本和编译后的 exe 路径不同：

```autohotkey
exePath := A_IsCompiled ? A_ScriptFullPath : A_ScriptDir . "\CapsCopyTip.exe"
```

`IsStartupEnabled` 和 `SetStartup` 必须使用相同的路径计算逻辑。

---

## 9. 类型检查

### 9.1 is 运算符

```autohotkey
if obj is Gui
    ; obj 是 Gui 类型

if obj is Integer
    ; obj 是整数
```

### 9.2 HasProp / HasMethod

```autohotkey
; 检查对象是否有某个属性
if ctrlOrGui.HasProp("Gui")
    g := ctrlOrGui.Gui

; 检查对象是否有某个方法
if obj.HasMethod("Destroy")
    obj.Destroy()
```

---

## 10. 字符串与表达式

### 10.1 字符串拼接

```autohotkey
; 用 . 拼接
tip := "大写" . " | " . "中"

; 在表达式中直接拼接
ShowTip("已复制：" . count . " 字符", duration)
```

### 10.2 三元运算符

```autohotkey
capsIcon := caps ? "🔒 大写" : "🔓 小写"
textColor := lightMode ? "333333" : "FFFFFF"
```

### 10.3 逻辑短路

```autohotkey
; || 用于提供默认值
duration := Max(100, Integer(edit.Value || 800))
; 如果 edit.Value 为空或 0，使用 800

; && 短路
if (IsObject(tipGui) && WinExist("ahk_id " . tipGui.Hwnd))
```

### 10.4 switch 语句

```autohotkey
switch position {
    case 1:
        CoordMode "Mouse", "Screen"
        MouseGetPos(&mx, &my)
        gx := mx + offset
    case 2:
        gx := (A_ScreenWidth - gw) / 2
        gy := (A_ScreenHeight - gh) / 2
    case 3:
        gx := (A_ScreenWidth - gw) / 2
        gy := topOffset
    case 4:
        gx := (A_ScreenWidth - gw) / 2
        gy := A_ScreenHeight - gh - bottomOffset
}
```

---

## 11. try-catch-finally

### 11.1 基本用法

```autohotkey
try {
    result := SendMessage(0x283, 0x005, 0, , "ahk_id " . hIMEWnd)
} catch {
    return ""  ; 静默处理
}
```

### 11.2 捕获异常信息

```autohotkey
try {
    IniWrite(value, path, section, key)
} catch as e {
    MsgBox("保存配置失败：" . e.Message, "错误", 16)
}
```

### 11.3 try-finally（资源清理）

```autohotkey
clipboardProcessing := true
try {
    ; 处理剪贴板...
} finally {
    clipboardProcessing := false  ; 无论是否异常都会执行
}
```

### 11.4 恢复全局设置

```autohotkey
DetectIMEViaMessage(hWnd) {
    saved := A_DetectHiddenWindows
    try {
        DetectHiddenWindows(true)
        ; ... 操作 ...
        DetectHiddenWindows(saved)  ; 正常路径恢复
    } catch {
        DetectHiddenWindows(saved)  ; 异常路径也要恢复！
    }
}
```

---

## 12. 回调与闭包

### 12.1 箭头函数（单行）

```autohotkey
A_TrayMenu.Add("🔄 重启", (*) => Reload())
A_TrayMenu.Add("❌ 退出", (*) => ExitApp())
```

`*` 表示忽略额外参数。

### 12.2 闭包捕获 GUI 控件

```autohotkey
; ✅ 闭包捕获 ctrl 变量，可以正确访问
g.ctl_caps.OnEvent("Click", (ctrl, *) => ctrl.Gui.ctl_ime.Enabled := ctrl.Value)
```

### 12.3 大括号函数体

```autohotkey
; OnMessage 不支持多行 fat-arrow，必须用独立函数
OnMessage(0x404, TrayClickHandler)
TrayClickHandler(wParam, lParam, msg, hwnd) {
    if (lParam = 0x201) {
        ShowSettings()
        return 0
    }
}
```

---

## 13. 项目特定设计模式

### 13.1 Config 类模式

配置管理用静态类，避免全局变量散落：

```autohotkey
class Config {
    static Path := A_ScriptDir . "\config.ini"
    static Defaults := { enableCapsTip: true, /* ... */ }

    ; 每个配置项独立静态属性
    static enableCapsTip := true
    static capsShowDuration := 800

    static Load() { /* 从 ini 读取 */ }
    static Save() { /* 写入 ini */ }
    static Reset() { /* 恢复 Defaults */ }
}
```

访问方式：`Config.enableCapsTip`，不需要 `global` 声明。

### 13.2 提示窗口复用模式

ShowTip 函数复用同一个 GUI 窗口，避免频繁创建销毁：

```autohotkey
ShowTip(text, duration := 0) {
    global tipGui, tipGuiText

    ; 快速路径：窗口已存在，只更新文本和位置
    if (IsObject(tipGui) && WinExist("ahk_id " . tipGui.Hwnd) && IsObject(tipGuiText)) {
        tipGuiText.Value := " " . text . " "
        ; 更新位置...
    } else {
        ; 慢路径：创建新窗口
        tipGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20", "")
        ; ...
    }
}
```

### 13.3 IME 检测的两层策略

1. **首选**：`ImmGetConversionStatus` — 标准 API，通过转换模式判断
2. **回退**：`ImmGetDefaultIMEWnd` + `SendMessage` — 兼容老版本和特殊窗口

两层都有 try-catch 保护，上层通过 `forceRefresh` 参数控制是否跳过缓存。

### 13.4 剪贴板防抖

```autohotkey
ClipChanged(dataType) {
    global clipboardProcessing, lastClipboardContent, lastClipboardTime
    if (!Config.enableCopyTip || clipboardProcessing)
        return

    clipboardProcessing := true
    try {
        if (A_TickCount - lastClipboardTime < 100)  ; 时间防抖
            return
        if (A_Clipboard = lastClipboardContent)      ; 内容去重
            return
        ; 处理...
    } finally {
        clipboardProcessing := false  ; 确保标志位被清除
    }
}
```

---

## 14. 文件结构

```
CapsCopyTip/
├── CapsCopyTipv2.ahk        # 主脚本（v2 重构版）
├── CapsCopyTip.ahk          # 旧版主脚本（归档）
├── config.ini               # 用户配置（自动生成）
├── lib/                     # 依赖库
│   ├── CaretIndicator.ahk   # 光标指示器主类
│   ├── CursorIndicator.ahk  # 鼠标指示器
│   ├── core/
│   │   ├── IndicatorBase.ahk  # 指示器基类
│   │   └── MarkResolver.ahk   # 标记解析
│   ├── detection/
│   │   ├── GetCaretRect.ahk   # 光标位置检测（含 shellcode）
│   │   ├── InputState.ahk     # 输入状态管理
│   │   └── ...
│   ├── image-utils/
│   │   ├── ImagePut.ahk       # 图片显示（5400+ 行）
│   │   ├── ImagePainter.ahk   # 图片绘制
│   │   └── UseBase64Image.ahk # Base64 图片
│   └── utils/
│       ├── Merge.ahk          # 对象合并
│       ├── BatchedPaintScheduler.ahk  # 批量绘制调度
│       └── ...
├── assets/
│   └── github.ico            # 设置窗口图标
├── docs/
│   └── ahk-v2-development-guide.md  # 本文档
└── CLAUDE.md                 # AI 开发规则
```

### 依赖关系

```
CapsCopyTipv2.ahk
├── lib/CaretIndicator.ahk
│   ├── core/IndicatorBase.ahk
│   ├── core/MarkResolver.ahk
│   ├── detection/GetCaretRect.ahk
│   ├── utils/DebugCaretPosition.ahk
│   ├── utils/BatchedPaintScheduler.ahk
│   └── image-utils/* (间接依赖)
└── lib/utils/Merge.ahk
```

**注意**：`lib/CaretIndicator.ahk` 及其依赖约 6000+ 行（含 ImagePut），不要尝试内联到主脚本。
