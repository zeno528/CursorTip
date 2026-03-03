; ============================================================
; CapsCopyTip v1.3.0 (AutoHotkey v2)
; 功能：合并大小写提示 + 复制提示 + 光标语言标记
; - 大小写/输入法：🔒 大写 | 中 / 🔓 小写 | 英
; - 复制提示：显示复制的字符数/图片/文件数
; - 光标标记：在文本光标旁显示语言状态（内置 CaretIndicator）
; - 右键托盘图标可打开设置
; ============================================================

#SingleInstance Force
Persistent

; ============================================================
; 引入 language-indicator 库
; ============================================================
#include lib\CaretIndicator.ahk
#include lib\utils\Merge.ahk

; ============================================================
; 全局设置
; ============================================================
global VERSION := "1.3.2"
global capsShowDuration := 800    ; 大小写提示显示时间
global copyShowDuration := 800    ; 复制提示显示时间
global lastCapsState := GetKeyState("CapsLock", "T")
global configPath := A_ScriptDir . "\config.ini"

; 功能开关
global enableCapsTip := true      ; 启用大小写提示
global enableCopyTip := true      ; 启用复制提示
global enableCaretIndicator := true  ; 启用光标指示器
global showIMEStatus := true      ; 显示中/英状态
global imeDetectInvert := false   ; 反转输入法检测逻辑（某些输入法需要）

; 提示位置设置
global tipPosition := 1           ; 提示位置: 1=鼠标附近, 2=屏幕中央, 3=屏幕顶部, 4=屏幕底部
global tipMouseOffset := 10       ; 鼠标附近时的偏移距离(像素)
global tipTopOffset := 50         ; 屏幕顶部偏移距离(像素)
global tipBottomOffset := 100     ; 屏幕底部偏移距离(像素)

; 外观设置
global tipFontSize := 9           ; 字体大小
global tipFontBold := true        ; 字体加粗
global tipLightMode := false      ; 浅色模式 (false=深色, true=浅色)

; 光标指示器实例
global caretIndicatorInst := ""

; 提示 GUI
global tipGui := ""

; 设置窗口 GUI（脚本级变量，便于独立函数清理）
global settingsGui := ""

; 剪贴板防抖
global lastClipboardContent := ""
global lastClipboardTime := 0

A_TrayTip := "CapsCopyTip v" . VERSION . " - 大小写+输入法+复制+光标指示"

; ============================================================
; 托盘菜单设置
; ============================================================
A_TrayMenu.Delete()
A_TrayMenu.Add("⚙ 设置", ShowSettings)
A_TrayMenu.Add()
A_TrayMenu.Add("🔄 重启", (*) => Reload())
A_TrayMenu.Add("❌ 退出", (*) => ExitApp())

; 单击托盘图标打开设置
OnMessage(0x404, TrayClickHandler)

TrayClickHandler(wParam, lParam, msg, hwnd) {
    if (lParam = 0x201 || lParam = 0x203) {  ; 单击或双击
        ShowSettings()
        return 0
    }
}

; ============================================================
; 启动时加载配置
; ============================================================
LoadConfig()

; ============================================================
; 启动光标标记 (内置 CaretIndicator)
; ============================================================
if (enableCaretIndicator) {
    caretIndicatorInst := CaretIndicator(merge(CaretIndicator.DefaultConfig, {
        markMargin: { x: 1, y: -1 }
    }))
    caretIndicatorInst.Run()
}

; ============================================================
; 大小写监听
; ============================================================
if (enableCapsTip) {
    SetTimer(CheckCapsLock, 30)
}

; Shift 组合键检测：使用 InputHook 监控按键
global shiftInputHook := ""

~Shift:: {
    if (enableCapsTip) {
        ; 检测其他修饰键是否被按住（Shift+Ctrl、Shift+Alt 等）
        if (GetKeyState("Ctrl", "P") || GetKeyState("Alt", "P") || GetKeyState("LWin", "P") || GetKeyState("RWin", "P"))
            return

        ; 启动 InputHook 监控任意按键（非阻塞）
        shiftInputHook := InputHook("V L0 T0.5", "{Shift}")
        shiftInputHook.Start()

        KeyWait("Shift")

        ; 检查是否在 Shift 按下期间有其他键被按下
        ; InProgress = true 表示没有其他键按下，正常结束
        if (shiftInputHook.InProgress)
            ShowCapsStatus(true, true)

        shiftInputHook.Stop()
        shiftInputHook := ""
    }
}

; ============================================================
; 复制监听
; ============================================================
if (enableCopyTip) {
    OnClipboardChange(ClipChanged)
}

return

; ============================================================
; 配置管理
; ============================================================
LoadConfig() {
    global

    if !FileExist(configPath)
        return

    try {
        capsShowDuration := IniRead(configPath, "Settings", "CapsShowDuration", 800)
        copyShowDuration := IniRead(configPath, "Settings", "CopyShowDuration", 800)
        enableCapsTip := IniRead(configPath, "Settings", "EnableCapsTip", 1) = 1
        enableCopyTip := IniRead(configPath, "Settings", "EnableCopyTip", 1) = 1
        enableCaretIndicator := IniRead(configPath, "Settings", "EnableCaretIndicator", 1) = 1
        tipPosition := Integer(IniRead(configPath, "Settings", "TipPosition", 1))
        tipMouseOffset := IniRead(configPath, "Settings", "TipMouseOffset", 10)
        tipTopOffset := IniRead(configPath, "Settings", "TipTopOffset", 50)
        tipBottomOffset := IniRead(configPath, "Settings", "TipBottomOffset", 100)
        tipFontSize := IniRead(configPath, "Settings", "TipFontSize", 9)
        tipFontBold := IniRead(configPath, "Settings", "TipFontBold", 1) = 1
        tipLightMode := IniRead(configPath, "Settings", "TipLightMode", 0) = 1
        showIMEStatus := IniRead(configPath, "Settings", "ShowIMEStatus", 1) = 1
        imeDetectInvert := IniRead(configPath, "Settings", "ImeDetectInvert", 0) = 1
    } catch {
        ; 读取失败，使用默认值
    }
}

SaveConfig() {
    global

    try {
        IniWrite(capsShowDuration, configPath, "Settings", "CapsShowDuration")
        IniWrite(copyShowDuration, configPath, "Settings", "CopyShowDuration")
        IniWrite(enableCapsTip ? 1 : 0, configPath, "Settings", "EnableCapsTip")
        IniWrite(enableCopyTip ? 1 : 0, configPath, "Settings", "EnableCopyTip")
        IniWrite(enableCaretIndicator ? 1 : 0, configPath, "Settings", "EnableCaretIndicator")
        IniWrite(tipPosition, configPath, "Settings", "TipPosition")
        IniWrite(tipMouseOffset, configPath, "Settings", "TipMouseOffset")
        IniWrite(tipTopOffset, configPath, "Settings", "TipTopOffset")
        IniWrite(tipBottomOffset, configPath, "Settings", "TipBottomOffset")
        IniWrite(tipFontSize, configPath, "Settings", "TipFontSize")
        IniWrite(tipFontBold ? 1 : 0, configPath, "Settings", "TipFontBold")
        IniWrite(tipLightMode ? 1 : 0, configPath, "Settings", "TipLightMode")
        IniWrite(showIMEStatus ? 1 : 0, configPath, "Settings", "ShowIMEStatus")
        IniWrite(imeDetectInvert ? 1 : 0, configPath, "Settings", "ImeDetectInvert")
    } catch as e {
        MsgBox("保存配置失败：" . e.Message, "错误", 16)
    }
}

; ============================================================
; 开机启动管理
; ============================================================
IsStartupEnabled() {
    global
    exePath := A_ScriptFullPath
    if (A_IsCompiled)
        exePath := A_ScriptFullPath
    else
        exePath := A_ScriptDir . "\CapsCopyTip.exe"

    try {
        regValue := RegRead("HKCU\Software\Microsoft\Windows\CurrentVersion\Run", "CapsCopyTip", "")
        return InStr(regValue, exePath) > 0
    } catch {
        return false
    }
}

SetStartup(enable) {
    global
    exePath := A_ScriptDir . "\CapsCopyTip.exe"

    if (enable) {
        try {
            RegWrite(exePath, "REG_SZ", "HKCU\Software\Microsoft\Windows\CurrentVersion\Run", "CapsCopyTip")
        } catch as e {
            MsgBox("设置开机启动失败：" . e.Message, "错误", 16)
        }
    } else {
        try {
            RegDelete("HKCU\Software\Microsoft\Windows\CurrentVersion\Run", "CapsCopyTip")
        } catch {
            ; 键不存在，忽略
        }
    }
}

; ============================================================
; 设置窗口 - 使用独立函数避免循环引用
; ============================================================
ShowSettings(*) {
    global settingsGui

    ; 防止多开：如果窗口已存在，直接激活
    ; 使用 try-catch 保护 Hwnd 属性访问
    guiHwnd := 0
    try {
        guiHwnd := settingsGui.Hwnd
    } catch {
        settingsGui := ""
    }

    if (guiHwnd && WinExist("ahk_id " . guiHwnd)) {
        WinActivate("ahk_id " . guiHwnd)
        return
    }

    settingsGui := Gui("+Owner", "CapsCopyTip v" . VERSION)
    settingsGui.SetFont("s10", "Microsoft YaHei")

    ; === 功能开关 ===
    settingsGui.Add("GroupBox", "x10 y10 w300 h110", "功能开关")
    settingsGui.ctl_startup := settingsGui.Add("CheckBox", "x20 y30 w100", "开机启动")
    settingsGui.ctl_startup.Value := IsStartupEnabled()
    settingsGui.ctl_caret := settingsGui.Add("CheckBox", "x180 y30 w100", "光标指示器")
    settingsGui.ctl_caret.Value := enableCaretIndicator
    settingsGui.ctl_copy := settingsGui.Add("CheckBox", "x20 y55 w80", "复制提示")
    settingsGui.ctl_copy.Value := enableCopyTip
    settingsGui.ctl_caps := settingsGui.Add("CheckBox", "x20 y80 w100", "大小写提示")
    settingsGui.ctl_caps.Value := enableCapsTip
    settingsGui.ctl_ime := settingsGui.Add("CheckBox", "x180 y80 w110", "显示中/英状态")
    settingsGui.ctl_ime.Value := showIMEStatus
    settingsGui.ctl_ime.Enabled := enableCapsTip

    ; 大小写提示变化时，控制中/英状态是否可选
    settingsGui.ctl_caps.OnEvent("Click", Settings_UpdateIMEState)

    ; === 显示时长 ===
    settingsGui.Add("GroupBox", "x10 y125 w300 h80", "显示时长")
    settingsGui.Add("Text", "x20 y148 w150", "大小写提示 (ms):")
    settingsGui.ctl_capsDur := settingsGui.Add("Edit", "x180 y145 w60", capsShowDuration)
    settingsGui.Add("Text", "x20 y178 w150", "复制提示 (ms):")
    settingsGui.ctl_copyDur := settingsGui.Add("Edit", "x180 y175 w60", copyShowDuration)

    ; === 提示位置 ===
    settingsGui.Add("GroupBox", "x10 y210 w300 h135", "提示位置")
    settingsGui.ctl_pos2 := settingsGui.Add("Radio", "x20 y235 w100 +Group" . (tipPosition = 2 ? " Checked" : ""), "屏幕中央")
    settingsGui.ctl_pos1 := settingsGui.Add("Radio", "x20 y262 w80" . (tipPosition = 1 ? " Checked" : ""), "鼠标附近")
    settingsGui.ctl_pos3 := settingsGui.Add("Radio", "x20 y289 w80" . (tipPosition = 3 ? " Checked" : ""), "屏幕顶部")
    settingsGui.ctl_pos4 := settingsGui.Add("Radio", "x20 y316 w80" . (tipPosition = 4 ? " Checked" : ""), "屏幕底部")
    settingsGui.Add("Text", "x180 y265 w30", "偏移:")
    settingsGui.ctl_mouseOffset := settingsGui.Add("Edit", "x220 y262 w40", tipMouseOffset)
    settingsGui.Add("Text", "x265 y265", "px")
    settingsGui.Add("Text", "x180 y292 w30", "偏移:")
    settingsGui.ctl_topOffset := settingsGui.Add("Edit", "x220 y289 w40", tipTopOffset)
    settingsGui.Add("Text", "x265 y292", "px")
    settingsGui.Add("Text", "x180 y319 w30", "偏移:")
    settingsGui.ctl_bottomOffset := settingsGui.Add("Edit", "x220 y316 w40", tipBottomOffset)
    settingsGui.Add("Text", "x265 y319", "px")

    ; === 外观样式 ===
    settingsGui.Add("GroupBox", "x10 y350 w300 h105", "外观样式（默认深色）")
    settingsGui.ctl_lightMode := settingsGui.Add("CheckBox", "x20 y375 w80", "浅色模式")
    settingsGui.ctl_lightMode.Value := tipLightMode
    settingsGui.Add("Text", "x20 y405 w40", "字号:")
    settingsGui.ctl_fontSize := settingsGui.Add("Edit", "x60 y402 w40", tipFontSize)
    settingsGui.ctl_bold := settingsGui.Add("CheckBox", "x180 y405 w60", "加粗")
    settingsGui.ctl_bold.Value := tipFontBold
    settingsGui.ctl_invert := settingsGui.Add("CheckBox", "x20 y435 w150", "反转输入法检测")
    settingsGui.ctl_invert.Value := imeDetectInvert

    ; === 按钮 ===
    settingsGui.Add("Button", "x25 y465 w80", "恢复默认").OnEvent("Click", Settings_ResetDefaults)
    settingsGui.Add("Button", "x125 y465 w80 Default", "保存").OnEvent("Click", Settings_SaveAndClose)
    settingsGui.Add("Button", "x225 y465 w80", "取消").OnEvent("Click", Settings_CancelAndClose)

    ; 窗口关闭时清理（点击 X 关闭）
    settingsGui.OnEvent("Close", Settings_CancelAndClose)

    ; GitHub 链接
    settingsGui.Add("Link", "x105 y505", '<a href="https://github.com/Ekko7778/AllInOneNotification">GitHub @Ekko7778</a>')

    settingsGui.Show("w340 h545")
}

; 独立的事件处理函数 - 通过参数接收 GUI，避免闭包捕获
Settings_UpdateIMEState(ctrl, *) {
    g := ctrl.Gui
    g.ctl_ime.Enabled := ctrl.Value
}

Settings_ResetDefaults(ctrl, *) {
    g := ctrl.Gui
    g.ctl_caps.Value := true
    g.ctl_ime.Value := true
    g.ctl_ime.Enabled := true
    g.ctl_copy.Value := true
    g.ctl_caret.Value := true
    g.ctl_capsDur.Value := 800
    g.ctl_copyDur.Value := 800
    g.ctl_pos1.Value := true
    g.ctl_mouseOffset.Value := 10
    g.ctl_topOffset.Value := 50
    g.ctl_bottomOffset.Value := 100
    g.ctl_fontSize.Value := 9
    g.ctl_bold.Value := true
    g.ctl_lightMode.Value := false
    g.ctl_invert.Value := false
}

Settings_CancelAndClose(ctrlOrGui, *) {
    global settingsGui
    ; 支持从按钮或关闭事件调用
    ; 按钮控件有 .Gui 属性，GUI 对象本身没有
    try {
        g := ctrlOrGui.Gui
    } catch {
        g := ctrlOrGui
    }
    g.Destroy()
    settingsGui := ""  ; 清除全局引用，允许 GC 回收
}

Settings_SaveAndClose(ctrl, *) {
    global enableCapsTip, enableCopyTip, enableCaretIndicator, capsShowDuration, copyShowDuration
    global tipPosition, tipMouseOffset, tipTopOffset, tipBottomOffset, tipFontSize, tipFontBold, tipLightMode, showIMEStatus, imeDetectInvert

    g := ctrl.Gui

    ; 保存功能开关
    enableCapsTip := g.ctl_caps.Value
    enableCopyTip := g.ctl_copy.Value
    enableCaretIndicator := g.ctl_caret.Value

    ; 保存开机启动
    SetStartup(g.ctl_startup.Value)

    ; 保存显示时长
    capsShowDuration := Max(100, Integer(g.ctl_capsDur.Value || 800))
    copyShowDuration := Max(100, Integer(g.ctl_copyDur.Value || 800))

    ; 保存提示位置
    if (g.ctl_pos1.Value)
        tipPosition := 1
    else if (g.ctl_pos2.Value)
        tipPosition := 2
    else if (g.ctl_pos3.Value)
        tipPosition := 3
    else if (g.ctl_pos4.Value)
        tipPosition := 4
    else
        tipPosition := 1

    ; 保存偏移
    tipMouseOffset := Max(0, Min(100, Integer(g.ctl_mouseOffset.Value || 10)))
    tipTopOffset := Max(0, Min(500, Integer(g.ctl_topOffset.Value || 50)))
    tipBottomOffset := Max(0, Min(500, Integer(g.ctl_bottomOffset.Value || 100)))

    ; 保存字体样式
    tipFontSize := Max(8, Min(72, Integer(g.ctl_fontSize.Value || 9)))
    tipFontBold := g.ctl_bold.Value
    tipLightMode := g.ctl_lightMode.Value
    showIMEStatus := g.ctl_ime.Value
    imeDetectInvert := g.ctl_invert.Value

    ; 应用设置
    SaveConfig()
    ApplySettings()

    ; 销毁窗口并释放引用
    g.Destroy()
    settingsGui := ""  ; 清除全局引用，允许 GC 回收

    ShowTip("设置已保存", 800)
}

; ============================================================
; 应用设置（重新注册监听）
; ============================================================
ApplySettings() {
    global enableCapsTip, enableCopyTip, enableCaretIndicator, tipGui, caretIndicatorInst

    ; 重新设置大小写监听
    SetTimer(CheckCapsLock, 0)  ; 先停止
    if (enableCapsTip) {
        SetTimer(CheckCapsLock, 30)
    }

    ; 应用光标指示器设置
    if (enableCaretIndicator) {
        if (!IsObject(caretIndicatorInst)) {
            caretIndicatorInst := CaretIndicator(merge(CaretIndicator.DefaultConfig, {
                markMargin: { x: 1, y: -1 }
            }))
            caretIndicatorInst.Run()
        }
    } else {
        if (IsObject(caretIndicatorInst)) {
            caretIndicatorInst.Stop()
            caretIndicatorInst := ""
        }
    }

    ; 销毁旧的提示窗口，让下次显示时重新创建（应用新字体设置）
    if (IsObject(tipGui)) {
        tipGui.Destroy()
        tipGui := ""
    }
}

; ============================================================
; 显示自定义提示（替代 ToolTip）
; ============================================================
ShowTip(text, duration := 0) {
    global tipGui, tipPosition, tipMouseOffset, tipTopOffset, tipBottomOffset, tipFontSize, tipFontBold, tipLightMode
    static tipText := ""
    static lastWidth := 0, lastHeight := 0

    ; 获取鼠标位置（使用屏幕坐标）
    CoordMode "Mouse", "Screen"
    MouseGetPos(&mx, &my)

    ; 如果 GUI 已存在且窗口有效，快速更新
    if (IsObject(tipGui) && WinExist("ahk_id " . tipGui.Hwnd)) {
        ; 直接更新文本（最快方式）
        tipText.Value := "  " . text . "  "

        ; 只在鼠标附近模式时更新位置
        if (tipPosition = 1) {
            tipGui.Show("x" . (mx + tipMouseOffset) . " y" . (my + tipMouseOffset) . " NA")
        }
    } else {
        ; 创建提示窗口
        tipGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20", "")
        ; 根据浅色/深色模式设置颜色
        if (tipLightMode) {
            tipGui.BackColor := "F5F5F5"
            textColor := "333333"
        } else {
            tipGui.BackColor := "333333"
            textColor := "FFFFFF"
        }
        tipGui.SetFont("s" . tipFontSize . (tipFontBold ? " Bold" : ""), "Microsoft YaHei")
        tipText := tipGui.Add("Text", "c" . textColor . " Center r1", "  " . text . "  ")

        ; 使用 DWM 设置圆角 (Windows 11)
        try {
            DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", tipGui.Hwnd, "Int", 33, "Int*", 2, "Int", 4)
        }

        ; 先隐藏显示以获取正确尺寸
        tipGui.Show("Hide AutoSize")
        tipGui.GetPos(,, &gw, &gh)
        lastWidth := gw
        lastHeight := gh

        ; 计算位置
        if (tipPosition = 1) {
            gx := mx + tipMouseOffset
            gy := my + tipMouseOffset
        } else if (tipPosition = 2) {
            gx := (A_ScreenWidth - gw) / 2
            gy := (A_ScreenHeight - gh) / 2
        } else if (tipPosition = 3) {
            gx := (A_ScreenWidth - gw) / 2
            gy := tipTopOffset
        } else {
            gx := (A_ScreenWidth - gw) / 2
            gy := A_ScreenHeight - gh - tipBottomOffset
        }

        tipGui.Show("x" . gx . " y" . gy . " NA")
    }

    ; 设置自动关闭（先取消旧定时器，防止累积）
    if (duration > 0) {
        SetTimer(HideTip, 0)
        SetTimer(HideTip, -duration)
    }
}

HideTip() {
    global tipGui
    if (IsObject(tipGui)) {
        tipGui.Hide()
    }
    SetTimer(HideTip, 0)
}

; ============================================================
; CapsLock 状态检查
; ============================================================
CheckCapsLock() {
    global lastCapsState, enableCapsTip
    if (!enableCapsTip)
        return

    current := GetKeyState("CapsLock", "T")
    if (current != lastCapsState) {
        lastCapsState := current
        ShowCapsStatus()
    }
}

; ============================================================
; 显示大小写+输入法状态
; ============================================================
ShowCapsStatus(forceRefreshIME := false, toggleMode := false) {
    global capsShowDuration, enableCapsTip, showIMEStatus
    static lastIMEState := "英"

    if (!enableCapsTip)
        return

    ; 获取大小写状态
    caps := GetKeyState("CapsLock", "T")
    capsIcon := caps ? "🔒 大写" : "🔓 小写"

    ; 根据开关决定是否显示中/英状态
    if (showIMEStatus) {
        ; 获取输入法状态
        if (toggleMode) {
            ; Shift 切换模式：反转上次状态
            lastIMEState := (lastIMEState = "中") ? "英" : "中"
            ime := lastIMEState
        } else {
            ime := GetIMEStatus(forceRefreshIME)
            lastIMEState := ime
        }
        ; 合并显示
        tip := capsIcon . " | " . ime
    } else {
        ; 只显示大小写
        tip := capsIcon
    }

    ShowTip(tip, capsShowDuration)
}

; ============================================================
; 获取输入法中/英状态
; ============================================================
GetIMEStatus(forceRefresh := false) {
    static lastResult := "英"
    static lastCheckTime := 0

    ; 防抖：150ms 内直接返回上次结果
    if (!forceRefresh && A_TickCount - lastCheckTime < 150)
        return lastResult

    currentResult := ""

    try {
        currentResult := DetectIMEViaKeyboardLayout()
        if (currentResult = "") {
            currentResult := DetectIMEViaIMM32()
        }
    } catch {
    }

    if (currentResult != "")
        lastResult := currentResult

    lastCheckTime := A_TickCount
    return lastResult
}

; ============================================================
; 通过键盘布局检测输入法状态
; ============================================================
DetectIMEViaKeyboardLayout() {
    try {
        hWnd := WinExist("A")
        if (!hWnd)
            return ""

        threadID := DllCall("GetWindowThreadProcessId", "Ptr", hWnd, "Ptr", 0, "UInt")
        if (!threadID)
            return ""

        hkl := DllCall("GetKeyboardLayout", "UInt", threadID, "UPtr")
        langID := hkl & 0xFFFF
        if (langID != 0x0804)
            return "英"

        hIMC := DllCall("imm32\ImmGetContext", "Ptr", hWnd, "UPtr")
        if (hIMC) {
            convMode := 0
            DllCall("imm32\ImmGetConversionStatus", "Ptr", hIMC, "UInt*", &convMode, "UInt*", 0)

            if (convMode & 0x0001)
                result := "中"
            else
                result := "英"

            DllCall("imm32\ImmReleaseContext", "Ptr", hWnd, "UPtr", hIMC)
            return result
        }
    } catch {
    }
    return ""
}

; ============================================================
; 通过 IMM32 窗口消息检测输入法状态
; ============================================================
DetectIMEViaIMM32() {
    global imeDetectInvert
    savedDetectHiddenWindows := A_DetectHiddenWindows

    try {
        hWnd := WinExist("A")
        if (!hWnd)
            return ""

        DetectHiddenWindows(true)
        hIMEWnd := DllCall("imm32\ImmGetDefaultIMEWnd", "UInt", hWnd, "UInt")

        if (hIMEWnd) {
            result := SendMessage(0x283, 0x001, 0, , "ahk_id " . hIMEWnd)
            DetectHiddenWindows(savedDetectHiddenWindows)
            ; 根据设置决定是否反转检测逻辑
            if (imeDetectInvert)
                return (result = 0) ? "英" : "中"
            else
                return (result = 0) ? "中" : "英"
        }

        DetectHiddenWindows(savedDetectHiddenWindows)
    } catch {
        DetectHiddenWindows(savedDetectHiddenWindows)
    }
    return ""
}

; ============================================================
; 剪贴板变化回调函数
; ============================================================
ClipChanged(dataType) {
    global copyShowDuration, enableCopyTip
    global lastClipboardContent, lastClipboardTime
    if (!enableCopyTip)
        return

    ; 防抖
    if (A_TickCount - lastClipboardTime < 100)
        return

    currentContent := A_Clipboard
    if (currentContent = lastClipboardContent)
        return

    lastClipboardContent := currentContent
    lastClipboardTime := A_TickCount

    isFile := DllCall("IsClipboardFormatAvailable", "UInt", 15)
    isImage := DllCall("IsClipboardFormatAvailable", "UInt", 2)
          || DllCall("IsClipboardFormatAvailable", "UInt", 8)
          || DllCall("IsClipboardFormatAvailable", "UInt", 17)

    if (isFile) {
        files := StrSplit(A_Clipboard, "`n", "`r")
        count := files.Length
        ShowTip("已复制：" . count . " 个文件", copyShowDuration)
    }
    else if (isImage) {
        ShowTip("已复制：图片", copyShowDuration)
    }
    else if (dataType = 1 || dataType = 2) {
        text := A_Clipboard
        length := StrLen(text)
        if (length > 0) {
            ShowTip("已复制：" . length . " 字符", copyShowDuration)
        }
    }
}
