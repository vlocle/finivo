import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:grouped_list/grouped_list.dart';
import 'package:month_picker_dialog/month_picker_dialog.dart';
import '../state/app_state.dart';
import 'package:fingrowth/screens/report_screen.dart';

class WalletHistoryScreen extends StatefulWidget {
  final Map<String, dynamic> wallet;

  const WalletHistoryScreen({Key? key, required this.wallet}) : super(key: key);

  @override
  _WalletHistoryScreenState createState() => _WalletHistoryScreenState();
}

class _WalletHistoryScreenState extends State<WalletHistoryScreen> {
  late DateTime _selectedMonth;
  late Future<List<Map<String, dynamic>>> _transactionsFuture;
  final NumberFormat currencyFormat =
  NumberFormat.currency(locale: 'vi_VN', symbol: 'VNĐ');

  @override
  void initState() {
    super.initState();
    _selectedMonth = DateTime.now();
    _loadTransactionsForMonth();
  }

  void _loadTransactionsForMonth() {
    setState(() {
      _transactionsFuture = Provider.of<AppState>(context, listen: false)
          .getTransactionsForWallet(widget.wallet['id'], _selectedMonth);
    });
  }

  void _pickMonth() {
    showMonthPicker(
      context: context,
      initialDate: _selectedMonth,
    ).then((date) {
      if (date != null) {
        setState(() {
          _selectedMonth = date;
        });
        _loadTransactionsForMonth(); // Tải lại giao dịch cho tháng mới
      }
    });
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

  void _editTransactionDialog(Map<String, dynamic> transaction) {
    _showStyledSnackBar("Tính năng sửa giao dịch đang được phát triển.", isError: false);
  }

  void _deleteTransaction(Map<String, dynamic> transaction) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Xác nhận xóa'),
        content: Text(
            'Bạn có chắc muốn xóa giao dịch "${transaction['name']}" không? Hành động này sẽ hoàn lại tiền vào ví và không thể hoàn tác.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Hủy')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Xóa'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    // Hiển thị dialog loading ngay lập tức
    showDialog(
      context: context,
      barrierDismissible: false, // Ngăn người dùng tắt dialog bằng cách chạm bên ngoài
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        content: Row(
          children: [
            CircularProgressIndicator(color: AppColors.primaryBlue),
            const SizedBox(width: 20),
            Text("Đang xóa...", style: GoogleFonts.poppins()),
          ],
        ),
      ),
    );

    final appState = Provider.of<AppState>(context, listen: false);

    try {
      // Logic thông minh để gọi đúng hàm xóa
      if (transaction['category'] == 'Điều chỉnh Ví') {
        await appState.deleteWalletAdjustment(adjustmentToRemove: transaction);
      } else {
        await appState.deleteTransactionAndUpdateAll(transactionToRemove: transaction);
      }

      // Đóng dialog loading sau khi xóa thành công
      if (mounted) {
        Navigator.pop(context); // Đóng dialog loading
        _showStyledSnackBar("Đã xóa giao dịch và cập nhật lại số dư ví.");
        _loadTransactionsForMonth(); // Tải lại danh sách
      }

    } catch (e) {
      // Đóng dialog loading nếu có lỗi
      if (mounted) {
        Navigator.pop(context); // Đóng dialog loading
        _showStyledSnackBar("Lỗi khi xóa giao dịch", isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.wallet['name'], style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white)),
        backgroundColor: AppColors.primaryBlue,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined, color: Colors.white),
            onPressed: _pickMonth,
            tooltip: 'Chọn tháng',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12.0),
            color: Colors.grey[200],
            child: Center(
              child: Text(
                "Lịch sử giao dịch - Tháng ${DateFormat('MM/yyyy').format(_selectedMonth)}",
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _transactionsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Lỗi tải lịch sử giao dịch: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Text(
                      'Không có giao dịch nào trong tháng này.',
                      style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey),
                    ),
                  );
                }

                final transactions = snapshot.data!;

                return GroupedListView<Map<String, dynamic>, String>(
                  elements: transactions,
                  groupBy: (transaction) {
                    // Ưu tiên nhóm theo ngày thanh toán nếu có, nếu không thì dùng ngày giao dịch
                    final String dateStringToGroupBy = transaction['paymentDate'] ?? transaction['date'];
                    return DateFormat('yyyy-MM-dd').format(DateTime.parse(dateStringToGroupBy));
                  },
                  groupSeparatorBuilder: (String groupByValue) => Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      DateFormat('EEEE, dd/MM/yyyy', 'vi_VN').format(DateTime.parse(groupByValue)),
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).textTheme.titleMedium?.color),
                    ),
                  ),
                  itemBuilder: (context, transaction) {
                    final bool isIncome = transaction['isIncome'] ?? false;
                    final amount = (transaction['total'] as num?)?.toDouble() ?? 0.0;

                    // === THÊM ĐIỀU KIỆN KIỂM TRA MỚI ===
                    // Chỉ cho phép xóa khi giao dịch đó không phải là một khoản thanh toán chi phí được liên kết
                    final bool canBeDeleted = transaction['adjustmentType'] != 'cogs_payment';
                    // ===================================

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: (isIncome ? Colors.green : Colors.red).withOpacity(0.1),
                          child: Icon(
                            isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                            color: isIncome ? Colors.green : Colors.red,
                          ),
                        ),
                        title: Text(
                          transaction['name'],
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        subtitle: Text(DateFormat('HH:mm').format(DateTime.parse(transaction['date']))),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${isIncome ? "+" : ""} ${currencyFormat.format(amount)}',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: isIncome ? Colors.green.shade700 : Colors.red.shade700,
                              ),
                            ),

                            // === ÁP DỤNG ĐIỀU KIỆN VÀO ĐÂY ===
                            if (canBeDeleted)
                              IconButton(
                                icon: Icon(Icons.delete_outline, color: Colors.grey[600]),
                                onPressed: () => _deleteTransaction(transaction),
                                tooltip: "Xóa giao dịch",
                              ),
                            // ==================================
                          ],
                        ),
                      ),
                    );
                  },
                  order: GroupedListOrder.DESC,
                  padding: const EdgeInsets.only(bottom: 80),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}