/// 打卡弹窗（设计文档 3.2）：点标签立即开始记录；备注可空，随标签提交。
library;

import 'package:flutter/material.dart';

import '../services/event_store.dart';

/// 弹出打卡弹窗。
void showPunchSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => const PunchSheet(),
  );
}

class PunchSheet extends StatefulWidget {
  const PunchSheet({super.key});

  @override
  State<PunchSheet> createState() => _PunchSheetState();
}

class _PunchSheetState extends State<PunchSheet> {
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  /// 点标签：立即记录（备注可空）并关闭。
  void _punch(String label) {
    EventStore.instance.punch(label, note: _noteController.text);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labels = EventStore.instance.labels; // 有序分类
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('现在在做什么？', style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final label in labels)
                  Builder(
                    builder: (ctx) {
                      final c = EventStore.instance.colorOf(label);
                      final onC = c.computeLuminance() > 0.5
                          ? Colors.black87
                          : Colors.white;
                      return ActionChip(
                        label: Text(label, style: TextStyle(color: onC)),
                        backgroundColor: c,
                        side: BorderSide(color: c.withValues(alpha: 0.6)),
                        onPressed: () => _punch(label),
                      );
                    },
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                hintText: '备注',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              textInputAction: TextInputAction.done,
            ),
          ],
        ),
      ),
    );
  }
}
