/// 统计页（设计文档 3.3）：月历跳日 + 按日聚合时长 + 占比条形。
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../services/event_store.dart';
import '../utils/format.dart';

class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => StatsPageState();
}

class StatsPageState extends State<StatsPage> {
  DateTime _day = DateTime.now();
  Timer? _timer;

  /// 月历条是否展开（false = 收缩周条）
  bool _calExpanded = false;

  /// 月历展开时浏览的月份（仅日历显示，与统计日独立；收起时忽略）
  DateTime _calMonth = DateTime.now();

  /// 从打卡页切回统计 Tab 时调用：重置为今日并收起月历。
  void resetToToday() => setState(() {
        _day = DateTime.now();
        _calExpanded = false;
      });

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

  /// 导出数据：Windows 直存系统下载目录；Android 走系统分享面板。
  Future<void> _export() async {
    final messenger = ScaffoldMessenger.of(context);
    void tip(String msg) => messenger.showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(milliseconds: 1500),
      ),
    );
    try {
      final snapshot = await EventStore.instance.exportSnapshot();
      if (Platform.isWindows) {
        final dir = await getDownloadsDirectory();
        if (dir == null) throw '找不到系统下载目录';
        final name = snapshot.uri.pathSegments.last;
        await snapshot.copy('${dir.path}${Platform.pathSeparator}$name');
        tip('已导出到下载目录：$name');
      } else {
        await Share.shareXFiles([XFile(snapshot.path)], text: '时间戳数据备份');
      }
    } catch (e) {
      tip('导出失败：$e');
    }
  }

  // ---------- 月历条 ----------

  DateTime _weekStart(DateTime d) =>
      DateTime(d.year, d.month, d.day - (d.weekday - 1));

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// 展开/收起月历；展开时定位到统计日所在月。
  void _toggleCalendar() => setState(() {
        _calExpanded = !_calExpanded;
        _calMonth = DateTime(_day.year, _day.month, 1);
      });

  /// 展开态切换浏览月份；只改月历显示，不改统计日。
  void _shiftCalMonth(int delta) => setState(() {
        _calMonth = DateTime(_calMonth.year, _calMonth.month + delta, 1);
      });

  /// 月份行标题："2026年9月"
  String _titleOf(DateTime m) => '${m.year}年${m.month}月';

  /// 点选日期：切统计日；月历保持展开，便于连续跳看。
  void _pickCalendarDay(DateTime d) => setState(() {
        _day = d;
      });

  Widget _calendar(ThemeData theme) {
    const weekHeads = ['一', '二', '三', '四', '五', '六', '日'];
    final now = DateTime.now();
    final store = EventStore.instance;

    // 月 -> 当月有记录的日集合（周条跨月时最多缓存 2 个月）
    final recCache = <String, Set<int>>{};
    Set<int> recordedOf(DateTime d) => recCache.putIfAbsent(
          '${d.year}-${d.month}',
          () => store.recordedDaysOfMonth(DateTime(d.year, d.month, 1)),
        );

    final headRow = Row(
      children: [
        for (final h in weekHeads)
          Expanded(
            child: Center(
              child: Text(
                h,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          ),
      ],
    );

    Widget dayCell(DateTime d) {
      final sel = _sameDay(d, _day);
      final isToday = _sameDay(d, now);
      final hasRecord = recordedOf(d).contains(d.day);
      final Widget face;
      if (sel) {
        face = Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            shape: BoxShape.circle,
          ),
          child: Text(
            '${d.day}',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onPrimary),
          ),
        );
      } else {
        face = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${d.day}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isToday
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface,
                fontWeight: isToday ? FontWeight.w600 : null,
              ),
            ),
            if (hasRecord) ...[
              const SizedBox(height: 2),
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        );
      }
      return Expanded(
        child: InkWell(
          onTap: () => _pickCalendarDay(d),
          child: SizedBox(height: 44, child: Center(child: face)),
        ),
      );
    }

    Widget emptyCell() => const Expanded(child: SizedBox.shrink());

    final List<Widget> rows;
    if (_calExpanded) {
      final m = _calMonth;
      final lead = DateTime(m.year, m.month, 1).weekday - 1;
      final daysInMonth = DateTime(m.year, m.month + 1, 0).day;
      final cells = <Widget>[
        for (var i = 0; i < lead; i++) emptyCell(),
        for (var day = 1; day <= daysInMonth; day++)
          dayCell(DateTime(m.year, m.month, day)),
      ];
      while (cells.length % 7 != 0) {
        cells.add(emptyCell());
      }
      rows = [
        for (var i = 0; i < cells.length; i += 7)
          Row(children: cells.sublist(i, i + 7)),
      ];
    } else {
      final ws = _weekStart(_day);
      rows = [
        Row(
          children: [
            for (var i = 0; i < 7; i++) dayCell(ws.add(Duration(days: i))),
          ],
        ),
      ];
    }

    // 月份行：月份 + 展开开关始终居中（Stack），切换状态时位置不变；
    // 展开态 [<]/[>] 翻月箭头浮在两端。
    final monthRow = SizedBox(
      height: 40,
      child: Stack(
        alignment: Alignment.center,
        children: [
          InkWell(
            onTap: _toggleCalendar,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _titleOf(_calExpanded ? _calMonth : _day),
                    style: theme.textTheme.titleMedium,
                  ),
                  Icon(_calExpanded ? Icons.arrow_drop_up : Icons.arrow_drop_down),
                ],
              ),
            ),
          ),
          if (_calExpanded) ...[
            Positioned(
              left: 0,
              child: IconButton(
                icon: const Icon(Icons.chevron_left),
                tooltip: '上个月',
                onPressed: () => _shiftCalMonth(-1),
              ),
            ),
            Positioned(
              right: 0,
              child: IconButton(
                icon: const Icon(Icons.chevron_right),
                tooltip: '下个月',
                onPressed: () => _shiftCalMonth(1),
              ),
            ),
          ],
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        monthRow,
        headRow,
        ...rows,
        const Divider(height: 20),
      ],
    );
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('统计'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_upload_outlined),
            tooltip: '导出数据',
            onPressed: _export,
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _calendar(theme),
            Text(fmtDay(_day), style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              '已记录 ${fmtHm(stat.recorded.inMinutes)} · 未记录 ${fmtHm(stat.unrecorded.inMinutes)}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            if (stat.recorded == Duration.zero &&
                stat.unrecorded == const Duration(hours: 24))
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '这一天没有记录',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
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
          ],
        ),
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
          SizedBox(
            width: 48,
            child: Text(label, style: theme.textTheme.bodyMedium),
          ),
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
