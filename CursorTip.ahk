; ============================================================
; CursorTip v2.0.2 (AutoHotkey v2)
; 功能：大小写提示 + 复制提示
; - 大小写/输入法：🔒 大写 | 中 / 🔓 小写 | 英
; - 复制提示：显示复制的字符数/图片/文件数
; - 右键托盘图标可打开设置
; ============================================================

#SingleInstance Force
Persistent

; ============================================================
; 版本
; ============================================================
global VERSION := "2.0.4"

; ============================================================
; 配置管理类 — 统一管理所有配置项
; ============================================================
class Config {
    static Path := A_ScriptDir . "\config.ini"

    ; 默认值（唯一维护处）
    static Defaults := {
        enableCapsTip: true,
        enableCopyTip: true,
        showIMEStatus: true,
        capsShowDuration: 800,
        copyShowDuration: 800,
        tipPosition: 1,          ; 1=跟随鼠标 2=屏幕中央 3=屏幕顶部 4=屏幕底部
        tipMouseOffset: 20,
        tipTopOffset: 50,
        tipBottomOffset: 100,
        tipFontSize: 9,
        tipFontBold: true,
        tipLightMode: false
    }

    ; 每个配置项声明为独立的静态属性（带默认值）
    static enableCapsTip := true
    static enableCopyTip := true
    static showIMEStatus := true
    static capsShowDuration := 800
    static copyShowDuration := 800
    static tipPosition := 1
    static tipMouseOffset := 20
    static tipTopOffset := 50
    static tipBottomOffset := 100
    static tipFontSize := 9
    static tipFontBold := true
    static tipLightMode := false

    ; 加载配置
    static Load() {
        if !FileExist(Config.Path)
            return

        try {
            c := Config
            c.enableCapsTip := IniRead(Config.Path, "Settings", "EnableCapsTip", 1) = 1
            c.enableCopyTip := IniRead(Config.Path, "Settings", "EnableCopyTip", 1) = 1
            c.showIMEStatus := IniRead(Config.Path, "Settings", "ShowIMEStatus", 1) = 1

            c.capsShowDuration := Integer(IniRead(Config.Path, "Settings", "CapsShowDuration", 800))
            c.copyShowDuration := Integer(IniRead(Config.Path, "Settings", "CopyShowDuration", 800))

            c.tipPosition := Integer(IniRead(Config.Path, "Settings", "TipPosition", 1))
            c.tipMouseOffset := Integer(IniRead(Config.Path, "Settings", "TipMouseOffset", 20))
            c.tipTopOffset := Integer(IniRead(Config.Path, "Settings", "TipTopOffset", 50))
            c.tipBottomOffset := Integer(IniRead(Config.Path, "Settings", "TipBottomOffset", 100))

            c.tipFontSize := Integer(IniRead(Config.Path, "Settings", "TipFontSize", 9))
            c.tipFontBold := IniRead(Config.Path, "Settings", "TipFontBold", 1) = 1
            c.tipLightMode := IniRead(Config.Path, "Settings", "TipLightMode", 0) = 1
        } catch {
            ; 读取失败，使用默认值
        }
    }

    ; 保存配置
    static Save() {
        try {
            c := Config
            IniWrite(c.enableCapsTip ? 1 : 0, Config.Path, "Settings", "EnableCapsTip")
            IniWrite(c.enableCopyTip ? 1 : 0, Config.Path, "Settings", "EnableCopyTip")
            IniWrite(c.showIMEStatus ? 1 : 0, Config.Path, "Settings", "ShowIMEStatus")

            IniWrite(c.capsShowDuration, Config.Path, "Settings", "CapsShowDuration")
            IniWrite(c.copyShowDuration, Config.Path, "Settings", "CopyShowDuration")

            IniWrite(c.tipPosition, Config.Path, "Settings", "TipPosition")
            IniWrite(c.tipMouseOffset, Config.Path, "Settings", "TipMouseOffset")
            IniWrite(c.tipTopOffset, Config.Path, "Settings", "TipTopOffset")
            IniWrite(c.tipBottomOffset, Config.Path, "Settings", "TipBottomOffset")

            IniWrite(c.tipFontSize, Config.Path, "Settings", "TipFontSize")
            IniWrite(c.tipFontBold ? 1 : 0, Config.Path, "Settings", "TipFontBold")
            IniWrite(c.tipLightMode ? 1 : 0, Config.Path, "Settings", "TipLightMode")
        } catch as e {
            MsgBox("保存配置失败：" . e.Message, "错误", 16)
        }
    }

    ; 恢复默认值
    static Reset() {
        for k, v in Config.Defaults.OwnProps()
            Config.%k% := v
    }
}

; ============================================================
; 全局状态
; ============================================================
global lastCapsState := GetKeyState("CapsLock", "T")
global lastCapsChangeTime := 0
global lastClipboardFingerprint := ""
global lastClipboardTime := 0
global clipboardProcessing := false
global shiftAlone := false
global tipGui := ""
global tipGuiText := ""
global settingsGui := ""
global trackedIMEState := ""  ; IME 模式追踪，启动时通过 API 初始化

; ============================================================
; 托盘菜单
; ============================================================
A_TrayTip := "CursorTip v" . VERSION

A_TrayMenu.Delete()
A_TrayMenu.Add("⚙ 设置", ShowSettings)
A_TrayMenu.Add()
A_TrayMenu.Add("🔄 重启", (*) => Reload())
A_TrayMenu.Add("❌ 退出", (*) => ExitApp())

; 单击托盘图标打开设置
OnMessage(0x404, TrayClickHandler)

TrayClickHandler(wParam, lParam, msg, hwnd) {
    if (lParam = 0x201 || lParam = 0x203) {  ; 左键单击或双击
        ShowSettings()
        return 0
    }
    ; 右键等其他消息不拦截，交给 AHK 默认处理（弹出菜单）
}

OnExit(OnScriptExit)

; ============================================================
; 启动
; ============================================================
Config.Load()
InitTrackedIMEState()
InitMonitors()

return ; 自动执行段结束

; ============================================================
; 退出清理
; ============================================================
OnScriptExit(exitReason, exitCode) {
    global tipGui, settingsGui
    SetTimer(CheckCapsLock, 0)
    SetTimer(HideTip, 0)

    if (IsObject(tipGui)) {
        tipGui.Destroy()
        tipGui := ""
    }
    if (IsObject(settingsGui)) {
        settingsGui.Destroy()
        settingsGui := ""
    }
}

; 初始化 IME 追踪状态（启动时通过 API 检测一次真实值）
InitTrackedIMEState() {
    global trackedIMEState
    try {
        hWnd := WinExist("A")
        if (hWnd) {
            hIMC := DllCall("imm32\ImmGetContext", "Ptr", hWnd, "UPtr")
            if (hIMC) {
                DllCall("imm32\ImmGetConversionStatus", "Ptr", hIMC, "UInt*", &fdwConversion := 0, "UInt*", &fdwSentence := 0, "Int")
                DllCall("imm32\ImmReleaseContext", "Ptr", hWnd, "UPtr", hIMC)
                trackedIMEState := (fdwConversion & 1) ? "中" : "英"
            }
        }
    }
    if (trackedIMEState = "")
        trackedIMEState := "中"
}

; ============================================================
; 注册/取消监听
; ============================================================
InitMonitors() {
    c := Config

    ; 大小写监听
    if (c.enableCapsTip)
        SetTimer(CheckCapsLock, 50)

    ; 复制监听
    if (c.enableCopyTip)
        OnClipboardChange(ClipChanged)
}

ApplySettings() {
    global tipGui, tipGuiText
    c := Config

    ; 大小写监听
    SetTimer(CheckCapsLock, 0)
    if (c.enableCapsTip)
        SetTimer(CheckCapsLock, 50)

    ; 复制监听
    OnClipboardChange(ClipChanged, 0)
    if (c.enableCopyTip)
        OnClipboardChange(ClipChanged)

    ; 销毁提示窗口以应用新外观
    if (IsObject(tipGui)) {
        tipGui.Destroy()
        tipGui := ""
        tipGuiText := ""
    }
}

; ============================================================
; 开机启动管理
; ============================================================
IsStartupEnabled() {
    exePath := A_IsCompiled ? A_ScriptFullPath : A_ScriptDir . "\CursorTip.exe"
    try {
        regValue := RegRead("HKCU\Software\Microsoft\Windows\CurrentVersion\Run", "CursorTip", "")
        return InStr(regValue, exePath) > 0
    } catch {
        return false
    }
}

SetStartup(enable) {
    exePath := A_IsCompiled ? A_ScriptFullPath : A_ScriptDir . "\CursorTip.exe"
    if (enable) {
        try {
            RegWrite(exePath, "REG_SZ", "HKCU\Software\Microsoft\Windows\CurrentVersion\Run", "CursorTip")
        } catch as e {
            MsgBox("设置开机启动失败：" . e.Message, "错误", 16)
        }
    } else {
        try {
            RegDelete("HKCU\Software\Microsoft\Windows\CurrentVersion\Run", "CursorTip")
        } catch {
        }
    }
}

; ============================================================
; 提示窗口管理
; ============================================================
ShowTip(text, duration := 0) {
    global tipGui, tipGuiText
    c := Config

    ; 快速路径：GUI 已存在且有效，直接更新文本
    if (IsObject(tipGui) && WinExist("ahk_id " . tipGui.Hwnd) && IsObject(tipGuiText)) {
        tipGuiText.Value := text

        ; 重新计算位置（文本长度变化时窗口需要自适应）
        SendMessage(0xB, 0, 0, , "ahk_id " . tipGui.Hwnd)  ; 禁用重绘
        tipGui.Show("Hide AutoSize")
        tipGui.GetPos(,, &gw, &gh)

        switch c.tipPosition {
            case 1:
                CoordMode "Mouse", "Screen"
                MouseGetPos(&mx, &my)
                tipGui.Show("x" . (mx + c.tipMouseOffset) . " y" . (my + c.tipMouseOffset) . " NA")
            case 2:
                tipGui.Show("x" . (A_ScreenWidth - gw) / 2 . " y" . (A_ScreenHeight - gh) / 2 . " NA")
            case 3:
                tipGui.Show("x" . (A_ScreenWidth - gw) / 2 . " y" . c.tipTopOffset . " NA")
            case 4:
                tipGui.Show("x" . (A_ScreenWidth - gw) / 2 . " y" . (A_ScreenHeight - gh - c.tipBottomOffset) . " NA")
        }
        SendMessage(0xB, 1, 0, , "ahk_id " . tipGui.Hwnd)  ; 启用重绘
    } else {
        ; 销毁旧窗口
        if (IsObject(tipGui)) {
            try tipGui.Destroy()
            tipGui := ""
            tipGuiText := ""
        }

        ; 创建新窗口
        tipGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20", "")
        if (c.tipLightMode) {
            tipGui.BackColor := "F5F5F5"
            textColor := "333333"
        } else {
            tipGui.BackColor := "333333"
            textColor := "FFFFFF"
        }
        tipGui.SetFont("s" . c.tipFontSize . (c.tipFontBold ? " Bold" : ""), "Microsoft YaHei")
        tipGuiText := tipGui.Add("Text", "c" . textColor . " Center r1", text)

        ; Windows 11 圆角
        try {
            DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", tipGui.Hwnd, "Int", 33, "Int*", 2, "Int", 4)
        }

        ; 获取尺寸并计算位置
        tipGui.Show("Hide AutoSize")
        tipGui.GetPos(,, &gw, &gh)
        gx := 0, gy := 0

        switch c.tipPosition {
            case 1:
                CoordMode "Mouse", "Screen"
                MouseGetPos(&mx, &my)
                gx := mx + c.tipMouseOffset
                gy := my + c.tipMouseOffset
            case 2:
                gx := (A_ScreenWidth - gw) / 2
                gy := (A_ScreenHeight - gh) / 2
            case 3:
                gx := (A_ScreenWidth - gw) / 2
                gy := c.tipTopOffset
            case 4:
                gx := (A_ScreenWidth - gw) / 2
                gy := A_ScreenHeight - gh - c.tipBottomOffset
        }

        tipGui.Show("x" . gx . " y" . gy . " NA")
    }

    ; 自动关闭
    if (duration > 0) {
        SetTimer(HideTip, 0)
        SetTimer(HideTip, -duration)
    }
}

HideTip() {
    global tipGui
    if (IsObject(tipGui))
        tipGui.Hide()
    SetTimer(HideTip, 0)
}

; ============================================================
; 输入法检测
; 检测链路：ImmGetConversionStatus → ImmGetDefaultIMEWnd+SendMessage → 模式追踪
; UWP 应用 (ApplicationFrameWindow) 因跨进程限制，前两种 API 均不可用
; 第三层通过监听 Shift 键追踪 IME 中/英切换来推断状态
; ============================================================
GetIMEStatus(forceRefresh := false) {
    global trackedIMEState
    static lastResult := "英"
    static lastCheckTime := 0
    static lastWindowHash := 0

    ; 防抖：150ms 内且同一窗口直接返回上次结果
    if (!forceRefresh) {
        if (A_TickCount - lastCheckTime < 150)
            return lastResult
        hWnd := WinExist("A")
        if (hWnd && hWnd = lastWindowHash)
            return lastResult
    }

    result := ""

    try {
        hWnd := GetTargetHWND()
        if (!hWnd)
            throw Error()

        ; 只用 ImmGetConversionStatus（在目标窗口同线程中调用才可靠）
        result := DetectIMEViaConversionStatus(hWnd)
    } catch {
    }

    if (result != "") {
        lastResult := result
        lastWindowHash := WinExist("A")
    } else {
        ; API 不可用时，使用 Shift 追踪的状态
        result := trackedIMEState
        lastResult := result
        lastWindowHash := WinExist("A")
    }

    lastCheckTime := A_TickCount
    return lastResult
}

; 获取目标窗口 HWND（处理 UWP 等特殊窗口）
GetTargetHWND() {
    hWnd := WinExist("A")
    if (!hWnd)
        return 0

    ; UWP 应用需要获取焦点控件
    if (WinActive("ahk_class ApplicationFrameWindow")) {
        try {
            focused := ControlGetFocus("A")
            if (focused) {
                ctrlHwnd := ControlGetHwnd(focused, "A")
                if (ctrlHwnd)
                    return ctrlHwnd
            }
        } catch {
        }
    }
    return hWnd
}

; 通过 ImmGetConversionStatus 检测（标准 API，兼容所有输入法）
DetectIMEViaConversionStatus(hWnd) {
    hIMC := DllCall("imm32\ImmGetContext", "Ptr", hWnd, "UPtr")
    if (!hIMC)
        return ""

    try {
        ; ImmGetConversionStatus 返回转换模式
        ; fdwConversion & 0x0001 = 1 → 中文输入模式, 0 → 英文模式
        DllCall("imm32\ImmGetConversionStatus", "Ptr", hIMC, "UInt*", &fdwConversion := 0, "UInt*", &fdwSentence := 0, "Int")
        DllCall("imm32\ImmReleaseContext", "Ptr", hWnd, "UPtr", hIMC)
        return (fdwConversion & 0x0001) ? "中" : "英"
    } catch {
        DllCall("imm32\ImmReleaseContext", "Ptr", hWnd, "UPtr", hIMC)
        return ""
    }
}

; ============================================================
; 大小写监听
; ============================================================
CheckCapsLock() {
    global lastCapsState, lastCapsChangeTime
    if (!Config.enableCapsTip)
        return

    current := GetKeyState("CapsLock", "T")
    if (current != lastCapsState) {
        lastCapsState := current
        lastCapsChangeTime := A_TickCount
        ShowCapsStatus()
    }
}

ShowCapsStatus(forceRefreshIME := false) {
    if (!Config.enableCapsTip)
        return

    caps := GetKeyState("CapsLock", "T")
    capsIcon := caps ? "🔒 大写" : "🔓 小写"

    if (Config.showIMEStatus) {
        ime := GetIMEStatus(forceRefreshIME)
        if (ime = "")
            ime := "中"  ; 检测失败时默认中文
        tip := capsIcon . " | " . ime
    } else {
        tip := capsIcon
    }

    ShowTip(tip, Config.capsShowDuration)
}

; Shift 独立按下检测：只有单独按下并释放 Shift 才触发
~*LShift::
~*RShift:: {
    global shiftAlone := true
}

~*LShift up::
~*RShift up:: {
    global lastCapsChangeTime, shiftAlone, trackedIMEState
    if (!Config.enableCapsTip)
        return

    ; 如果 Shift 不是独立按下（有其他键同时被按），不触发
    if (!shiftAlone)
        return

    ; 释放时仍有其他修饰键按住 → 组合键，不触发
    if (GetKeyState("Ctrl", "P") || GetKeyState("Alt", "P") || GetKeyState("LWin", "P") || GetKeyState("RWin", "P"))
        return

    ; 释放时仍有鼠标键按住 → 组合键，不触发
    if (GetKeyState("LButton", "P") || GetKeyState("RButton", "P") || GetKeyState("MButton", "P"))
        return

    ; 防抖
    if (A_TickCount - lastCapsChangeTime < 80)
        return

    Sleep(30)

    ; 所有应用统一使用 Shift 追踪方案
    ; 因为 ImmGetContext 在 AHK 线程中返回 0，IMC_GETCONVERSIONMODE 不反映中英切换
    trackedIMEState := (trackedIMEState = "中") ? "英" : "中"

    ShowCapsStatus(true)

    ShowCapsStatus(true)
}

; 任意其他键按下 → 标记 Shift 不是独立按下
~*a::
~*b::
~*c::
~*d::
~*e::
~*f::
~*g::
~*h::
~*i::
~*j::
~*k::
~*l::
~*m::
~*n::
~*o::
~*p::
~*q::
~*r::
~*s::
~*t::
~*u::
~*v::
~*w::
~*x::
~*y::
~*z::
~*0::
~*1::
~*2::
~*3::
~*4::
~*5::
~*6::
~*7::
~*8::
~*9::
~*Space::
~*Enter::
~*Tab::
~*Backspace::
~*Esc::
~*F1::
~*F2::
~*F3::
~*F4::
~*F5::
~*F6::
~*F7::
~*F8::
~*F9::
~*F10::
~*F11::
~*F12::
~*Up::
~*Down::
~*Left::
~*Right::
~*Home::
~*End::
~*PgUp::
~*PgDn::
~*Insert::
~*Delete::
~*PrintScreen::
~*ScrollLock::
~*Pause::
~*Numpad0::
~*Numpad1::
~*Numpad2::
~*Numpad3::
~*Numpad4::
~*Numpad5::
~*Numpad6::
~*Numpad7::
~*Numpad8::
~*Numpad9::
~*NumpadMult::
~*NumpadAdd::
~*NumpadSub::
~*NumpadDiv::
~*NumpadEnter::
~*NumpadDot::
~*`::
~*-::
~*=::
~*[::
~*]::
~*\::
~*;::
~*'::
~*,::
~*.::
~*/::
~*LButton up::
~*RButton up::
~*MButton up:: {
    global shiftAlone := false
}

; ============================================================
; 剪贴板监听
; ============================================================
ClipChanged(dataType) {
    global clipboardProcessing, lastClipboardFingerprint, lastClipboardTime
    if (!Config.enableCopyTip || clipboardProcessing)
        return

    clipboardProcessing := true

    try {
        if (A_TickCount - lastClipboardTime < 100) {
            clipboardProcessing := false
            return
        }

        ; 用长度+前缀摘要去重，避免保留剪贴板全文导致内存占用
        fingerprint := StrLen(A_Clipboard) . "|" . SubStr(A_Clipboard, 1, 200)
        if (fingerprint = lastClipboardFingerprint) {
            clipboardProcessing := false
            return
        }

        lastClipboardFingerprint := fingerprint
        lastClipboardTime := A_TickCount

        isFile := DllCall("IsClipboardFormatAvailable", "UInt", 15)
        isImage := DllCall("IsClipboardFormatAvailable", "UInt", 2)
              || DllCall("IsClipboardFormatAvailable", "UInt", 8)
              || DllCall("IsClipboardFormatAvailable", "UInt", 17)

        if (isFile) {
            files := StrSplit(A_Clipboard, "`n", "`r")
            count := files.Length
            if (count > 0 && files[1] != "")
                ShowTip("已复制：" . count . " 个文件", Config.copyShowDuration)
        } else if (isImage) {
            ShowTip("已复制：图片", Config.copyShowDuration)
        } else if (dataType = 1 || dataType = 2) {
            length := StrLen(A_Clipboard)
            if (length > 0)
                ShowTip("已复制：" . length . " 字符", Config.copyShowDuration)
        }
    } finally {
        clipboardProcessing := false
    }
}

; ============================================================
; 设置窗口
; ============================================================
ShowSettings(*) {
    global settingsGui
    ; 防止多开
    if (IsObject(settingsGui)) {
        try {
            if (WinExist("ahk_id " . settingsGui.Hwnd)) {
                WinActivate("ahk_id " . settingsGui.Hwnd)
                return
            }
        } catch {
            settingsGui := ""
        }
    }

    c := Config
    g := Gui("+Owner", "CursorTip v" . VERSION)
    g.SetFont("s10", "Microsoft YaHei")

    ; === 功能开关 ===
    g.SetFont("Bold")
    g.Add("Text", "x20 y10", "功能开关")
    g.SetFont("Norm")

    g.ctl_startup := g.Add("CheckBox", "x20 y32 w120", "🚀 开机启动")
    g.ctl_startup.Value := IsStartupEnabled()

    g.ctl_caps := g.Add("CheckBox", "x20 y57 w130", "🔠 大小写提示")
    g.ctl_caps.Value := c.enableCapsTip
    g.ctl_ime := g.Add("CheckBox", "x200 y57 w140", "🌐 显示中/英状态")
    g.ctl_ime.Value := c.showIMEStatus
    g.ctl_ime.Enabled := c.enableCapsTip

    g.ctl_copy := g.Add("CheckBox", "x20 y82 w130", "📋 复制提示")
    g.ctl_copy.Value := c.enableCopyTip

    g.ctl_caps.OnEvent("Click", (ctrl, *) => ctrl.Gui.ctl_ime.Enabled := ctrl.Value)

    ; 分割线
    g.Add("Text", "x10 y110 w320 h1 BackgroundDDDDDD")

    ; === 显示时长 ===
    g.SetFont("Bold")
    g.Add("Text", "x20 y122", "显示时长")
    g.SetFont("Norm")

    g.Add("Text", "x20 y147 w110", "大小写提示:")
    g.ctl_capsDur := g.Add("Edit", "x200 y144 w60 h22 Number", c.capsShowDuration)
    g.Add("Text", "x265 y147", "ms")
    g.Add("Text", "x20 y177 w110", "复制提示:")
    g.ctl_copyDur := g.Add("Edit", "x200 y174 w60 h22 Number", c.copyShowDuration)
    g.Add("Text", "x265 y177", "ms")

    g.Add("Text", "x10 y202 w320 h1 BackgroundDDDDDD")

    ; === 提示位置 ===
    g.SetFont("Bold")
    g.Add("Text", "x20 y214", "提示位置")
    g.SetFont("Norm")

    g.ctl_pos1 := g.Add("Radio", "x20 y239 w100 +Group" . (c.tipPosition = 1 ? " Checked" : ""), "跟随鼠标")
    g.ctl_pos2 := g.Add("Radio", "x20 y266 w280" . (c.tipPosition = 2 ? " Checked" : ""), "屏幕中央")
    g.ctl_pos3 := g.Add("Radio", "x20 y293 w100" . (c.tipPosition = 3 ? " Checked" : ""), "屏幕顶部")
    g.ctl_pos4 := g.Add("Radio", "x20 y320 w100" . (c.tipPosition = 4 ? " Checked" : ""), "屏幕底部")
    ; 偏移量输入框放在所有 Radio 之后，避免打断分组
    g.Add("Text", "x200 y242", "偏移:")
    g.ctl_mouseOffset := g.Add("Edit", "x240 y239 w40 h22 Number", c.tipMouseOffset)
    g.Add("Text", "x283 y242", "px")
    g.Add("Text", "x200 y296", "偏移:")
    g.ctl_topOffset := g.Add("Edit", "x240 y293 w40 h22 Number", c.tipTopOffset)
    g.Add("Text", "x283 y296", "px")
    g.Add("Text", "x200 y323", "偏移:")
    g.ctl_bottomOffset := g.Add("Edit", "x240 y320 w40 h22 Number", c.tipBottomOffset)
    g.Add("Text", "x283 y323", "px")

    g.Add("Text", "x10 y350 w320 h1 BackgroundDDDDDD")

    ; === 外观样式 ===
    g.SetFont("Bold")
    g.Add("Text", "x20 y362", "外观样式（默认深色）")
    g.SetFont("Norm")

    g.ctl_lightMode := g.Add("CheckBox", "x20 y387 w80", "浅色模式")
    g.ctl_lightMode.Value := c.tipLightMode
    g.Add("Text", "x20 y417 w40", "字号:")
    g.ctl_fontSize := g.Add("Edit", "x60 y414 w40 h22 Number", c.tipFontSize)
    g.ctl_bold := g.Add("CheckBox", "x200 y417 w60", "加粗")
    g.ctl_bold.Value := c.tipFontBold

    g.Add("Text", "x10 y445 w320 h1 BackgroundDDDDDD")

    ; === 按钮 ===
    g.Add("Button", "x20 y460 w80", "恢复默认").OnEvent("Click", SettingsReset)
    g.Add("Button", "x130 y460 w80 Default", "保存").OnEvent("Click", SettingsSave)
    g.Add("Button", "x240 y460 w80", "取消").OnEvent("Click", SettingsClose)
    g.OnEvent("Close", SettingsClose)

    ; 底部信息
    icoPath := A_Temp . "\CursorTip_github.ico"
    FileInstall("assets\github.ico", icoPath, 1)
    pic := g.Add("Picture", "x20 y500 w16 h16", icoPath)
    pic.OnEvent("Click", (*) => Run("https://github.com/zeno528/CapsCopyTip"))
    g.SetFont("s8", "Microsoft YaHei")
    g.Add("Link", "x40 y502", '<a href="https://github.com/zeno528/CapsCopyTip">GitHub</a>')  ; 仓库名暂不改
    g.Add("Text", "x200 y502", "© 2026  MIT License")

    g.Show("w340 h530")
    settingsGui := g
}

SettingsClose(ctrlOrGui, *) {
    global settingsGui
    ; Close 事件传入 Gui 对象，按钮点击传入 GuiControl（有 .Gui 属性）
    g := ctrlOrGui.HasProp("Gui") ? ctrlOrGui.Gui : ctrlOrGui
    g.Destroy()
    settingsGui := ""
}

SettingsReset(ctrl, *) {
    d := Config.Defaults
    g := ctrl.Gui

    g.ctl_startup.Value := false
    g.ctl_caps.Value := d.enableCapsTip
    g.ctl_ime.Value := d.showIMEStatus
    g.ctl_ime.Enabled := d.enableCapsTip
    g.ctl_copy.Value := d.enableCopyTip

    g.ctl_capsDur.Value := d.capsShowDuration
    g.ctl_copyDur.Value := d.copyShowDuration

    g.ctl_pos1.Value := (d.tipPosition = 1)
    g.ctl_pos2.Value := (d.tipPosition = 2)
    g.ctl_pos3.Value := (d.tipPosition = 3)
    g.ctl_pos4.Value := (d.tipPosition = 4)
    g.ctl_mouseOffset.Value := d.tipMouseOffset
    g.ctl_topOffset.Value := d.tipTopOffset
    g.ctl_bottomOffset.Value := d.tipBottomOffset

    g.ctl_fontSize.Value := d.tipFontSize
    g.ctl_bold.Value := d.tipFontBold
    g.ctl_lightMode.Value := d.tipLightMode
}

SettingsSave(ctrl, *) {
    global settingsGui
    g := ctrl.Gui
    c := Config

    ; 读取 GUI 值
    c.enableCapsTip := g.ctl_caps.Value
    c.enableCopyTip := g.ctl_copy.Value
    c.showIMEStatus := g.ctl_ime.Value

    SetStartup(g.ctl_startup.Value)

    c.capsShowDuration := Max(100, Integer(g.ctl_capsDur.Value || 800))
    c.copyShowDuration := Max(100, Integer(g.ctl_copyDur.Value || 800))

    if (g.ctl_pos1.Value)
        c.tipPosition := 1
    else if (g.ctl_pos2.Value)
        c.tipPosition := 2
    else if (g.ctl_pos3.Value)
        c.tipPosition := 3
    else if (g.ctl_pos4.Value)
        c.tipPosition := 4
    else
        c.tipPosition := 1

    c.tipMouseOffset := Max(0, Min(100, Integer(g.ctl_mouseOffset.Value || 20)))
    c.tipTopOffset := Max(0, Min(500, Integer(g.ctl_topOffset.Value || 50)))
    c.tipBottomOffset := Max(0, Min(500, Integer(g.ctl_bottomOffset.Value || 100)))

    c.tipFontSize := Max(8, Min(72, Integer(g.ctl_fontSize.Value || 9)))
    c.tipFontBold := g.ctl_bold.Value
    c.tipLightMode := g.ctl_lightMode.Value

    Config.Save()
    ApplySettings()

    g.Destroy()
    settingsGui := ""

    ShowTip("设置已保存", 800)
}
