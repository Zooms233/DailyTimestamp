# 手机端数据备份 / 恢复备忘

> 更新于 2026-09-05。适用：release 包。
> 数据文件已迁至外部应用专属目录（`Android/data` 下），手机文件管理器可见，备份/恢复直接拷文件，不依赖 `run-as`/debug 包，App 也无需内置导入功能。

## 数据位置

| 端 | 路径 |
|---|---|
| Windows | `E:\Documents\events.json` |
| Android | `/storage/emulated/0/Android/data/io.github.zooms233.daily_timestamp/files/events.json`（文件管理器中：内部存储/Android/data/…/files/events.json） |

- 旧版（内部存储 `/data/user/0/…/app_flutter/`）数据由新版启动时**自动迁移**（拷贝后删除旧文件），无需手工处理。
- 拷贝前确保 **App 未运行**（最近任务里划掉）：App 会防抖写盘，运行中拷入的文件会被覆盖。
- Android 11+ 对 `Android/data` 有 scoped storage 限制：多数**系统自带**文件管理器可访问；第三方管理器和 adb（Android 13+ 部分 ROM）可能被拒 → 以自己机型实测为准。

## 备份（手机 → 电脑）

```bash
# adb（系统版本支持时）
adb pull /sdcard/Android/data/io.github.zooms233.daily_timestamp/files/events.json /e/backup/events_mobile_$(date +%F).json
```

或 USB(MTP)/文件管理器直拷。内置导出（统计页右上角）仍是通用兜底：Android 走系统分享面板，Windows 直存下载目录。

## 恢复 / 同步（电脑 → 手机）

1. 手机上划掉 App（确保未运行）。
2. 把 `events.json` 拷入 `Android/data/io.github.zooms233.daily_timestamp/files/` 覆盖。
3. 打开 App 即读到新数据。

```bash
adb push /e/Documents/events.json /sdcard/Android/data/io.github.zooms233.daily_timestamp/files/events.json
```

## 完整性校验

```bash
md5sum /e/Documents/events.json
md5sum /e/backup/events_mobile_20260905_1430.json
```

两端 MD5 一致即同步无误。

## 注意

1. **卸载 App 会同时清掉内部存储和 Android/data** → 卸载/换机前必须备份。
2. 两台设备数据各自独立演进；合并需手工（当前无自动合并工具）。
3. 若 `adb push/pull` 对该目录报 Permission denied（系统版本限制），改用文件管理器/MTP 拷贝。
