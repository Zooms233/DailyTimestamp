import 'package:flutter/material.dart';

import 'pages/home_page.dart';
import 'pages/stats_page.dart';
import 'services/event_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EventStore.instance.load();
  runApp(const TimestampApp());
}

class TimestampApp extends StatelessWidget {
  const TimestampApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '时间戳记录',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Source Han Sans SC',
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3E7BFA)),
        useMaterial3: true,
      ),
      home: const RootPage(),
    );
  }
}

/// 单页双 Tab 骨架：body 根据选中索引切换打卡页/统计页。
class RootPage extends StatefulWidget {
  const RootPage({super.key});

  @override
  State<RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> with WidgetsBindingObserver {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    EventStore.instance.flush();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 退后台/失焦即落盘，防抖窗口内的改动不丢失
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      EventStore.instance.flush();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 监听数据变更：打卡/合并/拆分/改分类等操作后两页立即刷新。
      // children 不能用 const：相同实例会被框架短路，子树不会 rebuild。
      body: ListenableBuilder(
        listenable: EventStore.instance,
        builder: (context, _) => IndexedStack(
          index: _index,
          children: [HomePage(), StatsPage()],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: '首页'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: '统计'),
        ],
      ),
    );
  }
}