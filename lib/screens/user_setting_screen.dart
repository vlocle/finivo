import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import 'firestore_service.dart';
import 'general_settings_screen.dart'; // Giả sử bạn có màn hình này
import 'login_screen.dart';
import 'permissions_screen.dart';
import 'package:fingrowth/screens/report_screen.dart';
import 'subscription_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';

enum SnackBarType { success, error }

class UserSettingsScreen extends StatefulWidget {
  const UserSettingsScreen({super.key});

  @override
  State<UserSettingsScreen> createState() => _UserSettingsScreenState();
}

class _UserSettingsScreenState extends State<UserSettingsScreen> {

  Widget _buildBenefitRow(BuildContext context, {required IconData icon, required String text}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.green.shade600, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 15, color: AppColors.getTextColor(context)),
            ),
          ),
        ],
      ),
    );
  }

  void _showImprovedUpgradeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          titlePadding: const EdgeInsets.only(top: 24),
          contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          backgroundColor: AppColors.getCardColor(context),
          title: Column(
            children: [
              Icon(Icons.workspace_premium_rounded, color: Colors.amber.shade700, size: 50),
              const SizedBox(height: 16),
              Text(
                "Mở Khóa Tính Năng Premium",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.getTextColor(context),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Nâng cấp tài khoản để tận hưởng toàn bộ quyền lợi:",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: AppColors.getTextSecondaryColor(context)),
                ),
                const SizedBox(height: 20),
                _buildBenefitRow(context, icon: Icons.group_add_outlined, text: "Quản lý quyền truy cập cho nhân viên."),
                _buildBenefitRow(context, icon: Icons.bar_chart_rounded, text: "Xem báo cáo phân tích không giới hạn."),
                _buildBenefitRow(context, icon: Icons.lightbulb_outline_rounded, text: "Nhận các đề xuất thông minh từ A.I."),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionScreen()));
                    },
                    icon: const Icon(Icons.star_rounded),
                    label: const Text(
                      "Nâng Cấp Ngay",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(
                      "Để sau",
                      style: TextStyle(color: AppColors.getTextSecondaryColor(context))
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _requestReview() async {
    String? storeUrl;

    // Vui lòng đảm bảo các ID này là chính xác cho ứng dụng của bạn.
    const String appleAppId = "6746059564";
    const String googlePackageName = "com.vlocle.finivo";

    if (Platform.isIOS) {
      // URL này sẽ mở thẳng trang viết nhận xét trên App Store.
      storeUrl = "https://apps.apple.com/app/id$appleAppId?action=write-review";
    } else if (Platform.isAndroid) {
      // Đối với Google Play, cách đáng tin cậy nhất là mở trang chi tiết của ứng dụng.
      // Người dùng sẽ thấy ngay phần đánh giá ở vị trí nổi bật.
      storeUrl = "https://play.google.com/store/apps/details?id=$googlePackageName";
    }

    if (storeUrl != null) {
      // Gọi hàm _launchURL mà bạn đã có sẵn
      _launchURL(storeUrl);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Nền tảng không được hỗ trợ để đánh giá."))
        );
      }
    }
  }

  // --- Hàm đăng xuất ---
  Future<void> _signOut(BuildContext context) async {
    // Hiển thị hộp thoại xác nhận
    final bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.logout_outlined, color: Colors.red),
            SizedBox(width: 10),
            Text("Xác nhận đăng xuất", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text("Bạn có chắc muốn đăng xuất không?"),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Hủy"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Đăng xuất"),
          ),
        ],
      ),
    );

    // Nếu người dùng không xác nhận, không làm gì cả
    if (confirm != true) return;

    // KIỂM TRA `mounted` TRƯỚC KHI TIẾP TỤC
    // Điều này rất quan trọng vì showDialog là một hành động bất đồng bộ
    if (!context.mounted) return;

    // Lấy AppState từ Provider
    final appState = Provider.of<AppState>(context, listen: false);

    // BƯỚC 1: Đóng màn hình UserSettingsScreen trước.
    // Hành động này đảm bảo context không còn được sử dụng khi AuthWrapper rebuild.
    Navigator.of(context).pop();

    appState.performFullLogout();
  }

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    // Change the mode to launch in an external browser
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể mở đường dẫn: $urlString')),
        );
      }
    }
  }

  // --- Hàm hiển thị SnackBar hiện đại (Thiết kế mới) ---
  void _showModernSnackBar({
    required BuildContext context,
    required String message,
    required SnackBarType type,
  }) {
    final snackBar = SnackBar(
      // Bỏ viền và đổ bóng mặc định
      elevation: 0,
      backgroundColor: Colors.transparent,
      behavior: SnackBarBehavior.floating,
      // Căn lề trên cùng thay vì dưới cùng
      margin: const EdgeInsets.only(top: 20, left: 16, right: 16),
      content: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          // Chọn màu dựa trên loại thông báo
          color: type == SnackBarType.success
              ? const Color(0xFF2E7D32) // Xanh lá đậm
              : const Color(0xFFC62828), // Đỏ đậm
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon tương ứng
            Icon(
              type == SnackBarType.success ? Icons.check_circle : Icons.error,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar() // Ẩn snackbar cũ nếu có
      ..showSnackBar(snackBar);
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
            backgroundColor: AppColors.chartRed,
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
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.chartRed),
            SizedBox(width: 10),
            // Chỉ cần thêm Expanded ở đây
            Expanded(
              child: Text("Xác nhận xóa dữ liệu", style: TextStyle(color: AppColors.getTextColor(context), fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        content: Text(
            "Bạn có chắc muốn xóa toàn bộ dữ liệu không? Hành động này không thể hoàn tác.",
            style: TextStyle(color: AppColors.getTextSecondaryColor(context))),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text("Hủy", style: TextStyle(color: AppColors.getTextSecondaryColor(context))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.chartRed,
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
        final collections = ['expenses', 'products', 'daily_data'];
        for (var collectionName in collections) {
          if (collectionName == 'expenses') continue;

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
          'expenses/fixed/monthly',
          'expenses/variable/daily',
          'expenses/variableList/monthly',
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

        appState.resetAllUserData();

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
              content: Text("Xóa dữ liệu thất bại"),
              backgroundColor: AppColors.chartRed,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  // --- Hàm hiển thị Bottom Sheet chỉnh sửa tên (Thiết kế mới) ---
  Future<bool?> _showEditNameBottomSheet(BuildContext context, User currentUser) async {
    final TextEditingController nameController =
    TextEditingController(text: currentUser.displayName);
    final firestoreService = FirestoreService();

    // showModalBottomSheet sẽ trả về giá trị được truyền trong Navigator.pop()
    return await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: AppColors.getBackgroundColor(context),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              top: 24,
              left: 24,
              right: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Thay đổi tên của bạn",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.getTextColor(context),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Tên mới sẽ được hiển thị trên toàn bộ ứng dụng.",
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.getTextSecondaryColor(context),
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: "Tên hiển thị",
                  labelStyle: TextStyle(color: AppColors.primaryBlue),
                  prefixIcon: Icon(Icons.person_outline, color: AppColors.primaryBlue),
                  filled: true,
                  fillColor: AppColors.getCardColor(context),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.primaryBlue, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    String newName = nameController.text.trim();

                    if (newName.isEmpty) {
                      newName = currentUser.email?.split('@').first ?? 'Người dùng';
                    }

                    try {
                      await currentUser.updateDisplayName(newName);
                      await firestoreService.updateDisplayName(currentUser.uid, newName);

                      if (mounted) {
                        // Báo cáo thành công bằng cách trả về `true` khi pop
                        Navigator.pop(context, true);
                      }
                    } catch (e) {
                      if (mounted) {
                        // Đóng sheet và báo lỗi (bằng cách không trả về gì hoặc trả về false)
                        Navigator.pop(context, false);
                        // SnackBar lỗi sẽ được hiển thị bên ngoài
                      }
                    }
                  },
                  child: const Text("Lưu Thay Đổi", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  // --- Hàm xóa tài khoản ---
  Future<void> _deleteAccount(BuildContext context) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.delete_forever_outlined, color: AppColors.chartRed),
            SizedBox(width: 10),
            Text("Xác nhận xóa tài khoản", style: TextStyle(color: AppColors.getTextColor(context), fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
            "Bạn có chắc muốn xóa tài khoản không? Toàn bộ dữ liệu của bạn sẽ bị mất và hành động này không thể hoàn tác.",
            style: TextStyle(color: AppColors.getTextSecondaryColor(context))),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text("Hủy", style: TextStyle(color: AppColors.getTextSecondaryColor(context))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.chartRed,
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
        //appState.logout(); // Đảm bảo hàm này xử lý đúng việc reset state

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
              backgroundColor: AppColors.chartRed,
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
      backgroundColor: AppColors.getBackgroundColor(context),
      appBar: AppBar(
        title: const Text(
          "Cài đặt",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primaryBlue,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
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
                    _requestReview();
                  },
                ),
                _buildSettingsItem(
                  context,
                  icon: Icons.description_outlined,
                  title: "Hướng dẫn sử dụng",
                  onTap: () {
                    _launchURL("https://www.youtube.com/watch?v=RKSfwkiE_c8&list=PL2InoI8TNIdIp4tll4dKh7Jy1TjYzgDgq");
                  },
                ),
              ],
            ),
            _buildSettingsGroup(
              context,
              title: "Pháp lý & Hỗ trợ",
              children: [
                _buildSettingsItem(
                  context,
                  icon: Icons.shield_outlined, // Icon cho chính sách
                  title: "Chính sách Quyền riêng tư",
                  onTap: () => _launchURL("https://finivoapp.com/policy/privacy-policy/"),
                ),
                _buildSettingsItem(
                  context,
                  icon: Icons.gavel_outlined, // Icon cho điều khoản
                  title: "Điều khoản Dịch vụ",
                  onTap: () => _launchURL("https://finivoapp.com/policy/terms-and-conditions-of-use/"),
                ),
              ],
            ),
            _buildSettingsGroup(
              context,
              title: "Tài khoản",
              children: [
                Consumer<AppState>(
                  builder: (context, appState, child) {
                    if (appState.isSubscribed) {
                      return const SizedBox.shrink();
                    }
                    return _buildSettingsItem(
                      context,
                      icon: Icons.workspace_premium_outlined,
                      title: "Nâng Cấp lên Premium",
                      iconColor: Colors.amber[700],
                      textColor: Colors.amber[700],
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
                        );
                      },
                    );
                  },
                ),
                _buildSettingsItem(
                  context,
                  icon: Icons.group_add_outlined,
                  title: "Quản lý quyền truy cập",
                  onTap: () {
                    final appState = context.read<AppState>();
                    if (appState.isSubscribed) {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const PermissionsScreen()));
                    } else {
                      _showImprovedUpgradeDialog(context);
                    }
                  },
                ),
                _buildSettingsItem(
                  context,
                  icon: Icons.logout_outlined,
                  title: "Đăng xuất",
                  textColor: AppColors.chartRed,
                  iconColor: AppColors.chartRed,
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
                  textColor: AppColors.chartRed,
                  iconColor: AppColors.chartRed,
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
    if (user == null) {
      return const SizedBox.shrink(); //
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24.0), //
      decoration: const BoxDecoration(
        color: AppColors.primaryBlue, // Thay bằng màu của bạn
      ), //
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: Colors.white.withOpacity(0.9), //
            backgroundImage:
            user.photoURL != null ? NetworkImage(user.photoURL!) : null, //
            child: user.photoURL == null
                ? Icon(Icons.person_outline,
                size: 60, color: AppColors.primaryBlue.withOpacity(0.8)) // Thay bằng màu của bạn
                : null, //
          ),
          const SizedBox(height: 16), //
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  user.displayName ?? "Finivo", //
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white), //
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis, //
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined,
                    color: Colors.white, size: 24), //
                onPressed: () async {
                  final bool? updateSuccess = await _showEditNameBottomSheet(context, user); //
                  if (updateSuccess == true && mounted) {
                    _showModernSnackBar(
                        context: context,
                        message: "Cập nhật tên thành công!",
                        type: SnackBarType.success); //
                    setState(() {}); //
                  }
                  else if (updateSuccess == false && mounted){
                    _showModernSnackBar(
                        context: context,
                        message: "Đã xảy ra lỗi khi cập nhật tên.",
                        type: SnackBarType.error); //
                  }
                },
                splashRadius: 20, //
              ),
            ],
          ),
          const SizedBox(height: 6), //
          Text(
            user.email ?? "Không có thông tin email", //
            style: TextStyle(fontSize: 15, color: Colors.white.withOpacity(0.85)), //
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12), //

          // --- PHẦN THAY ĐỔI BẮT ĐẦU TỪ ĐÂY ---
          Consumer<AppState>(
            builder: (context, appState, child) {
              // Kiểm tra trạng thái subscription từ AppState
              if (appState.isSubscribed) {
                // Nếu đã đăng ký, hiển thị "Thành viên nâng cao"
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.amber[700], // Màu vàng cho nổi bật
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min, // Để Row chỉ chiếm không gian cần thiết
                    children: const [
                      Icon(Icons.workspace_premium_outlined, color: Colors.white, size: 16),
                      SizedBox(width: 6),
                      Text(
                        "Thành viên nâng cao",
                        style: TextStyle(
                            fontSize: 13,
                            color: Colors.white,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                );
              } else {
                // Nếu chưa, hiển thị "Thành viên cơ bản" như cũ
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), //
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2), //
                    borderRadius: BorderRadius.circular(20), //
                  ),
                  child: const Text(
                    "Thành viên cơ bản", //
                    style: TextStyle(
                        fontSize: 13,
                        color: Colors.white,
                        fontWeight: FontWeight.w500), //
                  ),
                );
              }
            },
          ),
          // --- KẾT THÚC PHẦN THAY ĐỔI ---

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
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.getTextColor(context),
              ),
            ),
          ),
          Material( // Sử dụng Material để có hiệu ứng ripple khi nhấn
            color: AppColors.getCardColor(context),
            borderRadius: BorderRadius.circular(12),
            elevation: 1.5, // Độ nổi nhẹ cho card
            shadowColor: Colors.black.withOpacity(0.05),
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
      splashColor: AppColors.primaryBlue.withOpacity(0.1),
      highlightColor: AppColors.primaryBlue.withOpacity(0.05),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (iconColor ?? AppColors.getTextSecondaryColor(context)).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor ?? AppColors.getTextSecondaryColor(context), size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: textColor ?? AppColors.getTextColor(context),
                ),
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.getTextSecondaryColor(context)),
          ],
        ),
      ),
    );
  }
}