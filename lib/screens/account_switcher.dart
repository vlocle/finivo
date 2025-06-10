import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';

// Class để lưu thông tin tài khoản có thể truy cập
class AccessibleAccount {
  final String uid;
  final String displayName;
  AccessibleAccount({required this.uid, required this.displayName});
}

class AccountSwitcher extends StatefulWidget {
  const AccountSwitcher({super.key});

  @override
  State<AccountSwitcher> createState() => _AccountSwitcherState();
}

class _AccountSwitcherState extends State<AccountSwitcher> {
  List<AccessibleAccount> _accounts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Dùng addPostFrameCallback để đảm bảo AppState đã sẵn sàng
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchAccessibleAccounts();
    });
  }

  // Thay thế hàm cũ bằng hàm này
  Future<void> _fetchAccessibleAccounts() async {
    // Đảm bảo widget vẫn còn trên cây giao diện trước khi cập nhật state
    if (!mounted) return;

    final appState = context.read<AppState>();
    if (appState.authUserId == null) {
      setState(() => _isLoading = false);
      return;
    }

    final String authUserId = appState.authUserId!;
    List<AccessibleAccount> foundAccounts = [];

    try {
      // 1. Lấy thông tin tài khoản của chính mình
      final currentUserDoc = await FirebaseFirestore.instance.collection('users').doc(authUserId).get();
      final currentUserName = currentUserDoc.data()?['displayName'] ?? currentUserDoc.data()?['email'] ?? 'Tài khoản của tôi';
      foundAccounts.add(AccessibleAccount(uid: authUserId, displayName: currentUserName));

      // 2. Tìm các tài khoản khác đã cấp quyền cho mình
      final query = await FirebaseFirestore.instance
          .collectionGroup('permissions')
          .where('granteeUid', isEqualTo: authUserId)
          .get();

      // Lấy thông tin chi tiết của những người đã cấp quyền
      for (var doc in query.docs) {
        // doc.reference.parent.parent.id chính là ownerId
        String ownerId = doc.reference.parent.parent!.id;
        final ownerDoc = await FirebaseFirestore.instance.collection('users').doc(ownerId).get();
        final ownerName = ownerDoc.data()?['displayName'] ?? ownerDoc.data()?['email'] ?? 'Tài khoản ẩn danh';

        // Tránh thêm trùng lặp nếu có lỗi dữ liệu
        if (!foundAccounts.any((acc) => acc.uid == ownerId)) {
          foundAccounts.add(AccessibleAccount(uid: ownerId, displayName: ownerName));
        }
      }

      if (mounted) {
        setState(() {
          _accounts = foundAccounts;
        });
      }
    } catch (e) {
      print("Lỗi khi tải danh sách tài khoản có thể truy cập: $e");
      // Nếu có lỗi, ít nhất vẫn hiển thị tài khoản của chính mình
      if (mounted && foundAccounts.isEmpty) {
        final currentUserDoc = await FirebaseFirestore.instance.collection('users').doc(authUserId).get();
        final currentUserName = currentUserDoc.data()?['displayName'] ?? 'Tài khoản của tôi';
        foundAccounts.add(AccessibleAccount(uid: authUserId, displayName: currentUserName));
        setState(() {
          _accounts = foundAccounts;
        });
      }
    } finally {
      // Quan trọng: Luôn đặt _isLoading = false ở cuối cùng để dừng loading indicator
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(8.0),
        child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    // Nếu chỉ có 1 tài khoản (của chính mình), không cần hiển thị gì
    if (_accounts.length <= 1) {
      return const SizedBox.shrink();
    }

    final appState = context.watch<AppState>();
    final currentAccount = _accounts.firstWhere(
          (acc) => acc.uid == appState.activeUserId,
      orElse: () => _accounts.first,
    );

    return PopupMenuButton<String>(
      onSelected: (String selectedUserId) {
        context.read<AppState>().switchActiveUser(selectedUserId);
      },
      itemBuilder: (BuildContext context) {
        return _accounts.map((AccessibleAccount account) {
          return PopupMenuItem<String>(
            value: account.uid,
            child: Text(account.displayName),
          );
        }).toList();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Row(
          children: [
            Text(currentAccount.displayName, style: const TextStyle(color: Colors.white)),
            const Icon(Icons.arrow_drop_down, color: Colors.white),
          ],
        ),
      ),
    );
  }
}