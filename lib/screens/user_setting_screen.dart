import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fingrowth/screens/user_guide_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import 'general_settings_screen.dart';
import 'login_screen.dart';

class UserSettingsScreen extends StatelessWidget {
  // Hàm đăng xuất
  Future<void> _signOut(BuildContext context) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Xác nhận đăng xuất"),
        content: const Text("Bạn có chắc muốn đăng xuất không?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Hủy", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Xác nhận", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseAuth.instance.signOut(); // Đăng xuất khỏi Firebase
        await GoogleSignIn().signOut(); // Đăng xuất khỏi Google Sign-In
        Navigator.pop(context); // Thoát UserSettingsScreen
        print("Đăng xuất thành công từ UserSettingsScreen");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Đã đăng xuất thành công")),
        );
      } catch (e) {
        print("Lỗi đăng xuất: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đăng xuất thất bại: $e')),
        );
      }
    }
  }

  // Hàm xóa toàn bộ dữ liệu
  // Trong user_setting_screen.dart, thay hàm _clearAllData bằng đoạn code sau:
  Future<void> _clearAllData(BuildContext context) async {
    final appState = Provider.of<AppState>(context, listen: false);
    String? userId = appState.userId;

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Không tìm thấy thông tin người dùng")),
      );
      return;
    }

    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Xác nhận làm mới dữ liệu"),
        content: const Text("Bạn có chắc muốn xóa toàn bộ dữ liệu không? Hành động này không thể hoàn tác."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Hủy", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Xóa", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final firestore = FirebaseFirestore.instance;
        final batch = firestore.batch();

        // Xóa dữ liệu Firestore
        final collections = ['expenses', 'revenue', 'transactions', 'products'];
        for (var collection in collections) {
          var snapshot = await firestore
              .collection('users')
              .doc(userId)
              .collection(collection)
              .get();
          for (var doc in snapshot.docs) {
            batch.delete(doc.reference);
          }
        }

        // Xóa các subcollections của expenses
        final expenseSubcollections = ['fixed/daily', 'variable/daily', 'fixedList', 'variableList/monthly', 'monthlyFixed/monthly'];
        for (var sub in expenseSubcollections) {
          var parts = sub.split('/');
          var snapshot = await firestore
              .collection('users')
              .doc(userId)
              .collection('expenses')
              .doc(parts[0])
              .collection(parts[1])
              .get();
          for (var doc in snapshot.docs) {
            batch.delete(doc.reference);
          }
        }

        await batch.commit();

        // Đặt lại trạng thái AppState
        appState.setExpenses(0.0, 0.0); // Cập nhật fixedExpense và variableExpense
        appState.mainRevenue = 0.0;
        appState.secondaryRevenue = 0.0;
        appState.otherRevenue = 0.0;
        appState.mainRevenueTransactions.value = [];
        appState.secondaryRevenueTransactions.value = [];
        appState.otherRevenueTransactions.value = [];
        appState.fixedExpenseList.value = [];
        appState.variableExpenseList.value = [];

        appState.notifyListeners();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Đã làm mới toàn bộ dữ liệu của người dùng")),
        );
      } catch (e) {
        print("Lỗi khi xóa dữ liệu: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Lỗi khi xóa dữ liệu: $e")),
        );
      }
    }
  }

  // Hàm xóa tài khoản
  Future<void> _deleteAccount(BuildContext context) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Xác nhận xóa tài khoản"),
        content: const Text("Bạn có chắc muốn xóa tài khoản không? Hành động này không thể hoàn tác."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Hủy", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Xóa", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final appState = Provider.of<AppState>(context, listen: false);
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) throw Exception("Không tìm thấy tài khoản");

        // Thử xóa tài khoản
        try {
          await user.delete();
        } on FirebaseAuthException catch (e) {
          if (e.code == 'requires-recent-login') {
            // Yêu cầu đăng nhập lại
            final GoogleSignIn googleSignIn = GoogleSignIn();
            final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
            if (googleUser == null) {
              throw Exception("Đăng nhập lại bị hủy");
            }

            final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
            final credential = GoogleAuthProvider.credential(
              accessToken: googleAuth.accessToken,
              idToken: googleAuth.idToken,
            );

            // Xác thực lại
            await FirebaseAuth.instance.currentUser!.reauthenticateWithCredential(credential);

            // Thử xóa lại
            await FirebaseAuth.instance.currentUser!.delete();
          } else {
            rethrow; // Ném lại các lỗi khác
          }
        }

        // Xóa dữ liệu Firestore
        await _clearAllData(context);

        // Đăng xuất Google Sign-In
        await GoogleSignIn().signOut();

        // Đặt lại AppState
        appState.logout();

        // Điều hướng về LoginScreen
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => LoginScreen()),
              (route) => false,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Tài khoản đã được xóa thành công")),
        );
      } catch (e) {
        print("Lỗi khi xóa tài khoản: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Lỗi khi xóa tài khoản: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20.0),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [const Color(0xFF1976D2), const Color(0xFF42A5F5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.white,
                      backgroundImage: user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
                      child: user?.photoURL == null ? const Icon(Icons.person, size: 50, color: Color(0xFF1976D2)) : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.displayName ?? "Người dùng",
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user?.email ?? "Tài khoản chưa xác định",
                            style: const TextStyle(fontSize: 16, color: Colors.white70),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              "Thành viên cơ bản",
                              style: TextStyle(fontSize: 14, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                      splashRadius: 20,
                      tooltip: 'Đóng',
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                child: Text("Ứng dụng", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              ),
              Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Column(
                  children: [
                    _buildListTile(context, "Cài đặt chung", Icons.settings, () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => GeneralSettingsScreen()),
                      );
                    }),
                    const Divider(height: 1),
                    _buildListTile(context, "Đánh giá ứng dụng", Icons.star, () {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Chức năng đang phát triển")));
                    }),
                    const Divider(height: 1),
                    _buildListTile(context, "Hướng dẫn sử dụng", Icons.description, () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => UserGuideScreen()),
                      );
                    }),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                child: Text("Tài khoản", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              ),
              Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Column(
                  children: [
                    _buildListTile(context, "Phân quyền", Icons.security, () {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Chức năng đang phát triển")));
                    }),
                    const Divider(height: 1),
                    _buildListTile(context, "Đăng xuất", Icons.logout, () async {
                      await _signOut(context); // Gọi _signOut với context
                    }, color: Colors.red),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                child: Text("Dữ liệu", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              ),
              Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Column(
                  children: [
                    _buildListTile(context, "Làm mới dữ liệu", Icons.refresh, () => _clearAllData(context)),
                    const Divider(height: 1),
                    _buildListTile(context, "Xóa tài khoản", Icons.delete_forever, () => _deleteAccount(context), color: Colors.red),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListTile(BuildContext context, String title, IconData icon, VoidCallback onTap, {Color? color}) {
    return ListTile(
      leading: Icon(icon, color: color ?? Theme.of(context).iconTheme.color),
      title: Text(
        title,
        style: TextStyle(color: color ?? Theme.of(context).textTheme.bodyLarge?.color),
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      splashColor: Colors.grey.withOpacity(0.2),
    );
  }
}