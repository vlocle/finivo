import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';

Future<String?> getDeviceId() async {
  final deviceInfoPlugin = DeviceInfoPlugin();
  try {
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfoPlugin.androidInfo;
      return androidInfo.id; // 'id' là một mã duy nhất cho thiết bị Android
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfoPlugin.iosInfo;
      return iosInfo.identifierForVendor; // unique ID for vendor on iOS
    }
  } catch (e) {
    print('Lỗi khi lấy Device ID: $e');
  }
  return null;
}