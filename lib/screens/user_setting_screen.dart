import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fingrowth/screens/user_guide_screen.dart'; // Giả sử bạn có màn hình này
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import 'general_settings_screen.dart'; // Giả sử bạn có màn hình này
import 'login_screen.dart';
import 'permissions_screen.dart';

class UserSettingsScreen extends StatelessWidget {
  const UserSettingsScreen({super.key});

  // --- Bảng màu hiện đại ---
  static const Color _primaryColor = Color(0xFF0A7AFF); // Màu xanh dương chủ đạo
  static const Color _secondaryColor = Color(0xFFF0F4F8); // Màu nền sáng
  static const Color _textColorPrimary = Color(0xFF1D2D3A); // Màu chữ chính (đậm)
  static const Color _textColorSecondary = Color(0xFF6E7A8A); // Màu chữ phụ (nhạt hơn)
  static const Color _cardBackgroundColor = Colors.white;
  static const Color _dangerColor = Color(0xFFD32F2F); // Màu cho các hành động nguy hiểm (đỏ đậm)
  static const Color _iconColor = Color(0xFF4A5568); // Màu icon chung

  // --- Hàm đăng xuất ---
  Future<void> _signOut(BuildContext context) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.logout_outlined, color: _dangerColor),
            SizedBox(width: 10),
            Text("Xác nhận đăng xuất", style: TextStyle(color: _textColorPrimary, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text("Bạn có chắc muốn đăng xuất không?", style: TextStyle(color: _textColorSecondary)),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Hủy", style: TextStyle(color: _textColorSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _dangerColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Đăng xuất"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseAuth.instance.signOut();
        await GoogleSignIn().signOut();
        // Không pop ở đây nữa, vì AuthWrapper sẽ xử lý việc điều hướng
        // Navigator.pop(context); // Thoát UserSettingsScreen
        print("Đăng xuất thành công từ UserSettingsScreen");
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Đã đăng xuất thành công"),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
          // Điều hướng về màn hình đăng nhập một cách an toàn
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => LoginScreen()),
                (Route<dynamic> route) => false,
          );
        }
      } catch (e) {
        print("Lỗi đăng xuất: $e");
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Đăng xuất thất bại: $e'),
              backgroundColor: _dangerColor,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  // --- Hàm xóa toàn bộ dữ liệu ---
  Future<void> _clearAllData(BuildContext context) async {
    final appState = Provider.of<AppState>(context, listen: false);
    String? userId = appState.activeUserId;

    if (userId == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Không tìm thấy thông tin người dùng"),
            backgroundColor: _dangerColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: _dangerColor),
            SizedBox(width: 10),
            Text("Xác nhận làm mới dữ liệu", style: TextStyle(color: _textColorPrimary, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
            "Bạn có chắc muốn xóa toàn bộ dữ liệu không? Hành động này không thể hoàn tác.",
            style: TextStyle(color: _textColorSecondary)),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Hủy", style: TextStyle(color: _textColorSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _dangerColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Xóa"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final firestore = FirebaseFirestore.instance;
        final batch = firestore.batch();

        // Xóa dữ liệu Firestore
        final collections = ['expenses', 'revenue', 'transactions', 'products', 'daily_data'];
        for (var collectionName in collections) {
          var snapshot = await firestore
              .collection('users')
              .doc(userId)
              .collection(collectionName)
              .get();
          for (var doc in snapshot.docs) {
            batch.delete(doc.reference);
          }
        }

        // Xóa các subcollections của expenses
        final expenseSubcollections = [
          'expenses/fixed/daily',
          'expenses/variable/daily',
          'expenses/fixedList/items', // Giả sử tên subcollection là 'items'
          'expenses/variableList/monthly', // Giả sử tên subcollection là 'monthly'
          // 'expenses/monthlyFixed/monthly' // Xem lại cấu trúc này nếu cần
        ];

        for (var path in expenseSubcollections) {
          var parts = path.split('/'); // Ví dụ: 'expenses', 'fixed', 'daily'
          CollectionReference<Map<String, dynamic>> subCollectionRef;
          if (parts.length == 3) { // expenses/fixed/daily
            subCollectionRef = firestore
                .collection('users')
                .doc(userId)
                .collection(parts[0]) // 'expenses'
                .doc(parts[1])        // 'fixed'
                .collection(parts[2]);// 'daily'
          } else if (parts.length == 4) { // users/userId/expenses/fixedList/items
            subCollectionRef = firestore
                .collection('users')
                .doc(userId)
                .collection(parts[0]) // 'expenses'
                .doc(parts[1])        // 'fixedList'
                .collection(parts[2]);// 'items' (Cần kiểm tra lại cấu trúc này, ví dụ trên là 3 parts)
            // Nếu cấu trúc là users/userId/expenses/fixedList/docId/items thì cần điều chỉnh
            // Hiện tại, giả định 'fixedList' và 'variableList' là document, và 'items', 'monthly' là subcollection của chúng.
            // Nếu 'fixedList' là collection, thì logic trên đã sai.
            // Dựa theo code gốc, 'fixedList' và 'variableList' là document.
            // Ví dụ: expenses/fixedList/items -> users/userId/expenses/fixedList/collection('items')
            // Điều chỉnh lại:
            // 'expenses/fixedList/items' -> collection('users').doc(userId).collection('expenses').doc('fixedList').collection('items')
            // 'expenses/variableList/monthly' -> collection('users').doc(userId).collection('expenses').doc('variableList').collection('monthly')
            // Vì vậy, path nên là: 'expenses/fixedList/items' và 'expenses/variableList/monthly'
            // Và parts[0] = 'expenses', parts[1] = 'fixedList' (tên document), parts[2] = 'items' (tên subcollection)
            print("Đang xử lý subcollection path: $path");
            subCollectionRef = firestore
                .collection('users')
                .doc(userId)
                .collection(parts[0]) // 'expenses'
                .doc(parts[1])        // 'fixedList' hoặc 'variableList'
                .collection(parts[2]);// 'items' hoặc 'monthly'

          } else {
            print("Đường dẫn subcollection không hợp lệ: $path");
            continue;
          }


          var snapshot = await subCollectionRef.get();
          for (var doc in snapshot.docs) {
            batch.delete(doc.reference);
          }
        }


        await batch.commit();

        // Đặt lại trạng thái AppState
        //appState.resetAllData(); // Gọi một hàm tổng hợp trong AppState để reset

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Đã làm mới toàn bộ dữ liệu của người dùng"),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        print("Lỗi khi xóa dữ liệu: $e");
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Lỗi khi xóa dữ liệu: $e"),
              backgroundColor: _dangerColor,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  // --- Hàm xóa tài khoản ---
  Future<void> _deleteAccount(BuildContext context) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_forever_outlined, color: _dangerColor),
            SizedBox(width: 10),
            Text("Xác nhận xóa tài khoản", style: TextStyle(color: _textColorPrimary, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
            "Bạn có chắc muốn xóa tài khoản không? Toàn bộ dữ liệu của bạn sẽ bị mất và hành động này không thể hoàn tác.",
            style: TextStyle(color: _textColorSecondary)),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Hủy", style: TextStyle(color: _textColorSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _dangerColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Xóa tài khoản"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final appState = Provider.of<AppState>(context, listen: false);
        final user = FirebaseAuth.instance.currentUser;

        if (user == null) throw Exception("Không tìm thấy tài khoản để xóa.");

        // Xóa dữ liệu Firestore trước khi xóa tài khoản
        // Lưu ý: _clearAllData hiển thị SnackBar riêng, có thể cân nhắc gộp thông báo
        await _clearAllData(context); // Gọi lại hàm xóa dữ liệu

        // Thử xóa tài khoản Firebase Auth
        try {
          await user.delete();
        } on FirebaseAuthException catch (e) {
          if (e.code == 'requires-recent-login') {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      "Vui lòng đăng nhập lại để thực hiện thao tác này."),
                  backgroundColor: Colors.orangeAccent,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
            // Cân nhắc điều hướng người dùng đến màn hình đăng nhập lại
            // hoặc cung cấp tùy chọn đăng nhập lại trực tiếp.
            // Hiện tại, chỉ thông báo và không xóa.
            return; // Ngăn chặn việc tiếp tục nếu cần đăng nhập lại
          } else {
            rethrow; // Ném lại các lỗi Firebase Auth khác
          }
        }

        // Đăng xuất Google Sign-In (nếu đã đăng nhập bằng Google)
        await GoogleSignIn().signOut();

        // Đặt lại AppState (nếu cần, ví dụ: xóa thông tin người dùng cục bộ)
        appState.logout(); // Đảm bảo hàm này xử lý đúng việc reset state

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Tài khoản đã được xóa thành công"),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
          // Điều hướng về màn hình đăng nhập
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => LoginScreen()),
                (Route<dynamic> route) => false,
          );
        }
      } catch (e) {
        print("Lỗi khi xóa tài khoản: $e");
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Lỗi khi xóa tài khoản: $e"),
              backgroundColor: _dangerColor,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: _secondaryColor,
      appBar: AppBar(
        title: const Text(
          "Cài đặt",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: _primaryColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white), // Màu cho nút back
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildUserProfileSection(context, user),
            const SizedBox(height: 20),
            _buildSettingsGroup(
              context,
              title: "Ứng dụng",
              children: [
                _buildSettingsItem(
                  context,
                  icon: Icons.settings_outlined,
                  title: "Cài đặt chung",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => GeneralSettingsScreen()),
                    );
                  },
                ),
                _buildSettingsItem(
                  context,
                  icon: Icons.star_outline,
                  title: "Đánh giá ứng dụng",
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Chức năng đang phát triển")));
                  },
                ),
                _buildSettingsItem(
                  context,
                  icon: Icons.description_outlined,
                  title: "Hướng dẫn sử dụng",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => UserGuideScreen()), // Thêm const nếu UserGuideScreen là const
                    );
                  },
                ),
              ],
            ),
            _buildSettingsGroup(
              context,
              title: "Tài khoản",
              children: [
                _buildSettingsItem(
                  context,
                  icon: Icons.group_add_outlined,
                  title: "Quản lý quyền truy cập",
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const PermissionsScreen()));
                  },
                ),
                _buildSettingsItem(
                  context,
                  icon: Icons.logout_outlined,
                  title: "Đăng xuất",
                  textColor: _dangerColor,
                  iconColor: _dangerColor,
                  onTap: () async {
                    await _signOut(context);
                  },
                ),
              ],
            ),
            _buildSettingsGroup(
              context,
              title: "Dữ liệu",
              children: [
                _buildSettingsItem(
                  context,
                  icon: Icons.refresh_outlined,
                  title: "Làm mới dữ liệu",
                  onTap: () => _clearAllData(context),
                ),
                _buildSettingsItem(
                  context,
                  icon: Icons.delete_forever_outlined,
                  title: "Xóa tài khoản",
                  textColor: _dangerColor,
                  iconColor: _dangerColor,
                  onTap: () => _deleteAccount(context),
                ),
              ],
            ),
            const SizedBox(height: 30), // Khoảng trống ở cuối
          ],
        ),
      ),
    );
  }

  Widget _buildUserProfileSection(BuildContext context, User? user) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24.0),
      decoration: const BoxDecoration(
        color: _primaryColor,
        // borderRadius: BorderRadius.only(
        //   bottomLeft: Radius.circular(30),
        //   bottomRight: Radius.circular(30),
        // ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: Colors.white.withOpacity(0.9),
            backgroundImage:
            user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
            child: user?.photoURL == null
                ? Icon(Icons.person_outline, size: 60, color: _primaryColor.withOpacity(0.8))
                : null,
          ),
          const SizedBox(height: 16),
          Text(
            user?.displayName ?? "Người dùng",
            style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            user?.email ?? "Không có thông tin email",
            style: TextStyle(fontSize: 15, color: Colors.white.withOpacity(0.85)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              "Thành viên cơ bản", // Hoặc có thể lấy từ thông tin người dùng nếu có
              style: TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsGroup(BuildContext context,
      {required String title, required List<Widget> children}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8.0, bottom: 12.0),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _textColorPrimary,
              ),
            ),
          ),
          Material( // Sử dụng Material để có hiệu ứng ripple khi nhấn
            color: _cardBackgroundColor,
            borderRadius: BorderRadius.circular(12),
            elevation: 1.5, // Độ nổi nhẹ cho card
            shadowColor: Colors.grey.withOpacity(0.15),
            child: Column(
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsItem(
      BuildContext context, {
        required IconData icon,
        required String title,
        required VoidCallback onTap,
        Color? textColor,
        Color? iconColor,
      }) {
    return InkWell( // Sử dụng InkWell để có hiệu ứng ripple
      onTap: onTap,
      borderRadius: BorderRadius.circular(12), // Cần khớp với borderRadius của Material ở trên nếu đây là item cuối/đầu
      splashColor: _primaryColor.withOpacity(0.1),
      highlightColor: _primaryColor.withOpacity(0.05),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (iconColor ?? _iconColor).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor ?? _iconColor, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: textColor ?? _textColorPrimary,
                ),
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: _textColorSecondary),
          ],
        ),
      ),
    );
  }
}