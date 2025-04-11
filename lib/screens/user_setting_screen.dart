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
  Future<void> _clearAllData(BuildContext context) async {
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
      var revenueBox = Hive.box('revenueBox');
      var expenseBox = Hive.box('expenseBox');
      var transactionBox = Hive.box('transactionBox');
      await revenueBox.clear();
      await expenseBox.clear();
      await transactionBox.clear();
      Provider.of<AppState>(context, listen: false).notifyListeners();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Đã làm mới toàn bộ dữ liệu")));
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
      await _signOut(context); // Gọi _signOut với context
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tài khoản đã được xóa")));
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
                    _buildListTile(context, "Điều khoản sử dụng", Icons.description, () {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Chức năng đang phát triển")));
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