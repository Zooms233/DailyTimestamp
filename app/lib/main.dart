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

class _RootPageState extends State<RootPage> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [HomePage(), StatsPage()],
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