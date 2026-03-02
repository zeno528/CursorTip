; ============================================================
; CapsCopyTip v1.2.0 (AutoHotkey v2)
; 功能：合并大小写提示 + 复制提示 + 光标语言标记
; - 大小写/输入法：🔒 大写 | 中 / 🔓 小写 | 英
; - 复制提示：显示复制的字符数/图片/文件数
; - 光标标记：在文本光标旁显示语言状态（调用 language-indicator）
; - 右键托盘图标可打开设置
; ============================================================

#SingleInstance Force
Persistent

; ============================================================
; 全局设置
; ============================================================
global VERSION := "1.2.0"
global capsShowDuration := 800    ; 大小写提示显示时间
global copyShowDuration := 800    ; 复制提示显示时间
global lastCapsState := GetKeyState("CapsLock", "T")
global configPath := A_ScriptDir . "\config.ini"

; 新增设置
global enableCapsTip := true      ; 启用大小写提示
global enableCopyTip := true      ; 启用复制提示
global tipPosition := 1           ; 提示位置: 1=鼠标附近, 2=屏幕中央, 3=屏幕顶部, 4=屏幕底部
global tipMouseOffset := 2        ; 鼠标附近时的偏移距离(像素)
global tipTopOffset := 10         ; 屏幕顶部偏移距离(像素)
global tipBottomOffset := 150     ; 屏幕底部偏移距离(像素)
global tipFontSize := 9           ; 字体大小
global tipFontBold := true        ; 字体加粗

; 提示 GUI
global tipGui := ""

A_TrayTip := "CapsCopyTip v" . VERSION . " - 大小写+输入法+复制提示"

; ============================================================
; 托盘菜单设置
; ============================================================
A_TrayMenu.Delete()
A_TrayMenu.Add("⚙ 设置", ShowSettings)
A_TrayMenu.Add()
A_TrayMenu.Add("🔄 重启", (*) => Reload())
A_TrayMenu.Add("❌ 退出", (*) => ExitApp())

; ============================================================
; 启动时加载配置
; ============================================================
LoadConfig()

; ============================================================
; 启动光标标记 (运行 language-indicator.exe)
; ============================================================
Run("`"" . A_ScriptDir . "\language-indicator\language-indicator.exe`"")

; ============================================================
; 大小写监听
; ============================================================
if (enableCapsTip) {
    SetTimer(CheckCapsLock, 30)
}

~Shift:: {
    if (enableCapsTip) {
        KeyWait("Shift")
        ShowCapsStatus()
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
        tipPosition := Integer(IniRead(configPath, "Settings", "TipPosition", 1))
        tipMouseOffset := IniRead(configPath, "Settings", "TipMouseOffset", 2)
        tipTopOffset := IniRead(configPath, "Settings", "TipTopOffset", 10)
        tipBottomOffset := IniRead(configPath, "Settings", "TipBottomOffset", 150)
        tipFontSize := IniRead(configPath, "Settings", "TipFontSize", 9)
        tipFontBold := IniRead(configPath, "Settings", "TipFontBold", 1) = 1
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
        IniWrite(tipPosition, configPath, "Settings", "TipPosition")
        IniWrite(tipMouseOffset, configPath, "Settings", "TipMouseOffset")
        IniWrite(tipTopOffset, configPath, "Settings", "TipTopOffset")
        IniWrite(tipBottomOffset, configPath, "Settings", "TipBottomOffset")
        IniWrite(tipFontSize, configPath, "Settings", "TipFontSize")
        IniWrite(tipFontBold ? 1 : 0, configPath, "Settings", "TipFontBold")
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
; 设置窗口
; ============================================================
ShowSettings(*) {
    global

    settingsGui := Gui("+Owner", "CapsCopyTip v" . VERSION)
    settingsGui.SetFont("s10", "Microsoft YaHei")

    ; === 功能开关 ===
    settingsGui.Add("GroupBox", "x10 y10 w300 h70", "功能开关")
    capsCheck := settingsGui.Add("CheckBox", "x20 y30 w140", "大小写提示")
    capsCheck.Value := enableCapsTip
    copyCheck := settingsGui.Add("CheckBox", "x170 y30 w140", "复制提示")
    copyCheck.Value := enableCopyTip
    startupCheck := settingsGui.Add("CheckBox", "x20 y50 w200", "开机启动")
    startupCheck.Value := IsStartupEnabled()

    ; === 显示时长 ===
    settingsGui.Add("GroupBox", "x10 y85 w300 h70", "显示时长")
    settingsGui.Add("Text", "x20 y105 w150", "大小写提示 (ms):")
    capsEdit := settingsGui.Add("Edit", "x180 y102 w60", capsShowDuration)
    settingsGui.Add("Text", "x20 y130 w150", "复制提示 (ms):")
    copyEdit := settingsGui.Add("Edit", "x180 y127 w60", copyShowDuration)

    ; === 提示位置 ===
    settingsGui.Add("GroupBox", "x10 y160 w300 h90", "提示位置")
    posRadio1 := settingsGui.Add("Radio", "x20 y180 w80" . (tipPosition = 1 ? " Checked" : ""), "鼠标附近")
    posRadio2 := settingsGui.Add("Radio", "x110 y180 w80" . (tipPosition = 2 ? " Checked" : ""), "屏幕中央")
    posRadio3 := settingsGui.Add("Radio", "x200 y180 w80" . (tipPosition = 3 ? " Checked" : ""), "屏幕顶部")
    posRadio4 := settingsGui.Add("Radio", "x20 y200 w80" . (tipPosition = 4 ? " Checked" : ""), "屏幕底部")
    settingsGui.Add("Text", "x110 y202 w30", "偏移:")
    offsetEdit := settingsGui.Add("Edit", "x145 y199 w35", tipMouseOffset)
    settingsGui.Add("Text", "x20 y222 w60", "顶部:")
    topOffsetEdit := settingsGui.Add("Edit", "x60 y219 w35", tipTopOffset)
    settingsGui.Add("Text", "x110 y222 w60", "底部:")
    bottomOffsetEdit := settingsGui.Add("Edit", "x150 y219 w35", tipBottomOffset)

    ; === 字体样式 ===
    settingsGui.Add("GroupBox", "x10 y255 w300 h50", "字体样式")
    settingsGui.Add("Text", "x20 y275 w80", "字号:")
    fontSizeEdit := settingsGui.Add("Edit", "x70 y272 w50", tipFontSize)
    boldCheck := settingsGui.Add("CheckBox", "x130 y275 w60", "加粗")
    boldCheck.Value := tipFontBold

    ; === 按钮 ===
    settingsGui.Add("Button", "x20 y315 w80", "恢复默认").OnEvent("Click", ResetDefaults)
    settingsGui.Add("Button", "x120 y315 w80 Default", "保存").OnEvent("Click", SaveAndClose)
    settingsGui.Add("Button", "x220 y315 w80", "取消").OnEvent("Click", (*) => settingsGui.Destroy())

    ; GitHub 链接
    settingsGui.Add("Link", "x100 y355", '<a href="https://github.com/Ekko7778/AllInOneNotification">GitHub @Ekko7778</a>')

    ResetDefaults(*) {
        ; 恢复默认值并更新界面
        capsCheck.Value := true
        copyCheck.Value := true
        capsEdit.Value := 800
        copyEdit.Value := 800
        posRadio1.Value := true
        offsetEdit.Value := 2
        topOffsetEdit.Value := 10
        bottomOffsetEdit.Value := 150
        fontSizeEdit.Value := 9
        boldCheck.Value := true
    }

    SaveAndClose(*) {
        global enableCapsTip, enableCopyTip, capsShowDuration, copyShowDuration
        global tipPosition, tipMouseOffset, tipTopOffset, tipBottomOffset, tipFontSize, tipFontBold

        ; 保存功能开关
        enableCapsTip := capsCheck.Value
        enableCopyTip := copyCheck.Value

        ; 保存开机启动
        SetStartup(startupCheck.Value)

        ; 保存显示时长
        capsShowDuration := Max(100, Integer(capsEdit.Value || 800))
        copyShowDuration := Max(100, Integer(copyEdit.Value || 800))

        ; 保存提示位置 - 检查哪个 Radio 被选中
        if (posRadio1.Value)
            tipPosition := 1
        else if (posRadio2.Value)
            tipPosition := 2
        else if (posRadio3.Value)
            tipPosition := 3
        else if (posRadio4.Value)
            tipPosition := 4
        else
            tipPosition := 1  ; 默认鼠标附近

        ; 保存鼠标偏移
        tipMouseOffset := Max(0, Min(100, Integer(offsetEdit.Value || 2)))

        ; 保存顶部和底部偏移
        tipTopOffset := Max(0, Min(500, Integer(topOffsetEdit.Value || 10)))
        tipBottomOffset := Max(0, Min(500, Integer(bottomOffsetEdit.Value || 150)))

        ; 保存字体样式
        tipFontSize := Max(8, Min(72, Integer(fontSizeEdit.Value || 9)))
        tipFontBold := boldCheck.Value

        ; 应用设置
        SaveConfig()
        ApplySettings()

        settingsGui.Destroy()
        ShowTip("设置已保存", 800)
    }

    settingsGui.Show("w340 h380")
}

; ============================================================
; 应用设置（重新注册监听）
; ============================================================
ApplySettings() {
    global enableCapsTip, enableCopyTip, tipGui

    ; 重新设置大小写监听
    SetTimer(CheckCapsLock, 0)  ; 先停止
    if (enableCapsTip) {
        SetTimer(CheckCapsLock, 30)
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
    global tipGui, tipPosition, tipMouseOffset, tipTopOffset, tipBottomOffset, tipFontSize, tipFontBold
    static tipText := ""

    ; 获取鼠标位置（使用屏幕坐标）
    CoordMode "Mouse", "Screen"
    MouseGetPos(&mx, &my)

    ; 如果 GUI 已存在且窗口有效，更新内容和位置
    if (IsObject(tipGui) && WinExist("ahk_id " . tipGui.Hwnd)) {
        ; 禁用重绘，避免闪烁
        SendMessage(0xB, 0, 0, , "ahk_id " . tipGui.Hwnd)

        ; 更新文本
        tipText.Value := "  " . text . "  "

        ; 先隐藏状态下获取新尺寸
        tipGui.Show("Hide AutoSize")
        tipGui.GetPos(,, &gw, &gh)

        ; 计算位置
        if (tipPosition = 1) {
            ; 鼠标附近
            gx := mx + tipMouseOffset
            gy := my + tipMouseOffset
        } else if (tipPosition = 2) {
            ; 屏幕中央
            gx := (A_ScreenWidth - gw) / 2
            gy := (A_ScreenHeight - gh) / 2
        } else if (tipPosition = 3) {
            ; 屏幕顶部居中
            gx := (A_ScreenWidth - gw) / 2
            gy := tipTopOffset
        } else {
            ; 屏幕底部居中
            gx := (A_ScreenWidth - gw) / 2
            gy := A_ScreenHeight - gh - tipBottomOffset
        }

        ; 直接在目标位置显示
        tipGui.Show("x" . gx . " y" . gy . " NA")

        ; 启用重绘
        SendMessage(0xB, 1, 0, , "ahk_id " . tipGui.Hwnd)
    } else {
        ; 创建提示窗口
        tipGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20", "")
        tipGui.BackColor := "333333"
        tipGui.SetFont("s" . tipFontSize . (tipFontBold ? " Bold" : ""), "Microsoft YaHei")
        tipText := tipGui.Add("Text", "cFFFFFF Center r1", "  " . text . "  ")

        ; 使用 DWM 设置圆角 (Windows 11)
        try {
            DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", tipGui.Hwnd, "Int", 33, "Int*", 2, "Int", 4)
        }

        ; 先隐藏显示以获取正确尺寸
        tipGui.Show("Hide AutoSize")
        tipGui.GetPos(,, &gw, &gh)

        ; 计算位置
        if (tipPosition = 1) {
            ; 鼠标附近
            gx := mx + tipMouseOffset
            gy := my + tipMouseOffset
        } else if (tipPosition = 2) {
            ; 屏幕中央
            gx := (A_ScreenWidth - gw) / 2
            gy := (A_ScreenHeight - gh) / 2
        } else if (tipPosition = 3) {
            ; 屏幕顶部居中
            gx := (A_ScreenWidth - gw) / 2
            gy := tipTopOffset
        } else {
            ; 屏幕底部居中
            gx := (A_ScreenWidth - gw) / 2
            gy := A_ScreenHeight - gh - tipBottomOffset
        }

        ; 直接在指定位置显示
        tipGui.Show("x" . gx . " y" . gy . " NA")
    }

    ; 设置自动关闭
    if (duration > 0) {
        SetTimer(HideTip, duration)
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
ShowCapsStatus() {
    global capsShowDuration, enableCapsTip
    if (!enableCapsTip)
        return

    ; 获取大小写状态
    caps := GetKeyState("CapsLock", "T")
    capsIcon := caps ? "🔒 大写" : "🔓 小写"

    ; 获取输入法状态
    ime := GetIMEStatus()

    ; 合并显示
    tip := capsIcon . " | " . ime

    ShowTip(tip, capsShowDuration)
}

; ============================================================
; 获取输入法中/英状态
; ============================================================
GetIMEStatus() {
    try hWnd := WinExist("A")
    catch
        return "英"

    if (!hWnd)
        return "英"

    ; 方法1: 通过 IME 窗口获取状态
    try hIMEWnd := DllCall("imm32\ImmGetDefaultIMEWnd", "Ptr", hWnd, "UInt")
    catch
        hIMEWnd := 0

    if (hIMEWnd) {
        DetectHiddenWindows(true)
        try {
            result := SendMessage(0x283, 0x005, 0, , "ahk_id " . hIMEWnd)
            DetectHiddenWindows(false)
            return (result = 1) ? "中" : "英"
        } catch {
            DetectHiddenWindows(false)
        }
    }

    ; 方法2: 通过输入法上下文获取状态（备用方案）
    try {
        hIMC := DllCall("imm32\ImmGetContext", "Ptr", hWnd, "UInt")
        if (hIMC) {
            isOpen := DllCall("imm32\ImmGetOpenStatus", "Ptr", hIMC, "Int")
            if (isOpen) {
                ; 输入法开启，尝试获取转换状态
                convMode := 0
                try {
                    DllCall("imm32\ImmGetConversionStatus", "Ptr", hIMC, "UInt*", &convMode, "UInt*", 0, "Int")
                }
                ; 释放上下文
                DllCall("imm32\ImmReleaseContext", "Ptr", hWnd, "Ptr", hIMC)
                ; 检查是否为中文模式（通常 bit 1 表示中文输入）
                return (convMode & 1) ? "中" : "英"
            }
            ; 释放上下文
            DllCall("imm32\ImmReleaseContext", "Ptr", hWnd, "Ptr", hIMC)
            return "英"  ; 输入法关闭
        }
    } catch {
        ; 忽略错误
    }

    return "英"  ; 默认显示英文
}

; ============================================================
; 剪贴板变化回调函数 (AutoHotkey v2)
; ============================================================
ClipChanged(dataType) {
    global copyShowDuration, enableCopyTip
    if (!enableCopyTip)
        return

    ; 剪贴板格式常量
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
