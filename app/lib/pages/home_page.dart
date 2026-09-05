/// 打卡页（设计文档 3.1）：进行中卡片 + 大按钮 + 今日时间轴。
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../models/timestamp_event.dart';
import 'labels_page.dart';
import '../services/event_store.dart';
import '../utils/format.dart';
import '../widgets/punch_sheet.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // 每秒刷新"已持续"时长
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = EventStore.instance;
    final theme = Theme.of(context);
    final now = DateTime.now();
    final ongoing = store.ongoing;
    final today = store.eventsOfDay(now);
    return Scaffold(
      appBar: AppBar(
        title: const Text('时间戳记录'),
        actions: [
          // 分类管理入口（右上角）
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: '分类管理',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const LabelsPage()),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
        children: [
          // 主视区：今日时间轴（可滚动），进行中状态随列表滚动被看到
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              children: [
                Text('今日时间轴（${today.length} 个事件）',
                    style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant)),
                const SizedBox(height: 8),
                if (today.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      '今日还没有记录，从下方按钮开始第一个事件',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.colorScheme.outline),
                    ),
                  )
                else
                  ...today.map((t) => _TimelineRow(
                        event: t.$1,
                        clippedStart: t.$2,
                        clippedEnd: t.$3,
                        ongoing: t.$4,
                      )),
              ],
            ),
          ),
          // 底部固定操作区：拇指轻松点按，不随列表滚动
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _OngoingCard(ongoing: ongoing),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => showPunchSheet(context),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    textStyle: theme.textTheme.titleMedium,
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('记录新事件'),
                ),
              ],
            ),
          ),
        ],
        ),
      ),
    );
  }
}

class _OngoingCard extends StatelessWidget {
  const _OngoingCard({required this.ongoing});

  final TimestampEvent? ongoing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final e = ongoing;
    if (e == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.timelapse, color: theme.colorScheme.outline),
              const SizedBox(width: 12),
              Text('当前没有进行中的事件',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.outline)),
            ],
          ),
        ),
      );
    }
    final now = DateTime.now();
    final mins = e.duration(now).inMinutes;
    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.circle, size: 12, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      text: '进行中：${e.label}',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                      children: [
                        if (e.note case final note? when note.isNotEmpty)
                          TextSpan(
                            text: '  $note',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '开始于 ${fmtClock(e.startAt)}，已持续 ${fmtZh(mins)}',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.event,
    required this.clippedStart,
    required this.clippedEnd,
    required this.ongoing,
  });

  final TimestampEvent event;
  final int clippedStart;
  final int clippedEnd;
  final bool ongoing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mins = Duration(milliseconds: clippedEnd - clippedStart).inMinutes;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: ongoing ? theme.colorScheme.secondaryContainer : null,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Text(
            '${fmtClock(clippedStart)}-${ongoing ? '现在' : fmtClock(clippedEnd)}',
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontFamily: 'monospace', color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              TextSpan(
                text: event.label,
                style: theme.textTheme.bodyMedium,
                children: [
                  if (event.note case final note? when note.isNotEmpty)
                    TextSpan(
                      text: '  $note',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (ongoing)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(Icons.play_arrow, size: 16, color: theme.colorScheme.primary),
            ),
          Text(
            ongoing ? '进行中' : fmtZh(mins),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: ongoing ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}