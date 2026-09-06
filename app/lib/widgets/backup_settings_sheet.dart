/// 自动存档设置弹窗（统计页 ⚙，doc/pages.md 3.4）：
/// 开关（持久化 settings）+ 备份位置 + 立即备份 + 最近备份列表。
library;

import 'dart:io';

import 'package:flutter/material.dart';

import '../services/backup_service.dart';
import '../services/event_store.dart';
import '../utils/format.dart';

/// 弹出自动存档设置弹窗。
void showBackupSettingsSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => const BackupSettingsSheet(),
  );
}

class BackupSettingsSheet extends StatefulWidget {
  const BackupSettingsSheet({super.key});

  @override
  State<BackupSettingsSheet> createState() => _BackupSettingsSheetState();
}

class _BackupSettingsSheetState extends State<BackupSettingsSheet> {
  Directory? _dir;
  List<File>? _files;
  String? _result; // 最近一次操作反馈
  bool _busy = false; // 立即备份进行中

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final dir = await BackupService.resolveDir();
    final files = await BackupService.list();
    if (!mounted) return;
    setState(() {
      _dir = dir;
      _files = files;
    });
  }

  /// 立即备份：完成后刷新列表并提示。
  Future<void> _backupNow() async {
    setState(() {
      _busy = true;
      _result = null;
    });
    final f =
        await BackupService.backupNow(json: EventStore.instance.encode());
    if (!mounted) return;
    setState(() {
      _busy = false;
      _result = f == null
          ? '备份失败（Documents 目录不可写？）'
          : '已备份：${f.uri.pathSegments.last}';
    });
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final store = EventStore.instance;
    final loc = _dir;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('自动存档', style: theme.textTheme.titleLarge),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: store.autoBackup,
              onChanged: (v) => setState(() => store.setAutoBackup(v)),
              title: const Text('自动存档'),
              subtitle: const Text('每次记录新事件时自动备份；每日一份，'
                  '距上次超过 1 小时才刷新；保留最近 9 份'),
            ),
            // 数据文件与备份同目录（Documents/DailyTimestamp）
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.folder_outlined),
              title: const Text('数据与备份位置'),
              subtitle: Text(loc == null ? '…' : loc.path,
                  style: theme.textTheme.bodySmall),
            ),
            OutlinedButton.icon(
              onPressed: _busy ? null : _backupNow,
              icon: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.backup_outlined),
              label: const Text('立即备份'),
            ),
            if (_result != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_result!,
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant)),
              ),
            const Divider(height: 24),
            // 备份列表
            Text('最近备份（最多保留 9 份）',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 4),
            if (_files == null)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_files!.isEmpty)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text('暂无备份，打卡后自动生成',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outline)),
              )
            else
              ..._files!.reversed.map((f) {
                final st = f.statSync();
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.description_outlined, size: 20),
                  title: Text(f.uri.pathSegments.last,
                      style: theme.textTheme.bodySmall),
                  subtitle: Text(
                    '${(st.size / 1024).toStringAsFixed(0)} KB · ${fmtClock(st.modified.millisecondsSinceEpoch)}',
                    style: theme.textTheme.bodySmall,
                  ),
                  // 点击查看前 200 字符，验证备份内容可读
                  onTap: () async {
                    final head =
                        (await f.readAsString()).substring(0, 120);
                    if (!context.mounted) return;
                    showDialog<void>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('备份内容预览'),
                        content: Text('$head …'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: const Text('关闭'),
                          ),
                        ],
                      ),
                    );
                  },
                );
              }),
          ],
        ),
      ),
    );
  }
}
