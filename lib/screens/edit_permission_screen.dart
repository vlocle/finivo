import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import 'package:fingrowth/screens/report_screen.dart';

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
    'canManageOtherExpenses': 'Sửa/Xóa Chi phí Khác',
    'canManageWallets': 'Quản lý Ví tiền',
    'canViewReport': 'Xem Báo cáo & Phân tích',
  };

  @override
  void initState() {
    super.initState();
    _loadCurrentPermissions();
  }

  // Toàn bộ logic xử lý dữ liệu với Firebase được giữ nguyên
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

  Future<void> _updatePermission(String key, bool value) async {
    final ownerId = context.read<AppState>().authUserId;
    if (ownerId == null) return;
    setState(() {
      _currentPermissions[key] = value;
      // Logic nghiệp vụ: Bật quyền sửa doanh thu thì tự động bật và khóa quyền sửa chi phí biến đổi
      if (key == 'canEditRevenue' && value == true) {
        _currentPermissions['canManageVariableExpenses'] = true;
      }
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
        // Rollback nếu lỗi
        setState(() => _currentPermissions[key] = !value);
      }
    }
  }

  // Giữ nguyên hàm lấy icon
  IconData _getIconForKey(String key) {
    switch (key) {
      case 'canEditRevenue': return Icons.monetization_on_outlined;
      case 'canManageProducts': return Icons.inventory_2_outlined;
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
      backgroundColor: AppColors.getBackgroundColor(context),
      body: CustomScrollView(
        slivers: [
          // [FIXED-UI] SliverAppBar được sửa lỗi layout
          SliverAppBar(
            pinned: true,
            expandedHeight: 120.0,
            backgroundColor: AppColors.getCardColor(context),
            foregroundColor: AppColors.getTextColor(context),
            elevation: 2,
            shadowColor: Colors.black.withOpacity(0.1),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
              centerTitle: false, // Quan trọng: Đảm bảo tiêu đề căn trái
              title: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Dòng chữ phụ đã được chuyển vào đây
                  Text(
                    'Phân quyền cho',
                    style: GoogleFonts.poppins(
                      color: AppColors.getTextSecondaryColor(context),
                      fontSize: 12, // Kích thước nhỏ hơn cho tiêu đề phụ
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  // Dòng tiêu đề chính
                  Text(
                    widget.granteeEmail,
                    style: GoogleFonts.poppins(
                      color: AppColors.getTextColor(context),
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
          ),
          _isLoading
              ? SliverFillRemaining(
            child: Center(child: CircularProgressIndicator(color: AppColors.primaryBlue)),
          )
              : SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                    (context, index) {
                  final entry = _availablePermissions.entries.elementAt(index);
                  final String key = entry.key;
                  final String title = entry.value;

                  bool isLocked = false;
                  if (key == 'canManageVariableExpenses' && (_currentPermissions['canEditRevenue'] ?? false)) {
                    isLocked = true;
                  }

                  return _buildPermissionSwitch(key, title, isLocked: isLocked);
                },
                childCount: _availablePermissions.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // [LUXURY-UI] Widget build switch được thiết kế lại
  Widget _buildPermissionSwitch(String key, String title, {bool isLocked = false}) {
    bool currentValue = _currentPermissions[key] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isLocked ? AppColors.getBackgroundColor(context) : AppColors.getCardColor(context),
        borderRadius: BorderRadius.circular(15),
        boxShadow: isLocked ? [] : [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isLocked ? AppColors.getTextSecondaryColor(context).withOpacity(0.1) : AppColors.primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _getIconForKey(key),
                color: isLocked ? AppColors.getTextSecondaryColor(context) : AppColors.primaryBlue,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w500,
                  color: isLocked ? AppColors.getTextSecondaryColor(context).withOpacity(0.7) : AppColors.getTextColor(context),
                  decoration: isLocked ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Switch(
              value: currentValue,
              onChanged: isLocked ? null : (bool value) {
                _updatePermission(key, value);
              },
              activeColor: AppColors.chartGreen,
              inactiveThumbColor: AppColors.getTextSecondaryColor(context).withOpacity(0.6),
              inactiveTrackColor: AppColors.getBorderColor(context),
            ),
          ],
        ),
      ),
    );
  }
}