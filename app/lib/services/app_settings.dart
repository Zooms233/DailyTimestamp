/// 轻量应用设置持久化：目前只存主题模式（明亮/深色/跟随系统）。
/// 独立小文件 `Documents/DailyTimestamp/settings.json`，与数据文件
/// events.json 解耦——外观配置不混入数据，且不依赖数据加载时机。
/// 读写失败一律静默（未授权/文件损坏等），主题缺失仅回退默认值，不影响启动。
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import 'storage_access.dart';

const _settingsFileName = 'settings.json';

/// 恢复主题模式（启动时调用一次）；无字段/读取失败返回 null（保持默认跟随系统）。
Future<ThemeMode?> loadThemeMode() async {
  try {
    final dir = await StorageAccess.root();
    final file = File('${dir.path}${Platform.pathSeparator}$_settingsFileName');
    if (!await file.exists()) return null;
    final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    final saved = data['themeMode'] as String?;
    if (saved == null) return null;
    return ThemeMode.values.firstWhere((m) => m.name == saved,
        orElse: () => ThemeMode.system);
  } catch (_) {
    return null;
  }
}

/// 保存主题模式（统计页切换时调用）。
Future<void> saveThemeMode(ThemeMode mode) async {
  try {
    final dir = await StorageAccess.root();
    final file = File('${dir.path}${Platform.pathSeparator}$_settingsFileName');
    Map<String, dynamic> data = {};
    if (await file.exists()) {
      // 保留其它已存字段；文件损坏则从空重建
      try {
        data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      } catch (_) {}
    }
    data['themeMode'] = mode.name; // light / dark / system
    await file.writeAsString(jsonEncode(data));
  } catch (_) {
    // 写失败静默：主题是体验项，不值得打断用户
  }
}
