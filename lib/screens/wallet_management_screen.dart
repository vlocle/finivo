// screens/wallet_management_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fingrowth/screens/wallet_history_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../state/app_state.dart';
import 'package:fingrowth/screens/report_screen.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:marquee/marquee.dart';


class WalletManagementScreen extends StatefulWidget {
  const WalletManagementScreen({Key? key}) : super(key: key);

  @override
  _WalletManagementScreenState createState() => _WalletManagementScreenState();
}

class _WalletManagementScreenState extends State<WalletManagementScreen> {
  bool _isBalanceVisible = true;
  final NumberFormat currencyFormat =
  NumberFormat.currency(locale: 'vi_VN', symbol: 'VNĐ');

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
  void _showDeleteWalletConfirmationDialog(BuildContext context, AppState appState, Map<String, dynamic> wallet) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text('Xác nhận xóa ví', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text(
          'Bạn có chắc chắn muốn xóa ví "${wallet['name']}" không? Mọi giao dịch liên quan đến ví này trong toàn bộ lịch sử sẽ bị xóa vĩnh viễn. Hành động này không thể hoàn tác.',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(dialogContext); // Đóng dialog trước
              // Hiển thị SnackBar thông báo đang xử lý
              _showStyledSnackBar('Đang xóa ví và các giao dịch liên quan...');

              try {
                await appState.deleteWalletAndAssociatedData(walletToDelete: wallet);
                _showStyledSnackBar('Đã xóa ví thành công!');
              } catch (e) {
                _showStyledSnackBar('Lỗi khi xóa ví: $e', isError: true);
              }
            },
            child: const Text('Xóa vĩnh viễn'),
          ),
        ],
      ),
    );
  }

  void _showAddOrEditWalletDialog({Map<String, dynamic>? existingWallet}) {
    final appState = Provider.of<AppState>(context, listen: false);
    final isEditing = existingWallet != null;

    final nameController = TextEditingController(text: isEditing ? existingWallet['name'] : '');
    final balanceController = TextEditingController(
        text: isEditing
            ? NumberFormat("#,##0", "vi_VN").format(existingWallet['balance'] ?? 0.0)
            : '0');

    String walletType = isEditing ? existingWallet['type'] ?? 'cash' : 'cash';
    bool isDefault = isEditing ? existingWallet['isDefault'] ?? false : false;

    final double originalBalance = isEditing ? (existingWallet['balance'] as num?)?.toDouble() ?? 0.0 : 0.0;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text(isEditing ? 'Chỉnh sửa Ví' : 'Thêm Ví mới',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.account_balance_wallet_outlined), // <--- MỚI: Thêm icon
                      labelText: 'Tên ví (VD: Tiền mặt, VCB)',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12))),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: balanceController,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.monetization_on_outlined), // <--- MỚI: Thêm icon
                    labelText: isEditing ? 'Số dư hiện tại' : 'Số dư ban đầu',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    TextInputFormatter.withFunction((oldValue, newValue) {
                      if (newValue.text.isEmpty) return newValue.copyWith(text: '0');
                      final number = int.tryParse(newValue.text.replaceAll('.', ''));
                      if (number == null) return oldValue;
                      final formattedText = NumberFormat("#,##0", "vi_VN").format(number);
                      return newValue.copyWith(
                        text: formattedText,
                        selection: TextSelection.collapsed(offset: formattedText.length),
                      );
                    }),
                  ],
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: walletType,
                  items: const [
                    DropdownMenuItem(value: 'cash', child: Text('Tiền mặt')),
                    DropdownMenuItem(value: 'bank', child: Text('Ngân hàng')),
                  ],
                  onChanged: (value) {
                    setDialogState(() {
                      walletType = value!;
                    });
                  },
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.category_outlined), // <--- MỚI: Thêm icon
                    labelText: 'Loại ví',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 10),

                // <--- THAY ĐỔI LỚN: Sử dụng Row thay cho SwitchListTile
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Đặt làm mặc định',
                      style: GoogleFonts.poppins(fontSize: 16),
                    ),
                    Switch(
                      value: isDefault,
                      onChanged: (value) {
                        setDialogState(() {
                          isDefault = value;
                        });
                      },
                      activeColor: AppColors.primaryBlue, // Đặt màu chủ đạo cho Switch
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey.shade700,
              ),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              // <--- MỚI: Style cho nút Lưu để có màu xanh chủ đạo
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue, // Sử dụng màu chủ đạo
                foregroundColor: Colors.white, // Màu chữ là màu trắng
              ),
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  _showStyledSnackBar('Tên ví không được để trống!', isError: true);
                  return;
                }
                final double newBalance = double.tryParse(balanceController.text.replaceAll('.', '')) ?? 0.0;
                final double delta = newBalance - originalBalance;
                final walletData = {
                  'id': isEditing ? existingWallet['id'] : Uuid().v4(),
                  'name': name,
                  'balance': newBalance,
                  'type': walletType,
                  'isDefault': isDefault,
                  'createdAt': isEditing ? existingWallet['createdAt'] : Timestamp.now(),
                  'ownerId': appState.activeUserId,
                };
                appState.saveOrUpdateWallet(walletData);
                if (isEditing && delta != 0) {
                  appState.createWalletBalanceAdjustment(
                    walletId: existingWallet['id'],
                    walletName: existingWallet['name'],
                    delta: delta,
                  );
                }
                Navigator.pop(dialogContext);
              },
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalBalanceCard(AppState appState) {
    final wallets = appState.wallets.value;
    final double totalBalance = wallets.fold(0.0,
            (sum, wallet) => sum + ((wallet['balance'] as num?)?.toDouble() ?? 0.0));

    // Tạo một định dạng số không có ký hiệu tiền tệ
    final NumberFormat numberOnlyFormat = NumberFormat("#,##0", "vi_VN");

    // Tạo style chung cho cả số và chữ VNĐ để nhất quán
    final balanceStyle = GoogleFonts.poppins(
      fontSize: 32,
      fontWeight: FontWeight.bold,
      color: Colors.white,
      letterSpacing: 1.5,
    );

    Widget balanceContent;
    if (_isBalanceVisible) {
      balanceContent = SizedBox( // Giới hạn chiều cao của cả hàng
        height: 40,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(
              child: Marquee(
                text: numberOnlyFormat.format(totalBalance), // Chỉ chạy số
                style: balanceStyle,
                velocity: 50.0,
                blankSpace: 40.0,
                pauseAfterRound: const Duration(seconds: 2),
                fadingEdgeEndFraction: 0.1,
                fadingEdgeStartFraction: 0.1,
                // <<< DÒNG GÂY LỖI ĐÃ ĐƯỢC XÓA Ở ĐÂY >>>
              ),
            ),
            const SizedBox(width: 8),
            Text('VNĐ', style: balanceStyle), // Chữ VNĐ đứng yên
          ],
        ),
      );
    } else {
      balanceContent = Text(
        '●●●●●●●● VNĐ',
        style: balanceStyle,
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            AppColors.primaryBlue,
            Colors.blue.shade700,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tổng số dư',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
              IconButton(
                icon: Icon(
                  _isBalanceVisible
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: Colors.white.withOpacity(0.9),
                ),
                onPressed: () {
                  setState(() {
                    _isBalanceVisible = !_isBalanceVisible;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Sử dụng widget đã tạo ở trên
          balanceContent,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Quản lý Ví tiền',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600, color: Colors.white)),
        backgroundColor: AppColors.primaryBlue,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Consumer<AppState>(
        builder: (context, appState, child) {
          final wallets = appState.wallets.value;

          return Column( // Sử dụng Column để sắp xếp các widget theo chiều dọc
            children: [
              // 1. Widget hiển thị tổng số dư
              _buildTotalBalanceCard(appState),

              // 2. Tiêu đề cho danh sách
              if (wallets.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
                  child: Row(
                    children: [
                      Text(
                        'Danh sách ví',
                        style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            ).copyWith(color: Theme.of(context).textTheme.titleLarge?.color),
                      ),
                    ],
                  ),
                ),

              // 3. Danh sách ví (hoặc thông báo trống)
              wallets.isEmpty
                  ? Expanded(
                child: Center(
                  child: Text(
                    'Bạn chưa có ví nào.\nNhấn nút + để tạo ví đầu tiên.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                        fontSize: 16, color: Colors.grey),
                  ),
                ),
              )
                  : Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: wallets.length,
                  itemBuilder: (context, index) {
                    final wallet = wallets[index];
                    // Toàn bộ Slidable và Card của bạn được giữ nguyên ở đây
                    return Slidable(
                      key: ValueKey(wallet['id']),
                      endActionPane: ActionPane(
                        motion: StretchMotion(),
                        children: [
                          SlidableAction(
                            onPressed: (context) {
                              _showAddOrEditWalletDialog(existingWallet: wallet);
                            },
                            backgroundColor: Colors.blueAccent,
                            foregroundColor: Colors.white,
                            icon: Icons.edit,
                            label: 'Sửa',
                            borderRadius: BorderRadius.circular(12),
                          ),
                          SlidableAction(
                            onPressed: (context) {
                              _showDeleteWalletConfirmationDialog(context, appState, wallet);
                            },
                            backgroundColor: Colors.redAccent,
                            foregroundColor: Colors.white,
                            icon: Icons.delete,
                            label: 'Xóa',
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ],
                      ),
                      child: Card(
                        elevation: 2,
                        margin: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 5),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          leading: Icon(
                            wallet['type'] == 'bank'
                                ? Icons.account_balance_outlined
                                : Icons.wallet_outlined,
                            color: AppColors.primaryBlue,
                          ),
                          title: Text(wallet['name'],
                              style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600)),
                          subtitle: Text(
                              currencyFormat.format(wallet['balance'] ?? 0.0),
                              style: GoogleFonts.poppins(
                                  color: AppColors.primaryBlue,
                                  fontWeight: FontWeight.bold)),
                          trailing: wallet['isDefault'] == true
                              ? Chip(
                            label: Text('Mặc định',
                                style: GoogleFonts.poppins(
                                    fontSize: 12)),
                            backgroundColor:
                            Colors.green.withOpacity(0.2),
                          )
                              : null,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    WalletHistoryScreen(wallet: wallet),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddOrEditWalletDialog(),
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
        tooltip: 'Thêm ví mới',
      ),
    );
  }
}