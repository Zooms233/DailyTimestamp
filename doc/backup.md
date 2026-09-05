# 手机端数据备份 / 恢复备忘

> 记录于 2026-09-05。适用：本仓库 daily_timestamp App（Android debug 包）。

## 数据位置

| 端 | 路径 |
|---|---|
| Windows | `E:\Documents\events.json` |
| Android（应用私有目录） | `/data/user/0/io.github.zooms233.daily_timestamp/app_flutter/events.json` |

- 手机端文件管理器看不到，卸载 App 即丢失 → 需定期备份。
- debug 包可用 `run-as`；若改用 release 包，`run-as` 将失效，需换别的方案。
- 复制前确保 App 未运行（避免写冲突）。

## 备份（手机 → 电脑）

```bash
mkdir -p /e/backup
# 方式 A：cat 重定向（推荐，一条命令）
adb shell "run-as io.github.zooms233.daily_timestamp cat app_flutter/events.json" > /e/backup/events_mobile_$(date +%F).json

# 方式 B：经公共目录中转
adb shell "run-as io.github.zooms233.daily_timestamp cp app_flutter/events.json /sdcard/Download/events_mobile.json"
adb pull /sdcard/Download/events_mobile.json /e/backup/
```

## 恢复 / 同步（电脑 → 手机）

```bash
# 首次需要先建目录
adb shell run-as io.github.zooms233.daily_timestamp mkdir -p app_flutter
# 整体加引号，防止 shell 把重定向目标解析错（曾踩坑）
adb shell "run-as io.github.zooms233.daily_timestamp sh -c 'cat > app_flutter/events.json'" < /e/Documents/events.json
```

PowerShell 用户（cmd 中继，注意反斜杠路径）：

```powershell
cmd /c "adb shell ""run-as io.github.zooms233.daily_timestamp sh -c 'cat > app_flutter/events.json'"" < E:\Documents\events.json"
```

## 完整性校验

```bash
md5sum /e/Documents/events.json
adb shell run-as io.github.zooms233.daily_timestamp md5sum app_flutter/events.json
# 两端 MD5 一致即成功（2026-09-05 实测: 1684850b8378f41c377a83ffd6798d18）
```

## 日常建议

1. 手机端每次产生新记录后，顺手跑一次备份命令。
2. 卸载/重装 App 前必须备份。
3. 两台设备数据各自独立演进；需要合并时把两份 events.json 汇到一处后处理（当前无自动合并工具）。