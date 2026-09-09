/// 应用数据的公共存储位置与"所有文件访问"权限。
/// Android 数据与备份统一存 `/storage/emulated/0/Documents/DailyTimestamp/`
/// （公共 Documents，卸载不清、文件管理器可见）；写入需"所有文件访问"
/// （MANAGE_EXTERNAL_STORAGE）授权，未授权时启动被权限页阻塞（去授权/退出），
/// 不做其他存储路径回退。桌面端（Windows）不受 scoped storage 限制，直接可写。
library;

import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class StorageAccess {
  StorageAccess._();

  /// 数据与自动备份的根目录：`Documents/DailyTimestamp`（不存在则创建）。
  /// Android = `/storage/emulated/0/Documents`；桌面端 = 系统文档目录。
  static Future<Directory> root() async {
    final Directory base;
    if (Platform.isAndroid) {
      // Android 标准公共 Documents 目录（path_provider 无对应 API，路径固定）
      base = Directory('/storage/emulated/0/Documents');
    } else {
      base = await getApplicationDocumentsDirectory();
    }
    final dir =
        Directory('${base.path}${Platform.pathSeparator}DailyTimestamp');
    await dir.create(recursive: true);
    return dir;
  }

  /// 可写性检测：真实写入+删除探测文件（桌面端视为已授权，无需授权）。
  static Future<bool> isGranted() async {
    if (!Platform.isAndroid) return true;
    try {
      final dir = await root();
      final probe = File('${dir.path}${Platform.pathSeparator}.probe');
      await probe.create();
      await probe.delete();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 跳系统"所有文件访问"设置页；用户开启后返回 app，由调用方在
  /// resumed 时机重检（AppGate 监听生命周期）。
  static Future<void> openManageSettings() async {
    await Permission.manageExternalStorage.request();
  }
}
