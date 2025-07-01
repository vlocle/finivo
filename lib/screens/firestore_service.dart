import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Lưu hoặc cập nhật thông tin người dùng vào collection 'users' trên Firestore.
  /// Sử dụng SetOptions(merge: true) để đảm bảo không ghi đè lên các
  /// sub-collection dữ liệu kinh doanh đã có của người dùng.
  Future<void> saveUserInfoToFirestore(User user, String? deviceId, {AuthorizationCredentialAppleID? appleCredential}) async {
    try {
      final userDocRef = _db.collection('users').doc(user.uid);
      final userSnapshot = await userDocRef.get();

      // Bước 1: Lấy displayName đã tồn tại một cách an toàn
      String? existingDisplayName;
      if (userSnapshot.exists) {
        // Ép kiểu dữ liệu sang Map<String, dynamic> để truy cập
        final data = userSnapshot.data() as Map<String, dynamic>?;
        existingDisplayName = data?['displayName'] as String?;
      }

      // ▲▲▲ KẾT THÚC PHẦN SỬA LỖI ▲▲▲

      // Dữ liệu mặc định
      final Map<String, dynamic> userData = {
        'email': user.email,
        'photoURL': user.photoURL,
        'lastLoginDeviceId': deviceId,
        'lastLoginAt': FieldValue.serverTimestamp(),
      };

      // Chỉ đặt 'createdAt' nếu là người dùng mới
      if (!userSnapshot.exists) {
        userData['createdAt'] = FieldValue.serverTimestamp();
      }

      // Logic lấy tên người dùng (giữ nguyên như trước)
      String? displayName = user.displayName;
      if (appleCredential?.givenName != null || appleCredential?.familyName != null) {
        final givenName = appleCredential!.givenName ?? '';
        final familyName = appleCredential.familyName ?? '';
        displayName = '$givenName $familyName'.trim();
      }
      displayName ??= user.email?.split('@').first;

      // Chỉ cập nhật displayName nếu nó có giá trị và người dùng chưa có tên
      if (displayName != null && displayName.isNotEmpty && (existingDisplayName == null || existingDisplayName.isEmpty)) {
        userData['displayName'] = displayName;
      }

      await userDocRef.set(userData, SetOptions(merge: true));
      print("Đã lưu/cập nhật thông tin và deviceId cho user: ${user.uid}");

    } catch (e) {
      print("Lỗi khi lưu thông tin người dùng vào Firestore: $e");
    }
  }

  Future<void> updateDisplayName(String uid, String newName) async {
    try {
      await _db.collection('users').doc(uid).update({
        'displayName': newName,
      });
      print("Đã cập nhật displayName cho user: $uid");
    } catch (e) {
      print("Lỗi khi cập nhật displayName trên Firestore: $e");
      // Ném lại lỗi để bên gọi có thể xử lý
      rethrow;
    }
  }
}