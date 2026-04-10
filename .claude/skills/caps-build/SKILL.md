---
name: caps-build
description: 编译 CursorTip AHK 脚本为 EXE 可执行文件。当用户说"编译"、"打包"、"构建"、"生成exe"、"封装成exe"时使用。
---

# CursorTip 编译

将 CursorTip.ahk 编译为带图标的 EXE 可执行文件。

## Instructions

### Step 1: 更新版本号（可选）

如果用户要求更新版本号，读取 `CursorTip.ahk` 中的版本号（`global VERSION := "x.y.z"`），按二十进制递增 PATCH 位：

- 每位范围 0-19，不存在 20+
- PATCH 到 19 → MINOR+1, PATCH=0
- MINOR 到 19 → MAJOR+1, MINOR=0, PATCH=0

更新文件中的版本号后再编译。如果用户说"不用改版本号"，跳过此步。

### Step 2: 检查资源文件嵌入

编译前必须确认脚本中的外部资源文件（图标、图片等）已通过 `FileInstall` 嵌入：

```autohotkey
; 正确：FileInstall 将文件嵌入 exe，运行时释放到临时目录
icoPath := A_Temp . "\CursorTip_github.ico"
FileInstall("assets\github.ico", icoPath, 1)
pic := g.Add("Picture", "x20 y500 w16 h16", icoPath)

; 错误：相对路径在编译后找不到文件
pic := g.Add("Picture", "x20 y500 w16 h16", "assets/github.ico")

; 错误：A_ScriptDir 拼接在 exe 单独运行时可能找不到 assets 目录
pic := g.Add("Picture", "x20 y500 w16 h16", A_ScriptDir . "\assets\github.ico")
```

**规则**：任何 GUI 控件引用的外部资源文件（ico/png/jpg 等），必须用 `FileInstall` 嵌入，不能依赖相对路径或 `A_ScriptDir` 拼接。

### Step 3: 执行编译

在 Git Bash 中运行以下命令：

输出文件名必须带版本号，格式：`CursorTip_v{版本号}.exe`（如 `CursorTip_v2.0.3.exe`）。

```bash
"/c/Program Files/AutoHotkey/Compiler/Ahk2Exe.exe" \
  //in "<项目目录>\\CursorTip.ahk" \
  //out "<项目目录>\\CursorTip_v{版本号}.exe" \
  //base "C:\\Program Files\\AutoHotkey\\v2\\AutoHotkey64.exe" \
  //compress 0 \
  //icon "<项目目录>\\assets\\capslocker_macos_bigsur_icon_190309.ico"
```

**关键注意事项**：
- `//icon` 参数是**必须的**，将托盘图标嵌入 exe，否则 exe 运行时依赖外部 ico 文件
- Ahk2Exe 的参数前缀在 Git Bash 下必须用 `//` 双斜杠，单斜杠会被 shell 吞掉
- `//in`、`//out`、`//base`、`//compress`、`//icon` 都是双斜杠
- 项目目录中的反斜杠路径要用 `\\` 转义（因为 Ahk2Exe 是 Windows 原生程序）
- `//compress 0` 不压缩，避免杀毒误报
- 不要覆盖已有 exe，输出带版本号的新文件

### Step 4: 确认结果

编译成功后会输出 `Successfully compiled as: ...`，确认 EXE 已生成。

## Examples

**用户说："帮我编译一下"**
1. 读取当前版本号 v2.0.2 → 递增为 v2.0.3
2. 更新 `CursorTip.ahk` 中的 `VERSION`
3. 检查资源文件是否都已 FileInstall 嵌入
4. 编译输出为 `CursorTip_v2.0.3.exe`
5. 报告结果

**用户说："编译，不用改版本号"**
1. 跳过版本号更新，读取当前版本号
2. 检查资源文件是否都已 FileInstall 嵌入
3. 直接编译，输出为 `CursorTip_v{当前版本号}.exe`
4. 报告结果
