import 'package:fingrowth/screens/report_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:month_picker_dialog/month_picker_dialog.dart';
// Assuming these are your existing imports
import '../state/app_state.dart';
import '/screens/expense_manager.dart';
// Ensure this path is correct
import 'account_switcher.dart';
import 'update_expense_list_screen.dart';
import 'edit_fixed_expense_screen.dart';
import 'edit_variable_expense_screen.dart';
import 'user_setting_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import '/screens/edit_other_expense_screen.dart';
import '/screens/manage_fixed_expense_rules_screen.dart';
import 'package:fingrowth/screens/wallet_management_screen.dart';

class ExpenseScreen extends StatefulWidget {
  @override
  _ExpenseScreenState createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends State<ExpenseScreen>
    with SingleTickerProviderStateMixin {
  final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'VNĐ');
  final dateTimeFormat = DateFormat('HH:mm a', 'vi_VN');
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  bool _hasAnimated = false;
  String selectedExpenseCategory = 'Chi phí cố định';
  final PageController _pageController = PageController();
  bool _isDialogOpen = false;
  late AppState appState;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        duration: const Duration(milliseconds: 700), vsync: this);
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Lưu trữ tham chiếu đến AppState
    appState = Provider.of<AppState>(context, listen: false);
    // Di chuyển logic thêm listener vào đây
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (appState.dataReadyListenable.value) {
        _runAnimation();
      }
      appState.dataReadyListenable.addListener(_onDataReady);
    });
  }

  void _onDataReady() {
    final appState = Provider.of<AppState>(context, listen: false);
    if (appState.dataReadyListenable.value && mounted) {
      _resetAnimation();
      _runAnimation();
    }
  }

  void _runAnimation() {
    if (!_hasAnimated && mounted) {
      if (_controller.isDismissed) {
        _controller.forward();
        _hasAnimated = true;
      } else {
        print('ExpenseScreen: Animation not run, controller status: ${_controller.status} at ${DateTime.now().toIso8601String()}');
      }
    } else {
      print('ExpenseScreen: Animation not run, hasAnimated: $_hasAnimated, mounted: $mounted at ${DateTime.now().toIso8601String()}');
    }
  }

  void _resetAnimation() {
    if (mounted) {
      _controller.reset();
      _hasAnimated = false;
    } else {
      print('ExpenseScreen: Animation not reset, not mounted at ${DateTime.now().toIso8601String()}');
    }
  }

  @override
  void dispose() {
    // final appState = Provider.of<AppState>(context, listen: false); // XÓA DÒNG NÀY
    appState.dataReadyListenable.removeListener(_onDataReady); // Sử dụng biến appState đã có [cite: 26]
    _controller.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final appState = Provider.of<AppState>(context, listen: false);
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: appState.selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          // SỬA Ở ĐÂY: Bắt đầu từ theme hiện tại của context
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppColors.chartRed, // Sử dụng màu đỏ đặc trưng của màn hình Chi phí
              onPrimary: Colors.white,
              surface: AppColors.getCardColor(context),
              onSurface: AppColors.getTextColor(context),
            ),
            dialogBackgroundColor: AppColors.getCardColor(context),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.chartRed, // Đồng bộ màu nút bấm
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != appState.selectedDate) {
      appState.setSelectedDate(picked);
      _resetAnimation(); // Reset animation for new data
      _runAnimation();
    }
  }

  void _showStyledSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: isError ? Colors.redAccent : AppColors.chartRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(10),
      ),
    );
  }

  void removeExpense(AppState appState, int index, String category) {
    ValueNotifier<List<Map<String, dynamic>>> targetNotifier = _getExpenseListenable(appState);

    if (index < 0 || index >= targetNotifier.value.length) return;

    final expenseToRemove = targetNotifier.value[index];
    final removedItemName = expenseToRemove['name'] ?? 'Chi phí không tên';

    // Kiểm tra category để gọi đúng logic xóa
    if (category == 'Chi phí khác') {
      appState.removeOtherExpenseAndUpdateState(expenseToRemove: expenseToRemove).then((_) {
        _showStyledSnackBar("Đã xóa: $removedItemName");
      }).catchError((e) {
        _showStyledSnackBar("Lỗi khi xóa: $e", isError: true);
      });
    } else {
      // Giữ lại logic cũ cho Chi phí Cố định và Biến đổi
      final currentList = List<Map<String, dynamic>>.from(targetNotifier.value);
      currentList.removeAt(index);

      Future<void> saveFuture;
      if (category == 'Chi phí cố định') {
        saveFuture = ExpenseManager.saveFixedExpenses(appState, currentList);
      } else { // Chi phí biến đổi
        saveFuture = ExpenseManager.saveVariableExpenses(appState, currentList);
      }

      saveFuture.then((_) {
        _showStyledSnackBar("Đã xóa: $removedItemName");
      }).catchError((e) {
        _showStyledSnackBar("Lỗi khi xóa: $e", isError: true);
      });
    }
  }

  void editExpense(AppState appState, int index, String category) {
    ValueNotifier<List<Map<String, dynamic>>> targetNotifier = _getExpenseListenable(appState);

    if (index < 0 || index >= targetNotifier.value.length) return;
    final originalExpense = targetNotifier.value[index];

    final _inputPriceFormatter = NumberFormat("#,##0", "vi_VN");
    final editNameController = TextEditingController(text: originalExpense['name']);
    final editAmountController = TextEditingController(text: _inputPriceFormatter.format(originalExpense['amount']));

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text("Chỉnh sửa: ${originalExpense['name']}"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if(category == 'Chi phí khác') ...[
              TextField(controller: editNameController, decoration: InputDecoration(labelText: "Tên chi phí mới")),
              SizedBox(height: 16),
            ],
            TextField(
              controller: editAmountController,
              decoration: InputDecoration(labelText: "Số tiền mới"),
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
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: Text("Hủy")),
          ElevatedButton(
            onPressed: () {
              final newAmount = double.tryParse(editAmountController.text.replaceAll('.', '')) ?? 0.0;
              final newName = editNameController.text.trim();

              if (newAmount <= 0 || (category == 'Chi phí khác' && newName.isEmpty)) {
                _showStyledSnackBar("Thông tin không hợp lệ.", isError: true);
                return;
              }

              final updatedExpense = {
                ...originalExpense,
                'name': category == 'Chi phí khác' ? newName : originalExpense['name'],
                'amount': newAmount,
              };

              Future<void> future;
              if (category == 'Chi phí khác') {
                future = appState.editOtherExpenseAndUpdateState(originalExpense: originalExpense, updatedExpense: updatedExpense);
              } else {
                final currentList = List<Map<String, dynamic>>.from(targetNotifier.value);
                currentList[index] = updatedExpense;
                if (category == 'Chi phí cố định') {
                  future = ExpenseManager.saveFixedExpenses(appState, currentList);
                } else {
                  future = ExpenseManager.saveVariableExpenses(appState, currentList);
                }
              }

              future.then((_) {
                _showStyledSnackBar("Đã cập nhật chi phí.");
              }).catchError((e){
                _showStyledSnackBar("Lỗi khi cập nhật: $e", isError: true);
              });
              Navigator.pop(dialogCtx);
            },
            child: Text("Lưu"),
          ),
        ],
      ),
    );
  }

  // Thay thế toàn bộ hàm cũ bằng hàm này
  void _navigateToEditExpense(String category) async {
    if (category == 'Cố định tháng') {
      Navigator.push(context, MaterialPageRoute(builder: (context) => const ManageFixedExpenseRulesScreen()));
    } else {
      Widget targetScreen;
      switch (category) {
        case 'Cố định ngày':
          targetScreen = const EditFixedExpenseScreen();
          break;
        case 'Biến đổi ngày':
          targetScreen = const EditVariableExpenseScreen();
          break;
        case 'Khác':
          targetScreen = const EditOtherExpenseScreen();
          break;
        default:
          return;
      }
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => targetScreen),
      );
    }
  }

  double _calculateTotal(List<Map<String, dynamic>> expenses) {
    return expenses.fold(0.0, (sum, expense) => sum + (expense['amount'] ?? 0.0));
  }

  void _showExpenseCategoryBottomSheet(BuildContext context) {
    final categories = [
      'Chi phí cố định',
      'Chi phí biến đổi',
      'Chi phí khác'
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          decoration: BoxDecoration(
              color: AppColors.getCardColor(context),
              borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: Offset(0, -5),
                )
              ]
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0, left: 8),
                child: Text(
                  'Chọn loại chi phí',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.getTextColor(context),
                  ),
                ),
              ),
              ...categories.map((categoryName) {
                bool isSelected = selectedExpenseCategory == categoryName;
                return ListTile(
                  title: Text(
                    categoryName,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? AppColors.chartRed : AppColors.getTextColor(context),
                    ),
                  ),
                  trailing: isSelected
                      ? Icon(Icons.check_circle, color: AppColors.chartRed)
                      : null,
                  onTap: () {
                    if (mounted) {
                      // Chỉ cần gọi setState để kích hoạt việc build lại widget
                      // ValueListenableBuilder sẽ tự động lấy giá trị mới nhất từ AppState
                      setState(() {
                        selectedExpenseCategory = categoryName;
                      });
                    }
                    Navigator.pop(context);
                  },
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)
                  ),
                  tileColor: isSelected ? AppColors.chartRed.withOpacity(0.1) : Colors.transparent,
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildModernDialogTextField({
    required TextEditingController controller,
    required String labelText,
    TextInputType keyboardType = TextInputType.text,
    bool isDense = false,
    String? hintText,
    IconData? prefixIcon,
    FocusNode? focusNode,
    void Function(String)? onChanged,
    void Function(String)? onSubmitted,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      focusNode: focusNode,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        labelStyle: TextStyle(color: AppColors.getTextSecondaryColor(context).withOpacity(0.9)),
        prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: AppColors.chartRed.withOpacity(0.7), size: 20) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.chartRed, width: 2),
        ),
        contentPadding: isDense ? EdgeInsets.symmetric(horizontal: 12, vertical: 10) : EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  // BẠN HÃY DÁN TOÀN BỘ ĐOẠN CODE NÀY ĐỂ THAY THẾ CHO HÀM _showMonthlyFixedExpenseDialog CŨ
// TRONG FILE expense_screen.docx (từ source 979 đến 1252)

  Future<Map<String, dynamic>?> _showEditDetailDialog({
    required BuildContext context,
    required String oldName,
    required double oldAmount,
    required DateTimeRange oldDateRange,
  }) async {
    final nameController = TextEditingController(text: oldName);
    final amountController = TextEditingController(text: oldAmount.toString());
    DateTimeRange? newDateRange = oldDateRange;

    return await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateInDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text("Chỉnh sửa chi phí"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildModernDialogTextField(
                      controller: nameController,
                      labelText: "Tên khoản chi",
                      prefixIcon: Icons.drive_file_rename_outline,
                    ),
                    SizedBox(height: 16),
                    _buildModernDialogTextField(
                      controller: amountController,
                      labelText: "Tổng số tiền",
                      keyboardType: TextInputType.number,
                      prefixIcon: Icons.monetization_on_outlined,
                    ),
                    SizedBox(height: 16),
                    // Widget chọn khoảng thời gian
                    GestureDetector(
                      onTap: () async {
                        final picked = await showDateRangePicker(
                          context: context,
                          initialDateRange: newDateRange,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          setStateInDialog(() {
                            newDateRange = picked;
                          });
                        }
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                                "${DateFormat('dd/MM/yy', 'vi').format(newDateRange!.start)} - ${DateFormat('dd/MM/yy', 'vi').format(newDateRange!.end)}",
                                style: TextStyle(fontSize: 14.5, color: AppColors.getTextColor(context))
                            ),
                            Icon(Icons.date_range_outlined, color: AppColors.chartRed, size: 20),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, null),
                  child: Text("Hủy"),
                ),
                ElevatedButton(
                  onPressed: () {
                    final newAmount = double.tryParse(amountController.text) ?? 0.0;
                    if (nameController.text.isNotEmpty && newAmount > 0) {
                      Navigator.pop(dialogContext, {
                        'newName': nameController.text,
                        'newAmount': newAmount,
                        'newDateRange': newDateRange,
                      });
                    }
                  },
                  child: Text("Lưu"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showMonthlyFixedExpenseDialog(AppState appState, {required bool canEdit}) async {
    if (_isDialogOpen) return;
    _isDialogOpen = true;

    DateTime _currentDialogMonth = appState.selectedDate;
    final TextEditingController _newExpenseNameController = TextEditingController();
    List<Map<String, dynamic>>? _expensesData;
    bool _isLoading = true;
    String? _errorMessage;
    bool _isMounted = true;
    DateTimeRange? _selectedDateRange;

    // Hàm tải dữ liệu, chỉ gọi khi cần (khi mở dialog hoặc đổi tháng)
    Future<void> _fetchDataForMonth(DateTime month, Function(void Function()) setStateDialog) async {
      if (!_isMounted) return;
      setStateDialog(() {
        _isLoading = true;
      });
      try {
        final data = await ExpenseManager.loadFixedExpenseList(appState, month);
        if (_isMounted) {
          setStateDialog(() {
            _expensesData = data;
            _isLoading = false;
            _errorMessage = null;
            _selectedDateRange = DateTimeRange(
              start: DateTime(month.year, month.month, 1),
              end: DateTime(month.year, month.month + 1, 0),
            );
          });
        }
      } catch (e) {
        if (_isMounted) {
          setStateDialog(() {
            _isLoading = false;
            _errorMessage = "Lỗi tải dữ liệu: ${e.toString()}";
          });
        }
      }
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogMainContext) => StatefulBuilder(
        builder: (dialogContext, setStateDialog) {
          if (_expensesData == null && _isLoading) {
            _fetchDataForMonth(_currentDialogMonth, setStateDialog);
          }

          Widget buildContent() {
            if (_isLoading) {
              return Container(height: 120, child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(color: AppColors.chartRed), SizedBox(height: 20), Text("Đang tải...", style: TextStyle(color: AppColors.getTextColor(context)))])));
            }
            if (_errorMessage != null) {
              return Text(_errorMessage!, style: TextStyle(color: AppColors.chartRed));
            }

            final List<TextEditingController> monthlyAmountControllers = List.generate(
                _expensesData!.length,
                    (index) => TextEditingController(text: _expensesData![index]['totalAmount']?.toString() ?? '')
            );

            return SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 10),
                    Text("Phân bổ chi phí cho các ngày:", style: TextStyle(color: AppColors.getTextSecondaryColor(context), fontSize: 13.5, fontWeight: FontWeight.w500)),
                    SizedBox(height: 6),
                    GestureDetector(
                      onTap: () async {
                        final DateTimeRange? pickedDateRange = await showDateRangePicker(
                            context: dialogContext,
                            initialDateRange: _selectedDateRange,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                            builder: (context, child) => Theme(data: Theme.of(context).copyWith(colorScheme: Theme.of(context).colorScheme.copyWith(primary: AppColors.chartRed, onPrimary: Colors.white, surface: AppColors.getCardColor(context), onSurface: AppColors.getTextColor(context)), dialogBackgroundColor: AppColors.getCardColor(context), textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: AppColors.chartRed))), child: child!)
                        );
                        if (pickedDateRange != null) {
                          setStateDialog(() => _selectedDateRange = pickedDateRange);
                        }
                      },
                      child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(12)),
                          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            Text("${DateFormat('dd/MM/yy', 'vi').format(_selectedDateRange!.start)} - ${DateFormat('dd/MM/yy', 'vi').format(_selectedDateRange!.end)}", style: TextStyle(fontSize: 14.5, color: AppColors.getTextColor(context))),
                            Icon(Icons.date_range_outlined, color: AppColors.chartRed, size: 20)
                          ])
                      ),
                    ),
                    SizedBox(height: 16),
                    Text("Thêm chi phí cố định mới:", style: TextStyle(color: AppColors.getTextSecondaryColor(context), fontSize: 13.5, fontWeight: FontWeight.w500)),
                    SizedBox(height: 6),
                    Row(children: [
                      Expanded(child: _buildModernDialogTextField(controller: _newExpenseNameController, labelText: "Tên khoản chi", prefixIcon: Icons.add_shopping_cart_outlined)),
                      SizedBox(width: 8),
                      IconButton(
                          icon: Icon(Icons.add_circle, color: AppColors.chartRed, size: 30),
                          onPressed: canEdit ? () {
                            if (_newExpenseNameController.text.isNotEmpty) {
                              final newExpenseName = _newExpenseNameController.text;
                              if (_expensesData!.any((exp) => exp['name'] == newExpenseName)) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Khoản chi '$newExpenseName' đã tồn tại."), backgroundColor: Colors.orangeAccent, behavior: SnackBarBehavior.floating));
                                return;
                              }
                              setStateDialog(() {
                                _expensesData!.add({'name': newExpenseName, 'totalAmount': null, 'startDate': _selectedDateRange!.start.toIso8601String(), 'endDate': _selectedDateRange!.end.toIso8601String()});
                                _expensesData!.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
                              });
                              _newExpenseNameController.clear();
                            }
                          } : null,
                          tooltip: "Thêm vào danh sách"
                      ),
                    ]),
                    const SizedBox(height: 20),
                    Text("Danh sách chi phí và số tiền:", style: TextStyle(color: AppColors.getTextSecondaryColor(context), fontSize: 13.5, fontWeight: FontWeight.w500)),
                    SizedBox(height: 6),
                    _expensesData!.isEmpty
                        ? Padding(padding: const EdgeInsets.symmetric(vertical: 20.0), child: Center(child: Text("Chưa có mục chi phí cố định nào.", style: TextStyle(color: AppColors.getTextSecondaryColor(context), fontStyle: FontStyle.italic))))
                        : Container(
                        constraints: BoxConstraints(maxHeight: 200),
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.getBorderColor(context))),
                        child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: _expensesData!.length,
                            itemBuilder: (lvContext, index) {
                              final expenseData = _expensesData![index];
                              final name = expenseData['name'] as String;
                              final savedAmount = expenseData['totalAmount'] as double?;
                              final isEditingThisAmount = savedAmount == null;
                              final dateRange = DateTimeRange(start: DateTime.parse(expenseData['startDate']), end: DateTime.parse(expenseData['endDate']));

                              return Card(
                                  elevation: 1.0,
                                  margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  child: Padding(
                                      padding: const EdgeInsets.only(left: 14.0, right: 6, top: 10, bottom: 10),
                                      child: Row(children: [
                                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                                          Text(name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.getTextColor(context)), overflow: TextOverflow.ellipsis),
                                          SizedBox(height: 5),
                                          isEditingThisAmount
                                              ? _buildModernDialogTextField(controller: monthlyAmountControllers[index], labelText: "Số tiền", keyboardType: TextInputType.number, isDense: true)
                                              : Text(currencyFormat.format(savedAmount), style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold, color: AppColors.chartRed)),
                                          Padding(
                                              padding: const EdgeInsets.only(top: 6.0),
                                              child: Text("(Áp dụng: ${DateFormat('dd/MM/yy').format(dateRange.start)} - ${DateFormat('dd/MM/yy').format(dateRange.end)})", style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: AppColors.getTextSecondaryColor(context)))
                                          )
                                        ])),
                                        SizedBox(width: 8),
                                        Row(mainAxisSize: MainAxisSize.min, children: [
                                          // Nút Lưu
                                          if (isEditingThisAmount)
                                            IconButton(
                                              icon: const Icon(Icons.check_circle, color: Colors.green, size: 28),
                                              tooltip: "Lưu số tiền",
                                              onPressed: canEdit ? () async {
                                                final newAmount = double.tryParse(monthlyAmountControllers[index].text.replaceAll('.', '')) ?? 0.0;
                                                if (newAmount > 0) {
                                                  await ExpenseManager.saveOrUpdateMonthlyFixedAmount(appState, name, newAmount, newDateRange: dateRange);

                                                  // <<< SỬA LỖI 1: CẬP NHẬT GIAO DIỆN TỨC THÌ KHI LƯU >>>
                                                  setStateDialog(() {
                                                    final savedIndex = _expensesData!.indexWhere((exp) => exp['name'] == name);
                                                    if (savedIndex != -1) {
                                                      _expensesData![savedIndex]['totalAmount'] = newAmount;
                                                    }
                                                  });

                                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Đã lưu '$name'."), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating));
                                                }
                                              } : null,
                                            ),
                                          // Nút Sửa
                                          if (!isEditingThisAmount)
                                            IconButton(
                                              icon: Icon(Icons.edit, color: AppColors.primaryBlue, size: 22),
                                              tooltip: "Chỉnh sửa",
                                              onPressed: canEdit ? () async {
                                                final result = await _showEditDetailDialog(context: context, oldName: name, oldAmount: savedAmount!, oldDateRange: dateRange);
                                                if (result != null) {
                                                  final newName = result['newName'] as String;
                                                  final newAmount = result['newAmount'] as double;
                                                  final newDateRange = result['newDateRange'] as DateTimeRange;

                                                  await ExpenseManager.saveOrUpdateMonthlyFixedAmount(appState, newName, newAmount, oldName: name, oldAmount: savedAmount, oldDateRange: dateRange, newDateRange: newDateRange);

                                                  // <<< SỬA LỖI 2: CẬP NHẬT GIAO DIỆN TỨC THÌ KHI SỬA >>>
                                                  setStateDialog(() {
                                                    final editedIndex = _expensesData!.indexWhere((exp) => exp['name'] == name);
                                                    if (editedIndex != -1) {
                                                      _expensesData![editedIndex]['name'] = newName;
                                                      _expensesData![editedIndex]['totalAmount'] = newAmount;
                                                      _expensesData![editedIndex]['startDate'] = newDateRange.start.toIso8601String();
                                                      _expensesData![editedIndex]['endDate'] = newDateRange.end.toIso8601String();
                                                      _expensesData!.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
                                                    }
                                                  });

                                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Đã cập nhật '${result['newName']}'."), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating));
                                                }
                                              } : null,
                                            ),
                                          // Nút Xóa
                                          IconButton(
                                            icon: Icon(Icons.delete_forever, color: AppColors.chartRed, size: 22),
                                            tooltip: "Xóa khoản chi",
                                            onPressed: canEdit ? () async {
                                              bool? confirm = await showDialog(context: dialogContext, builder: (ctx) => AlertDialog(title: Text("Xác nhận xóa"), content: Text("Bạn có chắc muốn xóa '$name' không?"), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text("Hủy")), ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text("Xóa"), style: ElevatedButton.styleFrom(backgroundColor: AppColors.chartRed, foregroundColor: Colors.white))]));
                                              if (confirm == true) {
                                                await ExpenseManager.deleteFixedExpenseRule(
                                                  appState: appState,
                                                  ruleToDelete: expenseData,
                                                );

                                                // <<< SỬA LỖI 3: CẬP NHẬT GIAO DIỆN TỨC THÌ KHI XÓA >>>
                                                setStateDialog(() {
                                                  _expensesData!.removeWhere((exp) => exp['name'] == name);
                                                });

                                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Đã xóa '$name'."), backgroundColor: AppColors.chartRed, behavior: SnackBarBehavior.floating));
                                              }
                                            } : null,
                                          )
                                        ])
                                      ])
                                  )
                              );
                            }
                        )
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            );
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            titlePadding: const EdgeInsets.fromLTRB(20, 20, 12, 10),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(DateFormat('MMMM y', 'vi').format(_currentDialogMonth), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.getTextColor(context))),
                IconButton(
                  icon: Icon(Icons.calendar_month_outlined, color: AppColors.chartRed),
                  onPressed: () async {
                    final DateTime? pickedMonth = await showMonthPicker(context: dialogContext, initialDate: _currentDialogMonth, firstDate: DateTime(2020), lastDate: DateTime(2030));
                    if (pickedMonth != null && pickedMonth != _currentDialogMonth) {
                      _currentDialogMonth = pickedMonth;
                      // Chỉ tải lại toàn bộ khi đổi tháng
                      _fetchDataForMonth(_currentDialogMonth, setStateDialog);
                    }
                  },
                  splashRadius: 22,
                ),
              ],
            ),
            contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            content: buildContent(),
            actionsAlignment: MainAxisAlignment.end,
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogMainContext),
                child: Text("Đóng", style: TextStyle(color: AppColors.chartRed, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ],
          );
        },
      ),
    ).then((_) {
      _isMounted = false;
      _isDialogOpen = false;
      if (mounted) {
        _resetAnimation();
        _runAnimation();
      }
    });
  }

  // Thêm 2 hàm này vào trong class _ExpenseScreenState

  /// Hàm xử lý và nhóm các chi phí biến đổi.
  List<dynamic> _groupVariableExpenses(List<Map<String, dynamic>> expenses) {
    final Map<String, List<Map<String, dynamic>>> groupedExpenses = {};
    final List<Map<String, dynamic>> manualExpenses = [];

    for (final expense in expenses) {
      final String? transactionId = expense['sourceSalesTransactionId'] as String?;
      if (transactionId != null) {
        if (groupedExpenses[transactionId] == null) {
          groupedExpenses[transactionId] = [];
        }
        groupedExpenses[transactionId]!.add(expense);
      } else {
        manualExpenses.add(expense);
      }
    }

    final List<dynamic> displayList = [];

    // Xử lý và thêm các nhóm
    groupedExpenses.forEach((transactionId, items) {
      if (items.isNotEmpty) {
        String productName = "Sản phẩm không xác định";
        final String firstItemName = items.first['name'] as String? ?? '';
        RegExp regExp = RegExp(r"\((?:Cho|Cho DTP): (.*?)\)");
        var match = regExp.firstMatch(firstItemName);
        if (match != null && match.groupCount >= 1) {
          productName = match.group(1)!;
        } else {
          regExp = RegExp(r":\s*(.*)$");
          match = regExp.firstMatch(firstItemName);
          if (match != null && match.groupCount >= 1) {
            productName = match.group(1)!.trim();
          }
        }

        displayList.add({
          'isGroup': true,
          'groupTitle': "Giá vốn cho: $productName",
          'items': items,
          'totalAmount': items.fold(0.0, (sum, item) => sum + (item['amount'] as num? ?? 0.0)),
          // Lấy ngày của mục đầu tiên làm đại diện để sắp xếp
          'date': items.first['date'],
        });
      }
    });

    // Thêm các chi phí thủ công
    displayList.addAll(manualExpenses);

    // Sắp xếp lại danh sách: mới nhất lên đầu
    displayList.sort((a, b) {
      DateTime dateA = DateTime.tryParse(a['date'] ?? '') ?? DateTime(1900);
      DateTime dateB = DateTime.tryParse(b['date'] ?? '') ?? DateTime(1900);
      return dateB.compareTo(dateA);
    });

    return displayList;
  }

  /// Widget để render một card cho cả nhóm chi phí COGS
  Widget _buildGroupedExpenseCard(Map<String, dynamic> group) {
    final String title = group['groupTitle'];
    final double totalAmount = group['totalAmount'];
    final List<Map<String, dynamic>> items = group['items'];

    return Card(
      elevation: 1.5,
      margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: AppColors.getCardColor(context),
      child: ExpansionTile(
        leading: Container(
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: Colors.orange.shade700.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(
            Icons.link, // Icon riêng cho nhóm giá vốn
            color: Colors.orange.shade700,
            size: 24,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: AppColors.getTextColor(context),
          ),
        ),
        subtitle: Text(
          'Tổng: ${currencyFormat.format(totalAmount)}',
          style: TextStyle(
              fontSize: 14,
              color: AppColors.getTextSecondaryColor(context).withOpacity(0.9),
              fontWeight: FontWeight.w500),
        ),
        childrenPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8).copyWith(left: 70),
        children: items.map((expense) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  expense['name'] ?? 'Không có tên',
                  style: TextStyle(fontSize: 14, color: AppColors.getTextColor(context)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: 10),
              Text(
                currencyFormat.format((expense['amount'] as num?)?.toDouble() ?? 0.0),
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.getTextSecondaryColor(context)),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }


  // THAY THẾ HÀM removeExpense BẰNG PHIÊN BẢN NÀY


  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final appState = context.read<AppState>();
    final bool canManageWallets = appState.hasPermission('canManageWallets');

    // This callback ensures animations run after the first frame is built and data is ready.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (appState.dataReadyListenable.value && mounted && !_hasAnimated) {
        _runAnimation();
      }
    });

    return Scaffold(
      backgroundColor: AppColors.getBackgroundColor(context),
      floatingActionButton: ValueListenableBuilder<int>(
        valueListenable: appState.permissionVersion,
        builder: (context, version, child) {
          final bool canManageWallets = appState.hasPermission('canManageWallets');
          return canManageWallets
              ? FloatingActionButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const WalletManagementScreen()),
              );
            },
            backgroundColor: AppColors.chartRed,
            tooltip: 'Quản lý Ví tiền',
            child: const Icon(Icons.wallet_outlined, color: Colors.white),
          )
              : const SizedBox.shrink(); // <-- SỬA Ở ĐÂY: Thay thế null bằng SizedBox.shrink()
        },
      ),
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(user, appState),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 20.0, bottom: 10),
              child: _buildTotalExpenseSection(appState),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
              child: ValueListenableBuilder<int>(
                valueListenable: appState.permissionVersion,
                builder: (context, version, child) {
                  final canManageFixed = appState.hasPermission('canManageFixedExpenses');
                  final canManageVariable = appState.hasPermission('canManageVariableExpenses');
                  final canManageOther = appState.hasPermission('canManageOtherExpenses');

                  return _buildNavigationActions(
                    canManageFixed: canManageFixed,
                    canManageVariable: canManageVariable,
                    canManageOther: canManageOther,
                  );
                },
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
              child: _buildExpenseCategorySelector(context, appState),
            ),
          ),
          _buildExpenseList(appState),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(User? user, AppState appState) {
    return SliverAppBar(
      expandedHeight: 120.0,
      floating: false,
      pinned: true,
      elevation: 2,
      backgroundColor: Colors.transparent, // Make it transparent to show gradient
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.chartRed.withOpacity(0.95), AppColors.chartRed.withOpacity(0.75)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 10, // Adjust for status bar
                left: 16, right: 16, bottom: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Flexible(
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          if (!mounted) return;
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => UserSettingsScreen()),
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withOpacity(0.8), width: 2.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: CircleAvatar(
                            radius: 26,
                            backgroundColor: Colors.white, // Fallback color
                            backgroundImage: user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
                            child: user?.photoURL == null
                                ? Icon(Icons.person_outline, size: 32, color: Colors.grey.shade700) // Changed to a more visible color
                                : null,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // WIDGET MỚI ĐẶT Ở ĐÂY
                            AccountSwitcher(),

                            // Giữ nguyên phần hiển thị ngày
                            const SizedBox(height: 4),
                            ValueListenableBuilder<DateTime>(
                              valueListenable: appState.selectedDateListenable,
                              builder: (context, selectedDate, _) => Text(
                                "Ngày ${DateFormat('dd MMMM, yyyy', 'vi').format(selectedDate)}",
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: Colors.white.withOpacity(0.9),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.calendar_month_outlined, color: Colors.white, size: 28),
                  onPressed: () => _selectDate(context),
                  splashRadius: 24,
                  tooltip: "Chọn ngày",
                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40), // Ensure tappable area
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // THAY THẾ TOÀN BỘ HÀM _buildTotalExpenseSection BẰNG PHIÊN BẢN NÀY
  Widget _buildTotalExpenseSection(AppState appState) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.getCardColor(context),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.15),
            spreadRadius: 2,
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.trending_down_rounded, color: AppColors.chartRed, size: 24),
              SizedBox(width: 10),
              Text(
                'Tổng chi phí ngày',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: AppColors.getTextSecondaryColor(context),
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          // SỬA ĐỔI CỐT LÕI NẰM Ở ĐÂY
          // Lắng nghe cả hai sự thay đổi của chi phí cố định và biến đổi
          ValueListenableBuilder<double>(
            valueListenable: appState.fixedExpenseListenable,
            builder: (context, fixedDailyExpense, _) {
              return ValueListenableBuilder<List<Map<String, dynamic>>>(
                valueListenable: appState.variableExpenseList,
                builder: (context, variableExpenses, __) {
                  // <<< LỒNG THÊM VALUE LISTENABLE BUILDER CHO CHI PHÍ KHÁC >>>
                  return ValueListenableBuilder<List<Map<String, dynamic>>>(
                    valueListenable: appState.otherExpenseTransactions,
                    builder: (context, otherExpenses, ___) {
                      final variableTotal = variableExpenses.fold(0.0, (sum, e) => sum + (e['amount'] ?? 0.0));
                      final otherTotal = otherExpenses.fold(0.0, (sum, e) => sum + (e['amount'] ?? 0.0));
                      final totalDailyExpense = fixedDailyExpense + variableTotal + otherTotal;

                      return Text(
                        currencyFormat.format(totalDailyExpense),
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                          color: AppColors.chartRed,
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationActions({
    required bool canManageFixed,
    required bool canManageVariable,
    required bool canManageOther,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildModernNavigationIcon(
          icon: Icons.account_balance_wallet_outlined,
          label: 'Cố định',
          isEnabled: canManageFixed,
          onTap: canManageFixed ? () => _navigateToEditExpense('Cố định ngày') : null,
        ),
        _buildModernNavigationIcon(
          icon: Icons.transform_outlined,
          label: 'Biến đổi',
          isEnabled: canManageVariable, // <-- CẬP NHẬT Ở ĐÂY
          onTap: canManageVariable ? () => _navigateToEditExpense('Biến đổi ngày') : null, // <-- CẬP NHẬT Ở ĐÂY
        ),
        _buildModernNavigationIcon(
          icon: Icons.receipt_long_outlined,
          label: 'Khác',
          isEnabled: canManageOther,
          onTap: canManageOther ? () => _navigateToEditExpense('Khác') : null,
        ),
        _buildModernNavigationIcon(
          icon: Icons.calendar_month_outlined,
          label: 'CĐ Tháng',
          isEnabled: canManageFixed,
          onTap: canManageFixed ? () => _navigateToEditExpense('Cố định tháng') : null,
        ),
      ],
    );
  }

  Widget _buildModernNavigationIcon({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    bool isEnabled = true, // Thêm biến này
  }) {
    // Xác định màu sắc dựa trên trạng thái
    final color = isEnabled ? AppColors.chartRed : Colors.grey.shade400;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap, // onTap sẽ là null nếu bị vô hiệu hóa
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isEnabled ? AppColors.getCardColor(context) : AppColors.getCardColor(context).withOpacity(0.6),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: isEnabled ? Colors.grey.withOpacity(0.1) : Colors.transparent,
                  spreadRadius: 1,
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              icon,
              size: 28,
              color: color, // Sử dụng màu đã xác định
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: isEnabled ? AppColors.getTextSecondaryColor(context) : Colors.grey.shade400,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  ValueNotifier<List<Map<String, dynamic>>> _getExpenseListenable(AppState appState) {
    switch (selectedExpenseCategory) {
      case 'Chi phí cố định':
        return appState.fixedExpenseList;
      case 'Chi phí biến đổi':
        return appState.variableExpenseList;
      case 'Chi phí khác':
        return appState.otherExpenseTransactions;
      default:
        return appState.fixedExpenseList;
    }
  }

  Widget _buildExpenseCategorySelector(BuildContext context, AppState appState) {
    return GestureDetector(
      onTap: () => _showExpenseCategoryBottomSheet(context),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
        decoration: BoxDecoration(
          color: AppColors.getCardColor(context),
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  selectedExpenseCategory,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppColors.getTextColor(context),
                  ),
                ),
                SizedBox(height: 4),
                ValueListenableBuilder<List<Map<String, dynamic>>>(
                  valueListenable: selectedExpenseCategory == 'Chi phí cố định'
                      ? appState.fixedExpenseList // Ensure this is the list of fixed expense *items*
                      : appState.variableExpenseList, // Ensure this is the list of variable expense *items*
                  builder: (context, expenses, _) => Text(
                    'Tổng mục: ${currencyFormat.format(_calculateTotal(expenses))}',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.chartRed,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppColors.getTextSecondaryColor(context),
              size: 28,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpenseList(AppState appState) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80), // Padding for the list
      sliver: ValueListenableBuilder<List<Map<String, dynamic>>>(
        valueListenable: _getExpenseListenable(appState),
        builder: (context, expenses, _) {
          if (expenses.isEmpty) {
            return SliverFillRemaining(
              hasScrollBody: false,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long_outlined, size: 60, color: Colors.grey.shade400),
                      SizedBox(height: 16),
                      Text(
                        'Không có chi phí nào',
                        style: TextStyle(fontSize: 17, color: AppColors.getTextSecondaryColor(context)),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Thêm chi phí mới để theo dõi.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          final bool isVariableCategory = selectedExpenseCategory == 'Chi phí biến đổi';
          final List<dynamic> displayItems = isVariableCategory ? _groupVariableExpenses(expenses) : expenses;

          return SliverList(
            delegate: SliverChildBuilderDelegate(
                  (context, index) {
                final item = displayItems[index];
                if (isVariableCategory && item is Map && item['isGroup'] == true) {
                  return FadeTransition(
                    opacity: _fadeAnimation,
                    child: _buildGroupedExpenseCard(item as Map<String, dynamic>),
                  );
                }

                final expense = item as Map<String, dynamic>;
                bool isAutoCogs = expense['sourceSalesTransactionId'] != null;

                IconData expenseItemIcon;
                Color iconColorInList;

                // <<< LOGIC CHỌN ICON VÀ MÀU SẮC ĐÃ ĐƯỢC CẬP NHẬT >>>
                switch (selectedExpenseCategory) {
                  case 'Chi phí cố định':
                    expenseItemIcon = Icons.shield_outlined;
                    iconColorInList = AppColors.primaryBlue.withOpacity(0.8);
                    break;
                  case 'Chi phí biến đổi':
                    expenseItemIcon = Icons.local_fire_department_outlined;
                    iconColorInList = Colors.orange.shade700;
                    break;
                  case 'Chi phí khác':
                    expenseItemIcon = Icons.receipt_long_outlined;
                    iconColorInList = Colors.teal.shade600;
                    break;
                  default:
                    expenseItemIcon = Icons.help_outline;
                    iconColorInList = Colors.grey;
                }

                final originalIndex = expenses.indexOf(expense);

                return ValueListenableBuilder<int>(
                  valueListenable: appState.permissionVersion,
                  builder: (context, permissionVersion, child) {
                    final bool isCreator = (expense['createdBy'] ?? "") == appState.authUserId;

                    // Xác định quyền chung dựa trên loại chi phí được chọn
                    bool hasGeneralPermission;
                    switch (selectedExpenseCategory) {
                      case 'Chi phí cố định':
                        hasGeneralPermission = appState.hasPermission('canManageFixedExpenses');
                        break;
                      case 'Chi phí biến đổi':
                      case 'Chi phí khác': // Chi phí khác dùng chung quyền với chi phí biến đổi
                        hasGeneralPermission = appState.hasPermission('canManageVariableExpenses');
                        break;
                      default:
                        hasGeneralPermission = false;
                    }

                    final bool canModifyThisRecord = appState.isOwner() || (hasGeneralPermission && isCreator);

                    return FadeTransition(
                      opacity: _fadeAnimation,
                      child: Slidable(
                        key: Key(expense['id']?.toString() ?? expense['name']?.toString() ?? UniqueKey().toString()),
                        endActionPane: isAutoCogs
                            ? ActionPane(
                          motion: const StretchMotion(),
                          children: [
                            SlidableAction(
                              onPressed: (context) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Đây là giá vốn tự động, quản lý qua giao dịch doanh thu.'),
                                    backgroundColor: AppColors.getTextSecondaryColor(context),
                                  ),
                                );
                              },
                              backgroundColor: Colors.grey.shade300,
                              foregroundColor: AppColors.getTextColor(context),
                              icon: Icons.info_outline,
                              label: 'Chi tiết',
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ],
                        )
                            : (canModifyThisRecord
                            ? ActionPane(
                          motion: const StretchMotion(),
                          children: [
                            SlidableAction(
                              onPressed: (context) {
                                if (originalIndex != -1) {
                                  editExpense(appState, originalIndex, selectedExpenseCategory);
                                }
                              },
                              backgroundColor: AppColors.primaryBlue,
                              foregroundColor: Colors.white,
                              icon: Icons.edit_outlined,
                              label: 'Sửa',
                              borderRadius: BorderRadius.circular(12),
                            ),
                            SlidableAction(
                              onPressed: (context) async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (dialogCtx) => AlertDialog(
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                    title: Text('Xác nhận xóa', style: TextStyle(color: AppColors.getTextColor(context), fontWeight: FontWeight.bold)),
                                    content: Text('Bạn có chắc chắn muốn xóa chi phí "${expense['name']}" không?', style: TextStyle(color: AppColors.getTextSecondaryColor(context))),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(dialogCtx, false),
                                        child: Text('Hủy', style: TextStyle(color: AppColors.getTextSecondaryColor(context))),
                                      ),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.chartRed,
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                                        onPressed: () => Navigator.pop(dialogCtx, true),
                                        child: Text('Xóa'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  if (originalIndex != -1) {
                                    removeExpense(appState, originalIndex, selectedExpenseCategory);
                                  }
                                }
                              },
                              backgroundColor: AppColors.chartRed.withOpacity(0.9),
                              foregroundColor: Colors.white,
                              icon: Icons.delete_outline,
                              label: 'Xóa',
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ],
                        )
                            : null),
                        child: Card(
                          elevation: 1.5,
                          margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 0),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          color: AppColors.getCardColor(context),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            leading: Container(
                              padding: EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                  color: iconColorInList.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10)),
                              child: Icon(
                                expenseItemIcon,
                                color: iconColorInList,
                                size: 24,
                              ),
                            ),
                            title: Text(
                              expense['name']?.toString() ?? 'Không xác định',
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: AppColors.getTextColor(context)),
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${currencyFormat.format(expense['amount'] ?? 0.0)}',
                              style: TextStyle(fontSize: 14, color: AppColors.getTextSecondaryColor(context).withOpacity(0.9), fontWeight: FontWeight.w500),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
              childCount: displayItems.length,
            ),
          );
        },
      ),
    );
  }
}

class ExpenseCategoryItem extends StatelessWidget {
  final String title;
  final double amount;
  final IconData icon;
  final VoidCallback onTap;
  final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'VNĐ');

  ExpenseCategoryItem({required this.title, required this.amount, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // Using the same color constants from _ExpenseScreenState for consistency

    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 1.5,
        margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 2), // Consistent margin
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), // Consistent shape
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), // Consistent padding
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(10), // Consistent padding
                    decoration: BoxDecoration(
                        color: AppColors.chartRed.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10) // Consistent styling
                    ),
                    child: Icon(icon, size: 24, color: AppColors.chartRed), // Consistent icon styling
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.getTextColor(context)), // Consistent text styling
                      ),
                      const SizedBox(height: 5),
                      Text(
                        currencyFormat.format(amount),
                        style: TextStyle(
                          fontSize: 16.5, // Consistent text styling
                          fontWeight: FontWeight.bold,
                          color: AppColors.chartRed,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ],
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey.shade500), // Consistent trailing icon
            ],
          ),
        ),
      ),
    );
  }
}