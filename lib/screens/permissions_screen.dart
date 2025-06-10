import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import 'edit_permission_screen.dart';


class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  // Hàm hiển thị hộp thoại để thêm quyền mới
  Future<void> _showAddPermissionDialog() async {
    final emailController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Cấp quyền cho người dùng mới'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Email người dùng'),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.isEmpty || !value.contains('@')) {
                  return 'Vui lòng nhập email hợp lệ';
                }
                return null;
              },
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Hủy'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            ElevatedButton(
              child: const Text('Thêm'),
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final email = emailController.text.trim();
                  // Đóng hộp thoại trước khi xử lý để tránh user nhấn nhiều lần
                  Navigator.of(dialogContext).pop();
                  await _addPermissionByEmail(email);
                }
              },
            ),
          ],
        );
      },
    );
  }


  // Trong file lib/screens/permissions_screen.dart

  Future<void> _addPermissionByEmail(String email) async {
    final appState = context.read<AppState>();
    if (appState.authUserId == null) return;

    try {
      // Tìm người dùng B thông qua email
      final userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không tìm thấy người dùng với email này.')),
        );
        return;
      }

      final targetUser = userQuery.docs.first;
      final targetUid = targetUser.id;
      final targetEmail = targetUser.data()['email'] ?? email;

      // TẠO DOCUMENT PERMISSION VỚI CẤU TRÚC CHUẨN
      // Đường dẫn sẽ là: /users/{UID của A}/permissions/{UID của B}
      await FirebaseFirestore.instance
          .collection('users')
          .doc(appState.authUserId) // UID của người cấp quyền (A)
          .collection('permissions')
          .doc(targetUid) // <-- DÙNG UID CỦA NGƯỜI NHẬN LÀM ID DOCUMENT
          .set({
        'granteeUid': targetUid, // <-- LƯU LẠI UID VÀO TRƯỜNG granteeUid
        'email': targetEmail,
        'grantedAt': FieldValue.serverTimestamp(),
        // Khởi tạo map permissions với tất cả các quyền là false
        'permissions': {
          'canEditRevenue': false,
          'canManageProducts': false,
          'canEditExpense': false,
          'canViewReport': false,
          'canManagePermissions': false,
        }
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã thêm người dùng $targetEmail. Hãy vào chỉnh sửa để cấp quyền chi tiết.')),
      );

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi cấp quyền: $e')),
      );
    }
  }

  // Hàm xóa quyền
  Future<void> _deletePermission(String targetUid) async {
    final appState = context.read<AppState>();
    if (appState.authUserId == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(appState.authUserId)
          .collection('permissions')
          .doc(targetUid)
          .delete();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã xóa quyền truy cập.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi xóa quyền: $e')),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    // Lấy authUserId từ AppState
    final authUserId = context.watch<AppState>().authUserId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý quyền truy cập'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Lắng nghe real-time collection 'permissions' của người dùng đang đăng nhập
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(authUserId)
            .collection('permissions')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Đã xảy ra lỗi: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'Chưa có ai được cấp quyền.\nNhấn nút + để thêm.',
                textAlign: TextAlign.center,
              ),
            );
          }

          // Nếu có dữ liệu, hiển thị danh sách
          final permissionDocs = snapshot.data!.docs;
          return ListView.builder(
            itemCount: permissionDocs.length,
            itemBuilder: (context, index) {
              final doc = permissionDocs[index];
              final data = doc.data() as Map<String, dynamic>;
              final email = data['email'] ?? 'Không có email';
              final appState = context.read<AppState>(); // Lấy AppState để dùng trong dialog

              // Tách Card ra thành một biến riêng để dễ quản lý
              final permissionCard = Card(
                margin: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 8.0),
                elevation: 2.0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).primaryColor.withAlpha(40),
                    foregroundColor: Theme.of(context).primaryColor,
                    child: Text(email.isNotEmpty ? email[0].toUpperCase() : '?'),
                  ),
                  title: Text(email, style: TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: Text("Chỉnh sửa quyền chi tiết"),
                  trailing: Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EditPermissionScreen(
                          granteeUid: doc.id,
                          granteeEmail: email,
                        ),
                      ),
                    );
                  },
                ),
              );

              // Bọc Card trong Dismissible để có hành động trượt
              return Dismissible(
                key: Key(doc.id), // Key là bắt buộc và phải độc nhất cho mỗi item
                direction: DismissDirection.endToStart, // Chỉ cho phép trượt từ phải qua trái

                // Hiển thị nền màu đỏ khi trượt
                background: Container(
                  color: Colors.redAccent.shade400,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  alignment: Alignment.centerRight,
                  child: const Icon(Icons.delete_forever, color: Colors.white),
                ),

                // Hiển thị hộp thoại xác nhận trước khi xóa
                confirmDismiss: (direction) async {
                  return await showDialog<bool>(
                    context: context,
                    builder: (BuildContext dialogContext) {
                      return AlertDialog(
                        title: const Text("Xác nhận"),
                        content: Text("Bạn có chắc muốn thu hồi quyền của $email không?"),
                        actions: <Widget>[
                          TextButton(
                            child: const Text("Hủy"),
                            onPressed: () {
                              Navigator.of(dialogContext).pop(false); // Trả về false
                            },
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent.shade400,
                                foregroundColor: Colors.white
                            ),
                            child: const Text("Xóa"),
                            onPressed: () async {
                              // Gọi hàm xóa ở đây trước khi đóng dialog
                              try {
                                await _deletePermission(doc.id);
                                Navigator.of(dialogContext).pop(true); // Trả về true nếu xóa thành công
                              } catch (e) {
                                Navigator.of(dialogContext).pop(false); // Trả về false nếu có lỗi
                                ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text("Lỗi khi xóa quyền: $e"))
                                );
                              }
                            },
                          ),
                        ],
                      );
                    },
                  ) ?? false; // Nếu người dùng nhấn ra ngoài, coi như là Hủy (false)
                },
                // onDismissed không cần thiết vì chúng ta đã xử lý trong confirmDismiss
                child: permissionCard,
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddPermissionDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}