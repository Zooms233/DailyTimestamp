/// 统计页（设计文档 3.3）：按日聚合时长 + 占比条形 + 上一日/下一日翻页。
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../services/event_store.dart';
import '../utils/format.dart';

class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  DateTime _day = DateTime.now();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // 每分钟刷新（进行中事件占用会随"现在"增长）
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  bool get _isToday {
    final now = DateTime.now();
    return _day.year == now.year && _day.month == now.month && _day.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final store = EventStore.instance;
    final stat = store.statsForDay(_day);
    // 按时长降序，空档固定排最后（设计图惯例）
    final rows = stat.byLabel.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final totalMinutes = stat.recorded.inMinutes + stat.unrecorded.inMinutes;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(fmtDay(_day), style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            '已记录 ${fmtHm(stat.recorded.inMinutes)} · 未记录 ${fmtHm(stat.unrecorded.inMinutes)}',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          if (stat.recorded == Duration.zero && stat.unrecorded == const Duration(hours: 24))
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                '这一天没有记录',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
            )
          else ...[
            for (final e in rows)
              _StatRow(
                label: e.key,
                minutes: e.value.inMinutes,
                totalMinutes: totalMinutes,
              ),
            _StatRow(
              label: '空档',
              minutes: stat.unrecorded.inMinutes,
              totalMinutes: totalMinutes,
              isGap: true,
            ),
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              OutlinedButton(
                onPressed: () => setState(() =>
                    _day = DateTime(_day.year, _day.month, _day.day - 1)),
                child: const Text('上一日'),
              ),
              TextButton(
                onPressed: _isToday
                    ? null
                    : () => setState(() => _day = DateTime.now()),
                child: const Text('今日'),
              ),
              OutlinedButton(
                onPressed: () => setState(() =>
                    _day = DateTime(_day.year, _day.month, _day.day + 1)),
                child: const Text('下一日'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.label,
    required this.minutes,
    required this.totalMinutes,
    this.isGap = false,
  });

  final String label;
  final int minutes;
  final int totalMinutes;
  final bool isGap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percent = totalMinutes == 0 ? 0.0 : minutes / totalMinutes;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 48, child: Text(label, style: theme.textTheme.bodyMedium)),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: percent,
                minHeight: 14,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                color: isGap
                    ? theme.colorScheme.outline
                    : EventStore.instance.colorOf(label),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 72,
            child: Text(
              '${fmtHm(minutes)}  ${(percent * 100).round()}%',
              textAlign: TextAlign.right,
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}