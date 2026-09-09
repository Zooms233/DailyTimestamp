/// 打卡弹窗：点标签立即开始记录；备注可空，随标签提交。
/// 复用为「修改事件」弹窗（传入事件即编辑模式）：文案「当时在做什么？」，
/// 预填当前备注、当前类别打勾高亮，点任一标签（含当前类别）即时保存类别+备注。
library;

import 'package:flutter/material.dart';

import '../models/timestamp_event.dart';
import '../services/event_store.dart';

/// 弹出打卡弹窗。
void showPunchSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => const PunchSheet(),
  );
}

/// 弹出修改事件弹窗（复用打卡弹窗）：预填类别/备注，点标签保存并关闭。
Future<void> showEditEventSheet(BuildContext context, TimestampEvent event) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => PunchSheet.edit(event),
  );
}

class PunchSheet extends StatefulWidget {
  const PunchSheet({super.key}) : event = null;

  /// 编辑模式：修改既有事件的类别与备注。
  const PunchSheet.edit(this.event, {super.key});

  /// 非空 = 编辑模式（修改该事件）；空 = 打卡模式（记录新事件）。
  final TimestampEvent? event;

  @override
  State<PunchSheet> createState() => _PunchSheetState();
}

class _PunchSheetState extends State<PunchSheet> {
  late final TextEditingController _noteController =
      TextEditingController(text: widget.event?.note);

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  /// 点标签：打卡模式立即记录（备注可空）；编辑模式保存类别+备注。均关闭。
  void _punch(String label) {
    final store = EventStore.instance;
    final e = widget.event;
    if (e == null) {
      store.punch(label, note: _noteController.text);
    } else {
      store.editEvent(e.id, label: label, note: _noteController.text);
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labels = EventStore.instance.labels; // 有序分类
    final editing = widget.event;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              editing == null ? '现在在做什么？' : '当时在做什么？',
              style: theme.textTheme.titleLarge,
            ),
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
                      final current = editing?.label == label;
                      return ActionChip(
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (current) ...[
                              Icon(Icons.check, size: 16, color: onC),
                              const SizedBox(width: 4),
                            ],
                            Text(label, style: TextStyle(color: onC)),
                          ],
                        ),
                        backgroundColor: c,
                        side: BorderSide(
                          color:
                              current ? onC : c.withValues(alpha: 0.6),
                          width: current ? 2 : 1,
                        ),
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
