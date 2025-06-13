import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import 'edit_permission_screen.dart';
import 'package:fingrowth/screens/report_screen.dart';

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen>
    with SingleTickerProviderStateMixin {

  // [LUXURY-UI] Animation Controller để tạo hiệu ứng xuất hiện
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Toàn bộ logic xử lý data với Firebase được giữ nguyên
  // Chỉ cập nhật style của các Dialog và SnackBar

  Future<void> _showAddPermissionDialog() async {
    final emailController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text('Cấp quyền người dùng mới', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: AppColors.getTextColor(context))),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: emailController,
              decoration: InputDecoration(
                  labelText: "Email người dùng",
                  labelStyle: GoogleFonts.poppins(color: AppColors.getTextSecondaryColor(context)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.getBorderColor(context))
                  ),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.primaryBlue, width: 1.5)
                  ),
                  filled: true,
                  fillColor: AppColors.getBackgroundColor(context),
                  prefixIcon: const Icon(Icons.email_outlined, color: AppColors.primaryBlue)),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.isEmpty || !value.contains('@')) {
                  return 'Vui lòng nhập email hợp lệ';
                }
                return null;
              },
            ),
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          actions: <Widget>[
            TextButton(
              child: Text("Hủy", style: GoogleFonts.poppins(color: AppColors.getTextSecondaryColor(context), fontWeight: FontWeight.w500)),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text('Thêm', style: GoogleFonts.poppins()),
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final email = emailController.text.trim();
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

  Future<void> _addPermissionByEmail(String email) async {
    final appState = context.read<AppState>();
    if (appState.authUserId == null) return;
    try {
      final userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      if (userQuery.docs.isEmpty) {
        if (!mounted) return;
        _showStyledSnackBar('Không tìm thấy người dùng với email này.', isError: true);
        return;
      }
      final targetUser = userQuery.docs.first;
      final targetUid = targetUser.id;
      final targetEmail = targetUser.data()['email'] ?? email;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(appState.authUserId)
          .collection('permissions')
          .doc(targetUid)
          .set({
        'granteeUid': targetUid,
        'email': targetEmail,
        'grantedAt': FieldValue.serverTimestamp(),
        'permissions': {
          'canEditRevenue': false,
          'canManageProducts': false,
          'canEditExpense': false,
          'canViewReport': false,
          'canManagePermissions': false,
        }
      });
      if (!mounted) return;
      _showStyledSnackBar('Đã thêm $targetEmail. Hãy cấp quyền chi tiết.', isError: false);
    } catch (e) {
      if (!mounted) return;
      _showStyledSnackBar('Lỗi khi cấp quyền: $e', isError: true);
    }
  }

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
      if (!mounted) return;
      _showStyledSnackBar('Đã xóa quyền truy cập thành công.');
    } catch (e) {
      if (!mounted) return;
      _showStyledSnackBar('Lỗi khi xóa quyền: $e', isError: true);
    }
  }

  void _showStyledSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: isError ? AppColors.chartRed : AppColors.primaryBlue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(10),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authUserId = context.watch<AppState>().authUserId;

    return Scaffold(
      backgroundColor: AppColors.getBackgroundColor(context),
      // [LUXURY-UI] Sử dụng CustomScrollView và SliverAppBar
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            title: Text('Quản Lý Quyền Hạn', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            pinned: true,
            floating: true,
            backgroundColor: AppColors.getCardColor(context),
            foregroundColor: AppColors.getTextColor(context),
            elevation: 2,
            shadowColor: Colors.black.withOpacity(0.05),
          ),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(authUserId)
                .collection('permissions')
                .orderBy('grantedAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverFillRemaining(child: Center(child: CircularProgressIndicator()));
              }
              if (snapshot.hasError) {
                return SliverFillRemaining(child: Center(child: Text('Đã xảy ra lỗi: ${snapshot.error}')));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                _animationController.forward(from: 0.0);
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.shield_moon_outlined, size: 70, color: AppColors.getTextSecondaryColor(context)),
                          const SizedBox(height: 16),
                          Text(
                            'Chưa cấp quyền cho ai',
                            style: GoogleFonts.poppins(fontSize: 18, color: AppColors.getTextColor(context), fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Nhấn nút "+" để bắt đầu thêm cộng tác viên.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(fontSize: 15, color: AppColors.getTextSecondaryColor(context)),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              final permissionDocs = snapshot.data!.docs;
              _animationController.forward(from: 0.0);

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (context, index) {
                      final doc = permissionDocs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final email = data['email'] ?? 'Không có email';
                      final timestamp = data['grantedAt'] as Timestamp?;
                      final permissions = data['permissions'] as Map<String, dynamic>? ?? {};

                      // [LUXURY-UI] Thẻ được bọc trong Dismissible và FadeTransition
                      return FadeTransition(
                        opacity: _fadeAnimation,
                        child: Dismissible(
                          key: Key(doc.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            decoration: BoxDecoration(
                              color: AppColors.chartRed,
                              borderRadius: BorderRadius.circular(15),
                            ),
                            margin: const EdgeInsets.symmetric(vertical: 8.0),
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            alignment: Alignment.centerRight,
                            child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
                          ),
                          confirmDismiss: (direction) async {
                            return await showDialog<bool>(
                              context: context,
                              builder: (BuildContext dialogContext) {
                                return AlertDialog(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                  title: Text("Xác nhận thu hồi", style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: AppColors.getTextColor(context))),
                                  content: Text("Bạn có chắc muốn thu hồi vĩnh viễn quyền của $email không?", style: GoogleFonts.poppins(color: AppColors.getTextSecondaryColor(context))),
                                  actions: <Widget>[
                                    TextButton(
                                      child: Text("Hủy", style: GoogleFonts.poppins(color: AppColors.getTextSecondaryColor(context), fontWeight: FontWeight.w500)),
                                      onPressed: () => Navigator.of(dialogContext).pop(false),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.chartRed),
                                      child: Text("Thu hồi", style: GoogleFonts.poppins(color: Colors.white)),
                                      onPressed: () async {
                                        Navigator.of(dialogContext).pop(true);
                                      },
                                    ),
                                  ],
                                );
                              },
                            ) ?? false;
                          },
                          onDismissed: (_) {
                            _deletePermission(doc.id);
                          },
                          // [LUXURY-UI] Permission Card được thiết kế lại hoàn toàn
                          child: _buildPermissionCard(
                            email: email,
                            timestamp: timestamp,
                            permissions: permissions,
                            onEdit: () {
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
                        ),
                      );
                    },
                    childCount: permissionDocs.length,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddPermissionDialog,
        label: Text('Thêm Cộng Tác Viên', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        icon: const Icon(Icons.add),
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 4.0,
      ),
    );
  }

  // [LUXURY-UI] Tách Card ra thành một widget riêng để dễ quản lý và tái sử dụng
  Widget _buildPermissionCard({
    required String email,
    required Timestamp? timestamp,
    required Map<String, dynamic> permissions,
    required VoidCallback onEdit,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      decoration: BoxDecoration(
        color: AppColors.getCardColor(context),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 20,
            spreadRadius: -5,
            offset: const Offset(0, 10),
          ),
        ],
        // Viền Gradient tinh tế
        gradient: LinearGradient(
          stops: const [0.01, 0.01],
          colors: [AppColors.primaryBlue.withOpacity(0.7), AppColors.getCardColor(context)],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Icon được trau chuốt
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primaryBlue.withOpacity(0.1), AppColors.primaryBlue.withOpacity(0.05)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.admin_panel_settings_outlined, color: AppColors.primaryBlue, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(email, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.getTextColor(context))),
                      const SizedBox(height: 2),
                      if (timestamp != null)
                        Text(
                          'Cấp ngày: ${DateFormat('dd/MM/yyyy').format(timestamp.toDate())}',
                          style: GoogleFonts.poppins(color: AppColors.getTextSecondaryColor(context), fontSize: 13),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(color: AppColors.getDividerColor(context)),
            const SizedBox(height: 12),
            // Giữ lại phần tóm tắt quyền bằng Chip
            _buildPermissionSummary(permissions),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_note, size: 20),
                label: Text("Chỉnh sửa chi tiết", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue.withOpacity(0.1),
                  foregroundColor: AppColors.primaryBlue,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Giữ lại widget helper để hiển thị tóm tắt quyền, cập nhật style
  Widget _buildPermissionSummary(Map<String, dynamic> permissions) {
    final permissionLabels = {
      'canEditRevenue': 'Sửa Doanh Thu',
      'canManageProducts': 'Quản Lý Sản Phẩm',
      'canEditExpense': 'Sửa Chi Phí',
      'canViewReport': 'Xem Báo Cáo',
      'canManagePermissions': 'Quản Lý Quyền',
    };

    final grantedPermissions = permissions.entries
        .where((entry) => entry.value == true && permissionLabels.containsKey(entry.key))
        .map((entry) => permissionLabels[entry.key]!)
        .toList();

    if (grantedPermissions.isEmpty) {
      return Text(
        'Chưa có quyền nào được cấp.',
        style: GoogleFonts.poppins(color: AppColors.getTextSecondaryColor(context), fontStyle: FontStyle.italic),
      );
    }

    return Wrap(
      spacing: 8.0,
      runSpacing: 6.0,
      children: grantedPermissions.map((label) {
        return Chip(
          avatar: Icon(Icons.check_circle, color: AppColors.chartGreen, size: 16),
          label: Text(label),
          labelStyle: GoogleFonts.poppins(fontSize: 12, color: AppColors.getTextColor(context), fontWeight: FontWeight.w500),
          backgroundColor: AppColors.chartGreen.withOpacity(0.1),
          side: BorderSide(color: AppColors.chartGreen.withOpacity(0.2)),
          padding: const EdgeInsets.symmetric(horizontal: 6.0),
        );
      }).toList(),
    );
  }
}