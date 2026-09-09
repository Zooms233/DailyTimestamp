/// 自动存档：每日备份一份快照，防数据文件被误删/损坏。
/// - 位置：`Documents/DailyTimestamp/`（与主数据 events.json 同目录；Android 为
///   公共 Documents，卸载不清；需"所有文件访问"授权，见 storage_access.dart）。
/// - 命名：`DailyTimestamp_backup_YYYYMMDD.json`，每日一份，当天内覆盖。
/// - 时机：每次记录新事件（punch）触发；距上次备份 ≥1h 才重写（恢复窗口 ≤1h）。
/// - 轮转：仅清理 `DailyTimestamp_backup_` 前缀的文件，按文件名日期保留最近 9 份。
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'storage_access.dart';

class BackupService {
  BackupService._();

  /// 保留的备份份数（按文件名日期轮转）。
  static const keepCount = 9;

  /// 备份文件名前缀（轮转只清理该前缀文件，不碰其他文件）。
  static const prefix = 'DailyTimestamp_backup_';

  /// 当天备份最短刷新间隔（间隔内跳过，减小写盘与恢复窗口）。
  static const minRefresh = Duration(hours: 1);

  static bool _running = false;

  /// 备份目录（与主数据同目录）。
  static Future<Directory> resolveDir() => StorageAccess.root();

  /// punch 触发的自动备份（每日一份 + ≥1h 节流）；开关关闭直接跳过。
  /// 全程静默失败（debugPrint），不影响打卡主流程。
  static Future<File?> autoBackup(
      {required bool enabled, required String json}) async {
    if (!enabled) return null;
    try {
      return await _write(json: json, force: false);
    } catch (e) {
      debugPrint('BackupService.autoBackup: $e');
      return null;
    }
  }

  /// 手动立即备份（设置页"立即备份"）：忽略开关与节流，强制重写当天文件。
  /// 失败返回 null（调用方提示）。
  static Future<File?> backupNow({required String json}) async {
    try {
      return await _write(json: json, force: true);
    } catch (e) {
      debugPrint('BackupService.backupNow: $e');
      return null;
    }
  }

  /// 写当天备份文件并轮转。
  static Future<File?> _write(
      {required String json, required bool force}) async {
    if (_running) return null; // 防并发重复写
    _running = true;
    try {
      final dir = await resolveDir();
      final now = DateTime.now();
      String p2(int v) => v.toString().padLeft(2, '0');
      final name =
          '$prefix${now.year}${p2(now.month)}${p2(now.day)}.json';
      final f = File('${dir.path}${Platform.pathSeparator}$name');
      if (!force && await f.exists()) {
        final age = now.difference((await f.stat()).modified);
        if (age < minRefresh) return f; // 当天备份仍新鲜，跳过
      }
      await f.writeAsString(json, flush: true);
      await _rotate(dir);
      return f;
    } finally {
      _running = false;
    }
  }

  /// 轮转：按文件名（日期序）保留最近 [keepCount] 份，仅删本前缀文件。
  static Future<void> _rotate(Directory dir) async {
    final backups = <File>[];
    await for (final e in dir.list()) {
      if (e is File && _isBackupName(e.uri.pathSegments.last)) {
        backups.add(e);
      }
    }
    if (backups.length <= keepCount) return;
    backups.sort((a, b) => a.path.compareTo(b.path)); // YYYYMMDD 字典序=时间序
    for (final f in backups.take(backups.length - keepCount)) {
      try {
        await f.delete();
      } catch (_) {/* 单个删除失败不阻塞 */}
    }
  }

  /// 现有备份文件（旧→新），供设置页展示。
  static Future<List<File>> list() async {
    try {
      final dir = await resolveDir();
      final out = <File>[];
      await for (final e in dir.list()) {
        if (e is File && _isBackupName(e.uri.pathSegments.last)) {
          out.add(e);
        }
      }
      out.sort((a, b) => a.path.compareTo(b.path));
      return out;
    } catch (e) {
      debugPrint('BackupService.list: $e');
      return const [];
    }
  }

  static bool _isBackupName(String name) =>
      name.startsWith(prefix) && name.endsWith('.json');
}
