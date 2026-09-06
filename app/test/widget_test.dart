import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:daily_timestamp/main.dart';

/// 测试环境 mock path_provider：AppGate 的权限检测/数据加载依赖文档目录。
/// 指向系统临时目录（events.json 不存在 → 空数据，不触发后台 isolate 解析）。
class _FakePathProvider extends PathProviderPlatform {
  late final String _root =
      Directory.systemTemp.createTempSync('daily_ts_test').path;

  @override
  Future<String?> getApplicationDocumentsPath() async => _root;
}

void main() {
  setUpAll(() => PathProviderPlatform.instance = _FakePathProvider());

  testWidgets('双 Tab 骨架冒烟测试', (WidgetTester tester) async {
    await tester.pumpWidget(const TimestampApp());
    await tester.pumpAndSettle(); // 权限检测 + 数据加载完成
    // 默认显示打卡页：进行中空态 + 大按钮 + 底部导航
    expect(find.text('记录新事件'), findsOneWidget);
    expect(find.text('统计'), findsOneWidget);
    await tester.tap(find.text('统计'));
    await tester.pumpAndSettle();
    // 统计页：默认显示今天日期行
    expect(find.textContaining('已记录'), findsOneWidget);
  });
}
