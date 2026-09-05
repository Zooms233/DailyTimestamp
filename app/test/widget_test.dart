import 'package:flutter_test/flutter_test.dart';

import 'package:daily_timestamp/main.dart';

void main() {
  testWidgets('双 Tab 骨架冒烟测试', (WidgetTester tester) async {
    await tester.pumpWidget(const TimestampApp());
    // 默认显示打卡页：进行中空态 + 大按钮 + 底部导航
    expect(find.text('记录新事件'), findsOneWidget);
    expect(find.text('统计'), findsOneWidget);
    await tester.tap(find.text('统计'));
    await tester.pumpAndSettle();
    // 统计页：默认显示今天日期行
    expect(find.textContaining('已记录'), findsOneWidget);
  });
}