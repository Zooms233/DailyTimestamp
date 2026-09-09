/// 时间轴行（打卡页/统计页共用）：`开始-结束 分类色条 标签 备注 时长`，
/// 进行中显示 `▶ 进行中`。
library;

import 'package:flutter/material.dart';

import '../models/timestamp_event.dart';
import '../services/event_store.dart';
import '../utils/format.dart';

class TimelineRow extends StatelessWidget {
  const TimelineRow({
    super.key,
    required this.event,
    required this.clippedStart,
    required this.clippedEnd,
    required this.ongoing,
    this.startsBeforeDay = false,
    this.endsAfterDay = false,
    this.onTap,
  });

  final TimestampEvent event;

  /// 展示用起止（毫秒；跨天/进行中已由调用方裁剪）
  final int clippedStart;
  final int clippedEnd;
  final bool ongoing;

  /// 事件开始早于展示日（裁剪头）：显示真实开始时刻并标「昨」
  final bool startsBeforeDay;

  /// 事件结束晚于展示日（裁剪尾）：显示真实结束时刻并标「明」
  final bool endsAfterDay;

  /// 点击回调；空则行不响应（统计页只读查看）。
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mins = Duration(milliseconds: clippedEnd - clippedStart).inMinutes;
    // 跨天事件显示真实时刻并标注：昨23:50-00:45 / 23:50-明00:45
    final startText = startsBeforeDay
        ? '昨${fmtClock(event.startAt)}'
        : fmtClock(clippedStart);
    final endText = ongoing
        ? '现在'
        : endsAfterDay
            ? '明${fmtClock(event.endAt!)}'
            : fmtClock(clippedEnd);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: ongoing ? theme.colorScheme.secondaryContainer : null,
          borderRadius: BorderRadius.circular(8),
        ),
      child: Row(
        children: [
          // 分类色条
          Container(
            width: 4,
            height: 24,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              color: EventStore.instance.colorOf(event.label),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(
            '$startText-$endText',
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
      ),
    );
  }
}
