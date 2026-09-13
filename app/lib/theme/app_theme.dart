/// 全局主题：明亮 / 深色 / 跟随系统（三态）。
/// 切换入口在统计页 AppBar（☀/🌙 图标，设置按钮左侧）；选择即生效并
/// 持久化到 settings.json，下次启动恢复（见 main.dart 与 app_settings.dart）。
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;

/// 全局主题模式（三态：明亮/深色/自动跟随系统）。
/// 统计页切换时写入；启动时从 settings.json 恢复（见 main.dart）。
final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier(ThemeMode.system);

/// 浅色主题（现状：蓝色种子派生的 Material 3 配色）
ThemeData buildLightTheme() => _buildTheme(Brightness.light);

/// 深色主题：GitHub Dark 系（同参考项目）——
///   背景 #24292E / 浮起层 #1F2428 / 主文字 #E1E4E8 / 次要 #959DA5 /
///   分割线 #30363D / 警示 #F97583；强调色沿用本应用蓝色系：
///   参考亮绿 #3FB950 → 亮蓝 #58A6FF（图标/选中态），
///   参考暗绿实心钮 #176F2C+#DCFFE4 → 同思路的暗实心钮 #1E63B0+白字：
///   比亮蓝 #1F6FEB 暗一档不刺眼，又比进行中容器色（#1B3A5F/#1C3050）
///   明显更亮更饱和——避免首页上按钮与正上方的进行中卡片糊成一片。
/// 手写 ColorScheme 而非 fromSeed：精确控制各层级底色，页面照常只读 colorScheme。
ThemeData buildDarkTheme() {
  const bg = Color(0xFF24292E); // 页面/顶栏背景
  const surface = Color(0xFF1F2428); // 浮起层：卡片/底栏/弹窗
  final scheme = ColorScheme.dark(
    primary: const Color(0xFF58A6FF), // 亮蓝：图标/选中日/今日数字/光标
    onPrimary: const Color(0xFF0D1117),
    primaryContainer: const Color(0xFF1B3A5F), // 「进行中」卡片底
    onPrimaryContainer: const Color(0xFFC9E5FF),
    secondary: const Color(0xFF58A6FF),
    onSecondary: const Color(0xFF0D1117),
    secondaryContainer: const Color(0xFF1C3050), // 时间线「进行中」行底
    onSecondaryContainer: const Color(0xFFC9E5FF),
    error: const Color(0xFFF97583), // 参考警示红
    onError: const Color(0xFF0D1117),
    surface: bg,
    onSurface: const Color(0xFFE1E4E8), // 主文字
    onSurfaceVariant: const Color(0xFF959DA5), // 次要文字/未选中导航
    outline: const Color(0xFF6A737D), // 弱文字/空状态/输入框边
    outlineVariant: const Color(0xFF30363D), // 分割线
    // SnackBar 反色：浅底深字，深色页面上一眼可读
    inverseSurface: const Color(0xFFE1E4E8),
    onInverseSurface: bg,
    inversePrimary: const Color(0xFF1F6FEB), // SnackBar action 蓝
    surfaceTint: bg, // elevation 不再向 primary 染色，层色稳定
    surfaceContainerLowest: const Color(0xFF1A1F23),
    surfaceContainerLow: surface, // Card/BottomSheet 底 = 浮起层
    surfaceContainer: const Color(0xFF23282D),
    surfaceContainerHigh: const Color(0xFF282E34), // PopupMenu 底
    surfaceContainerHighest: const Color(0xFF2D333B), // 占比条凹槽
  );
  return ThemeData(
    fontFamily: 'Source Han Sans SC',
    colorScheme: scheme,
    useMaterial3: true,
    // 页面与顶栏同为底色，内容区用浮起层色区分层级（对齐参考项目）
    scaffoldBackgroundColor: bg,
    appBarTheme: const AppBarTheme(
      backgroundColor: bg,
      foregroundColor: Color(0xFFE1E4E8),
      scrolledUnderElevation: 0, //列表滚动时顶栏不因 surfaceTint 变色
      systemOverlayStyle: SystemUiOverlayStyle.light, // 状态栏浅色图标
    ),
    // 全局分割线：极细线风格
    dividerTheme: const DividerThemeData(
      color: Color(0xFF30363D),
      thickness: 0.5,
    ),
    // 底部导航栏：浮起层底 + 亮蓝选中 / 次要灰未选中，选中胶囊 = 蓝 10% 透明度
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface,
      indicatorColor: const Color(0x1A58A6FF),
      iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : const Color(0xFF959DA5),
          )),
      labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
            fontSize: 12,
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : const Color(0xFF959DA5),
          )),
    ),
    // 实心按钮：暗蓝底 + 白字。介于 #1F6FEB（太亮）与 #17406F（与进行中
    // 容器色重合）之间：明度/饱和都高于容器色，按钮是“实心主钮”，
    // 容器是“低调色块”，两者同屏可分
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF1E63B0),
        foregroundColor: const Color(0xFFF0F6FC),
      ),
    ),
    // 对话框：浮起层色，与卡片同层级
    dialogTheme: const DialogThemeData(backgroundColor: surface),
  );
}

ThemeData _buildTheme(Brightness brightness) => ThemeData(
      fontFamily: 'Source Han Sans SC',
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF3E7BFA),
        brightness: brightness,
      ),
      useMaterial3: true,
    );
