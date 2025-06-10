import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';

class EditPermissionScreen extends StatefulWidget {
  final String granteeUid;
  final String granteeEmail;

  const EditPermissionScreen({
    Key? key,
    required this.granteeUid,
    required this.granteeEmail,
  }) : super(key: key);

  @override
  _EditPermissionScreenState createState() => _EditPermissionScreenState();
}

class _EditPermissionScreenState extends State<EditPermissionScreen> {
  bool _isLoading = true;
  Map<String, bool> _currentPermissions = {};

  // Danh sách các quyền có thể cấp và tên hiển thị tương ứng
  final Map<String, String> _availablePermissions = {
    'canEditRevenue': 'Sửa/Xóa Giao dịch Doanh thu',
    'canManageProducts': 'Quản lý Sản phẩm/Dịch vụ',
    'canManageFixedExpenses': 'Sửa/Xóa Chi phí Cố định',
    'canManageVariableExpenses': 'Sửa/Xóa Chi phí Biến đổi',
    'canManageExpenseTypes': 'Quản lý DS Chi phí Biến đổi',
    'canViewReport': 'Xem Báo cáo & Phân tích',
  };

  @override
  void initState() {
    super.initState();
    _loadCurrentPermissions();
  }

  // Tải các quyền hiện tại của người dùng từ Firestore
  Future<void> _loadCurrentPermissions() async {
    final ownerId = context.read<AppState>().authUserId;
    if (ownerId == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(ownerId)
          .collection('permissions')
          .doc(widget.granteeUid)
          .get();

      if (mounted && doc.exists && doc.data()?['permissions'] != null) {
        setState(() {
          _currentPermissions = Map<String, bool>.from(doc.data()!['permissions']);
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() {
          _currentPermissions = { for (var key in _availablePermissions.keys) key : false };
          _isLoading = false;
        });
      }
    } catch (e) {
      if(mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Lỗi tải quyền: $e")));
      }
    }
  }

  // Lưu lại các quyền đã thay đổi lên Firestore
  Future<void> _updatePermission(String key, bool value) async {
    final ownerId = context.read<AppState>().authUserId;
    if (ownerId == null) return;

    setState(() {
      _currentPermissions[key] = value;
    });

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(ownerId)
          .collection('permissions')
          .doc(widget.granteeUid)
          .set({
        'permissions': _currentPermissions,
      }, SetOptions(merge: true));
    } catch (e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Lỗi cập nhật quyền: $e")));
        setState(() => _currentPermissions[key] = !value); // Rollback nếu lỗi
      }
    }
  }

  Widget _buildPermissionSwitch(String key, String title) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: SwitchListTile(
        title: Text(title),
        value: _currentPermissions[key] ?? false,
        onChanged: (bool value) {
          _updatePermission(key, value);
        },
        secondary: Icon(_getIconForKey(key), color: Theme.of(context).primaryColor),
      ),
    );
  }

  IconData _getIconForKey(String key) {
    switch (key) {
      case 'canEditRevenue': return Icons.monetization_on_outlined;
      case 'canManageProducts': return Icons.inventory_2_outlined;
      case 'canEditExpense': return Icons.receipt_long_outlined;
      case 'canViewReport': return Icons.bar_chart_outlined;
      case 'canManageFixedExpenses': return Icons.lock_outline;
      case 'canManageVariableExpenses': return Icons.local_fire_department_outlined;
      case 'canManageExpenseTypes': return Icons.list_alt_outlined;
      default: return Icons.vpn_key_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Phân quyền cho'),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(20.0),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              widget.granteeEmail,
              style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.9)),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(8.0),
        children: _availablePermissions.entries.map((entry) {
          return _buildPermissionSwitch(entry.key, entry.value);
        }).toList(),
      ),
    );
  }
}