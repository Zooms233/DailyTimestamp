import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'pages/home_page.dart';
import 'pages/stats_page.dart';
import 'services/app_settings.dart';
import 'services/event_store.dart';
import 'services/storage_access.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _restoreThemeMode(); // 恢复用户主题偏好（明亮/深色/自动），失败静默用默认
  runApp(const TimestampApp());
}

/// 从 settings.json 恢复主题模式；无字段/读取失败时保持默认（跟随系统）。
Future<void> _restoreThemeMode() async {
  final saved = await loadThemeMode();
  if (saved != null) themeModeNotifier.value = saved;
}

class TimestampApp extends StatelessWidget {
  const TimestampApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 监听全局主题模式：统计页切换即重建整树（MaterialApp 换 themeMode）
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, mode, _) => MaterialApp(
        title: '时间戳记录',
        debugShowCheckedModeBanner: false,
        theme: buildLightTheme(),
        darkTheme: buildDarkTheme(),
        themeMode: mode, // light=明亮 / dark=深色 / system=跟随系统
        home: const AppGate(),
      ),
    );
  }
}

/// 启动权限门：数据存公共 Documents/DailyTimestamp（卸载不清），
/// Android 需"所有文件访问"授权；未授权时阻塞启动（去授权/退出），
/// 不做其他路径回退。授权通过后才 load 数据进入主界面。
class AppGate extends StatefulWidget {
  const AppGate({super.key});

  @override
  State<AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<AppGate> with WidgetsBindingObserver {
  bool _checking = true; // 首次检测中
  bool _granted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 从"所有文件访问"设置页返回时重检授权
    if (state == AppLifecycleState.resumed && !_granted) _check();
  }

  Future<void> _check() async {
    final ok = await StorageAccess.isGranted();
    if (!mounted) return;
    setState(() {
      _granted = ok;
      _checking = false;
    });
    if (ok) {
      // 授权即进主界面，数据并行加载（完成时 notifyListeners 全局刷新）；
      // load 内部容忍失败（空数据）。
      unawaited(EventStore.instance.load());
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_checking) {
      // 授权检测中：静默过场（探测文件读写，毫秒级）
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }
    if (!_granted) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.folder_shared_outlined,
                    size: 48, color: theme.colorScheme.primary),
                const SizedBox(height: 16),
                Text('需要"所有文件访问"权限',
                    style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  '数据保存在公共文档目录 Documents/DailyTimestamp，'
                  '卸载/重装后不丢失；请在系统设置中允许访问所有文件。',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => StorageAccess.openManageSettings(),
                  icon: const Icon(Icons.settings_outlined),
                  label: const Text('去授权'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => SystemNavigator.pop(),
                  child: const Text('退出应用'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return const RootPage();
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

  /// 切到统计 Tab 时通知其重置为今日
  final _statsKey = GlobalKey<StatsPageState>();

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
          children: [HomePage(), StatsPage(key: _statsKey)],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) {
          setState(() => _index = i);
          // 回到统计页时自动显示今日（并收起月历）
          if (i == 1) _statsKey.currentState?.resetToToday();
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: '首页'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: '统计'),
        ],
      ),
    );
  }
}