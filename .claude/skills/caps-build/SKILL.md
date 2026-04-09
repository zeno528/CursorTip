---
name: caps-build
description: 编译 CapsCopyTip AHK 脚本为 EXE 可执行文件。当用户说"编译"、"打包"、"构建"、"生成exe"、"封装成exe"时使用。
---

# CapsCopyTip 编译

将 CapsCopyTipv2.ahk 编译为带图标的 EXE 可执行文件。

## Instructions

### Step 1: 更新版本号

读取 `CapsCopyTipv2.ahk` 中的版本号（`global VERSION := "x.y.z"`），按二十进制递增 PATCH 位：

- 每位范围 0-19，不存在 20+
- PATCH 到 19 → MINOR+1, PATCH=0
- MINOR 到 19 → MAJOR+1, MINOR=0, PATCH=0

更新文件中的版本号后再编译。

### Step 2: 执行编译

在 Git Bash 中运行以下命令：

输出文件名必须带版本号，格式：`CapsCopyTip_v{版本号}.exe`（如 `CapsCopyTip_v2.0.2.exe`）。

```bash
rm -f "<项目目录>/CapsCopyTip_v*.exe" && \
"/c/Program Files/AutoHotkey/Compiler/Ahk2Exe.exe" \
  //in "<项目目录>\\CapsCopyTipv2.ahk" \
  //out "<项目目录>\\CapsCopyTip_v{版本号}.exe" \
  //base "C:\\Program Files\\AutoHotkey\\v2\\AutoHotkey64.exe" \
  //compress 0 \
  //icon "<项目目录>\\assets\\capslocker_macos_bigsur_icon_190309.ico"
```

**关键注意事项**：
- Ahk2Exe 的参数前缀在 Git Bash 下必须用 `//` 双斜杠，单斜杠会被 shell 吞掉
- `//in`、`//out`、`//base`、`//compress`、`//icon` 都是双斜杠
- 项目目录中的反斜杠路径要用 `\\` 转义（因为 Ahk2Exe 是 Windows 原生程序）
- `//compress 0` 不压缩，避免杀毒误报

### Step 3: 确认结果

编译成功后会输出 `Successfully compiled as: ...`，确认 EXE 已生成。

## Examples

**用户说："帮我编译一下"**
1. 读取当前版本号 v2.0.1 → 递增为 v2.0.2
2. 更新 `CapsCopyTipv2.ahk` 中的 `VERSION`
3. 编译输出为 `CapsCopyTip_v2.0.2.exe`
4. 报告结果

**用户说："编译，不用改版本号"**
1. 跳过版本号更新，读取当前版本号
2. 直接编译，输出为 `CapsCopyTip_v{当前版本号}.exe`
3. 报告结果
