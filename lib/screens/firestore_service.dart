import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Lưu hoặc cập nhật thông tin người dùng vào collection 'users' trên Firestore.
  /// Sử dụng SetOptions(merge: true) để đảm bảo không ghi đè lên các
  /// sub-collection dữ liệu kinh doanh đã có của người dùng.
  Future<void> saveUserInfoToFirestore(User user, String? deviceId) async {
    try {
      final userDocRef = _db.collection('users').doc(user.uid);
      await userDocRef.set({
        'email': user.email,
        'displayName': user.displayName ?? user.email?.split('@').first,
        'photoURL': user.photoURL,
        'lastLoginDeviceId': deviceId, // <-- Thêm dòng này
        'lastLoginAt': FieldValue.serverTimestamp(), // <-- Thêm dòng này
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)); //
      print("Đã lưu/cập nhật thông tin và deviceId cho user: ${user.uid}"); //
    } catch (e) {
      print("Lỗi khi lưu thông tin người dùng vào Firestore: $e"); //
    }
  }
}