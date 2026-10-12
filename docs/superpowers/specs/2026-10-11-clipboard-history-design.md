# 剪贴板历史 — 设计规格

日期：2026-10-11
状态：待实现

## 目标

CursorTip 增加剪贴板历史：热键弹出面板 → 上下键选 → Enter 把内容写回剪贴板 → 用户自己 Ctrl+V。

**只存文本。不做自动粘贴、图片存储、搜索、置顶。**

## 用户可见行为

| 操作 | 结果 |
|:---|:---|
| 复制任意文本 | 静默记入历史（现有复制气泡提示行为不变） |
| `Ctrl+Shift+V`（可在设置里改） | 面板在鼠标位置弹出，不抢焦点 |
| `↑` / `↓` | 移动选中行，超出可视区自动滚动 |
| `Enter` | 选中内容写回剪贴板，面板关闭，焦点仍在原窗口 → 直接 `Ctrl+V` |
| `Delete` | 删除选中条目；删完最后一条自动关面板 |
| `Esc` | 关闭面板 |
| 面板已开时按快捷键 | 无动作（关闭只走 `Esc`，见下） |
| 历史为空时按快捷键 | 不弹面板 |

**快捷键刻意不做「再按一次关闭」**：按住热键会持续触发键盘自动重复（约每 30ms 一次），
toggle 语义必然导致面板开关来回闪屏。试过 250ms 防抖，只是把闪烁放慢，没根治 —— 唯一干净的解法是面板开着时热键不响应。

**面板不能拖动**：这是设计取舍，不是缺陷 —— 无边框(`-Caption`) + 不抢焦点(`NA`) + 跟随鼠标位置，
三者是同一套「像气泡一样浮在光标旁」的视觉/交互方案。要拖动得改回有标题栏，或另加
`WM_NCHITTEST` 拖拽区，而后者会让点击列表选中行也变成拖动。

## 文件布局

```
CursorTip.ahk            改：Config 3 项 + 注册/注销回调 + 设置控件 + i18n
ClipboardHistory.ahk     新增：数据层 + 面板 + 键盘处理
clipboard_history.dat    运行时生成：历史数据（A_ScriptDir）
```

`ClipboardHistory.ahk` 通过 `#Include` 挂在 `VERSION.ahk`（`CursorTip.ahk:22`）之后。
主文件不新增业务逻辑，只做接线。

## 数据层

### 存储格式

路径：`A_ScriptDir\clipboard_history.dat`（与 `config.ini` 同目录；该目录可写性已由现有 `config.ini` 证明）

每条一行，字段用 TAB 分隔，文本做转义：

```
2026-10-11T01:39:30<TAB>转义后的文本
2026-10-11T01:39:25<TAB>另一条
```

- 写：`FileOpen(Path, "w", "UTF-8")` 覆盖式一次写全量（**不能用 FileAppend** —— v2 的 FileAppend 只有 3 参且 Options 仅接受编码/RAW，永远是追加模式，传 `"w"` 抛 `Invalid option`）
- 读：`Loop Parse, FileRead(Path, "UTF-8"), "\n", "\r"`
- 转义：写时 `\` → `\\`、`CR` → `\r`、`LF` → `\n`、`TAB` → `\t`（反斜杠最先处理）；读时用单遍正则 `\\(.)` 还原，避免顺序 `StrReplace` 把 `\\n` 误还原成换行

> **已废弃的方案**：最初设计用 NUL(`Chr(0)`) 分隔以省掉转义。实测 **AHK v2 的 `StrSplit(s, Chr(0))` 是坏的** —— 3 段输入全部塌成首字符（返回 `["A","A","A"]`），导致历史被拆成单字符、面板显示乱码，且回写时把文件进一步损坏。

### 内存结构

```ahk
global ClipHistory := []    ; [{t: "2026-10-11T10:23:45", v: "文本"}, ...] 最新的在 [1]
```

### 规则

| 规则 | 实现 |
|:---|:---|
| 空文本不记 | `StrLen(text) == 0` 直接返回 |
| 超长不记 | `StrLen(text) > 65536` 丢弃 + 写 debug.log（防止单条撑爆文件） |
| 去重 | 文本完全相同 → 从原位置删掉，重新插到最前 |
| 裁剪 | `while (ClipHistory.Length > Config.clipboardHistoryMax) ClipHistory.Pop()` |
| 时间戳 | `FormatTime(, "yyyy-MM-ddTHH:mm:ss")` 写入，面板显示用 `MM-dd HH:mm` |

`Pop()` 删末尾 = 删最早，因此裁剪天然满足"超出上限自动删最早的"。

### `TrimHistory()` 的三个调用点

1. `PushHistory()` 写入后
2. 启动 `LoadHistory()` 之后（上限在 config.ini 里可能被调小过）
3. 保存设置后（用户改小了上限，要立刻生效并重写文件）

## 采集：独立回调，不侵入 ClipChanged

`CursorTip.ahk` 的 `ClipChanged` **一行不改**。历史用独立回调，以 `-1` 前置注册：

```ahk
OnClipboardChange(HistClipChanged, -1)   ; AddRemove=-1 → 排在既有回调之前
```

`HistClipChanged` 只在 `Config.enableClipboardHistory` 为真且剪贴板是文本时 `PushHistory`。
它返回 0（默认），不影响后续 `ClipChanged` 执行。

比在 `ClipChanged` 的 if/else 分支里插桩更干净：两件事解耦，关掉复制提示不影响历史，反之亦然。

### 注册条件（`CursorTip.ahk:421` `InitMonitors` / `:433` `ApplySettings`）

```ahk
; 原来
OnClipboardChange(ClipChanged)
; 改为（两处对称）
OnClipboardChange(HistClipChanged, 0)          ; 先注销，防重复注册
if (c.enableClipboardHistory)
    OnClipboardChange(HistClipChanged, -1)
```

注销在前、注册在后，与现有 `ApplySettings`（`:448-450`）的模式一致。

## 回填：自触发抑制

官方文档明确：脚本自身修改剪贴板时，`OnClipboardChange` 的回调**仍会执行**（只是延后）。回填 → 历史里凭空多一条刚才那条。

```ahk
global suppressClip := false
```

- `FillFromHistory()` 写 `A_Clipboard` 前置 `true`
- `HistClipChanged` / `ClipChanged` 开头读到 `suppressClip` 立即 return
- 写完 `Sleep(30)` 后置回 `false`（依据官方文档，需短延迟让回调尽快执行完再解除）

**不复用 `clipboardProcessing`**：那个是 `ClipChanged` 内部的防重入位，复用会让回填期间的正常复制被吞掉。

## 面板

### 外观：完全复用 tip 窗口的既有代码

沿用 `CursorTip.ahk:885-913` 的全套：

- `Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20 +E0x02000000")`
- `DwmSetWindowAttribute` 圆角(33/2) + 禁用过渡动画(3/1)，整段 try 包裹
- 配色走 `GetSystemTheme()`，与 tip 同一套 light/dark 分支
- 字体 `Microsoft YaHei`，字号跟随 `Config.tipFontSize`

**不发明第二套视觉。**

### 结构

```
Gui
└ ListView (Report, 2 列)     ← 条目
└ Text                        ← 底部快捷键提示
```

- 列：`内容`（默认宽 320）/ `时间`（宽 90）
- 条目多行文本折叠为单行显示（`StrReplace(text, "`r`n", " ⏎ ")`），超 100 字符截断加 `…`
- **显示层截断，内存/磁盘里存全量**——回填必须拿到原文

**没有空状态 UI**：历史为空时 `Ctrl+Shift+V` 直接不响应；用 `Delete` 删掉最后一条时面板自动关闭。省掉一个占位控件和一套文案。

### 定位

跟随鼠标，复用 `ShowTipAt`（`:818`）case 1 的算法：`MouseGetPos` → `x = mx + tipMouseOffset`，`y` 按 `tipMouseAbove` 取上/下，`NA` 显示（不抢焦点）。

## 键盘：动态热键

NA 窗口的 ListView 不接收键盘事件，导航靠临时热键接管。

### 注册

启动时注册一次并置 Off（用 `Hotkey()` 函数形式，项目此前只用 `::` 指令式，这是首处函数式热键）：

```ahk
Hotkey("Up",     HistUp,     "Off")
Hotkey("Down",   HistDown,   "Off")
Hotkey("Enter",  HistEnter,  "Off")
Hotkey("Esc",    HistClose,  "Off")
Hotkey("Delete", HistDel,    "Off")
```

面板开→关时统一切换（`Hotkey(k, "On"/"Off")` 只改 Options、不改 Action，官方文档支持）：

```ahk
SetHistNavKeys(on) {
    static keys := ["Up", "Down", "Enter", "Esc", "Delete"]
    for k in keys
        Hotkey(k, on ? "On" : "Off")
}
```

**面板关闭时这 5 个键必须处于 Off**，否则全局吞键。

### 与既有通配热键的关系

`CursorTip.ahk:1166-1289` 已注册 `~*Up::` / `~*Enter::` / `~*Esc::` / `~*Delete::` 等全键位通配热键（Shift 单独按下判定用）。

它们带 `~`（放行）前缀，与本功能用的非 `~` 热键并存时，AHK 会同时触发两者——但通配热键只写 `shiftAlone := false`，历史逻辑不依赖该变量。**无冲突。**

### 主热键

历史热键（可在设置里改）。面板开着时再按**无动作**（不做 toggle —— 键盘自动重复会让它闪屏，见上表）。

设置窗口获得焦点时不响应（避免在设置里误触）。

## 设置窗口

### 新增 Config 项

```ahk
; Defaults
enableClipboardHistory: true,
clipboardHistoryMax: 50,
clipboardHistoryKey: "^+v",
```

同名的静态属性、`Load()`、`Save()` 各加 2~3 行，与现有项完全同构。

### 控件布局

`功能开关` 区补一个复选框（`x200 y82` 正好是 `ctl_ime` 下方的空位）：

```ahk
g.ctl_history := g.Add("CheckBox", "x200 y82 w140", T("set_history"))
g.ctl_history.Value := c.enableClipboardHistory
```

新增两整行：历史条数滑块 + 快捷键，用**内置 `Hotkey` 控件**（编辑框 + 抓键按钮，抓键逻辑不自己实现）：

```ahk
g.ctl_histMax := AddNumSlider(g, "histMax", 135, 119, 10, 200, c.clipboardHistoryMax, "", 10)
g.ctl_hotkey  := g.Add("Hotkey", "x135 y159 w185", c.clipboardHistoryKey)
```

行高取 **40**（不是 30）—— 复选框在 YaHei 下底边约 y104，行距 30 会让控件贴上去，
代码注释里已警告过贴太近会出悬停重绘伪影。

**插入两行 → 其下所有硬编码 Y 坐标整体 +80**（`ShowSettings` 中 y190 以下的约 27 处），
`SETTINGS_BASE_H` 由 `647` 改为 `727`。

`TrackBelow` 登记的是创建时的实际 Y，`ReflowBelow` 的 `(2 - rows) * 30` 折叠逻辑不受影响。

滑块是纯数值控件，不挂 `MakePreviewCb`（拖动历史条数不该触发 tip 预览，与 `capsDur`/`copyDur` 一致）。
但注意 `AddNumSlider` 内部会统一调 `OnPreviewChange(kind)`，**必须把 `"histMax"` 加进
`OnPreviewChange` 开头的短路判断**，否则拖动条数会每档弹一次预览 tip。

### 接线（现有机制逐个跟）

| 位置 | 改动 |
|:---|:---|
| `SnapshotSettings` `:1572` | +`history: g.ctl_history.Value`、+`histMax: g.ctl_histMax.Value` |
| `RestoreSettings` `:1595` | +`g.ctl_history.Value := s.history`、+`g.ctl_histMax.Value := s.histMax` |
| `SettingsReset` `:1845` | +复位复选框与滑块两行 |
| `SyncConfigFromGui` `:1884` | +`c.enableClipboardHistory := g.ctl_history.Value`、+`c.clipboardHistoryMax := Max(10, Min(200, Integer(g.ctl_histMax.Value \|\| 50)))` |
| `SettingsSave` `:1907` | `Config.Save()` 之后调 `TrimHistory()` + `SaveHistory()` |

`enableClipboardHistory` 走的是"保存才落盘"通路，不进 `SnapshotConfig()`（该函数只管即时预览的视觉属性，功能开关本就不在其中）。

## i18n

`L` 表新增 4 键 × 2 语言：

| key | zh | en |
|:---|:---|:---|
| `set_history` | `📋 剪贴板历史` | `📋 Clipboard history` |
| `set_histmax_label` | `历史条数:` | `Max entries:` |
| `hist_hint` | `↑↓ 选择　Enter 回填　Del 删除　Esc 关闭` | `↑↓ Select　Enter Fill　Del Delete　Esc Close` |

## .gitignore

```
config.ini
clipboard_history.dat
```

历史文件装的是用户剪贴板内容（可能是密码），必须与 `config.ini` 同等对待。

## 隐私说明

- 历史文件位于脚本目录，明文存储
- 密码管理器复制的密码会进历史（Windows 自带剪贴板历史同样如此，不是本功能独有）
- 用户可随时通过设置里的复选框关闭收集；关闭后 `InitMonitors` 的注销逻辑使其立即停止写入
- 文件不进 git

**已知不做**：密码字段自动排除（需读前台窗口类型，成本高）。用户知情即可。

## 验证

本项目无编译期检查 / 无测试。按 `CLAUDE.md` 流程：

1. `Ahk2Exe //silent` 编译，`EXIT=0` = 语法通过
2. `Ahk2Exe //silent` 通过后手动跑 `work/debug.log` 看新增日志行
3. **功能验证交还用户**——热键、GUI 键盘交互、跨应用粘贴 AI 无法自动测

自查清单：
- 复制 → 重启 → 历史仍在（持久化）
- 上限从 50 改到 10 → 历史当场缩到 10 条且文件重写（裁剪）
- Enter 回填后历史**不新增**条目（自触发抑制）
- 面板关闭时 ↑↓Enter/Esc 全局无反应（热键 Off）
- 关闭收集开关 → 复制不再写文件