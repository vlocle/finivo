import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../state/app_state.dart';
import '/screens/expense_manager.dart';
import 'package:fingrowth/screens/report_screen.dart';

class EditOtherExpenseScreen extends StatefulWidget {
  const EditOtherExpenseScreen({Key? key}) : super(key: key);

  @override
  _EditOtherExpenseScreenState createState() => _EditOtherExpenseScreenState();
}

class _EditOtherExpenseScreenState extends State<EditOtherExpenseScreen> {
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'VNĐ');
  final _inputPriceFormatter = NumberFormat("#,##0", "vi_VN");
  late AppState _appState;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _appState = Provider.of<AppState>(context, listen: false);
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    await ExpenseManager.loadOtherExpenses(_appState);
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  // CẬP NHẬT: Hàm này giờ nhận tham số từ widget con
  void _addExpense(bool isCashSpent, String? selectedWalletId) {
    final name = _nameController.text.trim();
    final amount = double.tryParse(_amountController.text.replaceAll('.', '').replaceAll(',', '')) ?? 0.0;
    if (name.isEmpty || amount <= 0) {
      _showStyledSnackBar("Vui lòng nhập đầy đủ tên và số tiền hợp lệ.", isError: true);
      return;
    }
    if (isCashSpent && selectedWalletId == null) {
      _showStyledSnackBar("Vui lòng chọn ví để thực chi.", isError: true);
      return;
    }

    // Lấy ngày đã chọn từ AppState và kết hợp với giờ hiện tại
    final now = DateTime.now();
    final correctTransactionDate = DateTime(
        _appState.selectedDate.year,
        _appState.selectedDate.month,
        _appState.selectedDate.day,
        now.hour,
        now.minute,
        now.second
    );

    final newExpense = {
      'id': Uuid().v4(),
      'name': name,
      'amount': amount,
      'date': correctTransactionDate.toIso8601String(), // <-- Sửa ở đây: Ngày ghi nhận nghiệp vụ
      'createdBy': _appState.authUserId,
      'walletId': isCashSpent ? selectedWalletId : null,
      'category': 'Chi phí khác',
    };

    _appState.addOtherExpenseAndUpdateState(newExpense: newExpense).then((_) {
      _nameController.clear();
      _amountController.clear();
      FocusScope.of(context).unfocus();
      _showStyledSnackBar("Đã thêm chi phí: $name");
    }).catchError((e) {
      _showStyledSnackBar("Lỗi khi thêm chi phí: $e", isError: true);
    });
  }

  void _editExpense(int index, Map<String, dynamic> originalExpense) {
    final editNameController = TextEditingController(text: originalExpense['name']);
    final editAmountController = TextEditingController(text: _inputPriceFormatter.format(originalExpense['amount']));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Chỉnh sửa: ${originalExpense['name']}"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: editNameController,
              decoration: InputDecoration(labelText: "Tên chi phí"),
            ),
            SizedBox(height: 16),
            TextField(
              controller: editAmountController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                TextInputFormatter.withFunction((oldValue, newValue) {
                  if (newValue.text.isEmpty) return newValue.copyWith(text: '0');
                  final number = int.tryParse(newValue.text.replaceAll('.', ''));
                  if (number == null) return oldValue;
                  final formattedText = _inputPriceFormatter.format(number);
                  return newValue.copyWith(
                    text: formattedText,
                    selection: TextSelection.collapsed(offset: formattedText.length),
                  );
                }),
              ],
              decoration: InputDecoration(labelText: "Số tiền mới"),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text("Hủy")),
          ElevatedButton(
            onPressed: () {
              final newAmount = double.tryParse(editAmountController.text.replaceAll('.', '').replaceAll(',', '')) ?? 0.0;
              final newName = editNameController.text.trim();
              if (newAmount > 0 && newName.isNotEmpty) {
                final updatedExpense = {
                  ...originalExpense,
                  'name': newName,
                  'amount': newAmount,
                };
                _appState.editOtherExpenseAndUpdateState(
                  originalExpense: originalExpense,
                  updatedExpense: updatedExpense,
                ).then((_){
                  Navigator.pop(ctx);
                  _showStyledSnackBar("Đã cập nhật chi phí.");
                }).catchError((e){
                  _showStyledSnackBar("Lỗi khi cập nhật: $e", isError: true);
                });
              }
            },
            child: Text("Lưu"),
          ),
        ],
      ),
    );
  }

  void _removeExpense(Map<String, dynamic> expenseToRemove) {
    final removedName = expenseToRemove['name'];
    _appState.removeOtherExpenseAndUpdateState(expenseToRemove: expenseToRemove)
        .then((_){
      _showStyledSnackBar("Đã xóa chi phí: $removedName");
    }).catchError((e){
      _showStyledSnackBar("Lỗi khi xóa: $e", isError: true);
    });
  }

  void _showPayExpenseDialog(Map<String, dynamic> expenseToPay) {
    String? selectedWalletIdForPayment;
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text('Xác nhận Thực chi'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Thanh toán cho khoản chi: "${expenseToPay['name']}"?'),
                SizedBox(height: 16),
                ValueListenableBuilder<List<Map<String, dynamic>>>(
                  valueListenable: _appState.wallets,
                  builder: (context, walletList, child) {
                    if (walletList.isEmpty) return Text("Vui lòng tạo ví tiền trước.");
                    selectedWalletIdForPayment ??= _appState.defaultWallet?['id'] ?? walletList.first['id'];
                    return DropdownButtonFormField<String>(
                      value: selectedWalletIdForPayment,
                      items: walletList.map((w) => DropdownMenuItem(value: w['id'] as String, child: Text(w['name']))).toList(),
                      onChanged: (val) => setDialogState(() => selectedWalletIdForPayment = val),
                      decoration: InputDecoration(labelText: 'Chi từ ví'),
                    );
                  },
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text('Hủy')),
              ElevatedButton(
                onPressed: () {
                  if (selectedWalletIdForPayment != null) {
                    _appState.payForOtherExpense(
                      expenseToPay: expenseToPay,
                      walletId: selectedWalletIdForPayment!,
                    ).then((_){
                      _showStyledSnackBar("Đã thực chi thành công.");
                    }).catchError((e){
                      _showStyledSnackBar("Lỗi khi thực chi: $e", isError: true);
                    });
                    Navigator.pop(dialogContext);
                  }
                },
                child: Text('Xác nhận'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showStyledSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins()),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getBackgroundColor(context),
      appBar: AppBar(
        title: Text("Chi phí khác", style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white)),
        backgroundColor: AppColors.chartRed,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: AppColors.chartRed))
            : SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // CẬP NHẬT: Sử dụng widget input mới
              ExpenseInputSection(
                nameController: _nameController,
                amountController: _amountController,
                onAddExpense: _addExpense,
                appState: _appState,
                inputPriceFormatter: _inputPriceFormatter,
              ),
              const SizedBox(height: 24),
              Text(
                "Các khoản đã thêm trong ngày",
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.getTextColor(context)),
              ),
              const SizedBox(height: 10),
              _buildExpenseList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpenseList() {
    return ValueListenableBuilder<List<Map<String, dynamic>>>(
      valueListenable: _appState.otherExpenseTransactions,
      builder: (context, expenses, _) {
        if (expenses.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 20.0),
              child: Text("Chưa có chi phí nào được thêm."),
            ),
          );
        }
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: expenses.length,
          itemBuilder: (context, index) {
            final expense = expenses[index];
            final bool isUnpaid = expense['walletId'] == null;
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 6),
              child: ListTile(
                title: Text(expense['name']),
                subtitle: Text(_currencyFormat.format(expense['amount'])),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isUnpaid)
                      IconButton(
                        icon: Icon(Icons.price_check_outlined, color: Colors.green.shade600),
                        onPressed: () => _showPayExpenseDialog(expense),
                        tooltip: 'Thực chi',
                      ),
                    IconButton(
                      icon: Icon(Icons.edit, color: AppColors.primaryBlue),
                      onPressed: () => _editExpense(index, expense),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete, color: AppColors.chartRed),
                      onPressed: () => _removeExpense(expense),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// =======================================================================
// WIDGET MỚI: Giao diện nhập liệu được thiết kế lại
// =======================================================================
class ExpenseInputSection extends StatefulWidget {
  final TextEditingController amountController;
  final TextEditingController nameController;
  final Function(bool isCashSpent, String? walletId) onAddExpense;
  final AppState appState;
  final NumberFormat inputPriceFormatter;

  const ExpenseInputSection({
    required this.amountController,
    required this.nameController,
    required this.onAddExpense,
    required this.appState,
    required this.inputPriceFormatter,
    Key? key,
  }) : super(key: key);

  @override
  State<ExpenseInputSection> createState() => _ExpenseInputSectionState();
}

class _ExpenseInputSectionState extends State<ExpenseInputSection> {
  bool _isCashSpent = true;
  String? _selectedWalletId;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: AppColors.getCardColor(context),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Thêm chi phí mới",
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.chartRed,
              ),
            ),
            const SizedBox(height: 24),
            _buildInputTextField(
              context: context,
              controller: widget.nameController,
              labelText: 'Tên khoản chi',
              prefixIconData: Icons.description_outlined,
              maxLength: 100,
            ),
            const SizedBox(height: 16),
            _buildInputTextField(
              context: context,
              controller: widget.amountController,
              labelText: 'Số tiền',
              prefixIconData: Icons.monetization_on_outlined,
              keyboardType: TextInputType.numberWithOptions(decimal: false),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                TextInputFormatter.withFunction(
                      (oldValue, newValue) {
                    if (newValue.text.isEmpty) return newValue;
                    final number = int.tryParse(newValue.text.replaceAll('.', '').replaceAll(',', ''));
                    if (number == null) return oldValue;
                    final formattedText = widget.inputPriceFormatter.format(number);
                    return newValue.copyWith(
                      text: formattedText,
                      selection: TextSelection.collapsed(offset: formattedText.length),
                    );
                  },
                ),
              ],
              maxLength: 15,
            ),
            const SizedBox(height: 20),
            SwitchListTile.adaptive(
              title: Text("Thực chi từ ví?", style: GoogleFonts.poppins(fontSize: 16, color: AppColors.getTextColor(context), fontWeight: FontWeight.w500)),
              value: _isCashSpent,
              onChanged: (bool value) {
                setState(() {
                  _isCashSpent = value;
                  if (!value) {
                    _selectedWalletId = null;
                  }
                });
              },
              activeColor: AppColors.chartRed,
              contentPadding: EdgeInsets.zero,
            ),
            if (_isCashSpent)
              ValueListenableBuilder<List<Map<String, dynamic>>>(
                valueListenable: widget.appState.wallets,
                builder: (context, walletList, child) {
                  if (walletList.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text("Chưa có ví tiền nào được tạo.", style: GoogleFonts.poppins(color: AppColors.getTextSecondaryColor(context))),
                    );
                  }
                  final defaultWallet = widget.appState.defaultWallet;
                  if (_selectedWalletId == null || !walletList.any((w) => w['id'] == _selectedWalletId)) {
                    _selectedWalletId = defaultWallet != null ? defaultWallet['id'] : walletList.first['id'];
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: DropdownButtonFormField<String>(
                      value: _selectedWalletId,
                      items: walletList.map((wallet) {
                        return DropdownMenuItem<String>(
                          value: wallet['id'],
                          child: Text(wallet['isDefault'] == true ? "${wallet['name']} (Mặc định)" : wallet['name'], overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedWalletId = newValue;
                        });
                      },
                      decoration: InputDecoration(
                        labelText: 'Chọn ví chi tiền',
                        prefixIcon: Icon(Icons.account_balance_wallet_outlined, color: AppColors.chartRed),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  );
                },
              ),
            const SizedBox(height: 28),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.chartRed,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                minimumSize: Size(screenWidth, 52),
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 2,
              ),
              onPressed: () => widget.onAddExpense(_isCashSpent, _selectedWalletId),
              child: Text(
                "Thêm chi phí",
                style: GoogleFonts.poppins(fontSize: 16.5, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputTextField({
    required BuildContext context,
    required TextEditingController controller,
    required String labelText,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    int? maxLength,
    int maxLines = 1,
    IconData? prefixIconData,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLength: maxLength,
      maxLines: maxLines,
      style: GoogleFonts.poppins(color: AppColors.getTextColor(context), fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: GoogleFonts.poppins(color: AppColors.getTextSecondaryColor(context)),
        prefixIcon: prefixIconData != null ? Icon(prefixIconData, color: AppColors.chartRed, size: 22) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.chartRed, width: 1.5)),
        filled: true,
        fillColor: AppColors.getBackgroundColor(context).withOpacity(0.5),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        counterText: "",
      ),
    );
  }
}