; ============================================================
; AllInOneNotification.ahk (AutoHotkey v2)
; 功能：合并大小写提示 + 复制提示
; - 大小写/输入法：🔒 大写 | 中 / 🔓 小写 | 英
; - 复制提示：显示复制的字符数/图片/文件数
; ============================================================

#SingleInstance Force
Persistent

; ============================================================
; 全局设置
; ============================================================
global capsShowDuration := 800    ; 大小写提示显示时间
global copyShowDuration := 800    ; 复制提示显示时间
global lastCapsState := GetKeyState("CapsLock", "T")

A_TrayTip := "大小写+输入法+复制提示"

; ============================================================
; 大小写监听
; ============================================================
SetTimer(CheckCapsLock, 30)

~Shift:: {
    KeyWait("Shift")
    ShowCapsStatus()
}

; ============================================================
; 复制监听
; ============================================================
OnClipboardChange(ClipChanged)

return

; ============================================================
; CapsLock 状态检查
; ============================================================
CheckCapsLock() {
    global lastCapsState
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
    global capsShowDuration

    ; 获取大小写状态
    caps := GetKeyState("CapsLock", "T")
    capsIcon := caps ? "🔒 大写" : "🔓 小写"

    ; 获取输入法状态
    ime := GetIMEStatus()

    ; 合并显示
    tip := capsIcon . " | " . ime

    MouseGetPos(&x, &y)
    ToolTip(tip, x + 10, y + 10)
    SetTimer(RemoveCapsTip, capsShowDuration)
}

; ============================================================
; 获取输入法中/英状态
; ============================================================
GetIMEStatus() {
    try hWnd := WinExist("A")
    catch
        return "?"

    if (!hWnd)
        return "?"

    hIMEWnd := DllCall("imm32\ImmGetDefaultIMEWnd", "Ptr", hWnd, "UInt")

    if (!hIMEWnd)
        return "?"

    DetectHiddenWindows(true)
    result := SendMessage(0x283, 0x005, 0, , "ahk_id " . hIMEWnd)
    DetectHiddenWindows(false)

    return (result = 1) ? "中" : "英"
}

; ============================================================
; 关闭大小写提示
; ============================================================
RemoveCapsTip() {
    ToolTip()
    SetTimer(RemoveCapsTip, 0)
}

; ============================================================
; 剪贴板变化回调函数
; dataType: 0=剪贴板为空, 1=文本, 2=图片, 4=文件
; ============================================================
ClipChanged(dataType) {
    global copyShowDuration

    if (dataType = 1) {
        ; 获取剪贴板文本长度
        text := A_Clipboard
        length := StrLen(text)

        ; 显示简洁提示
        ToolTip("已复制：" . length . " 字符")
        SetTimer(RemoveCopyTip, copyShowDuration)
    }
    else if (dataType = 2) {
        ToolTip("已复制：图片")
        SetTimer(RemoveCopyTip, copyShowDuration)
    }
    else if (dataType = 4) {
        ; 统计文件数量
        files := StrSplit(A_Clipboard, "`n", "`r")
        count := files.Length
        ToolTip("已复制：" . count . " 个文件")
        SetTimer(RemoveCopyTip, copyShowDuration)
    }
}

; ============================================================
; 关闭复制提示
; ============================================================
RemoveCopyTip() {
    ToolTip()
    SetTimer(RemoveCopyTip, 0)
}
