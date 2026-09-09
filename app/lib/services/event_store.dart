/// 单文件 JSON 存储 + 事件流操作（打卡/改/合并/拆分/统计聚合）。
/// 原子写：先写 tmp 再 rename，防断电损坏。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../models/timestamp_event.dart';
import 'backup_service.dart';
import 'storage_access.dart';

/// 后台 isolate 解析整份 JSON（compute 入口须为顶层函数）。
/// 返回 (事件, 分类, 旧版自定义分类, 分类色, 自动存档开关)。
(List<TimestampEvent>, List<String>, List<String>, Map<String, int>, bool)
    _parseFile(String raw) {
  final data = jsonDecode(raw) as Map<String, dynamic>;
  final settings = data['settings'] as Map<String, dynamic>?;
  return (
    (data['events'] as List? ?? [])
        .map((e) => TimestampEvent.fromJson(e as Map<String, dynamic>))
        .toList(),
    (data['labels'] as List? ?? []).cast<String>().toList(),
    (data['customLabels'] as List? ?? []).cast<String>().toList(),
    (data['colors'] as Map? ?? {})
        .map((k, v) => MapEntry(k as String, v as int)),
    settings?['autoBackup'] as bool? ?? true,
  );
}

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

  /// 分类语义色（按分类名匹配最合适的颜色）。
  static const Map<String, Color> semanticColors = {
    '睡眠': Colors.indigo,
    '清洁': Colors.cyan,
    '吃饭': Colors.orange,
    '行路': Colors.lightBlue,
    '学习': Colors.green,
    '运动': Colors.red,
    '代码': Colors.blue,
    '阅读': Colors.amber,
    '游戏': Colors.purple,
    '碎片信息流': Colors.blueGrey,
    '总结': Colors.teal,
    '其他': Colors.grey,
    '家务': Colors.brown,
    '放松': Colors.pink,
  };

  final List<TimestampEvent> _events = [];
  final List<String> _labels = [];
  final Map<String, int> _labelColors = {}; // 用户改过的分类色（持久化）
  Timer? _saveTimer;
  bool _saving = false;
  bool _resaveQueued = false;

  bool get loaded => _loaded;
  bool _loaded = false;

  /// 自动存档开关（设置页控制；默认开，每次记录新事件时触发）。
  bool get autoBackup => _autoBackup;
  bool _autoBackup = true;

  /// 用户改自动存档开关（持久化到 settings 字段）。
  void setAutoBackup(bool v) {
    if (_autoBackup == v) return;
    _autoBackup = v;
    notifyListeners();
    _save();
  }

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
        // 万级事件 JSON 解析放后台 isolate，主线程不卡首帧
        final (events, labels, legacy, colors, autoBackup) =
            await compute(_parseFile, await file.readAsString());
        _events
          ..clear()
          ..addAll(events);
        if (labels.isNotEmpty) {
          _labels
            ..clear()
            ..addAll(labels);
        } else {
          // 旧格式兼容：预设 + 旧 customLabels
          _labels
            ..clear()
            ..addAll(defaultLabels);
          for (final l in legacy) {
            if (!_labels.contains(l)) _labels.add(l);
          }
        }
        _labelColors
          ..clear()
          ..addAll(colors);
        _autoBackup = autoBackup;
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
    // 自动存档：每日一份备份到公共下载目录（内部 ≥1h 节流、静默失败，不阻塞打卡）
    unawaited(BackupService.autoBackup(enabled: _autoBackup, json: encode()));
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

  /// 分类颜色：用户改色优先；未改色按语义表匹配；自定义分类从调色板确定性指派（同序同色，稳定）。
  Color colorOf(String label) {
    final saved = _labelColors[label];
    if (saved != null) return Color(saved);
    final used = <int>{};
    for (final l in _labels) {
      final c = semanticColors[l] ?? _pickUnusedColor(used);
      if (l == label) return c;
      used.add(c.toARGB32());
    }
    return Colors.blueGrey;
  }

  /// 用户手动改色（持久化到 colors 字段）。
  void setLabelColor(String label, int argb) {
    _labelColors[label] = argb;
    notifyListeners();
    _save();
  }

  /// 从主色板取第一个尚未被已命名分类占用的颜色（确定性）。
  Color _pickUnusedColor(Set<int> used) {
    for (final c in Colors.primaries) {
      if (!used.contains(c.toARGB32())) return c;
    }
    return Colors.blueGrey;
  }

  // ---------- 事件修正（防误触） ----------

  /// 修改事件类别与备注（备注空串/null 清空备注）；成功返回 true。
  bool editEvent(String id, {required String label, String? note}) {
    final text = label.trim();
    if (text.isEmpty) return false;
    final i = _events.indexWhere((e) => e.id == id);
    if (i < 0) return false;
    final e = _events[i];
    e.label = text;
    final n = note?.trim();
    e.note = (n == null || n.isEmpty) ? null : n;
    notifyListeners();
    _save();
    return true;
  }

  /// 全局时间线上 startAt 相邻的上一条；无则 null。
  TimestampEvent? previousOf(String id) {
    final sorted = [..._events]..sort((a, b) => a.startAt.compareTo(b.startAt));
    final i = sorted.indexWhere((e) => e.id == id);
    if (i <= 0) return null;
    return sorted[i - 1];
  }

  /// 把事件并入其前一条（全局时间线上 startAt 相邻的上一条）：
  /// 前一条 endAt 扩展为该事件的 endAt（若该事件进行中则前一条变进行中），
  /// 备注合并，类别**保留前一条的**；返回 false 表示已是第一条或不存在。
  bool mergeToPrevious(String id) {
    final sorted = [..._events]..sort((a, b) => a.startAt.compareTo(b.startAt));
    final i = sorted.indexWhere((e) => e.id == id);
    if (i <= 0) return false;
    final cur = sorted[i];
    final prev = sorted[i - 1];
    prev.endAt = cur.endAt;
    final n2 = cur.note;
    if (n2 != null && n2.isNotEmpty) {
      final n1 = prev.note;
      prev.note = (n1 == null || n1.isEmpty) ? n2 : '$n1 · $n2';
    }
    _events.remove(cur);
    notifyListeners();
    _save();
    return true;
  }

  /// 在 atMs 处把事件拆为两段：第一段保留原 id、备注（endAt=atMs），
  /// 第二段新 id、同类别同备注（startAt=atMs，原 endAt 延续，进行中状态保留）。
  /// atMs 必须在 (startAt, min(endAt, now)) 开区间内。成功返回 true。
  bool splitEvent(String id, int atMs) {
    final i = _events.indexWhere((e) => e.id == id);
    if (i < 0) return false;
    final e = _events[i];
    final upper = e.endAt ?? DateTime.now().millisecondsSinceEpoch;
    if (atMs <= e.startAt || atMs >= upper) return false;
    final second = TimestampEvent(
      id: '${atMs}_${Random().nextInt(65536).toRadixString(16).padLeft(4, '0')}',
      label: e.label,
      startAt: atMs,
      endAt: e.endAt,
      note: e.note,
    );
    e.endAt = atMs;
    _events.add(second);
    notifyListeners();
    _save();
    return true;
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

  /// 某月中有记录（当日已记录时长 > 0）的"日"集合，供月历圆点。
  /// 与统计同口径：事件裁剪到当月区间；进行中事件截止到"现在"；跨天事件两侧日期都标记。
  Set<int> recordedDaysOfMonth(DateTime month) {
    final s0 = DateTime(month.year, month.month, 1).millisecondsSinceEpoch;
    final s1 = DateTime(month.year, month.month + 1, 1).millisecondsSinceEpoch;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final days = <int>{};
    for (final e in _events) {
      final es = max(e.startAt, s0);
      final ee = min(e.endAt ?? nowMs, s1);
      if (ee <= es) continue;
      var d = DateTime.fromMillisecondsSinceEpoch(es);
      while (d.millisecondsSinceEpoch < ee && d.month == month.month) {
        days.add(d.day);
        d = DateTime(d.year, d.month, d.day + 1);
      }
    }
    return days;
  }

  /// 与某一天有交集的事件，裁剪到日界。
  /// 返回 (事件, 裁剪后开始ms, 裁剪后结束ms, 当日是否进行中,
  ///       是否开始于日界前(标「昨」), 是否结束于日界后(标「明」))。
  List<(TimestampEvent, int, int, bool, bool, bool)> eventsOfDay(DateTime day, {DateTime? now}) {
    final t = now ?? DateTime.now();
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final s0 = dayStart.millisecondsSinceEpoch;
    final s1 = dayEnd.millisecondsSinceEpoch;
    final result = <(TimestampEvent, int, int, bool, bool, bool)>[];
    for (final e in _events) {
      final rawEnd = e.endAt;
      final ongoingInDay = rawEnd == null;
      final ee = ongoingInDay ? t.millisecondsSinceEpoch : rawEnd;
      final es = max(e.startAt, s0);
      final end = min(ee, s1);
      if (end <= es) continue;
      result.add((
        e,
        es,
        end,
        ongoingInDay,
        e.startAt < s0,
        rawEnd != null && rawEnd > s1,
      ));
    }
    result.sort((a, b) => a.$2.compareTo(b.$2));
    return result;
  }

  // ---------- 持久化 ----------

  /// 当前全量数据的 JSON 文本（写盘、导出与自动存档共用）。
  String encode() => jsonEncode({
        'labels': _labels,
        'colors': _labelColors,
        'settings': {'autoBackup': _autoBackup},
        'events': _events.map((e) => e.toJson()).toList(),
      });

  /// 导出快照：当前数据写入应用缓存目录的带时间戳 JSON，返回文件（供分享/复制）。
  Future<File> exportSnapshot() async {
    final dir = await getTemporaryDirectory();
    final n = DateTime.now();
    String p2(int v) => v.toString().padLeft(2, '0');
    final file =
        File('${dir.path}/events_${n.year}${p2(n.month)}${p2(n.day)}_${p2(n.hour)}${p2(n.minute)}.json');
    await file.writeAsString(encode());
    return file;
  }

  /// 防抖保存：150ms 内连续改动合并为一次写盘。
  void _save() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 150), _flush);
  }

  /// 立即落盘（App 退后台/关闭时调用，防丢最近改动）。
  void flush() {
    _saveTimer?.cancel();
    _saveTimer = null;
    unawaited(_flush());
  }

  Future<void> _flush() async {
    if (_saving) {
      // 上一笔还在写：排队补写一次，保证最终状态落盘且串行
      _resaveQueued = true;
      return;
    }
    _saving = true;
    try {
      final file = await _file();
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsString(encode());
      try {
        await tmp.rename(file.path);
      } catch (_) {
        // 仅当 tmp 仍在（rename 因其它原因失败）才覆盖目标；tmp 已被移走则跳过
        if (await tmp.exists()) {
          if (await file.exists()) await file.delete();
          await tmp.rename(file.path);
        }
      }
    } catch (e) {
      debugPrint('EventStore.save: $e');
    } finally {
      _saving = false;
      if (_resaveQueued) {
        _resaveQueued = false;
        unawaited(_flush());
      }
    }
  }

  /// 数据文件位置：`Documents/DailyTimestamp/events.json`（需"所有文件访问"授权）。
  /// Android = /storage/emulated/0/Documents/DailyTimestamp；桌面 = 文档目录/DailyTimestamp。
  /// 与自动备份同目录；未授权时启动被权限页阻塞，不做其他路径回退。
  Future<File> _file() async {
    final dir = await StorageAccess.root();
    return File('${dir.path}${Platform.pathSeparator}events.json');
  }
}