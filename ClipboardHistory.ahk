; ============================================================
; 剪贴板历史 — 数据层 + 面板 + 键盘处理
; 由 CursorTip.ahk 的 #Include 引入（放在 VERSION.ahk 之后）
; 状态全局全部声明在本文件顶部，主文件只在 ClipChanged 里 global suppressClip
; ============================================================

; 历史数据文件（与 config.ini 同目录；NUL 分隔，无转义）
HIST_PATH := A_ScriptDir . "\clipboard_history.dat"

global ClipHistory := []     ; [{t: "2026-10-11T10:23:45", v: "文本"}, ...] 最新的在 [1]
global suppressClip := false ; 回填剪贴板期间为 true，挡住自触发（脚本自身写剪贴板也会触发 OnClipboardChange）
global histGui := ""
global histLv := ""
global histTitle := ""
global histHint := ""
global histGrip := ""
global histSel := 0
global histStateDirty := false  ; 面板被用户拖移/缩放过，关闭时才落盘一次
global histOwner := 0  ; 打开面板时的前台窗口（粘贴目标），鼠标点过面板后焦点要还给它
global HistCurrentKey := "" ; 当前已注册的历史热键，换键位时用它先注销旧的
global HistRowsShown := 8   ; 面板最多同时显示多少行，超出滚动

; ============================================================
; 数据层
; ============================================================

; 超出上限就丢最早（数组末尾）。Push / 启动加载 / 保存设置后各调一次
TrimHistory() {
    global ClipHistory
    maxN := Max(1, Config.clipboardHistoryMax)
    while (ClipHistory.Length > maxN)
        ClipHistory.Pop()
}

; 存储格式：每条一行 "<时间戳>\t<转义后的文本>"
; 曾经用 NUL 分隔想省掉转义，实测 AHK v2 的 StrSplit 遇 Chr(0) 分隔符会返回垃圾
; （3 段全部塌成首字符），已废弃。换行 + 转义是最朴素可靠的组合。
HistEscape(s) {
    s := StrReplace(s, "\", "\\")   ; 反斜杠必须最先转，否则后面补的 \r \n \t 会被二次转义
    s := StrReplace(s, "`r", "\r")
    s := StrReplace(s, "`n", "\n")
    s := StrReplace(s, "`t", "\t")
    return s
}

HistUnescape(s) {
    ; 单遍正则：先吃掉 \" 这一对，还原出的 \ 不会再参与后续匹配（顺序 StrReplace 会把 \\n 误还原成换行）
    return RegExReplace(s, "\\(.)", (m) => (m[1] = "n" ? "`n" : m[1] = "r" ? "`r" : m[1] = "t" ? "`t" : m[1]))
}

LoadHistory() {
    global ClipHistory, HIST_PATH
    ClipHistory := []
    if !FileExist(HIST_PATH)
        return
    try {
        Loop Parse, FileRead(HIST_PATH, "UTF-8"), "`n", "`r" {
            tab := InStr(A_LoopField, "`t")
            if (tab > 0)
                ClipHistory.Push({t: SubStr(A_LoopField, 1, tab - 1), v: HistUnescape(SubStr(A_LoopField, tab + 1))})
        }
    } catch {
        ; 文件损坏/读失败 → 当空历史，绝不阻断启动
        ClipHistory := []
    }
    TrimHistory()
}

SaveHistory() {
    global ClipHistory, HIST_PATH
    buf := ""
    for it in ClipHistory
        buf .= it.t . "`t" . HistEscape(it.v) . "`n"
    ; 不能用 FileAppend：v2 的 FileAppend 只有 3 参且 Options 仅接受编码/RAW，
    ; 它永远是「追加」模式，传 "w" 会抛 Invalid option。要覆盖写必须走 FileOpen 的 w 标志。
    try {
        f := FileOpen(HIST_PATH, "w", "UTF-8")   ; w = 覆盖；编码是第 3 参（v2 FileOpen 只有 3 参）
        f.Write(buf)
        f.Close()
    } catch as e
        FileAppend("CursorTip: history save failed: " e.Message "`n", "work\debug.log")
}

; 记一条：空内容丢弃、超长丢弃、同文本去重后置顶，再裁剪并落盘
PushHistory(text) {
    global ClipHistory
    n := StrLen(text)
    if (n == 0)
        return
    ; 单条上限：防止一次复制上百 MB 文本把文件撑爆（50 条上限只约束条数，不约束体积）
    if (n > 65536) {
        FileAppend("CursorTip: history skip oversized entry " n " chars`n", "work\debug.log")
        return
    }
    ; 去重：从后往前扫，同文本移除旧位（RemoveAt 会让后续索引左移，倒着扫才不漏）
    i := ClipHistory.Length
    while (i >= 1) {
        if (ClipHistory[i].v = text)
            ClipHistory.RemoveAt(i)
        i -= 1
    }
    ; v2 的 Array.InsertAt 签名是 InsertAt(Index, Value)——索引在第 1 位，写反会抛 ValueError
    ClipHistory.InsertAt(1, {t: FormatTime(, "yyyy-MM-ddTHH:mm:ss"), v: text})
    TrimHistory()
    SaveHistory()
}

; 独立回调（-1 = 排在 ClipChanged 之前），互不干扰：关掉复制提示不影响历史，反之亦然
HistClipChanged(dataType) {
    global suppressClip, ClipHistory
    if (suppressClip || !Config.enableClipboardHistory) {
        FileAppend("CursorTip: history skip (suppress=" suppressClip " enabled=" Config.enableClipboardHistory ")`n", "work\debug.log")
        return
    }
    ; dataType 不可尽信：官方文档说 2=完全非文本，但本机实测纯文本复制也报 2
    ; （ClipChanged 同期读到 185 字符文本）。判定逻辑直接复用 ClipChanged 的格式探测，
    ; 不再靠 dataType 过滤 —— 0=空，其余交给下面的 CF_* 探测
    if (dataType == 0) {
        FileAppend("CursorTip: history skip (empty)`n", "work\debug.log")
        return
    }
    ; 从资源管理器复制的文件（CF_HDROP），A_Clipboard 是路径文本。回填出来只是一串路径，不收
    if (DllCall("IsClipboardFormatAvailable", "UInt", 15)) {
        FileAppend("CursorTip: history skip (file drop)`n", "work\debug.log")
        return
    }
    ; 图片/HTML（CF_BITMAP / CF_DIB / CF_CFHTML），与 ClipChanged 用同一组常量
    if (DllCall("IsClipboardFormatAvailable", "UInt", 2)
     || DllCall("IsClipboardFormatAvailable", "UInt", 8)
     || DllCall("IsClipboardFormatAvailable", "UInt", 17)) {
        FileAppend("CursorTip: history skip (image/html)`n", "work\debug.log")
        return
    }
    try {
        PushHistory(A_Clipboard)
        FileAppend("CursorTip: history push ok, total=" ClipHistory.Length "`n", "work\debug.log")
    } catch as e {
        FileAppend("CursorTip: history push failed: " e.Message "`n", "work\debug.log")
    }
}

; ============================================================
; 面板
; ============================================================

; 历史条目 → 列表显示文本：多行折成单行、超长截断。
; 只在显示层截断，内存/磁盘里存全量——回填必须拿到原文
HistDispText(s) {
    s := StrReplace(s, "`r`n", " ⏎ ")
    s := StrReplace(s, "`n", " ⏎ ")
    s := StrReplace(s, "`r", " ⏎ ")
    s := StrReplace(s, "`t", " ")
    return StrLen(s) > 100 ? SubStr(s, 1, 100) "…" : s
}

HistTimeText(t) {
    ; 时间戳由 PushHistory 固定生成为 "yyyy-MM-ddTHH:mm:ss"，直接切字符串即可。
    ; 不走 FormatTime：v2 对传入的日期串做自动识别时，"2026-10-11 01:37:37" 这种形式会抛
    ; "Parameter #1 of FormatTime is invalid"，而这里并不需要它的任何时区/本地化能力
    return StrLen(t) >= 16 ? SubStr(t, 6, 5) " " SubStr(t, 12, 5) : t
}

; 用当前 ClipHistory 填满 ListView 并选中 histSel 行（打开面板 / 删除条目后共用）
HistFillList() {
    global histLv, ClipHistory, histSel
    lv := histLv
    while (lv.GetCount())
        lv.Delete(1)
    for it in ClipHistory
        ; v2 的 ListView.Add 第 1 参是 Options（列属性），不是内容；
        ; 要跳过它必须给个空串。官方示例写法即 LV.Add(, Col1, Col2)
        lv.Add("", HistDispText(it.v), HistTimeText(it.t))
    ; 这里不用 LV.Opt("-Redraw")/+Redraw 批量优化：上限才 200 行，收益可忽略，
    ; 却引入重绘时序的不确定性（曾导致面板画出来是空的）
    histSel := Min(Max(1, histSel), ClipHistory.Length)
    ; Vis = 滚动到可视区。面板只露 8 行，导航到第 9 行之后不加它选中行会看不见
    lv.Modify(histSel, "Select Vis")
    FileAppend("CursorTip: fill list rows=" lv.GetCount() " total=" ClipHistory.Length " sel=" histSel "`n", "work\debug.log")
}

ShowClipHistory(*) {
    global histGui, histLv, histTitle, histHint, histGrip, histSel, histOwner, settingsGui, ClipHistory
    ; 面板已开 → 热键不做任何事（关闭交给 Esc）。
    ; 不能做成「再按一次关闭」：按住热键会持续触发键盘自动重复，toggle 必然满屏闪烁
    ; （试过 250ms 防抖，只把闪烁从每 30ms 放慢到每 250ms，没根治）
    if (IsObject(histGui) && DllCall("IsWindow", "Ptr", histGui.Hwnd))
        return
    ; 设置窗口聚焦时不响应，避免在设置里误触
    fg := DllCall("user32\GetForegroundWindow", "Ptr")
    if (IsObject(settingsGui) && DllCall("IsWindow", "Ptr", settingsGui.Hwnd) && fg = settingsGui.Hwnd)
        return
    histOwner := fg
    if (ClipHistory.Length = 0)
        return

    c := Config
    theme := (c.tipLightMode = "auto") ? GetSystemTheme() : c.tipLightMode
    bg := (theme = "light") ? "F5F5F5" : "333333"
    fgColor := (theme = "light") ? "333333" : "FFFFFF"
    hintColor := (theme = "light") ? "888888" : "AAAAAA"

    ; 尺寸：用户拖边调过就用保存值，否则按内容自适应（宽 320，高随条目数，最多 HistRowsShown 行）
    gw := (Config.clipboardHistoryW > 0) ? Config.clipboardHistoryW : 320
    rows := Min(ClipHistory.Length, HistRowsShown)
    gh := (Config.clipboardHistoryH > 0) ? Config.clipboardHistoryH : (26 + rows * 20 + 56)

    ; 窗口参数：绝不照抄 tip 气泡的 E0x20/E0x02000000！
    ; - E0x20(WS_EX_TRANSPARENT)：等底层窗口画完再画+表现透明，只适合纯展示气泡
    ; - E0x02000000(WS_EX_COMPOSITED)：官方论坛实测与 ListView 不兼容 —— AutoIt bug#1492「no listview
    ;   visible」、AHK 论坛「it does not load any listview」，且微软文档明说其子控件双缓冲与 DWM 冲突
    ;   （Win11 DWM 恒开）→ 表现为持续闪屏/列表空白
    ; ListView 的防闪走自己的 LVS_EX_DOUBLEBUFFER（下方 SendMessage），窗口保持素样式。
    ; 拖移/缩放不用 WS_SIZEBOX(+Resize)：-Caption 下抓不到边，走标题栏+◢手柄（见 HistLButtonDown）
    g := Gui("+AlwaysOnTop -Caption +ToolWindow")
    g.BackColor := bg
    g.SetFont("s" c.tipFontSize . (c.tipFontBold ? " Bold" : ""), "Microsoft YaHei")
    ; 标题栏 = 拖移手柄。0x100(SS_NOTIFY)：官方文档明确 Text 只有带它才发点击通知，否则 WM_LBUTTONDOWN 收不到
    histTitle := g.Add("Text", "x4 y4 w" (gw - 8) " h18 c" fgColor " 0x100", T("hist_title"))
    ; -Multi：选条回填天然单选，禁掉多选（Modify 的 Select 也不会取消旧行，靠 HistMove 显式清）
    lv := g.Add("ListView", "Report -Multi -Border Background" bg " c" fgColor " x4 y26 w" (gw - 8) " h" (gh - 58), [T("hist_col_text"), T("hist_col_time")])
    ; LVM_SETEXTENDEDLISTVIEWSTYLE(0x1000+54) 挂 LVS_EX_DOUBLEBUFFER(0x10000)：ListView 标准防闪样式。
    ; GuiControl 没有 SendMessage 方法，走全局函数 + Hwnd
    SendMessage(0x1036, 0x10000, 0x10000, lv.Hwnd)
    g.SetFont("s8", "Microsoft YaHei")
    histHint := g.Add("Text", "x4 y" (gh - 26) " w" (gw - 8) " c" hintColor " 0x100", T("hist_hint"))
    histGrip := g.Add("Text", "x" (gw - 20) " y" (gh - 18) " w16 h14 Right c" hintColor " 0x100", "◢")  ; 右下角尺寸手柄
    lv.OnEvent("Click", HistLvClick)
    lv.OnEvent("DoubleClick", HistLvDbl)

    try {
        DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", g.Hwnd, "Int", 33, "Int*", 2, "Int", 4)  ; 圆角
        DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", g.Hwnd, "Int", 3, "Int*", 1, "Int", 4)   ; 禁用过渡动画
    }

    ; 全局引用必须在 Show 之前挂好：首次 Show 指定 w/h 也可能触发 Size 事件
    histGui := g
    histLv := lv
    histSel := 1
    g.OnEvent("Size", HistOnResize)
    HistApplyLayout(g, gw, gh)   ; Show 之前先定好控件/列宽，避免首帧默认列宽溢出

    if (Config.clipboardHistoryX != "") {
        ; 用户拖移过 → 上次的位置原地出现，并夹回屏幕内（分辨率变了也不至于找不回）
        x := Min(Max(0, Integer(Config.clipboardHistoryX)), A_ScreenWidth - gw)
        y := Min(Max(0, Integer(Config.clipboardHistoryY)), A_ScreenHeight - gh)
    } else {
        ; 从没挪过 → 跟随鼠标（与 ShowTipAt case 1 同款）
        CoordMode "Mouse", "Screen"
        MouseGetPos(&mx, &my)
        y := c.tipMouseAbove ? Max(0, my - gh - c.tipMouseOffset) : my + c.tipMouseOffset
        x := Min(mx + c.tipMouseOffset, A_ScreenWidth - gw)
        y := Min(Max(0, y), A_ScreenHeight - gh)
    }
    g.Show("x" x " y" y " w" gw " h" gh " NA")   ; NA = 不抢焦点，回填后直接 Ctrl+V
    histStateDirty := false   ; Show 自己触发的 Size 事件不算用户改动

    HistFillList()
    SetHistNavKeys(true)
}

; 按窗口客户区尺寸重排控件与列宽。面板创建时和拖动时共用一份布局
HistApplyLayout(g, w, h) {
    global histLv, histTitle, histHint, histGrip
    histTitle.Move(4, 4, w - 8)
    histLv.Move(4, 26, w - 8, h - 58)
    histHint.Move(4, h - 26, w - 8)
    histGrip.Move(w - 20, h - 18)
    histLv.ModifyCol(2, 90)
    ; 时间列固定 90；内容列吃掉剩余宽度并预留一条纵向滚动条的宽度——
    ; 否则行数超屏出现纵向条时，它挤占的客户区会让列宽总和超出列表 → 冒出横向滚动条
    histLv.ModifyCol(1, w - 8 - 90 - DllCall("user32\GetSystemMetrics", "Int", 2))  ; 2 = SM_CXVSCROLL
}

; 缩放 → 重排控件并记忆。最小尺寸由 HistGetMinMax 原生限制，
; 不在 Size 事件里 g.Move 弹回下限——那会和拖动循环互相打架导致闪烁
HistOnResize(g, minMax, w, h) {
    global histLv, histHint, histStateDirty
    if (minMax != 0 || !IsObject(histLv) || histHint = "")   ; 首次 Show 期间控件还没就绪则跳过
        return
    HistApplyLayout(g, w, h)
    Config.clipboardHistoryW := w
    Config.clipboardHistoryH := h
    histStateDirty := true
}

; 标题栏按住拖移（HTCAPTION）、◢ 手柄按住缩放（HTBOTTOMRIGHT），走 Windows 原生拖动循环。
; 社区标准三件套缺一不可：
;   1. Text 控件要带 SS_NOTIFY(0x100) 才收得到 WM_LBUTTONDOWN（官方 GuiControls 文档）
;   2. 先 ReleaseCapture() 释放鼠标捕获，否则 DefWindowProc 进不了 NC 拖动循环（AutoIt Wiki 同款）
;   3. lParam 必须是屏幕坐标（低字 x 高字 y），传 0 会让缩放锚到 (0,0) 尺寸乱跳（闪烁根因）
HistLButtonDown(wParam, lParam, msg, hwnd) {
    global histGui, histTitle, histGrip
    if !(IsObject(histGui) && DllCall("IsWindow", "Ptr", histGui.Hwnd))
        return
    if (hwnd = histTitle.Hwnd)
        ht := 2          ; HTCAPTION
    else if (IsObject(histGrip) && hwnd = histGrip.Hwnd)
        ht := 17         ; HTBOTTOMRIGHT
    else
        return
    CoordMode "Mouse", "Screen"
    MouseGetPos(&mx, &my)
    DllCall("user32\ReleaseCapture")
    ; 0xA1 = WM_NCLBUTTONDOWN；用 SendMessage（同步），PostMessage 异步进不了模态循环
    SendMessage(0xA1, ht, (my & 0xFFFF) << 16 | (mx & 0xFFFF), , "ahk_id " histGui.Hwnd)
}

; 原生最小尺寸（WM_GETMINMAXINFO）。280 宽防提示行折行，110 高保住标题+列表+提示行
HistGetMinMax(wParam, lParam, msg, hwnd) {
    global histGui
    if (IsObject(histGui) && hwnd = histGui.Hwnd) {
        NumPut("Int", 280, "Int", 110, lParam, 24)   ; MINMAXINFO.ptMinTrackSize 在第 4 个 POINT
        return 0
    }
}

; 原生拖移/缩放循环结束（WM_EXITSIZEMOVE）→ 标记为用户主动改动，关闭时才记位置
HistExitSizeMove(*) {
    global histGui, histStateDirty
    if (IsObject(histGui) && DllCall("IsWindow", "Ptr", histGui.Hwnd))
        histStateDirty := true
}

HistClose(*) {
    global histGui, histLv, histTitle, histHint, histGrip, histSel, histStateDirty
    SetHistNavKeys(false)
    ; 位置必须在 Destroy 之前读；只有用户真拖过才记，保持"没动过就跟随鼠标"
    if (histStateDirty && IsObject(histGui) && DllCall("IsWindow", "Ptr", histGui.Hwnd)) {
        WinGetPos(&px, &py, , , "ahk_id " histGui.Hwnd)
        Config.clipboardHistoryX := px
        Config.clipboardHistoryY := py
        Config.Save()   ; 关面板才落盘一次，避免拖动过程中频繁重写 config.ini
    }
    if (IsObject(histGui)) {
        try histGui.Destroy()
        histGui := ""
    }
    histStateDirty := false
    histLv := ""
    histTitle := ""
    histHint := ""
    histGrip := ""
    histSel := 0
}

; ============================================================
; 键盘
; ============================================================

; NA 窗口的 ListView 不吃键盘事件，导航靠面板开启期间临时接管这些键；
; ~LButton 是透传热键（点击照常落到目标窗口），用于检测面板外点击后自动关闭。
; 面板关闭时必须全部 Off，否则全局吞键。
SetHistNavKeys(on) {
    static keys := ["Up", "Down", "Enter", "Esc", "Delete", "~LButton"]
    for k in keys
        Hotkey(k, on ? "On" : "Off")   ; 省略 Action 只改 Options，保留已注册的回调
}

HistMove(d) {
    global histLv, histSel
    n := histLv.GetCount()
    if (n = 0)
        return
    old := histSel
    histSel := Mod(histSel - 1 + d + n, n) + 1   ; 上下环绕
    ; 官方文档：Modify 的 Select 不会取消其他行的选中，必须显式清旧行，否则行行累积高亮
    histLv.Modify(old, "-Select")
    histLv.Modify(histSel, "Select Vis")
}

HistUp(*) {
    HistMove(-1)
}

HistDown(*) {
    HistMove(1)
}

HistEnter(*) {
    global histSel, histOwner, ClipHistory, suppressClip
    if (histSel < 1 || histSel > ClipHistory.Length)
        return
    idx := histSel
    text := ClipHistory[idx].v
    HistClose()   ; 这里会把 histSel 清零，所以行号必须先取出来
    ; 回填前先关面板再写剪贴板：面板开着时按 Enter 不该把当前内容顶掉
    suppressClip := true
    try A_Clipboard := text
    Sleep(30)   ; 等剪贴板写完再粘贴
    ; 面板是 NA 窗口不抢焦点，但鼠标点过面板后焦点会落在面板上，粘贴前先还给原窗口
    if (histOwner && WinExist("ahk_id " histOwner) && !WinActive("ahk_id " histOwner))
        WinActivate("ahk_id " histOwner)
    Send("^v")
    ; OnClipboardChange 回调要等当前线程结束才跑（实测本文件 fill 后 push 仍执行），
    ; Sleep 在同一线程里挡不住它，必须延后解除抑制
    SetTimer(HistUnsuppress, -200)
    FileAppend("CursorTip: history fill #" idx " len=" StrLen(text) "`n", "work\debug.log")
}

HistUnsuppress() {
    global suppressClip
    suppressClip := false
}

; 鼠标点选行 → 同步 histSel（否则点完行再按 Enter 回填的还是旧行）
HistLvClick(ctrl, row) {
    global histSel
    if (row > 0)
        histSel := row
}

; 双击行 → 直接回填
HistLvDbl(ctrl, row) {
    global histSel
    if (row > 0) {
        histSel := row
        HistEnter()
    }
}

; 面板外点击 → 自动关闭。~ 前缀让点击照常落到被点的窗口，不吞
HistClick(*) {
    global histGui
    if !(IsObject(histGui) && DllCall("IsWindow", "Ptr", histGui.Hwnd))
        return
    CoordMode "Mouse", "Screen"
    MouseGetPos(&mx, &my)
    WinGetPos(&gx, &gy, &gw, &gh, "ahk_id " histGui.Hwnd)
    if (mx < gx || my < gy || mx > gx + gw || my > gy + gh)
        HistClose()
}

HistDel(*) {
    global histSel, ClipHistory
    if (histSel < 1 || histSel > ClipHistory.Length)
        return
    ClipHistory.RemoveAt(histSel)
    SaveHistory()
    if (ClipHistory.Length = 0) {
        HistClose()
        return
    }
    HistFillList()   ; histSel 由 HistFillList 夹回有效范围
}

; ============================================================
; 初始化（主文件启动段调用，须在 Config.Load 之后）
; ============================================================

InitClipHistory() {
    global ClipHistory
    LoadHistory()
    ApplyHistoryKey()
    ; 导航键先注册好并置 Off，开面板时才 On
    Hotkey("Up", HistUp, "Off")
    Hotkey("Down", HistDown, "Off")
    Hotkey("Enter", HistEnter, "Off")
    Hotkey("Esc", HistClose, "Off")
    Hotkey("Delete", HistDel, "Off")
    Hotkey("~LButton", HistClick, "Off")
    OnMessage(0x24, HistGetMinMax)        ; WM_GETMINMAXINFO：面板最小尺寸
    OnMessage(0x201, HistLButtonDown)     ; WM_LBUTTONDOWN：标题栏/手柄触发原生拖移缩放
    OnMessage(0x232, HistExitSizeMove)    ; WM_EXITSIZEMOVE：拖完标记为用户改动
    FileAppend("CursorTip: history loaded " ClipHistory.Length . " entries (max=" Config.clipboardHistoryMax ")`n", "work\debug.log")
}

; 注册/换绑历史热键。改键位必须先注销旧的，否则新旧两个都会触发。
; 空串或非法组合 → 回退默认 ^+v，并把失败原因写进 debug.log（面板打不开时唯一的线索）
ApplyHistoryKey(key := "") {
    global HistCurrentKey
    key := (key != "") ? key : Config.clipboardHistoryKey
    if (key = "")
        key := "^+v"
    if (HistCurrentKey != "")
        try Hotkey(HistCurrentKey, "Off")
    try {
        Hotkey(key, ShowClipHistory)
        HistCurrentKey := key
        FileAppend("CursorTip: history hotkey = " key "`n", "work\debug.log")
    } catch as e {
        HistCurrentKey := ""
        FileAppend("CursorTip: history hotkey FAILED: " e.Message " key=" key "`n", "work\debug.log")
    }
}