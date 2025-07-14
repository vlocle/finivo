import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'; // Để dùng 'kIsWeb' và 'TargetPlatform'
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  Future<void> initialize() async {
    // Chỉ yêu cầu quyền trên các nền tảng không phải web
    if (!kIsWeb) {
      await _fcm.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
    }

    // Lấy FCM token của thiết bị
    final String? token = await _fcm.getToken();
    if (token != null) {
      print("FCM Token: $token");
      await _saveTokenToDatabase(token);
    }

    // Lắng nghe sự kiện token được làm mới và cập nhật lại trong Firestore
    _fcm.onTokenRefresh.listen(_saveTokenToDatabase);
  }

  static Future<void> initializeLocalNotifications() async {
    final FlutterLocalNotificationsPlugin localNotifications = FlutterLocalNotificationsPlugin();

    // Tên file âm thanh không có đuôi
    final AndroidNotificationSound customSound = RawResourceAndroidNotificationSound('fingrowth_sound');

    // Tạo một kênh thông báo có đính kèm âm thanh tùy chỉnh
    final AndroidNotificationChannel channel = AndroidNotificationChannel(
      'fingrowth_sound_channel', // <<< ID này phải khớp với channelId đã gửi từ Cloud Function
      'FinGrowth Notifications', // Tên kênh
      description: 'Kênh cho các thông báo của FinGrowth',
      importance: Importance.max,
      playSound: true,
      sound: customSound, // Đặt âm thanh tùy chỉnh
    );

    // Đăng ký kênh này với hệ thống Android
    await localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  /// Lưu token vào sub-collection `fcmTokens` của người dùng hiện tại
  Future<void> _saveTokenToDatabase(String token) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    try {
      String platform = 'unknown';
      if (!kIsWeb) {
        platform = defaultTargetPlatform.name; // Lấy tên nền tảng (iOS, Android)
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('fcmTokens')
          .doc(token) // Sử dụng token làm ID để tránh lưu trùng lặp
          .set({
        'token': token,
        'createdAt': FieldValue.serverTimestamp(),
        'platform': platform,
      });
    } catch (e) {
      print("Lỗi khi lưu FCM token: $e");
    }
  }

  /// Xóa token khỏi Firestore, hữu ích khi đăng xuất
  static Future<void> removeTokenFromDatabase() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    final fcmToken = await FirebaseMessaging.instance.getToken();

    if (userId == null || fcmToken == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('fcmTokens')
          .doc(fcmToken)
          .delete();
      print("Đã xóa FCM token khi đăng xuất.");
    } catch (e) {
      print("Lỗi khi xóa FCM token: $e");
    }
  }
}