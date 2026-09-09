/// 拆分时刻选择器：时/分双滚轮，在事件时段 (startMs, endMs) 内选拆分时刻。
///
/// 状态只有一个：偏移分钟 k（拆分时刻 = startMs + k * 60000），
/// 两个滚轮的显示与选中全部由 k 派生：
/// - 小时滚轮列出时段覆盖的全部时钟小时（跨天按 24 回绕显示，上大下小）；
/// - 分钟滚轮 0..59 循环（上大下小）。
/// 分钟滚轮滑动 = 显示分钟差 → 偏移增量（取最短方向），跨整点（59↔00）天然
/// 进/退位，小时变化时同步跳转小时滚轮；小时滚轮滑动 = 目标小时（分钟保持）
/// 直接换算偏移，越界截断到边界。拆分时刻限在开始后 1 分钟 ~ 结束前 1 分钟。
library;

import 'package:flutter/cupertino.dart'
    show CupertinoPicker, FixedExtentScrollController;
import 'package:flutter/material.dart';

class TimeOffsetPicker extends StatefulWidget {
  const TimeOffsetPicker({
    super.key,
    required this.startMs,
    required this.endMs,
    required this.onChanged,
    this.initialOffset,
  });

  /// 事件开始时刻（毫秒 epoch），拆分时刻严格晚于它。
  final int startMs;

  /// 事件结束 / 进行中事件的当前时刻，拆分时刻严格早于它。
  final int endMs;

  /// 初始偏移分钟（相对 startMs）；默认取可选区间中点。
  final int? initialOffset;

  /// 滚轮变化后回调当前偏移分钟，时刻 = startMs + 偏移 * 60000。
  final ValueChanged<int> onChanged;

  @override
  State<TimeOffsetPicker> createState() => _TimeOffsetPickerState();
}

class _TimeOffsetPickerState extends State<TimeOffsetPicker> {
  static const int _minMs = 60000;
  static const int _hourMs = 3600000;

  /// 最大偏移分钟（拆完尾段至少留 1 分钟）。
  late final int maxK = (widget.endMs - widget.startMs) ~/ _minMs - 1;

  /// 候选时钟小时（绝对小时：从 start 当日 0 点计，跨天递增不取模），
  /// 首项 = start 所在小时，末项 = end 所在小时。
  late final List<int> _hours = _buildHours();

  /// 当前偏移分钟 ∈ [1, maxK]。
  late int k;

  late final FixedExtentScrollController _hCtrl;
  late final FixedExtentScrollController _mCtrl;

  int get _atMs => widget.startMs + k * _minMs;

  /// 某时刻的绝对小时（本地时区，从当日 0 点计）。
  int _hourOf(int ms) {
    final t = DateTime.fromMillisecondsSinceEpoch(ms);
    final day = DateTime(t.year, t.month, t.day);
    return (ms - day.millisecondsSinceEpoch) ~/ _hourMs;
  }

  List<int> _buildHours() {
    final first = _hourOf(widget.startMs);
    final last = _hourOf(widget.endMs);
    return [for (var h = first; h <= last; h++) h];
  }

  /// 小时轮选中索引：上大下小，顶部 = 最晚小时。
  int get _hIndex => _hours.length - 1 - (_hourOf(_atMs) - _hours.first);

  /// 分钟轮选中索引：上大下小，59 在顶。
  int get _mIndex => 59 - DateTime.fromMillisecondsSinceEpoch(_atMs).minute;

  @override
  void initState() {
    super.initState();
    k = (widget.initialOffset ?? maxK ~/ 2).clamp(1, maxK);
    _hCtrl = FixedExtentScrollController(initialItem: _hIndex);
    _mCtrl = FixedExtentScrollController(initialItem: _mIndex);
  }

  @override
  void dispose() {
    _hCtrl.dispose();
    _mCtrl.dispose();
    super.dispose();
  }

  void _emit() => widget.onChanged(k);

  /// 分钟滚轮：目标显示分钟 → 偏移增量（取最短方向），跨整点自动进/退位。
  void _onMinute(int i) {
    final minNew = (59 - i) % 60;
    final minOld = DateTime.fromMillisecondsSinceEpoch(_atMs).minute;
    if (minNew == minOld) return; // jumpToItem 回声
    var delta = minNew - minOld;
    if (delta > 30) delta -= 60; // 00→59 等回退跨整点
    if (delta < -30) delta += 60; // 59→00 等前进跨整点
    final kNew = k + delta;
    if (kNew < 1 || kNew > maxK) {
      _mCtrl.jumpToItem(_mIndex); // 起点/终点边界，弹回停住
      return;
    }
    k = kNew;
    _hCtrl.jumpToItem(_hIndex); // 小时进位/退位，同步小时滚轮
    _emit();
  }

  /// 小时滚轮：目标小时（分钟保持）→ 直接换算偏移，越界截断到边界。
  void _onHour(int i) {
    final hNew = _hours[_hours.length - 1 - i];
    if (hNew == _hourOf(_atMs)) return; // jumpToItem 回声
    final t = DateTime.fromMillisecondsSinceEpoch(_atMs);
    final day = DateTime(t.year, t.month, t.day);
    final targetMs = day.millisecondsSinceEpoch + hNew * _hourMs;
    k = ((targetMs - widget.startMs) ~/ _minMs).clamp(1, maxK);
    _mCtrl.jumpToItem(_mIndex); // 截断可能改变分钟，同步分钟滚轮
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 160,
      child: Row(
        children: [
          Expanded(
            child: CupertinoPicker(
              scrollController: _hCtrl,
              itemExtent: 40,
              onSelectedItemChanged: _onHour,
              children: [
                for (var i = 0; i < _hours.length; i++)
                  Center(
                    child: Text(
                      '${(_hours[_hours.length - 1 - i] % 24).toString().padLeft(2, '0')} 时',
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: CupertinoPicker(
              scrollController: _mCtrl,
              itemExtent: 40,
              looping: true,
              onSelectedItemChanged: _onMinute,
              children: [
                for (var i = 0; i < 60; i++)
                  Center(
                    child: Text('${(59 - i + 60) % 60} 分'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
