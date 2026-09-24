/// 打卡页：今日时间轴（主视区）+ 底部固定的进行中卡片与打卡按钮。
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../models/timestamp_event.dart';
import 'labels_page.dart';
import '../services/event_store.dart';
import '../utils/format.dart';
import '../widgets/punch_sheet.dart';
import '../widgets/time_offset_picker.dart';
import '../widgets/timeline_row.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  Timer? _timer;

  /// 正在查看的日期（默认今日；AppBar [<]/[>] 切换，用于回看/修改邻近日期）
  DateTime _viewDay = DateTime.now();

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// 从其他 Tab 切回打卡页时调用：自动跳回今日。
  void resetToToday() {
    final today = DateTime.now();
    if (_sameDay(_viewDay, today)) return; // 已在今日，避免无谓重建
    setState(() => _viewDay = today);
  }

  /// 切换查看日：delta = -1 上一日 / +1 下一日；不能晚于今日。
  void _shiftDay(int delta) => setState(() {
        final today = DateTime.now();
        final d = DateTime(_viewDay.year, _viewDay.month, _viewDay.day + delta);
        if (d.isAfter(DateTime(today.year, today.month, today.day))) return;
        _viewDay = d;
      });

  @override
  void initState() {
    super.initState();
    // 低频刷新"已持续"时长（分钟粒度显示，10s 足够；无进行中事件时页面无时间相关内容，跳过重建）
    _timer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (EventStore.instance.ongoing != null) setState(() {});
    });
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
    final isToday = _sameDay(_viewDay, now);
    final ongoing = store.ongoing;
    final today = store.eventsOfDay(_viewDay, now: now);
    return Scaffold(
      appBar: AppBar(
        // 日期切换器：[<] 上一日 / [>] 下一日（今日时禁用，用于回看后返回）
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              tooltip: '上一日',
              onPressed: () => _shiftDay(-1),
            ),
            Text(
              isToday ? '今日' : fmtDay(_viewDay),
              style: theme.textTheme.titleMedium,
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              tooltip: isToday ? '已是今日' : '下一日（返回）',
              onPressed: isToday ? null : () => _shiftDay(1),
            ),
          ],
        ),
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
                Text(
                  '${isToday ? '今日时间轴' : fmtDay(_viewDay)}（${today.length} 个事件）',
                  style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant)),
                const SizedBox(height: 8),
                if (today.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      isToday
                          ? '今日还没有记录，从下方按钮开始第一个事件'
                          : '这一天没有记录',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.colorScheme.outline),
                    ),
                  )
                else
                  ...today.map((t) => TimelineRow(
                        event: t.$1,
                        clippedStart: t.$2,
                        clippedEnd: t.$3,
                        ongoing: t.$4,
                        startsBeforeDay: t.$5,
                        endsAfterDay: t.$6,
                        onTap: () => _showRowActions(context, t.$1),
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
  /// 时间轴行点击：修改事件（类别+备注）/ 与上一个合并（防误触修正手段）。
  Future<void> _showRowActions(BuildContext context, TimestampEvent event) async {
    final store = EventStore.instance;
    final theme = Theme.of(context);
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  '${event.label}${event.note == null || event.note!.isEmpty ? '' : ' · ${event.note}'}',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('修改事件'),
                onTap: () => Navigator.of(ctx).pop('edit'),
              ),
              ListTile(
                leading: const Icon(Icons.call_merge_outlined),
                title: const Text('与上一个合并'),
                onTap: () => Navigator.of(ctx).pop('merge'),
              ),
              ListTile(
                leading: const Icon(Icons.call_split),
                title: const Text('拆分事件'),
                onTap: () => Navigator.of(ctx).pop('split'),
              ),
            ],
          ),
        ),
      ),
    );
    if (action == null || !context.mounted) return;
    if (action == 'edit') {
      // 复用打卡弹窗：预填当前类别/备注，点标签即时保存
      await showEditEventSheet(context, event);
    } else if (action == 'merge') {
      final prev = store.previousOf(event.id);
      if (prev == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('已是第一个事件，无法合并'),
          duration: Duration(milliseconds: 1500),
        ));
        return;
      }
      final curDur = fmtHm(event.duration(DateTime.now()).inMinutes);
      final prevDur = fmtHm(prev.duration(DateTime.now()).inMinutes);
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('确认合并？'),
          content: Text('「${event.label} $curDur」并入「${prev.label} $prevDur」，类别取「${prev.label}」？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('合并'),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;
      final ok = store.mergeToPrevious(event.id);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? '已合并入「${prev.label}」' : '合并失败'),
        duration: const Duration(milliseconds: 1500),
      ));
    } else if (action == 'split') {
      await _showSplitDialog(context, event);
    }
  }

  /// 拆分流程：双滚轮（时/分）在事件时段内选拆分时刻，滚轮联动见 TimeOffsetPicker。
  Future<void> _showSplitDialog(BuildContext context, TimestampEvent event) async {
    final store = EventStore.instance;
    final startMs = event.startAt;
    final upper = event.endAt ?? DateTime.now().millisecondsSinceEpoch;
    final maxTotalMin = ((upper - startMs) ~/ 60000) - 1; // 至少留 1 分钟
    if (maxTotalMin < 1) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('事件过短（<2 分钟），无法拆分'),
        duration: Duration(milliseconds: 1500),
      ));
      return;
    }
    var offset = maxTotalMin ~/ 2;
    // 跨天事件：范围/选中时刻带日期显示（MM-DD HH:mm），避免 "23:00 ~ 02:00" 歧义
    final st = DateTime.fromMillisecondsSinceEpoch(startMs);
    final ut = DateTime.fromMillisecondsSinceEpoch(upper);
    final crossDay =
        st.year != ut.year || st.month != ut.month || st.day != ut.day;
    String fmt(int ms) => crossDay ? fmtClockDay(ms) : fmtClock(ms);
    final theme = Theme.of(context);
    final atMs = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('拆分「${event.label}」',
                    style: theme.textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  '范围 ${fmt(startMs)} ~ ${fmt(upper)}',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                TimeOffsetPicker(
                  startMs: startMs,
                  endMs: upper,
                  initialOffset: offset,
                  onChanged: (v) => setSheetState(() => offset = v),
                ),
                Center(
                  child: Text(
                    fmt(startMs + offset * 60000),
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => Navigator.of(ctx)
                      .pop(startMs + offset * 60000),
                  child: Text('在 ${fmt(startMs + offset * 60000)} 拆分'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (atMs == null || !context.mounted) return;
    if (store.splitEvent(event.id, atMs)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('已拆分为两段，可分别修改事件'),
        duration: Duration(milliseconds: 1500),
      ));
    }
  }

}

class _OngoingCard extends StatelessWidget {
  const _OngoingCard({required this.ongoing});

  final TimestampEvent? ongoing;

  /// 开始时刻文本：当日 HH:MM；昨日「昨HH:MM」；更早「MM-DD HH:MM」（跨多天进行中）。
  String _startText(int ms, DateTime now) {
    final t = DateTime.fromMillisecondsSinceEpoch(ms);
    final today = DateTime(now.year, now.month, now.day);
    if (!t.isBefore(today)) return fmtClock(ms);
    final yesterday = today.subtract(const Duration(days: 1));
    if (!t.isBefore(yesterday)) return '昨${fmtClock(ms)}';
    final mm = t.month.toString().padLeft(2, '0');
    final dd = t.day.toString().padLeft(2, '0');
    return '$mm-$dd ${fmtClock(ms)}';
  }

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
                Icon(
                  Icons.circle,
                  size: 12,
                  color: EventStore.instance.colorOf(e.label),
                ),
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
              '开始于 ${_startText(e.startAt, now)}，已持续 ${fmtZh(mins)}',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
