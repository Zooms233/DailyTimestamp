# 手机端数据备份 / 恢复备忘

> 更新于 2026-09-06。适用：release 包。
> 数据已统一存于公共文档目录（`Documents/DailyTimestamp/`），卸载/重装**不清**；App 需"所有文件访问"授权（未授权启动时被权限页阻塞，点"去授权"到系统设置开启）。

## 数据位置

| 内容 | 路径 |
|---|---|
| 主数据 | Android `/storage/emulated/0/Documents/DailyTimestamp/events.json`；Windows `文档目录\DailyTimestamp\events.json` |
| 自动存档 | 同目录 `DailyTimestamp_backup_YYYYMMDD.json`（每日一份，当天覆盖，距上次 ≥1h 刷新，保留 9 份） |

- **授权在卸载重装后会重置**：重装后首次启动会停在权限页，去授权即可，数据原地保留、无损。
- **手动迁移**（从旧位置 Android/data 迁入）：文件管理器/adb 把旧 events.json 拷入 `Documents/DailyTimestamp/` 即可，App 不做自动迁移。
- 拷贝前确保 **App 未运行**（最近任务里划掉）：App 会防抖写盘，运行中拷入的文件会被覆盖。

## 备份（手机 → 电脑）

```bash
# adb（公共 Documents 无需特殊权限）
adb pull /sdcard/Documents/DailyTimestamp/events.json /e/backup/events_mobile_$(date +%F).json
```

或 USB(MTP)/文件管理器直拷（Documents/DailyTimestamp 整个目录）。内置导出（统计页右上角）仍是通用兜底：Android 走系统分享面板，Windows 直存下载目录。

## 恢复 / 同步（电脑 → 手机）

1. 手机上划掉 App（确保未运行）。
2. 把 `events.json` 拷入 `/sdcard/Documents/DailyTimestamp/` 覆盖。
3. 打开 App 即读到新数据。

```bash
adb push /e/Documents/events.json /sdcard/Documents/DailyTimestamp/events.json
```

## 完整性校验

```bash
md5sum /e/Documents/events.json
md5sum /e/backup/events_mobile_20260905_1430.json
```

两端 MD5 一致即同步无误。

## 自动存档（App 内置，2026-09-06）

- 位置：Android 直接放公共下载目录根（Android 11+ 应用无法在公共目录自建子目录）；文件名 `DailyTimestamp_backup_YYYYMMDD.json`，**每日一份、当天覆盖**，距上次备份 ≥1h 才刷新，保留最近 9 份。
- 触发：每次**记录新事件**（开关默认开，存于 events.json 的 `settings.autoBackup`）；统计页 ⚙ 弹窗可开关、看位置、**立即备份**、查备份列表。
- 为什么放 Download：卸载时系统清 `Android/data` 与 MediaStore 归属本应用的多媒体文件，但公共下载文件保留（浏览器下载同理）。
- 恢复方法同上（拷回 events.json）；注意备份是每日快照，恢复点早于最后一次备份的记录会丢（窗口 ≤1h）。

## 注意

1. 公共 Documents/DailyTimestamp 目录本身随用户可见：误删主数据靠每日备份兜底（恢复窗口 ≤1h）。
2. 两台设备数据各自独立演进；合并需手工（当前无自动合并工具）。
