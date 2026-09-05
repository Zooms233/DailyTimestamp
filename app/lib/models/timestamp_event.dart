/// 时间戳事件数据模型。
/// 时间一律存毫秒 epoch；endAt == null 表示进行中（至多一条）。
class TimestampEvent {
  TimestampEvent({
    required this.id,
    required this.label,
    required this.startAt,
    this.endAt,
    this.note,
  });

  final String id;
  String label;
  final int startAt; // 开始，毫秒 epoch
  int? endAt; // 结束，毫秒 epoch；null = 进行中
  String? note; // 备注（可空）

  bool get isOngoing => endAt == null;

  /// 事件时长；进行中事件截止到 [now]。
  Duration duration(DateTime now) =>
      Duration(milliseconds: (endAt ?? now.millisecondsSinceEpoch) - startAt);

  factory TimestampEvent.fromJson(Map<String, dynamic> json) => TimestampEvent(
        id: json['id'] as String,
        label: json['label'] as String,
        startAt: json['startAt'] as int,
        endAt: json['endAt'] as int?,
        note: json['note'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'startAt': startAt,
        'endAt': endAt,
        'note': note,
      };
}