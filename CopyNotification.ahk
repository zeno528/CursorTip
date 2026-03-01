; ============================================================
; CopyNotification.ahk (AutoHotkey v2)
; 功能：复制成功后显示提示
; 使用方法：双击运行即可
; ============================================================

#SingleInstance Force
Persistent

global copyShowDuration := 800    ; 提示显示时间 (ms)

; 监听剪贴板变化
OnClipboardChange(ClipChanged)

; 托盘提示
A_TrayTip := "复制提示已运行"

return

; ============================================================
; 剪贴板变化回调函数 (AutoHotkey v2)
; dataType: 0=空, 1=文本或文件, 2=非文本(图片等)
; ============================================================
ClipChanged(dataType) {
    global copyShowDuration

    ; 剪贴板格式常量
    ; CF_BITMAP = 2, CF_DIB = 8, CF_DIBV5 = 17, CF_HDROP = 15
    isFile := DllCall("IsClipboardFormatAvailable", "UInt", 15)
    isImage := DllCall("IsClipboardFormatAvailable", "UInt", 2)
          || DllCall("IsClipboardFormatAvailable", "UInt", 8)
          || DllCall("IsClipboardFormatAvailable", "UInt", 17)

    if (isFile) {
        ; 复制的是文件
        files := StrSplit(A_Clipboard, "`n", "`r")
        count := files.Length
        ToolTip("已复制：" . count . " 个文件")
        SetTimer(RemoveToolTip, copyShowDuration)
    }
    else if (isImage) {
        ; 复制的是图片
        ToolTip("已复制：图片")
        SetTimer(RemoveToolTip, copyShowDuration)
    }
    else if (dataType = 1 || dataType = 2) {
        ; 复制的是文本
        text := A_Clipboard
        length := StrLen(text)
        if (length > 0) {
            ToolTip("已复制：" . length . " 字符")
            SetTimer(RemoveToolTip, copyShowDuration)
        }
    }
}

RemoveToolTip() {
    ToolTip()
    SetTimer(RemoveToolTip, 0)
}
