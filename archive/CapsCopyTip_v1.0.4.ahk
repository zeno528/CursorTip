; ============================================================
; CapsCopyTip v1.0.4 (AutoHotkey v2)
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
global VERSION := "1.0.4"
global capsShowDuration := 800    ; 大小写提示显示时间
global copyShowDuration := 800    ; 复制提示显示时间
global lastCapsState := GetKeyState("CapsLock", "T")
global configPath := A_ScriptDir . "\config.ini"

; 新增设置
global enableCapsTip := true      ; 启用大小写提示
global enableCopyTip := true      ; 启用复制提示
global tipPosition := 1           ; 提示位置: 1=鼠标附近, 2=屏幕中央, 3=屏幕顶部, 4=屏幕底部
global tipMouseOffset := 10       ; 鼠标附近时的偏移距离(像素)
global tipTopOffset := 50         ; 屏幕顶部偏移距离(像素)
global tipBottomOffset := 100     ; 屏幕底部偏移距离(像素)
global tipFontSize := 9           ; 字体大小
global tipFontBold := true        ; 字体加粗
global tipLightMode := false      ; 浅色模式 (false=深色, true=浅色)

; 提示 GUI
global tipGui := ""

; 剪贴板防抖（Bug 1 修复）
global lastClipboardContent := ""
global lastClipboardTime := 0

A_TrayTip := "CapsCopyTip v" . VERSION . " - 大小写+输入法+复制提示"

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
; 启动光标标记 (运行 language-indicator.exe)
; ============================================================
Run("`"" . A_ScriptDir . "\language-indicator\language-indicator.exe`"")

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
        tipPosition := Integer(IniRead(configPath, "Settings", "TipPosition", 1))
        tipMouseOffset := IniRead(configPath, "Settings", "TipMouseOffset", 10)
        tipTopOffset := IniRead(configPath, "Settings", "TipTopOffset", 50)
        tipBottomOffset := IniRead(configPath, "Settings", "TipBottomOffset", 100)
        tipFontSize := IniRead(configPath, "Settings", "TipFontSize", 9)
        tipFontBold := IniRead(configPath, "Settings", "TipFontBold", 1) = 1
        tipLightMode := IniRead(configPath, "Settings", "TipLightMode", 0) = 1
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
        IniWrite(tipLightMode ? 1 : 0, configPath, "Settings", "TipLightMode")
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
    settingsGui.Add("GroupBox", "x10 y160 w300 h120", "提示位置")
    ; 所有 Radio 必须连续创建才能正确分组
    posRadio2 := settingsGui.Add("Radio", "x25 y182 w100 +Group" . (tipPosition = 2 ? " Checked" : ""), "屏幕中央")
    posRadio1 := settingsGui.Add("Radio", "x25 y204 w80" . (tipPosition = 1 ? " Checked" : ""), "鼠标附近")
    posRadio3 := settingsGui.Add("Radio", "x25 y226 w80" . (tipPosition = 3 ? " Checked" : ""), "屏幕顶部")
    posRadio4 := settingsGui.Add("Radio", "x25 y248 w80" . (tipPosition = 4 ? " Checked" : ""), "屏幕底部")
    ; 偏移设置（Radio 创建完后添加）
    settingsGui.Add("Text", "x115 y207 w30", "偏移:")
    offsetEdit := settingsGui.Add("Edit", "x150 y204 w40", tipMouseOffset)
    settingsGui.Add("Text", "x195 y207", "px")
    settingsGui.Add("Text", "x115 y229 w30", "偏移:")
    topOffsetEdit := settingsGui.Add("Edit", "x150 y226 w40", tipTopOffset)
    settingsGui.Add("Text", "x195 y229", "px")
    settingsGui.Add("Text", "x115 y251 w30", "偏移:")
    bottomOffsetEdit := settingsGui.Add("Edit", "x150 y248 w40", tipBottomOffset)
    settingsGui.Add("Text", "x195 y251", "px")

    ; === 外观样式 ===
    settingsGui.Add("GroupBox", "x10 y285 w300 h70", "外观样式")
    lightModeCheck := settingsGui.Add("CheckBox", "x25 y305 w80", "浅色模式")
    lightModeCheck.Value := tipLightMode
    settingsGui.Add("Text", "x25 y328 w40", "字号:")
    fontSizeEdit := settingsGui.Add("Edit", "x65 y325 w40", tipFontSize)
    boldCheck := settingsGui.Add("CheckBox", "x120 y328 w60", "加粗")
    boldCheck.Value := tipFontBold

    ; === 按钮 ===
    settingsGui.Add("Button", "x25 y365 w80", "恢复默认").OnEvent("Click", ResetDefaults)
    settingsGui.Add("Button", "x125 y365 w80 Default", "保存").OnEvent("Click", SaveAndClose)
    settingsGui.Add("Button", "x225 y365 w80", "取消").OnEvent("Click", (*) => settingsGui.Destroy())

    ; GitHub 链接
    settingsGui.Add("Link", "x105 y405", '<a href="https://github.com/Ekko7778/AllInOneNotification">GitHub @Ekko7778</a>')

    ResetDefaults(*) {
        ; 恢复默认值并更新界面
        capsCheck.Value := true
        copyCheck.Value := true
        capsEdit.Value := 800
        copyEdit.Value := 800
        posRadio1.Value := true
        offsetEdit.Value := 10
        topOffsetEdit.Value := 50
        bottomOffsetEdit.Value := 100
        fontSizeEdit.Value := 9
        boldCheck.Value := true
        lightModeCheck.Value := false
    }

    SaveAndClose(*) {
        global enableCapsTip, enableCopyTip, capsShowDuration, copyShowDuration
        global tipPosition, tipMouseOffset, tipTopOffset, tipBottomOffset, tipFontSize, tipFontBold, tipLightMode

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
        tipMouseOffset := Max(0, Min(100, Integer(offsetEdit.Value || 10)))

        ; 保存顶部和底部偏移
        tipTopOffset := Max(0, Min(500, Integer(topOffsetEdit.Value || 50)))
        tipBottomOffset := Max(0, Min(500, Integer(bottomOffsetEdit.Value || 100)))

        ; 保存字体样式
        tipFontSize := Max(8, Min(72, Integer(fontSizeEdit.Value || 9)))
        tipFontBold := boldCheck.Value
        tipLightMode := lightModeCheck.Value

        ; 应用设置
        SaveConfig()
        ApplySettings()

        settingsGui.Destroy()
        ShowTip("设置已保存", 800)
    }

    settingsGui.Show("w340 h435")
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
; 优化：快速切换时直接更新文本，不重新创建窗口
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
        ; 其他位置模式不需要重新计算，保持原位置
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

    ; 设置自动关闭 - 重置定时器
    if (duration > 0) {
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
    global capsShowDuration, enableCapsTip
    static lastIMEState := "英"

    if (!enableCapsTip)
        return

    ; 获取大小写状态
    caps := GetKeyState("CapsLock", "T")
    capsIcon := caps ? "🔒 大写" : "🔓 小写"

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

    ShowTip(tip, capsShowDuration)
}

; ============================================================
; 获取输入法中/英状态
; Windows 11 需要使用 TSF 框架检测
; ============================================================
GetIMEStatus(forceRefresh := false) {
    static lastResult := "英"
    static lastCheckTime := 0

    ; 防抖：150ms 内直接返回上次结果（强制刷新时跳过）
    if (!forceRefresh && A_TickCount - lastCheckTime < 150)
        return lastResult

    currentResult := ""

    try {
        ; 方法1: 使用 WMI 检测当前键盘布局
        currentResult := DetectIMEViaKeyboardLayout()

        ; 方法2: 传统 IMM32 方法（备选）
        if (currentResult = "") {
            currentResult := DetectIMEViaIMM32()
        }
    } catch {
    }

    ; 确保返回有效值
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
        ; 获取前台窗口
        hWnd := WinExist("A")
        if (!hWnd)
            return ""

        ; 获取窗口线程
        threadID := DllCall("GetWindowThreadProcessId", "Ptr", hWnd, "Ptr", 0, "UInt")
        if (!threadID)
            return ""

        ; 获取当前键盘布局
        hkl := DllCall("GetKeyboardLayout", "UInt", threadID, "UPtr")

        ; 检测是否是中文输入法 (0x0804 = 简体中文)
        langID := hkl & 0xFFFF
        if (langID != 0x0804)
            return "英"

        ; 对于中文输入法，尝试检测 Shift 状态
        ; 通过 ImmGetContext 获取更详细的状态
        hIMC := DllCall("imm32\ImmGetContext", "Ptr", hWnd, "UPtr")
        if (hIMC) {
            convMode := 0
            DllCall("imm32\ImmGetConversionStatus", "Ptr", hIMC, "UInt*", &convMode, "UInt*", 0)

            ; 检测多个状态位
            ; IME_CMODE_NATIVE = 0x0001 (中文模式)
            ; IME_CMODE_KATAKANA = 0x0002
            ; IME_CMODE_FULLSHAPE = 0x0008 (全角)
            ; IME_CMODE_ROMAN = 0x0010 (罗马字)
            ; IME_CMODE_CHARCODE = 0x0020
            ; IME_CMODE_HANJACONVERT = 0x0040
            ; IME_CMODE_SOFTKBD = 0x0080
            ; IME_CMODE_NOCONVERSION = 0x0100
            ; IME_CMODE_EUDC = 0x0200
            ; IME_CMODE_SYMBOL = 0x0400 (符号模式)

            ; 微软拼音: IME_CMODE_NATIVE (0x0001) = 1 表示中文模式，= 0 表示英文模式
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
            return (result = 0) ? "英" : "中"
        }

        DetectHiddenWindows(savedDetectHiddenWindows)
    } catch {
        DetectHiddenWindows(savedDetectHiddenWindows)
    }
    return ""
}

; ============================================================
; 剪贴板变化回调函数 (AutoHotkey v2)
; ============================================================
ClipChanged(dataType) {
    global copyShowDuration, enableCopyTip
    global lastClipboardContent, lastClipboardTime
    if (!enableCopyTip)
        return

    ; Bug 1 修复：防抖机制
    ; 100ms 内的重复事件直接忽略
    if (A_TickCount - lastClipboardTime < 100)
        return

    ; 检查剪贴板内容是否真正变化
    currentContent := A_Clipboard
    if (currentContent = lastClipboardContent)
        return

    ; 更新记录
    lastClipboardContent := currentContent
    lastClipboardTime := A_TickCount

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
