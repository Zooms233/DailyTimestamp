/// 分类管理页（首页右上角进入）：添加 / 删除 / 上移下移排序。
/// 删除仅影响打卡列表，历史事件保留，统计不受影响。
library;

import 'package:flutter/material.dart';

import '../services/event_store.dart';

class LabelsPage extends StatefulWidget {
  const LabelsPage({super.key});

  @override
  State<LabelsPage> createState() => _LabelsPageState();
}

class _LabelsPageState extends State<LabelsPage> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 换色弹窗：从主色板选择，选中即保存。
  Future<void> _pickColor(String label) async {
    final picked = await showDialog<Color>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('选择颜色'),
        content: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in Colors.primaries)
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => Navigator.of(ctx).pop(c),
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: c,
                  child: c.toARGB32() ==
                          EventStore.instance.colorOf(label).toARGB32()
                      ? const Icon(Icons.check, size: 18, color: Colors.white)
                      : null,
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
        ],
      ),
    );
    if (picked != null) {
      EventStore.instance.setLabelColor(label, picked.toARGB32());
    }
  }

  void _add() {
    final ok = EventStore.instance.addLabel(_controller.text);
    if (ok) {
      _controller.clear();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('分类已存在或为空'),
          duration: const Duration(milliseconds: 1500),
        ),
      );
    }
  }

  void _remove(String label) {
    EventStore.instance.removeLabel(label);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已删除「$label」，历史记录不受影响'),
        duration: const Duration(milliseconds: 1500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('分类管理')),
      body: ListenableBuilder(
        listenable: EventStore.instance,
        builder: (context, _) {
          final labels = EventStore.instance.labels;
          return Column(
            children: [
              // 添加分类
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        decoration: const InputDecoration(
                          hintText: '新分类名称',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _add(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(onPressed: _add, child: const Text('添加')),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: labels.length,
                  itemBuilder: (context, i) {
                    final label = labels[i];
                    final first = i == 0;
                    final last = i == labels.length - 1;
                    return ListTile(
                      leading: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => _pickColor(label),
                        child: CircleAvatar(
                          radius: 14,
                          backgroundColor: EventStore.instance.colorOf(label),
                          child: const Icon(Icons.colorize,
                              size: 16, color: Colors.white),
                        ),
                      ),
                      title: Text(label),
                      subtitle: Text(
                        '点色块改色',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(fontSize: 10),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_upward, size: 20),
                            tooltip: '上移',
                            onPressed:
                                first ? null : () => EventStore.instance.moveLabel(label, -1),
                          ),
                          IconButton(
                            icon: const Icon(Icons.arrow_downward, size: 20),
                            tooltip: '下移',
                            onPressed:
                                last ? null : () => EventStore.instance.moveLabel(label, 1),
                          ),
                          IconButton(
                            icon: Icon(Icons.delete_outline,
                                size: 20, color: theme.colorScheme.error),
                            tooltip: '删除',
                            onPressed: () => _remove(label),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              // 提示
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  '提示：删除分类仅从打卡列表移除，历史事件与统计保留',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.outline),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}