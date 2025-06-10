import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Lưu hoặc cập nhật thông tin người dùng vào collection 'users' trên Firestore.
  /// Sử dụng SetOptions(merge: true) để đảm bảo không ghi đè lên các
  /// sub-collection dữ liệu kinh doanh đã có của người dùng.
  Future<void> saveUserInfoToFirestore(User user) async {
    try {
      final userDocRef = _db.collection('users').doc(user.uid);

      // set với merge: true sẽ tạo mới document nếu chưa có,
      // hoặc chỉ cập nhật các trường được cung cấp nếu document đã tồn tại.
      // Quan trọng: Nó sẽ không xóa các sub-collection (daily_data, expenses,...)
      await userDocRef.set({
        'email': user.email,
        'displayName': user.displayName ?? user.email?.split('@').first,
        'photoURL': user.photoURL,
        'createdAt': FieldValue.serverTimestamp(), // Ghi lại thời gian tạo/cập nhật lần đầu
      }, SetOptions(merge: true));

      print("Đã lưu/cập nhật thông tin cho user: ${user.uid}");

    } catch (e) {
      print("Lỗi khi lưu thông tin người dùng vào Firestore: $e");
      // Bạn có thể rethrow lỗi nếu cần xử lý ở nơi gọi
      // rethrow;
    }
  }
}