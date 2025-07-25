import 'package:fingrowth/screens/subscription_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../state/app_state.dart'; // Ensure this path is correct
import 'package:fingrowth/screens/report_screen.dart';
import 'package:google_fonts/google_fonts.dart';

class EditOtherRevenueScreen extends StatefulWidget {
  final VoidCallback onUpdate;
  const EditOtherRevenueScreen({required this.onUpdate, Key? key})
      : super(key: key);

  @override
  _EditOtherRevenueScreenState createState() => _EditOtherRevenueScreenState();
}

class _EditOtherRevenueScreenState extends State<EditOtherRevenueScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _totalController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final NumberFormat currencyFormat =
  NumberFormat.currency(locale: 'vi_VN', symbol: 'VNĐ');
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  int _selectedTab = 0;

  final NumberFormat _inputPriceFormatter = NumberFormat("#,##0", "vi_VN");

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
        duration: const Duration(milliseconds: 300), vsync: this);
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
        CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack));
    _animationController.forward();
  }

  @override
  void dispose() {
    _totalController.dispose();
    _nameController.dispose();
    _animationController.dispose();
    super.dispose();
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

  void _showCollectPaymentDialog(BuildContext context, AppState appState, Map<String, dynamic> transaction) {
    String? selectedWalletId;
    DateTime paymentDate = DateTime.now(); // Mặc định là hôm nay
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            title: Text('Xác nhận Thu tiền', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Giao dịch: "${transaction['name']}"'),
                const SizedBox(height: 4),
                Text('Số tiền: ${currencyFormat.format(transaction['total'] ?? 0.0)}', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                // Widget chọn ví tiền
                ValueListenableBuilder<List<Map<String, dynamic>>>(
                  valueListenable: appState.wallets,
                  builder: (context, walletList, child) {
                    if (walletList.isEmpty) return const Text("Vui lòng tạo ví tiền trước.");
                    // Tự động chọn ví mặc định
                    selectedWalletId ??= appState.defaultWallet?['id'] ?? walletList.first['id'];
                    return DropdownButtonFormField<String>(
                      value: selectedWalletId,
                      items: walletList.map((w) => DropdownMenuItem<String>(value: w['id'] as String, child: Text(w['name']))).toList(),
                      onChanged: (val) => setDialogState(() => selectedWalletId = val),
                      decoration: InputDecoration(
                        labelText: 'Thu vào ví',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    );
                  },
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Hủy')),
              ElevatedButton(
                onPressed: () async {
                  if (selectedWalletId != null) {
                    try {
                      // Gọi hàm core trong AppState với tham số category đã được cập nhật
                      await appState.collectPaymentForTransaction(
                        category: 'Doanh thu khác', // Cung cấp đúng category
                        transactionToUpdate: transaction,
                        paymentDate: paymentDate,
                        walletId: selectedWalletId!,
                        transactionRecordDate: appState.selectedDate,
                      );
                      Navigator.pop(dialogContext);
                      _showStyledSnackBar("Đã ghi nhận thu tiền thành công!");
                    } catch (e) {
                      _showStyledSnackBar("Lỗi khi thu tiền: $e", isError: true);
                    }
                  }
                },
                child: const Text('Xác nhận'),
              ),
            ],
          );
        },
      ),
    );
  }

  // Thay thế hàm _addTransaction [14] trong file edit_other_revenue.docx

  void _addTransaction(AppState appState, bool isCashReceived, String? walletId) {
    double total = double.tryParse(_totalController.text.replaceAll('.', '').replaceAll(',', '')) ?? 0.0;

    if (!appState.isSubscribed && (appState.totalRevenueListenable.value + total > 2000000)) {
      _showUpgradeDialog(context);
      return;
    }

    String name = _nameController.text.trim();
    if (name.isEmpty) {
      _showStyledSnackBar('Vui lòng nhập tên giao dịch!', isError: true);
      return;
    }
    if (total <= 0) {
      _showStyledSnackBar('Số tiền phải lớn hơn 0!', isError: true);
      return;
    }

    final newTransaction = {
      'id': Uuid().v4(), // Thêm ID để xử lý dễ dàng hơn
      'name': name,
      'category': 'Doanh thu khác',
      'total': total,
      'quantity': 1.0,
      'date': DateTime.now().toIso8601String(),
      'createdBy': appState.authUserId,
    };

    appState.addOtherRevenueAndUpdateState(
      newTransaction,
      isCashReceived: isCashReceived,
      walletId: walletId,
    ).then((_) {
      _showStyledSnackBar('Đã thêm giao dịch: $name');
      _totalController.clear();
      _nameController.clear();
      FocusScope.of(context).unfocus();
      widget.onUpdate();
    }).catchError((e) {
      _showStyledSnackBar('Lỗi khi thêm giao dịch: $e', isError: true);
    });
  }

  // Dành cho file edit_other_revenue.docx

  void _editTransaction(AppState appState, int originalIndexInValueNotifier) {
    // Lấy giao dịch cần sửa từ ValueNotifier bằng chỉ mục gốc
    final transactionToEdit =
    appState.otherRevenueTransactions.value[originalIndexInValueNotifier];

    // Tạo các controller tạm thời cho dialog
    final TextEditingController editNameController =
    TextEditingController(text: transactionToEdit['name']?.toString() ?? '');
    final TextEditingController editTotalController = TextEditingController(
        text: _inputPriceFormatter.format(transactionToEdit['total'] ?? 0.0));

    showDialog(
      context: context,
      builder: (dialogContext) => GestureDetector(
        onTap: () => FocusScope.of(dialogContext).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: AlertDialog(
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text('Chỉnh sửa giao dịch',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600, color: AppColors.getTextColor(context))),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDialogTextField(
                context: dialogContext,
                controller: editNameController,
                labelText: 'Tên giao dịch',
                prefixIconData: Icons.description_outlined,
                maxLength: 100,
              ),
              const SizedBox(height: 16),
              _buildDialogTextField(
                context: dialogContext,
                controller: editTotalController,
                labelText: 'Số tiền',
                prefixIconData: Icons.monetization_on_outlined,
                keyboardType: TextInputType.numberWithOptions(decimal: false),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  TextInputFormatter.withFunction(
                        (oldValue, newValue) {
                      if (newValue.text.isEmpty) return newValue;
                      final String plainNumberText = newValue.text
                          .replaceAll('.', '')
                          .replaceAll(',', '');
                      final number = int.tryParse(plainNumberText);
                      if (number == null) return oldValue;
                      final formattedText =
                      _inputPriceFormatter.format(number);
                      return newValue.copyWith(
                        text: formattedText,
                        selection: TextSelection.collapsed(
                            offset: formattedText.length),
                      );
                    },
                  ),
                ],
                maxLength: 15,
              ),
            ],
          ),
          actionsPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: Text('Hủy',
                  style: GoogleFonts.poppins(
                      color: AppColors.getTextSecondaryColor(context),
                      fontWeight: FontWeight.w500)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              onPressed: () {
                // Chuẩn bị dữ liệu từ dialog
                double newTotal = double.tryParse(editTotalController.text
                    .replaceAll('.', '')
                    .replaceAll(',', '')) ??
                    0.0;
                String newName = editNameController.text.trim();

                // Validate dữ liệu
                if (newName.isEmpty) {
                  _showStyledSnackBar('Tên giao dịch không được để trống!',
                      isError: true);
                  return;
                }
                if (newTotal <= 0) {
                  _showStyledSnackBar('Số tiền phải lớn hơn 0!', isError: true);
                  return;
                }

                // Chuẩn bị map giao dịch đã cập nhật
                final updatedTransaction = {
                  ...transactionToEdit, // Giữ lại các trường cũ như date, createdBy...
                  'name': newName,
                  'total': newTotal,
                };

                // THAY ĐỔI CỐT LÕI: Gọi hàm tập trung của AppState
                appState
                    .editOtherRevenueAndUpdateState(
                    originalIndexInValueNotifier, updatedTransaction)
                    .then((_) {
                  // Các hành động sau khi thành công
                  Navigator.pop(dialogContext);
                  _showStyledSnackBar('Đã cập nhật giao dịch: $newName');
                  widget.onUpdate();
                })
                    .catchError((e) {
                  // Xử lý nếu có lỗi
                  Navigator.pop(dialogContext);
                  _showStyledSnackBar('Lỗi khi cập nhật: $e', isError: true);
                });
              },
              child: Text('Lưu', style: GoogleFonts.poppins()),
            ),
          ],
        ),
      ),
    );
  }

  // Thay thế hàm removeTransaction/deleteTransaction cũ
  void _deleteTransaction(int index) {
    final appState = context.read<AppState>();
    final transactionsNotifier = appState.otherRevenueTransactions;

    if (index < 0 || index >= transactionsNotifier.value.length) return;
    final transactionToRemove = transactionsNotifier.value[index];

    appState.deleteTransactionAndUpdateAll(
      transactionToRemove: transactionToRemove,
    ).then((_) {
      if (mounted) {
        _showStyledSnackBar(
          "Đã xóa: ${transactionToRemove['name']}. Mọi dữ liệu liên quan đã được cập nhật.",
        );
        widget.onUpdate();
      }
    }).catchError((e) {
      if (mounted) {
        _showStyledSnackBar('Lỗi khi xóa: $e', isError: true);
      }
    });
  }


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
            color: isSelected ? AppColors.getCardColor(context) : AppColors.primaryBlue,
            borderRadius: BorderRadius.only(
              topLeft: isFirst ? const Radius.circular(12) : Radius.zero,
              bottomLeft: isFirst ? const Radius.circular(12) : Radius.zero,
              topRight: isLast ? const Radius.circular(12) : Radius.zero,
              bottomRight: isLast ? const Radius.circular(12) : Radius.zero,
            ),
            border: isSelected
                ? Border.all(color: AppColors.primaryBlue, width: 0.5)
                : null,
            boxShadow: isSelected
                ? [
              BoxShadow(
                  color: Colors.blue.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 5,
                  offset: Offset(0, 2))
            ]
                : [],
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 15.5,
              color: isSelected ? AppColors.primaryBlue : Colors.white.withOpacity(0.9),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.read<AppState>();
    final bool canEditThisRevenue = appState.hasPermission('canEditRevenue');
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        backgroundColor: AppColors.getBackgroundColor(context),
        appBar: AppBar(
          backgroundColor: AppColors.primaryBlue,
          elevation: 1,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            "Doanh thu khác",
            style: GoogleFonts.poppins(
                fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white),
          ),
          centerTitle: true,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(50),
            child: Padding(
              padding:
              const EdgeInsets.symmetric(horizontal: 12.0, vertical: 5.0),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    _buildTab("Thêm giao dịch", 0, true, false),
                    _buildTab("Lịch sử", 1, false, true),
                  ],
                ),
              ),
            ),
          ),
        ),
        body: ValueListenableBuilder<int>(
          valueListenable: appState.permissionVersion,
          builder: (context, permissionVersion, child) {
            final bool canEditThisRevenue = appState.hasPermission('canEditRevenue');

            return ScaleTransition(
              scale: _scaleAnimation,
              child: IndexedStack(
                index: _selectedTab,
                children: [
                  TransactionInputSection(
                    key: const ValueKey('otherRevenueInput'),
                    totalController: _totalController,
                    nameController: _nameController,
                    // --- CẬP NHẬT LỜI GỌI HÀM ---
                    onAddTransaction: canEditThisRevenue
                        ? (isCashReceived, walletId) => _addTransaction(appState, isCashReceived, walletId)
                        : null,
                    appState: appState,
                    inputPriceFormatter: _inputPriceFormatter,
                  ),
                  TransactionHistorySection(
                    key: const ValueKey('otherRevenueHistory'),
                    transactionsNotifier: appState.otherRevenueTransactions,
                    // `canEditThisRevenue` đã được cập nhật
                    onEditTransaction: canEditThisRevenue ? _editTransaction : null,
                    onDeleteTransaction: canEditThisRevenue ? _deleteTransaction : null,
                    appState: appState,
                    currencyFormat: currencyFormat,
                    primaryColor: AppColors.primaryBlue,
                    textColorPrimary: AppColors.getTextColor(context),
                    textColorSecondary: AppColors.getTextSecondaryColor(context),
                    cardBackgroundColor: AppColors.getCardColor(context),
                    accentColor: AppColors.chartRed,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // Helper method for TextFields in Dialogs to maintain consistency
  Widget _buildDialogTextField({
    required BuildContext context,
    required TextEditingController controller,
    required String labelText,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    int? maxLength,
    IconData? prefixIconData,
    int maxLines = 1,
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
        prefixIcon: prefixIconData != null ? Icon(prefixIconData, color: AppColors.primaryBlue, size: 22) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.primaryBlue, width: 1.5)),
        filled: true,
        fillColor: AppColors.getBackgroundColor(context), // Dialog fields might have a slightly different background
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        counterText: "",
      ),
    );
  }
}

void _showUpgradeDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      title: Text("Vượt giới hạn doanh thu", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
      content: Text(
        "Người dùng miễn phí chỉ có thể ghi nhận tối đa 2.000.000đ doanh thu mỗi ngày. Vui lòng nâng cấp để ghi nhận không giới hạn.",
        style: GoogleFonts.poppins(),
      ),
      actions: [
        TextButton(
          child: Text("Để sau", style: GoogleFonts.poppins()),
          onPressed: () => Navigator.of(dialogContext).pop(),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue),
          child: Text("Nâng cấp ngay", style: GoogleFonts.poppins(color: Colors.white)),
          onPressed: () {
            Navigator.of(dialogContext).pop(); // Đóng dialog
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const SubscriptionScreen(),
            ));
          },
        ),
      ],
    ),
  );
}

class TransactionInputSection extends StatefulWidget {
  final TextEditingController totalController;
  final TextEditingController nameController;
  final Function(bool isCashReceived, String? walletId)? onAddTransaction; // THAY ĐỔI
  final AppState appState;
  final NumberFormat inputPriceFormatter;

  const TransactionInputSection({
    required this.totalController,
    required this.nameController,
    required this.onAddTransaction,
    required this.appState,
    required this.inputPriceFormatter,
    Key? key,
  }) : super(key: key);

  @override
  State<TransactionInputSection> createState() => _TransactionInputSectionState();
}

class _TransactionInputSectionState extends State<TransactionInputSection> {
  // THÊM MỚI: State để quản lý UI
  bool _isCashReceived = true;
  String? _selectedWalletId;

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
                    "Thêm giao dịch mới",
                    style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryBlue),
                  ),
                  const SizedBox(height: 24),
                  _buildInputTextField(
                    context: context,
                    controller: widget.nameController,
                    labelText: 'Tên giao dịch',
                    prefixIconData: Icons.description_outlined,
                    maxLength: 100,
                  ),
                  const SizedBox(height: 16),
                  _buildInputTextField(
                    context: context,
                    controller: widget.totalController,
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

                  // --- BẮT ĐẦU CODE MỚI ---
                  const SizedBox(height: 20),
                  SwitchListTile.adaptive(
                    title: Text("Thực thu vào quỹ?", style: GoogleFonts.poppins(fontSize: 16, color: AppColors.getTextColor(context), fontWeight: FontWeight.w500)),
                    value: _isCashReceived,
                    onChanged: (bool value) {
                      setState(() {
                        _isCashReceived = value;
                        if (!value) {
                          _selectedWalletId = null;
                        }
                      });
                    },
                    activeColor: AppColors.primaryBlue,
                    contentPadding: EdgeInsets.zero,
                  ),

                  if (_isCashReceived)
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
                              labelText: 'Chọn ví nhận tiền',
                              prefixIcon: Icon(Icons.account_balance_wallet_outlined, color: AppColors.primaryBlue),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        );
                      },
                    ),
                  // --- KẾT THÚC CODE MỚI ---

                  const SizedBox(height: 28),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      minimumSize: Size(screenWidth, 52),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 2,
                    ),
                    onPressed: widget.onAddTransaction != null
                        ? () => widget.onAddTransaction!(_isCashReceived, _selectedWalletId)
                        : null,
                    child: Text(
                      "Thêm giao dịch",
                      style: GoogleFonts.poppins(fontSize: 16.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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
        prefixIcon: prefixIconData != null ? Icon(prefixIconData, color: AppColors.primaryBlue, size: 22) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.primaryBlue, width: 1.5)),
        filled: true,
        fillColor: AppColors.getBackgroundColor(context).withOpacity(0.5),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        counterText: "",
      ),
    );
  }
}

class TransactionHistorySection extends StatelessWidget {
  final ValueNotifier<List<Map<String, dynamic>>> transactionsNotifier; // MODIFIED: Changed name for clarity
  final Function(AppState, int)? onEditTransaction;
  final Function(int)? onDeleteTransaction;
  final AppState appState; // Passed to be available for callbacks
  final NumberFormat currencyFormat;
  final Color primaryColor;
  final Color textColorPrimary;
  final Color textColorSecondary;
  final Color cardBackgroundColor;
  final Color accentColor;

  const TransactionHistorySection({
    required this.transactionsNotifier, // MODIFIED
    required this.onEditTransaction,
    required this.onDeleteTransaction,
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
      valueListenable: transactionsNotifier, // MODIFIED
      builder: (context, List<Map<String, dynamic>> currentHistory, _) { // MODIFIED: variable name
        if (currentHistory.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(30.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_toggle_off_outlined,
                      size: 70, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    "Chưa có giao dịch nào",
                    style:
                    GoogleFonts.poppins(fontSize: 17, color: textColorSecondary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Thêm giao dịch mới để xem lịch sử tại đây.",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                        fontSize: 14, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
          );
        }

        // Sort history by date descending (newest first)
        final sortedHistory = List<Map<String, dynamic>>.from(currentHistory);
        sortedHistory.sort((a, b) {
          DateTime dateA = DateTime.tryParse(a['date'] ?? '') ?? DateTime(1900);
          DateTime dateB = DateTime.tryParse(b['date'] ?? '') ?? DateTime(1900);
          return dateB.compareTo(dateA); // Sorts newest first
        });


        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 80.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Text(
                  "Lịch sử giao dịch", // Simplified title
                  style: GoogleFonts.poppins(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: textColorPrimary),
                ),
              ),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: sortedHistory.length,
                itemBuilder: (context, index) {
                  final transaction = sortedHistory[index];
                  final bool isUnpaid = transaction['paymentStatus'] == 'unpaid';
                  final bool isOwner = appState.isOwner();
                  final bool isCreator = (transaction['createdBy'] ?? "") == appState.authUserId;
                  final originalIndex = currentHistory.indexOf(transaction);
                  final bool canModifyThisRecord = isOwner || isCreator;

                  return Dismissible(
                    key: Key(transaction['date'].toString() + (transaction['name'] ?? '') + index.toString()), // Ensure name is not null
                    background: Container(
                      color: accentColor.withOpacity(0.8),
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      child: const Icon(Icons.delete_sweep_outlined,
                          color: Colors.white, size: 26),
                    ),
                    direction: (onDeleteTransaction != null && canModifyThisRecord)
                        ? DismissDirection.endToStart
                        : DismissDirection.none,
                    onDismissed: (direction) {
                      // THAY ĐỔI 2: Thêm kiểm tra đầy đủ trước khi thực thi
                      if (onDeleteTransaction != null && canModifyThisRecord) {
                        if (originalIndex != -1) {
                          onDeleteTransaction!(originalIndex);
                        }
                      }
                    },
                    child: Card(
                      elevation: 1.5,
                      margin: const EdgeInsets.symmetric(vertical: 5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      color: AppColors.getCardColor(context),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        visualDensity: VisualDensity.compact,
                        leading: CircleAvatar(
                          backgroundColor: primaryColor.withOpacity(0.15),
                          radius: 20,
                          child: Text(
                            transaction['name'] != null &&
                                (transaction['name'] as String).isNotEmpty
                                ? (transaction['name'] as String)[0]
                                .toUpperCase()
                                : "?",
                            style: GoogleFonts.poppins(
                                color: AppColors.primaryBlue,
                                fontWeight: FontWeight.w600,
                                fontSize: 18),
                          ),
                        ),
                        title: Text(
                          transaction['name']?.toString() ?? 'N/A',
                          style: GoogleFonts.poppins(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w600,
                              color: textColorPrimary),
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text( // For "Other Revenue", only total is primary
                              "Tổng: ${currencyFormat.format(transaction['total'] ?? 0.0)}",
                              style: GoogleFonts.poppins(
                                  fontSize: 13.0,
                                  color: AppColors.primaryBlue, // Emphasize total
                                  fontWeight: FontWeight.w500),
                            ),
                            if (transaction['date'] != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 2.0),
                                child: Text(
                                  DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(transaction['date'])),
                                  style: GoogleFonts.poppins(fontSize: 11.0, color: textColorSecondary.withOpacity(0.8)),
                                ),
                              ),
                            if (isUnpaid)
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Chip(
                                  label: Text('Chưa thu tiền', style: GoogleFonts.poppins(fontSize: 10, color: Colors.orange.shade900)),
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
                          // --- THÊM MỚI: NÚT "THU TIỀN" ---
                          if (isUnpaid && onEditTransaction != null && canModifyThisRecord)
                          IconButton(
                          icon: Icon(Icons.price_check_outlined, color: Colors.green.shade600),
                      onPressed: () {
                        // Gọi dialog đã tạo ở Bước 1
                        (context.findAncestorStateOfType<_EditOtherRevenueScreenState>())
                            ?._showCollectPaymentDialog(context, appState, transaction);
                      },
                      tooltip: 'Thu tiền',
                      splashRadius: 18,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                    ),
                    // Nút sửa hiện tại
                    IconButton(
                        icon: Icon(Icons.edit_note_outlined,
                            color: AppColors.primaryBlue.withOpacity(0.8), size: 22), // [cite: 6775-6776]
                    onPressed: (onEditTransaction != null && canModifyThisRecord)
                        ? () {
                      if (originalIndex != -1) {
                        onEditTransaction!(appState, originalIndex);
                      }
                    }
                        : null, // [cite: 6777-6784]
                    splashRadius: 18,
                    padding: EdgeInsets.zero,
                    constraints:
                    const BoxConstraints(minWidth: 30, minHeight: 30), // [cite: 6784-6787]
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