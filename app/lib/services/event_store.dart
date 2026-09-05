/// 单文件 JSON 存储 + 事件流操作（设计文档第 5/6 节）。
/// 原子写：先写 tmp 再 rename，防断电损坏。
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/timestamp_event.dart';

/// 某一天的统计聚合结果。
class DayStat {
  DayStat({required this.byLabel, required this.recorded, required this.unrecorded});

  final Map<String, Duration> byLabel; // label -> 当日时长（已按日界裁剪）
  final Duration recorded; // 当日已记录总时长
  final Duration unrecorded; // 24h - recorded（日首 + 日尾空档）
}

class EventStore extends ChangeNotifier {
  EventStore._();

  static final EventStore instance = EventStore._();

  /// 首次启动默认分类（用户可在分类管理中增删排序）。
  static const defaultLabels = [
    '睡眠', '清洁', '吃饭', '行路', '学习', '运动',
    '代码', '阅读', '游戏', '碎片信息流', '总结', '其他',
  ];

  final List<TimestampEvent> _events = [];
  final List<String> _labels = [];

  bool get loaded => _loaded;
  bool _loaded = false;

  List<TimestampEvent> get events => List.unmodifiable(_events);

  /// 有序分类（顺序即打卡弹窗显示顺序）。
  List<String> get labels => List.unmodifiable(_labels);

  /// 当前进行中的事件；无则 null。
  TimestampEvent? get ongoing {
    for (final e in _events) {
      if (e.isOngoing) return e;
    }
    return null;
  }

  /// 启动时加载；文件不存在或损坏都容忍为空数据，不阻塞 UI。
  Future<void> load() async {
    try {
      final file = await _file();
      if (await file.exists()) {
        final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        _events
          ..clear()
          ..addAll((data['events'] as List? ?? [])
              .map((e) => TimestampEvent.fromJson(e as Map<String, dynamic>)));
        final labels = data['labels'];
        if (labels is List && labels.isNotEmpty) {
          _labels
            ..clear()
            ..addAll(labels.cast<String>());
        } else {
          // 旧格式兼容：预设 + 旧 customLabels
          _labels
            ..clear()
            ..addAll(defaultLabels);
          for (final l in data['customLabels'] as List? ?? []) {
            if (!_labels.contains(l)) _labels.add(l as String);
          }
        }
      } else {
        _labels
          ..clear()
          ..addAll(defaultLabels);
      }
    } catch (e) {
      debugPrint('EventStore.load: $e');
      if (_labels.isEmpty) _labels.addAll(defaultLabels);
    }
    _loaded = true;
    notifyListeners();
  }

  /// 打卡：结束旧进行中事件（endAt=now），开始新事件（startAt=now）。
  /// 规则 1/2：任意时刻至多一个进行中事件，时间线无缝衔接。
  void punch(String label, {String? note}) {
    final text = label.trim();
    if (text.isEmpty) return;
    final noteText = note?.trim();
    final ms = DateTime.now().millisecondsSinceEpoch;
    for (final e in _events) {
      if (e.isOngoing) e.endAt = ms;
    }
    _events.add(TimestampEvent(
      id: '${ms}_${Random().nextInt(65536).toRadixString(16).padLeft(4, '0')}',
      label: text,
      startAt: ms,
      note: (noteText == null || noteText.isEmpty) ? null : noteText,
    ));
    notifyListeners();
    _save();
  }

  // ---------- 分类管理 ----------

  /// 添加分类（去重，忽略空名）；成功返回 true。
  bool addLabel(String name) {
    final text = name.trim();
    if (text.isEmpty || _labels.contains(text)) return false;
    _labels.add(text);
    notifyListeners();
    _save();
    return true;
  }

  /// 删除分类：仅从打卡列表移除，历史事件保留（统计不受影响）。
  void removeLabel(String name) {
    if (_labels.remove(name)) {
      notifyListeners();
      _save();
    }
  }

  /// 上移/下移分类（delta = -1 上移，+1 下移）。
  void moveLabel(String name, int delta) {
    final i = _labels.indexOf(name);
    final j = i + delta;
    if (i < 0 || j < 0 || j >= _labels.length) return;
    final tmp = _labels[i];
    _labels[i] = _labels[j];
    _labels[j] = tmp;
    notifyListeners();
    _save();
  }

  // ---------- 统计 ----------

  /// 某一天（按本地日历日）的统计聚合。
  /// 事件按与当日的交集裁剪；进行中事件截止到 [now]。
  DayStat statsForDay(DateTime day, {DateTime? now}) {
    final t = now ?? DateTime.now();
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final s0 = dayStart.millisecondsSinceEpoch;
    final s1 = dayEnd.millisecondsSinceEpoch;
    final byLabel = <String, Duration>{};
    var recorded = Duration.zero;
    for (final e in _events) {
      final es = max(e.startAt, s0);
      final ee = min(e.endAt ?? t.millisecondsSinceEpoch, s1);
      if (ee <= es) continue;
      final d = Duration(milliseconds: ee - es);
      byLabel.update(e.label, (v) => v + d, ifAbsent: () => d);
      recorded += d;
    }
    return DayStat(
      byLabel: byLabel,
      recorded: recorded,
      unrecorded: Duration(milliseconds: s1 - s0) - recorded,
    );
  }

  /// 与某一天有交集的事件，裁剪到日界。
  /// 返回 (事件, 裁剪后开始ms, 裁剪后结束ms, 当日是否进行中)。
  List<(TimestampEvent, int, int, bool)> eventsOfDay(DateTime day, {DateTime? now}) {
    final t = now ?? DateTime.now();
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final s0 = dayStart.millisecondsSinceEpoch;
    final s1 = dayEnd.millisecondsSinceEpoch;
    final result = <(TimestampEvent, int, int, bool)>[];
    for (final e in _events) {
      final rawEnd = e.endAt;
      final ongoingInDay = rawEnd == null;
      final ee = ongoingInDay ? t.millisecondsSinceEpoch : rawEnd;
      final es = max(e.startAt, s0);
      final end = min(ee, s1);
      if (end <= es) continue;
      result.add((e, es, end, ongoingInDay));
    }
    result.sort((a, b) => a.$2.compareTo(b.$2));
    return result;
  }

  // ---------- 持久化 ----------

  Future<void> _save() async {
    try {
      final file = await _file();
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsString(jsonEncode({
        'labels': _labels,
        'events': _events.map((e) => e.toJson()).toList(),
      }));
      try {
        await tmp.rename(file.path);
      } catch (_) {
        if (await file.exists()) await file.delete();
        await tmp.rename(file.path);
      }
    } catch (e) {
      debugPrint('EventStore.save: $e');
    }
  }

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}${Platform.pathSeparator}events.json');
  }
}