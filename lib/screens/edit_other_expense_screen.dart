import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../state/app_state.dart';
import '/screens/expense_manager.dart';
import 'package:fingrowth/screens/report_screen.dart'; // Giả định AppColors nằm trong đây hoặc được import toàn cục

// =======================================================================
// === BẮT ĐẦU PHIÊN BẢN CẬP NHẬT CHO EDIT_OTHER_EXPENSE_SCREEN.DOCX ===
// =======================================================================

class EditOtherExpenseScreen extends StatefulWidget {
  const EditOtherExpenseScreen({Key? key}) : super(key: key);

  @override
  _EditOtherExpenseScreenState createState() => _EditOtherExpenseScreenState();
}

class _EditOtherExpenseScreenState extends State<EditOtherExpenseScreen>
    with SingleTickerProviderStateMixin { // THÊM MỚI: Dành cho animation
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'VNĐ');
  final _inputPriceFormatter = NumberFormat("#,##0", "vi_VN");

  // --- THÊM MỚI: Các biến state để quản lý giao diện tab và animation ---
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  int _selectedTab = 0;
  // ---------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    final appState = Provider.of<AppState>(context, listen: false);

    // --- THÊM MỚI: Khởi tạo animation ---
    _animationController = AnimationController(
        duration: const Duration(milliseconds: 300), vsync: this);
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
        CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack));
    _animationController.forward();
    // ------------------------------------

    // Tải dữ liệu ban đầu
    ExpenseManager.loadOtherExpenses(appState);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _animationController.dispose(); // THÊM MỚI
    super.dispose();
  }

  void _showStyledSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: isError ? AppColors.chartRed : Colors.green, // Dùng màu phù hợp
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(10),
      ),
    );
  }

  void _addExpense(AppState appState, bool isCashSpent, String? selectedWalletId, DateTime paymentDate) {
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

    final now = DateTime.now();
    final correctTransactionDate = DateTime(
        appState.selectedDate.year,
        appState.selectedDate.month,
        appState.selectedDate.day,
        now.hour, now.minute, now.second
    );

    final newExpense = {
      'id': Uuid().v4(),
      'name': name,
      'amount': amount,
      'date': correctTransactionDate.toIso8601String(),
      'createdBy': appState.authUserId,
      'walletId': isCashSpent ? selectedWalletId : null,
      // THÊM MỚI: Gán ngày thanh toán nếu có
      if (isCashSpent) 'paymentDate': paymentDate.toIso8601String(),
      'category': 'Chi phí khác',
    };

    appState.addOtherExpenseAndUpdateState(newExpense: newExpense).then((_) {
      _nameController.clear();
      _amountController.clear();
      FocusScope.of(context).unfocus();
      _showStyledSnackBar("Đã thêm chi phí: $name");
    }).catchError((e) {
      _showStyledSnackBar("Lỗi khi thêm chi phí: $e", isError: true);
    });
  }

  void _editExpense(AppState appState, int index) {
    final expenseToEdit = appState.otherExpenseTransactions.value[index];
    final editNameController = TextEditingController(text: expenseToEdit['name']);
    final editAmountController = TextEditingController(text: _inputPriceFormatter.format(expenseToEdit['amount']));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Chỉnh sửa: ${expenseToEdit['name']}"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: editNameController, decoration: InputDecoration(labelText: "Tên chi phí")),
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
                  ...expenseToEdit,
                  'name': newName,
                  'amount': newAmount,
                };
                appState.editOtherExpenseAndUpdateState(
                  originalExpense: expenseToEdit,
                  updatedExpense: updatedExpense,
                ).then((_) {
                  Navigator.pop(ctx);
                  _showStyledSnackBar("Đã cập nhật chi phí.");
                }).catchError((e) {
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

  void _deleteExpense(int index) {
    final appState = context.read<AppState>();
    final transactionsNotifier = appState.otherExpenseTransactions;
    if (index < 0 || index >= transactionsNotifier.value.length) return;
    final expenseToRemove = transactionsNotifier.value[index];

    appState.removeOtherExpenseAndUpdateState(expenseToRemove: expenseToRemove)
        .then((_){
      _showStyledSnackBar("Đã xóa chi phí: ${expenseToRemove['name']}");
    }).catchError((e){
      _showStyledSnackBar("Lỗi khi xóa: $e", isError: true);
    });
  }

  void _showPayExpenseDialog(Map<String, dynamic> expenseToPay) {
    String? selectedWalletIdForPayment;
    final appState = context.read<AppState>();
    // THÊM MỚI: Biến state cho ngày
    DateTime paymentDate = DateTime.now();

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            title: Text('Xác nhận Thực chi', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Thanh toán cho khoản chi: "${expenseToPay['name']}"?'),
                const SizedBox(height: 20),

                // THÊM MỚI: Giao diện chọn ngày
                InkWell(
                  onTap: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: paymentDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null && picked != paymentDate) {
                      setDialogState(() {
                        paymentDate = picked;
                      });
                    }
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Ngày thực chi',
                      prefixIcon: Icon(Icons.calendar_today, color: AppColors.chartRed),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      DateFormat('dd/MM/yyyy').format(paymentDate),
                      style: GoogleFonts.poppins(fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                ValueListenableBuilder<List<Map<String, dynamic>>>(
                  valueListenable: appState.wallets,
                  builder: (context, walletList, child) {
                    if (walletList.isEmpty) return Text("Vui lòng tạo ví tiền trước.");
                    selectedWalletIdForPayment ??= appState.defaultWallet?['id'] ?? walletList.first['id'];
                    return DropdownButtonFormField<String>(
                      value: selectedWalletIdForPayment,
                      items: walletList.map((w) => DropdownMenuItem(value: w['id'] as String, child: Text(w['name']))).toList(),
                      onChanged: (val) => setDialogState(() => selectedWalletIdForPayment = val),
                      decoration: InputDecoration(
                        labelText: 'Chi từ ví',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
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
                    appState.payForOtherExpense(
                      expenseToPay: expenseToPay,
                      walletId: selectedWalletIdForPayment!,
                      paymentDate: paymentDate, // << TRUYỀN NGÀY VÀO HÀM
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

  // === THÊM MỚI: Widget để xây dựng các tab, tương tự EditOtherRevenueScreen ===
  Widget _buildTab(String title, int tabIndex, bool isFirst, bool isLast) {
    bool isSelected = _selectedTab == tabIndex;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (mounted) setState(() => _selectedTab = tabIndex);
          _animationController.reset();
          _animationController.forward();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.getCardColor(context) : AppColors.chartRed,
            borderRadius: BorderRadius.only(
              topLeft: isFirst ? const Radius.circular(12) : Radius.zero,
              bottomLeft: isFirst ? const Radius.circular(12) : Radius.zero,
              topRight: isLast ? const Radius.circular(12) : Radius.zero,
              bottomRight: isLast ? const Radius.circular(12) : Radius.zero,
            ),
            border: isSelected ? Border.all(color: AppColors.chartRed, width: 0.5) : null,
            boxShadow: isSelected
                ? [BoxShadow(color: Colors.red.withOpacity(0.1), spreadRadius: 1, blurRadius: 5, offset: Offset(0, 2))]
                : [],
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 15.5,
              color: isSelected ? AppColors.chartRed : Colors.white.withOpacity(0.9),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
  // =========================================================================

  @override
  Widget build(BuildContext context) {
    final appState = context.read<AppState>();
    final bool canEditThisExpense = appState.hasPermission('canEditExpenses'); // Giả định có quyền này

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        backgroundColor: AppColors.getBackgroundColor(context),
        // === CẬP NHẬT: AppBar với thanh Tab ===
        appBar: AppBar(
          backgroundColor: AppColors.chartRed,
          elevation: 1,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            "Chi phí khác",
            style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white),
          ),
          centerTitle: true,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(50),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 5.0),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.chartRed,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    _buildTab("Thêm chi phí", 0, true, false),
                    _buildTab("Lịch sử", 1, false, true),
                  ],
                ),
              ),
            ),
          ),
        ),
        // === CẬP NHẬT: Body với IndexedStack để chuyển đổi giữa các Tab ===
        body: ValueListenableBuilder<int>(
            valueListenable: appState.permissionVersion,
            builder: (context, permissionVersion, child) {
              final bool canEdit = appState.hasPermission('canEditExpenses');
              return ScaleTransition(
                scale: _scaleAnimation,
                child: IndexedStack(
                  index: _selectedTab,
                  children: [
                    // --- Tab 0: Giao diện nhập liệu ---
                    ExpenseInputSection(
                      key: const ValueKey('otherExpenseInput'),
                      amountController: _amountController,
                      nameController: _nameController,
                      onAddExpense: canEdit ? (isCash, walletId, paymentDate) => _addExpense(appState, isCash, walletId, paymentDate) : null,
                      appState: appState,
                      inputPriceFormatter: _inputPriceFormatter,
                    ),
                    // --- Tab 1: Lịch sử chi phí ---
                    ExpenseHistorySection(
                      key: const ValueKey('otherExpenseHistory'),
                      transactionsNotifier: appState.otherExpenseTransactions,
                      onEditExpense: canEdit ? _editExpense : null,
                      onDeleteExpense: canEdit ? _deleteExpense : null,
                      onPayExpense: canEdit ? _showPayExpenseDialog : null,
                      appState: appState,
                      currencyFormat: _currencyFormat,
                      primaryColor: AppColors.chartRed,
                      textColorPrimary: AppColors.getTextColor(context),
                      textColorSecondary: AppColors.getTextSecondaryColor(context),
                      cardBackgroundColor: AppColors.getCardColor(context),
                      accentColor: AppColors.primaryBlue,
                    )
                  ],
                ),
              );
            }
        ),
      ),
    );
  }
}

// =======================================================================
// === WIDGET NHẬP LIỆU: Giữ nguyên từ file cũ (ExpenseInputSection) ===
// =======================================================================
class ExpenseInputSection extends StatefulWidget {
  final TextEditingController amountController;
  final TextEditingController nameController;
  final Function(bool isCashSpent, String? walletId, DateTime paymentDate)? onAddExpense;
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
  DateTime _paymentDate = DateTime.now();
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
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
                          } else {
                            _paymentDate = DateTime.now();
                          }
                        });
                      },
                      activeColor: AppColors.chartRed,
                      contentPadding: EdgeInsets.zero,
                    ),
                    if (_isCashSpent) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: InkWell(
                          onTap: () async {
                            final DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate: _paymentDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (picked != null && picked != _paymentDate) {
                              setState(() {
                                _paymentDate = picked;
                              });
                            }
                          },
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Ngày thực chi',
                              prefixIcon: Icon(Icons.calendar_today, color: AppColors.chartRed),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(
                              DateFormat('dd/MM/yyyy').format(_paymentDate),
                              style: GoogleFonts.poppins(fontSize: 16, color: AppColors.getTextColor(context)),
                            ),
                          ),
                        ),
                      ),
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
                    ],
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
                      onPressed: widget.onAddExpense != null
                          ? () => widget.onAddExpense!(_isCashSpent, _selectedWalletId, _paymentDate) // << TRUYỀN NGÀY
                          : null,
                      child: Text(
                        "Thêm chi phí",
                        style: GoogleFonts.poppins(fontSize: 16.5, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ]
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

// =======================================================================
// === WIDGET LỊCH SỬ MỚI: Dựa trên TransactionHistorySection của Doanh thu ===
// =======================================================================
class ExpenseHistorySection extends StatelessWidget {
  final ValueNotifier<List<Map<String, dynamic>>> transactionsNotifier;
  final Function(AppState, int)? onEditExpense;
  final Function(int)? onDeleteExpense;
  final Function(Map<String, dynamic>)? onPayExpense;
  final AppState appState;
  final NumberFormat currencyFormat;
  final Color primaryColor;
  final Color textColorPrimary;
  final Color textColorSecondary;
  final Color cardBackgroundColor;
  final Color accentColor;

  const ExpenseHistorySection({
    required this.transactionsNotifier,
    required this.onEditExpense,
    required this.onDeleteExpense,
    required this.onPayExpense,
    required this.appState,
    required this.currencyFormat,
    required this.primaryColor,
    required this.textColorPrimary,
    required this.textColorSecondary,
    required this.cardBackgroundColor,
    required this.accentColor,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<Map<String, dynamic>>>(
      valueListenable: transactionsNotifier,
      builder: (context, List<Map<String, dynamic>> currentHistory, _) {
        if (currentHistory.isEmpty) {
          return Center( /* Widget hiển thị khi danh sách rỗng */ );
        }
        final sortedHistory = List<Map<String, dynamic>>.from(currentHistory);
        sortedHistory.sort((a, b) {
          DateTime dateA = DateTime.tryParse(a['date'] ?? '') ?? DateTime(1900);
          DateTime dateB = DateTime.tryParse(b['date'] ?? '') ?? DateTime(1900);
          return dateB.compareTo(dateA);
        });

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 80.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Text(
                  "Lịch sử chi phí",
                  style: GoogleFonts.poppins(fontSize: 19, fontWeight: FontWeight.w700, color: textColorPrimary),
                ),
              ),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: sortedHistory.length,
                itemBuilder: (context, index) {
                  final expense = sortedHistory[index];
                  final bool isUnpaid = expense['walletId'] == null;
                  final bool isOwner = appState.isOwner();
                  final bool isCreator = (expense['createdBy'] ?? "") == appState.authUserId;
                  final originalIndex = currentHistory.indexOf(expense);
                  final bool canModifyThisRecord = isOwner || isCreator;

                  return Dismissible(
                    key: Key(expense['id'].toString()),
                    background: Container(
                      color: primaryColor.withOpacity(0.8),
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      child: const Icon(Icons.delete_sweep_outlined, color: Colors.white, size: 26),
                    ),
                    direction: (onDeleteExpense != null && canModifyThisRecord) ? DismissDirection.endToStart : DismissDirection.none,
                    onDismissed: (direction) {
                      if (onDeleteExpense != null && canModifyThisRecord && originalIndex != -1) {
                        onDeleteExpense!(originalIndex);
                      }
                    },
                    child: Card(
                      elevation: 1.5,
                      margin: const EdgeInsets.symmetric(vertical: 5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      color: AppColors.getCardColor(context),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: CircleAvatar(
                            backgroundColor: primaryColor.withOpacity(0.15),
                            radius: 20,
                            child: Icon(Icons.receipt_long_outlined, color: primaryColor)
                        ),
                        title: Text(expense['name']?.toString() ?? 'N/A', style: GoogleFonts.poppins(fontSize: 15.5, fontWeight: FontWeight.w600, color: textColorPrimary)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Số tiền: ${currencyFormat.format(expense['amount'] ?? 0.0)}", style: GoogleFonts.poppins(fontSize: 13.0, color: primaryColor, fontWeight: FontWeight.w500)),
                            if (expense['date'] != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 2.0),
                                child: Text(
                                  DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(expense['date'])),
                                  style: GoogleFonts.poppins(fontSize: 11.0, color: textColorSecondary.withOpacity(0.8)),
                                ),
                              ),
                            if (isUnpaid)
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Chip(
                                  label: Text('Chưa chi', style: GoogleFonts.poppins(fontSize: 10, color: Colors.orange.shade900)),
                                  backgroundColor: Colors.orange.withOpacity(0.2),
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  labelPadding: EdgeInsets.zero,
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isUnpaid && onPayExpense != null && canModifyThisRecord)
                              IconButton(
                                icon: Icon(Icons.price_check_outlined, color: Colors.green.shade600),
                                onPressed: () => onPayExpense!(expense),
                                tooltip: 'Thực chi',
                                splashRadius: 18,
                              ),
                            IconButton(
                              icon: Icon(Icons.edit_note_outlined, color: accentColor.withOpacity(0.8), size: 22),
                              onPressed: (onEditExpense != null && canModifyThisRecord && originalIndex != -1)
                                  ? () => onEditExpense!(appState, originalIndex)
                                  : null,
                              splashRadius: 18,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}