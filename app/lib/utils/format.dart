/// 时间格式化工具：时刻 HH:mm、时长中文/紧凑格式、日期星期。
library;

/// 毫秒 epoch -> "HH:mm"（本地时间）。
String fmtClock(int ms) {
  final t = DateTime.fromMillisecondsSinceEpoch(ms);
  return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

/// 毫秒 epoch -> "MM-DD HH:mm"（跨天事件展示拆分时刻时用，带日期避免歧义）。
String fmtClockDay(int ms) {
  final t = DateTime.fromMillisecondsSinceEpoch(ms);
  final mm = t.month.toString().padLeft(2, '0');
  final dd = t.day.toString().padLeft(2, '0');
  return '$mm-$dd ${fmtClock(ms)}';
}

/// 分钟数 -> "1 小时 24 分" / "24 分" / "1 小时"。
String fmtZh(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h > 0 && m > 0) return '$h 小时 $m 分';
  if (h > 0) return '$h 小时';
  return '$m 分';
}

/// 分钟数 -> "1h24m" / "24m"（统计页紧凑格式）。
String fmtHm(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h > 0) return '${h}h${m}m';
  return '${m}m';
}

/// 本地日期 -> "2026-03-03 周二"。
String fmtDay(DateTime day) {
  const week = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
  final mm = day.month.toString().padLeft(2, '0');
  final dd = day.day.toString().padLeft(2, '0');
  return '${day.year}-$mm-$dd ${week[day.weekday - 1]}';
}