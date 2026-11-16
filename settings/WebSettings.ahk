; WebView2 runs in a second invocation of the same executable. The tray process
; owns configuration, hotkeys and updates. Neither side polls when settings close.
ShowSettings(*) {
    global settingsGui
    if IsObject(settingsGui) {
        ShowNativeSettings()
        return
    }
    state := WebSettingsState()
    if (state.pid && ProcessExist(state.pid)) {
        if (hwnd := WinExist("ahk_class AutoHotkeyGUI ahk_pid " state.pid))
            WinActivate("ahk_id " hwnd)
        return
    }
    command := '"' A_AhkPath '"'
    if !A_IsCompiled
        command .= ' /script "' A_ScriptFullPath '"'
    state.child := 0
    try {
        Run(command ' --settings ' A_ScriptHwnd, A_ScriptDir, , &pid)
        state.pid := pid
        OnMessage(0x4A, WebSettingsFromChild)
        SetTimer(CheckSettingsChild, 500)
    } catch as e {
        ErrorLog("Settings launch: " e.Message)
        ShowNativeSettings()
    }
}

WebSettingsState() {
    static state := {pid: 0, child: 0, pending: 0}
    return state
}

CheckSettingsChild() {
    state := WebSettingsState()
    if ProcessExist(state.pid)
        return
    state.pid := state.child := 0
    SetTimer(CheckSettingsChild, 0)
    OnMessage(0x4A, WebSettingsFromChild, 0)
}

WebSettingsConnected() {
    return WebSettingsState().child != 0
}

SendWebUpdateState(progress := "") {
    child := WebSettingsState().child
    if !child
        return
    global g_updateState, g_updateLatestVer
    SendSettingsMessage(child, "update|" g_updateState "|" g_updateLatestVer "|" progress)
}

; WM_COPYDATA is synchronous. Queue actions that can send a reply or open a window.
WebSettingsFromChild(sender, data, *) {
    state := WebSettingsState()
    if !state.pid || !SettingsSenderMatches(sender, state.pid)
        return 0
    message := ReadSettingsMessage(data)
    if (message = "ready") {
        state.child := sender
        SetTimer(SendWebUpdateState, -1)
    } else if (message = "fallback") {
        state.child := 0
        SetTimer(ShowNativeSettings, -1)
    } else if (sender = state.child) {
        if (message = "closed")
            state.child := 0
        else if (message = "check")
            SetTimer(() => OnUpdateButtonClick(0), -1)
        else if (SubStr(message, 1, 6) = "apply|") {
            if !(values := ReadWebSettingsValues(SubStr(message, 7)))
                return 0
            state.pending := {sender: sender, values: values}
            SetTimer(CommitWebSettings, -1)
        } else if (message = "changelog")
            SetTimer(() => Run("https://cursortip-website.pages.dev/"), -1)
        else if (message = "repository")
            SetTimer(() => Run("https://github.com/zeno528/CursorTip"), -1)
    }
    return 1
}

SettingsSenderMatches(hwnd, pid) {
    DllCall("GetWindowThreadProcessId", "ptr", hwnd, "uint*", &senderPid := 0)
    return senderPid && senderPid = pid
}

ReadSettingsMessage(data) {
    if (!data || NumGet(data, 0, "uptr") != 0x43544950)
        return ""
    size := NumGet(data, A_PtrSize, "uint")
    return size >= 2 && size <= 1024 && Mod(size, 2) = 0
        ? StrGet(NumGet(data, 2 * A_PtrSize, "ptr"), size // 2 - 1, "UTF-16") : ""
}

SendSettingsMessage(target, message) {
    payload := Buffer(2 * (StrLen(message) + 1))
    StrPut(message, payload, "UTF-16")
    data := Buffer(3 * A_PtrSize, 0)
    NumPut("uptr", 0x43544950, "uint", payload.Size, data)
    NumPut("ptr", payload.Ptr, data, 2 * A_PtrSize)
    return DllCall("SendMessageTimeoutW", "ptr", target, "uint", 0x4A, "ptr", A_ScriptHwnd,
        "ptr", data, "uint", 2, "uint", 500, "uptr*", &accepted := 0, "ptr") && accepted
}

; The bridge accepts a fixed set of enum, boolean and bounded integer values.
WebSettingsValues(source, startup) {
    return [startup ? 1 : 0, source.enableCapsTip ? 1 : 0, source.showIMEStatus ? 1 : 0,
        source.enableCopyTip ? 1 : 0, SelectionModeOf(source), source.capsShowDuration,
        source.copyShowDuration, source.tipPosition, source.tipMouseOffset, source.tipMouseAbove ? 1 : 0,
        source.tipTopOffset, source.tipBottomOffset, source.tipFontSize, source.tipFontBold ? 1 : 0,
        source.tipLightMode, source.language]
}

JoinSettingsValues(values) {
    line := ""
    for value in values
        line .= (A_Index = 1 ? "" : "|") value
    return line
}

ReadWebSettingsValues(payload) {
    v := StrSplit(payload, "|")
    if (v.Length != 16)
        return 0
    for index, limits in [[0,1],[0,1],[0,1],[0,1],[1,3],[100,2147483647],[100,2147483647],
        [1,4],[0,100],[0,1],[0,500],[0,500],[8,72],[0,1]] {
        if !RegExMatch(v[index], "^\d{1,10}$") || v[index] < limits[1] || v[index] > limits[2]
            return 0
        v[index] := Integer(v[index])
    }
    if !RegExMatch(v[15], "^(auto|light|dark)$") || !RegExMatch(v[16], "^(auto|zh|en)$")
        return 0
    return v
}

ApplyWebAppearance(v) {
    Config.tipPosition := v[8]
    Config.tipMouseOffset := v[9]
    Config.tipMouseAbove := v[10]
    Config.tipTopOffset := v[11]
    Config.tipBottomOffset := v[12]
    Config.tipFontSize := v[13]
    Config.tipFontBold := v[14]
    Config.tipLightMode := v[15]
}

CommitWebSettings() {
    Critical()
    state := WebSettingsState()
    pending := state.pending
    state.pending := 0
    if !pending
        return
    v := pending.values
    old := WebSettingsValues(Config, IsStartupEnabled())
    desired := JoinSettingsValues(v)
    ; The first value is managed in the registry and does not require an INI write.
    if (SubStr(desired, 3) != SubStr(JoinSettingsValues(old), 3)) {
        ApplyWebValues(v)
        if Config.Save()
            ApplySettings()
        else {
            ApplyWebValues(old)
            ReportWebSettingsError(pending.sender, desired)
            return
        }
    }
    if (old[1] != v[1]) {
        SetStartup(v[1])
        if (IsStartupEnabled() != v[1])
            ReportWebSettingsError(pending.sender, desired)
    }
}

ReportWebSettingsError(sender, desired) {
    state := WebSettingsState()
    if (sender = state.child && SettingsSenderMatches(sender, state.pid))
        SendSettingsMessage(sender, "apply-error|" desired "|" JoinSettingsValues(WebSettingsValues(Config, IsStartupEnabled())))
}

ApplyWebValues(v) {
    ApplyWebAppearance(v)
    Config.enableCapsTip := v[2]
    Config.showIMEStatus := v[3]
    Config.enableCopyTip := v[4]
    Config.enableSelectTip := v[5] = 1
    Config.autoCopySelection := v[5] = 2
    Config.capsShowDuration := v[6]
    Config.copyShowDuration := v[7]
    Config.language := v[16]
}

RunWebSettings(parent) {
    DllCall("GetWindowThreadProcessId", "ptr", parent, "uint*", &pid := 0)
    if !pid
        ExitApp()
    Suspend(true)
    Config.Load()
    session := SettingsWebView(parent, pid)
    try session.Open()
    catch as e
        session.Fail(e)
}

SettingsAssetBase64(path) {
    data := FileRead(path, "RAW")
    flags := 0x40000001 ; CRYPT_STRING_BASE64 | CRYPT_STRING_NOCRLF
    if !DllCall("Crypt32\CryptBinaryToStringW", "ptr", data, "uint", data.Size, "uint", flags, "ptr", 0, "uint*", &length := 0)
        throw OSError()
    encoded := Buffer(length * 2)
    if !DllCall("Crypt32\CryptBinaryToStringW", "ptr", data, "uint", data.Size, "uint", flags, "ptr", encoded, "uint*", &length)
        throw OSError()
    return StrGet(encoded, "UTF-16")
}

class SettingsWebView {
    __New(parent, pid) {
        this.parent := parent
        this.parentPid := pid
        this.controller := this.web := 0
        this.handlers := []
        this.ready := false
        this.navigated := false
        this.closing := false
    }

    Open() {
        ; Keep this profile separate from Edge and from other applications' WebViews.
        dir := EnvGet("LOCALAPPDATA") "\CursorTip\Settings"
        loader := A_ScriptDir "\assets\webview2\loader-" (A_PtrSize = 8 ? "x64" : "x86") ".dll"
        if A_IsCompiled {
            sdk := dir "\sdk-1.0.2903.40"
            DirCreate(sdk)
            loader := sdk "\loader-" (A_PtrSize = 8 ? "x64" : "x86") ".dll"
            if A_PtrSize = 8
                FileInstall("assets\webview2\loader-x64.dll", loader, 1)
            else
                FileInstall("assets\webview2\loader-x86.dll", loader, 1)
            FileInstall("assets\webview2\LICENSE.txt", sdk "\LICENSE.txt", 1)
        }
        module := DllCall("LoadLibraryExW", "wstr", loader, "ptr", 0, "uint", 0x900, "ptr")
        if !module
            throw OSError()
        create := DllCall("GetProcAddress", "ptr", module, "astr", "CreateCoreWebView2EnvironmentWithOptions", "ptr")
        if !create
            throw OSError()
        minWidth := 520, minHeight := 484
        this.gui := Gui("+Resize +MinSize" minWidth "x" minHeight, "CursorTip · " (DetectLang() = "zh" ? "设置" : "Settings"))
        this.gui.BackColor := GetSystemTheme() = "dark" ? "212123" : "FAFAFA"
        this.gui.OnEvent("Close", (*) => this.RequestClose())
        this.gui.OnEvent("Escape", (*) => this.RequestClose())
        this.gui.OnEvent("Size", ObjBindMethod(this, "OnSize"))
        saved := IniRead(Config.Path, "SettingsWindow", "Size", "")
        width := 592, height := 532
        if RegExMatch(saved, "^(\d{1,5})x(\d{1,5})$", &size) {
            width := Integer(size[1])
            height := Integer(size[2])
        }
        MonitorGetWorkArea(, &left, &top, &right, &bottom)
        width := Max(minWidth, Min(width, Floor((right - left) * 96 / A_ScreenDPI) - 32))
        height := Max(minHeight, Min(height, Floor((bottom - top) * 96 / A_ScreenDPI) - 60))
        this.gui.Show("Hide w" width " h" height)
        this.gui.GetClientPos(,, &openedWidth, &openedHeight)
        this.openedSize := this.normalSize := openedWidth "x" openedHeight
        this.receive := ObjBindMethod(this, "FromParent")
        OnMessage(0x4A, this.receive)
        this.watch := ObjBindMethod(this, "CheckParent")
        this.timeout := (*) => this.Fail(Error("WebView2 initialization timed out"))
        SetTimer(this.watch, 500)
        SetTimer(this.timeout, -12000)
        handler := this.Handler("4E8A3389-C9D8-4BD2-B6B5-124FEE6CC14D", "EnvironmentReady")
        DllCall(create, "ptr", 0, "wstr", dir "\profile", "ptr", 0, "ptr", handler, "hresult")
    }

    EnvironmentReady(result, environment) {
        if (result < 0 || !environment)
            throw Error(Format("WebView2 environment HRESULT 0x{:08X}", result & 0xFFFFFFFF))
        handler := this.Handler("6C4819F3-C9B7-4260-8127-C9F5BDE7F68C", "ControllerReady")
        ComCall(3, environment, "ptr", this.gui.Hwnd, "ptr", handler)
    }

    ControllerReady(result, controller) {
        if (result < 0 || !controller)
            throw Error(Format("WebView2 controller HRESULT 0x{:08X}", result & 0xFFFFFFFF))
        ObjAddRef(controller)
        this.controller := ComValue(13, controller)
        ComCall(25, this.controller, "ptr*", &web := 0)
        this.web := ComValue(13, web)
        ComCall(3, this.web, "ptr*", &settings := 0)
        settings := ComValue(13, settings)
        for slot in [8, 10, 12, 14, 16, 18]
            ComCall(slot, settings, "int", 0)
        this.Listen(7, "9ADBE429-F36D-432B-9DDC-F8881FBD76E3", "GuardNavigation")
        this.Listen(34, "57213F19-00E6-49FA-8E07-898EA01ECBD2", "FromPage")
        this.Listen(44, "D4C185FE-C81C-4989-97AF-2D3FA7AB5651", "BlockNewWindow")
        this.Resize()
        dest := A_ScriptDir "\settings\settings.html"
        logo := A_ScriptDir "\assets\logo.png"
        github := A_ScriptDir "\assets\github.ico"
        if A_IsCompiled {
            dest := EnvGet("LOCALAPPDATA") "\CursorTip\Settings\settings.html"
            logo := EnvGet("LOCALAPPDATA") "\CursorTip\Settings\logo.png"
            github := EnvGet("LOCALAPPDATA") "\CursorTip\Settings\github.ico"
            FileInstall("settings\settings.html", dest, 1)
            FileInstall("assets\logo.png", logo, 1)
            FileInstall("assets\github.ico", github, 1)
        }
        html := StrReplace(FileRead(dest, "UTF-8"), "{{LOGO_PNG}}", SettingsAssetBase64(logo))
        html := StrReplace(html, "{{GITHUB_ICON}}", SettingsAssetBase64(github))
        ComCall(6, this.web, "wstr", html)
    }

    OnSize(gui, state, width, height) {
        if (this.ready && state = 0)
            this.normalSize := width "x" height
        if (state != -1)
            this.Resize()
    }

    Resize() {
        if !this.controller
            return
        rect := Buffer(16, 0)
        DllCall("GetClientRect", "ptr", this.gui.Hwnd, "ptr", rect)
        if A_PtrSize = 8
            ComCall(6, this.controller, "ptr", rect)
        else
            ComCall(6, this.controller, "int64", NumGet(rect, 0, "int64"), "int64", NumGet(rect, 8, "int64"))
    }

    Listen(slot, iid, method) {
        ComCall(slot, this.web, "ptr", this.Handler(iid, method), "int64*", &token := 0)
    }

    ; Minimal IUnknown + Invoke vtable for WebView2's STA event handlers.
    ; Callback buffers live in the settings process until controller shutdown.
    Handler(iid, method) {
        guid := Buffer(16)
        DllCall("ole32\CLSIDFromString", "wstr", "{" iid "}", "ptr", guid, "hresult")
        handler := {vtable: Buffer(4 * A_PtrSize), object: Buffer(A_PtrSize), refs: 1}
        query := CallbackCreate((self, id, out) => this.QueryHandler(handler, guid, self, id, out), , 3)
        add := CallbackCreate((*) => ++handler.refs, , 1)
        release := CallbackCreate((*) => --handler.refs, , 1)
        invoke := CallbackCreate((self, a, b) => this.Invoke(method, a, b), , 3)
        NumPut("ptr", query, "ptr", add, "ptr", release, "ptr", invoke, handler.vtable)
        NumPut("ptr", handler.vtable.Ptr, handler.object)
        this.handlers.Push(handler)
        return handler.object.Ptr
    }

    QueryHandler(handler, guid, self, id, out) {
        unknown := NumGet(id, 0, "int64") = 0 && NumGet(id, 8, "uint64") = 0x46000000000000C0
        own := NumGet(id, 0, "int64") = NumGet(guid, 0, "int64") && NumGet(id, 8, "int64") = NumGet(guid, 8, "int64")
        NumPut("ptr", unknown || own ? self : 0, out)
        if !(unknown || own)
            return 0x80004002
        handler.refs++
        return 0
    }

    Invoke(method, a, b) {
        if !this.closing {
            try this.%method%(a, b)
            catch as e
                SetTimer(ObjBindMethod(this, "Fail", e), -1)
        }
        return 0
    }

    ReadString(args, slot) {
        ComCall(slot, args, "ptr*", &ptr := 0)
        try return ptr ? StrGet(ptr, "UTF-16") : ""
        finally DllCall("ole32\CoTaskMemFree", "ptr", ptr)
    }

    GuardNavigation(sender, args) {
        if this.navigated || !RegExMatch(this.ReadString(args, 3), "^(about:blank|data:text/html;charset=utf-8;base64,)")
            ComCall(8, args, "int", 1)
        else
            this.navigated := true
    }

    BlockNewWindow(sender, args) => ComCall(6, args, "int", 1)

    FromPage(sender, args) {
        if (this.ReadString(args, 3) != "about:blank")
            return
        try message := this.ReadString(args, 5)
        catch
            return
        if (message = "ready" && !this.ready) {
            lang := DetectLang()
            this.Post("init|" VERSION "|" lang "|" JoinSettingsValues(WebSettingsValues(Config, IsStartupEnabled()))
                "|" JoinSettingsValues(WebSettingsValues(Config.Defaults, false)))
        } else if (message = "painted" && !this.ready) {
            this.ready := true
            SetTimer(this.timeout, 0)
            this.gui.Show()
            ComCall(4, this.controller, "int", 1) ; IsVisible
            if !SendSettingsMessage(this.parent, "ready")
                SetTimer(ObjBindMethod(this, "Close"), -1)
        } else if this.ready {
            if (message = "close")
                SetTimer(ObjBindMethod(this, "Close"), -1)
            else if (SubStr(message, 1, 6) = "apply|") {
                if !SendSettingsMessage(this.parent, message)
                    this.Post("apply-unavailable|" SubStr(message, 7))
            } else if (message = "check" || message = "changelog" || message = "repository")
                SendSettingsMessage(this.parent, message)
            else if (SubStr(message, 1, 8) = "preview|" && (v := ReadWebSettingsValues(SubStr(message, 9))))
                SetTimer(ObjBindMethod(this, "Preview", v), -1)
        }
    }

    Post(message) {
        if this.web
            ComCall(33, this.web, "wstr", message)
    }

    FromParent(sender, data, *) {
        if (sender != this.parent || !SettingsSenderMatches(sender, this.parentPid))
            return 0
        message := ReadSettingsMessage(data)
        if (SubStr(message, 1, 12) = "apply-error|" || SubStr(message, 1, 7) = "update|")
            SetTimer(ObjBindMethod(this, "Post", message), -1)
        return 1
    }

    Preview(v) {
        if this.closing
            return
        global curLang
        ApplyWebAppearance(v)
        curLang := v[16] = "auto" ? DetectLang() : v[16]
        MeasureTipFixedWidth()
        ShowTip((curLang = "zh" ? "大写 · 中文" : "CAPS · EN"), v[6], true)
    }

    CheckParent() {
        if !SettingsSenderMatches(this.parent, this.parentPid)
            this.Close()
    }

    Fail(error) {
        if this.closing
            return
        ErrorLog("Web settings: " error.Message)
        SendSettingsMessage(this.parent, "fallback")
        this.Close()
    }

    RequestClose() {
        ; Give the page a chance to commit an active number field before destroying it.
        SetTimer(ObjBindMethod(this, "Close"), -1000)
        if this.ready
            this.Post("closing")
        return true
    }

    Close(*) {
        if this.closing
            return
        this.closing := true
        ; Window dimensions are stored separately from the settings values.
        if (this.ready && this.normalSize != this.openedSize) {
            try IniWrite(this.normalSize, Config.Path, "SettingsWindow", "Size")
            catch as e
                ErrorLog("Settings window size: " e.Message)
        }
        SendSettingsMessage(this.parent, "closed")
        if this.controller
            try ComCall(24, this.controller) ; ICoreWebView2Controller::Close
        this.web := this.controller := 0
        ExitApp()
    }
}
