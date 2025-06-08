import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:month_picker_dialog/month_picker_dialog.dart';
// Assuming these are your existing imports
import '../state/app_state.dart';
import '/screens/expense_manager.dart';
// Ensure this path is correct
import 'update_expense_list_screen.dart';
import 'edit_fixed_expense_screen.dart';
import 'edit_variable_expense_screen.dart';
import 'user_setting_screen.dart';

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

  // Modern color palette for Expense Screen
  static const Color _headerColor = Color(0xFFE53935); // Distinct Red for Expense AppBar
  static const Color _accentColor = Color(0xFFD32F2F); // Deep Red for expense amounts and key elements
  static const Color _secondaryColor = Color(0xFFF0F4F8); // Light background (Consistent with Revenue)
  static const Color _textColorPrimary = Color(0xFF1D2D3A); // Dark text (Consistent)
  static const Color _textColorSecondary = Color(0xFF6E7A8A); // Lighter text (Consistent)
  static const Color _cardBackgroundColor = Colors.white; // Card background (Consistent)
  static const Color _buttonPrimaryColor = Color(0xFF0A7AFF); // Blue for general primary buttons if not expense-specific

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
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: _headerColor,
              onPrimary: Colors.white,
              onSurface: _textColorPrimary,
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != appState.selectedDate) {
      appState.setSelectedDate(picked);
      _resetAnimation(); // Reset animation for new data
    }
  }

  void _navigateToEditExpense(String category) async {
    final appState = Provider.of<AppState>(context, listen: false);
    if (category == 'Cố định tháng') {
      await _showMonthlyFixedExpenseDialog(appState);
      if (mounted) {
        _resetAnimation();
        _runAnimation();
      }
    } else {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => category == 'Cố định ngày'
              ? const EditFixedExpenseScreen()
              : category == 'Biến đổi ngày'
              ? const EditVariableExpenseScreen()
              : UpdateExpenseListScreen(category: 'Chi phí biến đổi'),
        ),
      );
    }
  }

  double _calculateTotal(List<Map<String, dynamic>> expenses) {
    return expenses.fold(0.0, (sum, expense) => sum + (expense['amount'] ?? 0.0));
  }

  void _showExpenseCategoryBottomSheet(BuildContext context) {
    final categories = [
      'Chi phí cố định',
      'Chi phí biến đổi'
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          decoration: BoxDecoration(
              color: _cardBackgroundColor,
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
                    color: _textColorPrimary,
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
                      color: isSelected ? _headerColor : _textColorPrimary,
                    ),
                  ),
                  trailing: isSelected
                      ? Icon(Icons.check_circle, color: _headerColor)
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
                  tileColor: isSelected ? _headerColor.withOpacity(0.1) : Colors.transparent,
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
        labelStyle: TextStyle(color: _textColorSecondary.withOpacity(0.9)),
        prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: _headerColor.withOpacity(0.7), size: 20) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _headerColor, width: 2),
        ),
        contentPadding: isDense ? EdgeInsets.symmetric(horizontal: 12, vertical: 10) : EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Future<void> _showMonthlyFixedExpenseDialog(AppState appState) async {
    if (_isDialogOpen) return;
    _isDialogOpen = true;
    DateTime _currentDialogMonth = appState.selectedDate;
    DateTimeRange? _currentDialogDateRange = null;
    final TextEditingController _newExpenseNameController = TextEditingController();

    return showDialog<void>(
      context: context,
      builder: (dialogMainContext) => StatefulBuilder(
        builder: (dialogContext, setStateDialog) {
          return FutureBuilder<Map<String, dynamic>>(
            key: ValueKey(_currentDialogMonth.toIso8601String()),
            future: Future.wait([
              ExpenseManager.loadFixedExpenseList(appState, _currentDialogMonth),
              ExpenseManager.loadMonthlyFixedAmounts(appState, _currentDialogMonth),
            ]).then((results) => {
              'fixedExpenses': results[0],
              'monthlyAmounts': results[1],
            }).catchError((e) async {
              print('Error loading monthly fixed expenses: $e, StackTrace: ${StackTrace.current}');
              // Tải từ Hive nếu Firestore lỗi
              final String monthKey = DateFormat('yyyy-MM').format(_currentDialogMonth);
              final String hiveFixedListKey = '${appState.userId}-fixedExpenseList-$monthKey';
              final String hiveAmountsKey = '${appState.userId}-monthlyFixedAmounts-$monthKey';
              final monthlyFixedExpensesBox = Hive.box('monthlyFixedExpensesBox');
              final monthlyFixedAmountsBox = Hive.box('monthlyFixedAmountsBox');

              // Lấy dữ liệu thô từ Hive
              var rawFixedExpenses = monthlyFixedExpensesBox.get(hiveFixedListKey);
              var rawMonthlyAmounts = monthlyFixedAmountsBox.get(hiveAmountsKey);

              // Chuẩn bị danh sách và map đã ép kiểu
              List<Map<String, dynamic>> castedFixedExpenses = [];
              Map<String, double> castedMonthlyAmounts = {};

              // Ép kiểu cho fixedExpenses
              if (rawFixedExpenses != null && rawFixedExpenses is List) {
                for (var item in rawFixedExpenses) {
                  if (item is Map) {
                    castedFixedExpenses.add(
                        Map<String, dynamic>.fromEntries(
                            item.entries.map((entry) => MapEntry(entry.key.toString(), entry.value))
                        )
                    );
                  }
                }
              }

              // Ép kiểu cho monthlyAmounts
              if (rawMonthlyAmounts != null && rawMonthlyAmounts is Map) {
                rawMonthlyAmounts.forEach((key, value) {
                  double valAsDouble = 0.0;
                  if (value is num) {
                    valAsDouble = value.toDouble();
                  } else if (value is String) {
                    valAsDouble = double.tryParse(value) ?? 0.0;
                  }
                  castedMonthlyAmounts[key.toString()] = valAsDouble;
                });
              }

              return {
                'fixedExpenses': castedFixedExpenses,
                'monthlyAmounts': castedMonthlyAmounts,
              };
            }),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  content: Container(
                    height: 120,
                    child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: _headerColor),
                            SizedBox(height: 20),
                            Text("Đang tải...", style: TextStyle(color: _textColorSecondary))
                          ],
                        )),
                  ),
                );
              }
              if (snapshot.hasError) {
                return AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  title: Row(
                      children: [
                        Icon(Icons.error_outline, color: _accentColor),
                        SizedBox(width: 10),
                        Text("Lỗi")
                      ]),
                  content: Text("Có lỗi xảy ra khi tải dữ liệu.\nVui lòng thử lại.",
                      style: TextStyle(color: _textColorPrimary)),
                  actions: [
                    TextButton(
                        onPressed: () {
                          Navigator.pop(dialogContext);
                        },
                        child: Text("Đóng", style: TextStyle(color: _headerColor)))
                  ],
                );
              }

              if (snapshot.hasData) {
                List<Map<String, dynamic>> fixedExpensesFromManager =
                List<Map<String, dynamic>>.from(snapshot.data!['fixedExpenses'] ?? []);
                Map<String, double> savedMonthlyAmountsFromManager =
                Map<String, double>.from(snapshot.data!['monthlyAmounts'] ?? {});
                List<TextEditingController> monthlyAmountControllers = List.generate(
                  fixedExpensesFromManager.length,
                      (index) {
                    final name = fixedExpensesFromManager[index]['name'];
                    final controller = TextEditingController();
                    if (savedMonthlyAmountsFromManager.containsKey(name)) {
                      controller.text = savedMonthlyAmountsFromManager[name]?.toString() ?? '';
                    }
                    return controller;
                  },
                );

                final daysInSelectedMonth =
                    DateTime(_currentDialogMonth.year, _currentDialogMonth.month + 1, 0).day;

                return AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  titlePadding: const EdgeInsets.fromLTRB(20, 20, 12, 10),
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        DateFormat('MMMM y', 'vi').format(_currentDialogMonth),
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 18, color: _textColorPrimary),
                      ),
                      IconButton(
                        icon: Icon(Icons.calendar_month_outlined, color: _headerColor),
                        onPressed: () async {
                          final DateTime? pickedMonth = await showMonthPicker(
                            context: dialogContext,
                            initialDate: _currentDialogMonth,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (pickedMonth != null) {
                            setStateDialog(() {
                              _currentDialogMonth = pickedMonth;
                              _currentDialogDateRange = null;
                            });
                          }
                        },
                        splashRadius: 22,
                      ),
                    ],
                  ),
                  contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  content: SizedBox(
                    width: double.maxFinite,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 10),
                          Text("Phân bổ chi phí cho các ngày:",
                              style: TextStyle(
                                  color: _textColorSecondary,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w500)),
                          SizedBox(height: 6),
                          GestureDetector(
                            onTap: () async {
                              final DateTimeRange? pickedDateRange = await showDateRangePicker(
                                context: dialogContext,
                                initialDateRange: _currentDialogDateRange ??
                                    DateTimeRange(
                                      start: DateTime(
                                          _currentDialogMonth.year, _currentDialogMonth.month, 1),
                                      end: DateTime(_currentDialogMonth.year,
                                          _currentDialogMonth.month, daysInSelectedMonth),
                                    ),
                                firstDate:
                                DateTime(_currentDialogMonth.year, _currentDialogMonth.month, 1),
                                lastDate: DateTime(_currentDialogMonth.year,
                                    _currentDialogMonth.month, daysInSelectedMonth),
                                builder: (context, child) {
                                  return Theme(
                                    data: ThemeData.light().copyWith(
                                      colorScheme: ColorScheme.light(
                                        primary: _headerColor,
                                        onPrimary: Colors.white,
                                        surface: _cardBackgroundColor,
                                        onSurface: _textColorPrimary,
                                      ),
                                      dialogBackgroundColor: _cardBackgroundColor,
                                      textButtonTheme: TextButtonThemeData(
                                          style: TextButton.styleFrom(
                                              foregroundColor: _headerColor)),
                                    ),
                                    child: child!,
                                  );
                                },
                              );
                              if (pickedDateRange != null) {
                                setStateDialog(() => _currentDialogDateRange = pickedDateRange);
                              }
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade400),
                                  borderRadius: BorderRadius.circular(12)),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _currentDialogDateRange == null
                                        ? "Cả tháng (${DateFormat('MM/yyyy', 'vi').format(_currentDialogMonth)})"
                                        : "${DateFormat('dd/MM/yy', 'vi').format(_currentDialogDateRange!.start)} - ${DateFormat('dd/MM/yy', 'vi').format(_currentDialogDateRange!.end)}",
                                    style:
                                    TextStyle(fontSize: 14.5, color: _textColorPrimary),
                                  ),
                                  Icon(Icons.date_range_outlined,
                                      color: _headerColor, size: 20),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(height: 16),
                          Text("Thêm chi phí cố định mới vào danh sách tháng:",
                              style: TextStyle(
                                  color: _textColorSecondary,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w500)),
                          SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: _buildModernDialogTextField(
                                    controller: _newExpenseNameController,
                                    labelText: "Tên khoản chi",
                                    prefixIcon: Icons.add_shopping_cart_outlined),
                              ),
                              SizedBox(width: 8),
                              IconButton(
                                icon: Icon(Icons.add_circle, color: _headerColor, size: 30),
                                onPressed: () async {
                                  if (_newExpenseNameController.text.isNotEmpty) {
                                    final newExpenseName = _newExpenseNameController.text;
                                    if (fixedExpensesFromManager.any((exp) => exp['name'] == newExpenseName)) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text("Khoản chi '$newExpenseName' đã tồn tại trong danh sách tháng."),
                                          backgroundColor: Colors.orangeAccent,
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                      return;
                                    }
                                    showDialog(
                                      context: dialogContext,
                                      barrierDismissible: false,
                                      builder: (ctx) => AlertDialog(
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                        content: Row(
                                          children: [
                                            CircularProgressIndicator(color: _headerColor),
                                            SizedBox(width: 15),
                                            Text("Đang thêm...")
                                          ],
                                        ),
                                      ),
                                    );
                                    try {
                                      fixedExpensesFromManager.add({'name': newExpenseName});
                                      monthlyAmountControllers.add(TextEditingController());
                                      await ExpenseManager.saveFixedExpenseList(appState, fixedExpensesFromManager, _currentDialogMonth);
                                      _newExpenseNameController.clear();
                                      Navigator.pop(dialogContext); // Close loading indicator
                                      setStateDialog(() {});
                                      Future.microtask(() {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text("Đã thêm '$newExpenseName' vào danh sách tháng."),
                                            backgroundColor: Colors.green,
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      });
                                    } catch (e) {
                                      Navigator.pop(dialogContext); // Close loading indicator
                                      Future.microtask(() {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text("Lỗi khi thêm: $e"),
                                            backgroundColor: Colors.redAccent,
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      });
                                    }
                                  }
                                },
                                tooltip: "Thêm vào danh sách chi phí của tháng",
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Text("Danh sách chi phí và số tiền tháng:",
                              style: TextStyle(
                                  color: _textColorSecondary,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w500)),
                          SizedBox(height: 6),
                          fixedExpensesFromManager.isEmpty
                              ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20.0),
                            child: Center(
                                child: Text(
                                    "Chưa có mục chi phí cố định nào được định nghĩa cho tháng này.",
                                    style: TextStyle(
                                        color: _textColorSecondary,
                                        fontStyle: FontStyle.italic))),
                          )
                              : Container(
                            constraints: BoxConstraints(maxHeight: 200),
                            decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300)),
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: fixedExpensesFromManager.length,
                              itemBuilder: (lvContext, index) {
                                final expenseMap = fixedExpensesFromManager[index];
                                final name = expenseMap['name'] as String;
                                final currentSavedAmount =
                                    savedMonthlyAmountsFromManager[name] ?? 0.0;
                                bool isEditingThisAmount = !(currentSavedAmount > 0);

                                if (isEditingThisAmount &&
                                    monthlyAmountControllers[index].text.isEmpty &&
                                    currentSavedAmount > 0) {
                                  monthlyAmountControllers[index].text =
                                      currentSavedAmount.toString();
                                }

                                return Card(
                                  elevation: 1.0,
                                  margin: const EdgeInsets.symmetric(
                                      vertical: 5, horizontal: 2),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                  child: Padding(
                                    padding: const EdgeInsets.only(
                                        left: 14.0, right: 6, top: 10, bottom: 10),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                name,
                                                style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
                                                    color: _textColorPrimary),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 6),
                                              !isEditingThisAmount
                                                  ? Text(
                                                currencyFormat
                                                    .format(currentSavedAmount),
                                                style: TextStyle(
                                                    fontSize: 16.5,
                                                    fontWeight: FontWeight.bold,
                                                    color: _headerColor),
                                                overflow: TextOverflow.ellipsis,
                                              )
                                                  : Row(
                                                children: [
                                                  Expanded(
                                                    child:
                                                    _buildModernDialogTextField(
                                                      controller:
                                                      monthlyAmountControllers[
                                                      index],
                                                      labelText: "Số tiền",
                                                      keyboardType:
                                                      TextInputType.number,
                                                      isDense: true,
                                                    ),
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(Icons.check_circle, color: Colors.green, size: 28),
                                                    onPressed: () async {
                                                      final amount = double.tryParse(monthlyAmountControllers[index].text) ?? 0.0;
                                                      if (amount > 0) {
                                                        DateTimeRange? rangeToSave = _currentDialogDateRange;
                                                        if (rangeToSave == null) {
                                                          final defaultRangeStart = DateTime(_currentDialogMonth.year, _currentDialogMonth.month, 1);
                                                          final defaultRangeEnd = DateTime(_currentDialogMonth.year, _currentDialogMonth.month, DateTime(_currentDialogMonth.year, _currentDialogMonth.month + 1, 0).day);
                                                          rangeToSave = DateTimeRange(start: defaultRangeStart, end: defaultRangeEnd);
                                                          Future.microtask(() {
                                                            ScaffoldMessenger.of(context).showSnackBar(
                                                              SnackBar(
                                                                content: Text("Áp dụng cho cả tháng (${DateFormat('MM/yyyy').format(_currentDialogMonth)}). Bạn có thể chọn lại khoảng thời gian."),
                                                                backgroundColor: _buttonPrimaryColor,
                                                                duration: Duration(seconds: 4),
                                                                behavior: SnackBarBehavior.floating,
                                                              ),
                                                            );
                                                          });
                                                        }
                                                        showDialog(
                                                          context: dialogContext,
                                                          barrierDismissible: false,
                                                          builder: (ctx) => AlertDialog(
                                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                                            content: Row(
                                                              children: [
                                                                CircularProgressIndicator(color: _headerColor),
                                                                SizedBox(width: 15),
                                                                Text("Đang lưu...")
                                                              ],
                                                            ),
                                                          ),
                                                        );
                                                        try {
                                                          await ExpenseManager.saveMonthlyFixedAmount(appState, name, amount, _currentDialogMonth, dateRange: rangeToSave);
                                                          Navigator.pop(dialogContext); // Close loading
                                                          savedMonthlyAmountsFromManager[name] = amount;
                                                          await appState.loadExpenseValues();
                                                          if (mounted) setState(() {});
                                                          setStateDialog(() {});
                                                          Future.microtask(() {
                                                            ScaffoldMessenger.of(context).showSnackBar(
                                                              SnackBar(
                                                                content: Text("Đã lưu số tiền cho '$name'."),
                                                                backgroundColor: Colors.green,
                                                                behavior: SnackBarBehavior.floating,
                                                              ),
                                                            );
                                                          });
                                                        } catch (e) {
                                                          Navigator.pop(dialogContext); // Close loading
                                                          Future.microtask(() {
                                                            ScaffoldMessenger.of(context).showSnackBar(
                                                              SnackBar(
                                                                content: Text("Lỗi khi lưu: $e"),
                                                                backgroundColor: Colors.redAccent,
                                                                behavior: SnackBarBehavior.floating,
                                                              ),
                                                            );
                                                          });
                                                        }
                                                      } else {
                                                        Future.microtask(() {
                                                          ScaffoldMessenger.of(context).showSnackBar(
                                                            SnackBar(
                                                              content: Text("Số tiền không hợp lệ."),
                                                              backgroundColor: Colors.orangeAccent,
                                                              behavior: SnackBarBehavior.floating,
                                                            ),
                                                          );
                                                        });
                                                      }
                                                    },
                                                    tooltip: "Lưu số tiền và phân bổ",
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (!isEditingThisAmount)
                                              IconButton(
                                                icon: Icon(Icons.edit, color: _buttonPrimaryColor, size: 22),
                                                tooltip: "Chỉnh sửa số tiền tháng",
                                                onPressed: () async {
                                                  TextEditingController editAmountController = TextEditingController(
                                                    text: savedMonthlyAmountsFromManager[name]?.toString() ?? '',
                                                  );
                                                  bool? saved = await showDialog<bool>(
                                                    context: dialogContext,
                                                    builder: (ctx) => AlertDialog(
                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                                      title: Text("Chỉnh sửa: $name",
                                                          style: TextStyle(color: _textColorPrimary, fontWeight: FontWeight.bold)),
                                                      content: _buildModernDialogTextField(
                                                        controller: editAmountController,
                                                        labelText: "Số tiền (VNĐ)",
                                                        keyboardType: TextInputType.number,
                                                        prefixIcon: Icons.monetization_on_outlined,
                                                      ),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () => Navigator.pop(ctx, false),
                                                          child: Text("Hủy", style: TextStyle(color: _textColorSecondary)),
                                                        ),
                                                        ElevatedButton(
                                                          style: ElevatedButton.styleFrom(
                                                            backgroundColor: _headerColor,
                                                            foregroundColor: Colors.white,
                                                          ),
                                                          onPressed: () => Navigator.pop(ctx, true),
                                                          child: Text("Lưu"),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                  if (saved == true) {
                                                    double amount = double.tryParse(editAmountController.text) ?? 0.0;
                                                    if (amount > 0) {
                                                      try {
                                                        await ExpenseManager.saveMonthlyFixedAmount(
                                                          appState,
                                                          name,
                                                          amount,
                                                          _currentDialogMonth,
                                                          dateRange: _currentDialogDateRange,
                                                        );
                                                        savedMonthlyAmountsFromManager[name] = amount;
                                                        monthlyAmountControllers[index].text = amount.toString();
                                                        await appState.loadExpenseValues();
                                                        setStateDialog(() {});
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          SnackBar(
                                                            content: Text("Đã cập nhật số tiền cho '$name'."),
                                                            backgroundColor: Colors.green,
                                                            behavior: SnackBarBehavior.floating,
                                                          ),
                                                        );
                                                      } catch (e) {
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          SnackBar(
                                                            content: Text("Lỗi khi lưu: $e"),
                                                            backgroundColor: Colors.redAccent,
                                                            behavior: SnackBarBehavior.floating,
                                                          ),
                                                        );
                                                      }
                                                    } else {
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        SnackBar(
                                                          content: Text("Số tiền không hợp lệ."),
                                                          backgroundColor: Colors.orangeAccent,
                                                          behavior: SnackBarBehavior.floating,
                                                        ),
                                                      );
                                                    }
                                                  }
                                                },
                                              ),
                                            IconButton(
                                              icon: Icon(Icons.delete_forever, color: _accentColor, size: 22),
                                              onPressed: () async {
                                                bool? confirm = await showDialog(
                                                  context: dialogContext,
                                                  builder: (ctx) => AlertDialog(
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                                    title: Text("Xác nhận xóa", style: TextStyle(color: _textColorPrimary, fontWeight: FontWeight.bold)),
                                                    content: Text("Bạn có chắc muốn xóa '$name' khỏi danh sách chi phí tháng và tất cả các phân bổ của nó không?", style: TextStyle(color: _textColorSecondary)),
                                                    actions: [
                                                      TextButton(
                                                        onPressed: () {
                                                          Navigator.pop(ctx, false);
                                                        },
                                                        child: Text("Hủy", style: TextStyle(color: _textColorSecondary)),
                                                      ),
                                                      ElevatedButton(
                                                        style: ElevatedButton.styleFrom(backgroundColor: _accentColor, foregroundColor: Colors.white),
                                                        onPressed: () => Navigator.pop(ctx, true),
                                                        child: Text("Xóa"),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                                if (confirm == true) {
                                                  showDialog(
                                                    context: dialogContext,
                                                    barrierDismissible: false,
                                                    builder: (ctx) => AlertDialog(
                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                                      content: Row(
                                                        children: [
                                                          CircularProgressIndicator(color: _headerColor),
                                                          SizedBox(width: 15),
                                                          Text("Đang xóa...")
                                                        ],
                                                      ),
                                                    ),
                                                  );
                                                  try {
                                                    await ExpenseManager.deleteMonthlyFixedExpense(appState, name, _currentDialogMonth, dateRange: _currentDialogDateRange);
                                                    fixedExpensesFromManager.removeAt(index);
                                                    monthlyAmountControllers.removeAt(index);
                                                    savedMonthlyAmountsFromManager.remove(name);
                                                    await appState.loadExpenseValues();
                                                    Navigator.pop(dialogContext); // Close loading dialog
                                                    setStateDialog(() {});
                                                    if (mounted) setState(() {});
                                                    Future.microtask(() {
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        SnackBar(
                                                          content: Text("Đã xóa '$name' và các phân bổ."),
                                                          backgroundColor: _accentColor,
                                                          behavior: SnackBarBehavior.floating,
                                                        ),
                                                      );
                                                    });
                                                  } catch (e) {
                                                    Navigator.pop(dialogContext); // Close loading dialog
                                                    Future.microtask(() {
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        SnackBar(
                                                          content: Text("Lỗi khi xóa: $e"),
                                                          backgroundColor: Colors.redAccent,
                                                          behavior: SnackBarBehavior.floating,
                                                        ),
                                                      );
                                                    });
                                                  }
                                                }
                                              },
                                              tooltip: "Xóa khỏi danh sách tháng và các phân bổ",
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 12),
                          Center(
                            child: Text(
                              _currentDialogDateRange == null
                                  ? "Các khoản chi sẽ được phân bổ đều cho $daysInSelectedMonth ngày trong tháng."
                                  : "Các khoản chi sẽ được phân bổ đều cho ${_currentDialogDateRange!.end.difference(_currentDialogDateRange!.start).inDays + 1} ngày đã chọn.",
                              style: TextStyle(
                                  fontSize: 12.5,
                                  color: _textColorSecondary,
                                  fontStyle: FontStyle.italic),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  actionsAlignment: MainAxisAlignment.end,
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(dialogMainContext);
                      },
                      child: Text("Đóng",
                          style: TextStyle(
                              color: _headerColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                    ),
                  ],
                );
              }
              return AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                title: Row(
                    children: [
                      Icon(Icons.info_outline, color: _textColorSecondary),
                      SizedBox(width: 10),
                      Text("Thông báo")
                    ]),
                content: Text("Không có dữ liệu hoặc có lỗi xảy ra khi tải.",
                    style: TextStyle(color: _textColorPrimary)),
                actions: [
                  TextButton(
                      onPressed: () {
                        Navigator.pop(dialogMainContext);
                      },
                      child: Text("Đóng", style: TextStyle(color: _headerColor)))
                ],
              );
            },
          );
        },
      ),
    ).then((_) {
      _isDialogOpen = false;
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
      color: _cardBackgroundColor,
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
            color: _textColorPrimary,
          ),
        ),
        subtitle: Text(
          'Tổng: ${currencyFormat.format(totalAmount)}',
          style: TextStyle(
              fontSize: 14,
              color: _textColorSecondary.withOpacity(0.9),
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
                  style: TextStyle(fontSize: 14, color: _textColorPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: 10),
              Text(
                currencyFormat.format((expense['amount'] as num?)?.toDouble() ?? 0.0),
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: _textColorSecondary),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }


  void removeExpense(AppState appState, List<Map<String, dynamic>> currentExpensesList, int index, String category) {
    List<Map<String, dynamic>> modifiableExpenses = List.from(currentExpensesList);
    if (index < 0 || index >= modifiableExpenses.length) {
      return;
    }

    final removedExpenseName = modifiableExpenses[index]['name'] ?? 'Chi phí không tên';
    modifiableExpenses.removeAt(index);

    if (category == 'Chi phí cố định') {
      appState.fixedExpenseList.value = List.from(modifiableExpenses);
      ExpenseManager.saveFixedExpenses(appState, modifiableExpenses);
    } else {
      appState.variableExpenseList.value = List.from(modifiableExpenses);
      ExpenseManager.saveVariableExpenses(appState, modifiableExpenses);
    }
    appState.loadExpenseValues();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã xóa chi phí: $removedExpenseName'),
          backgroundColor: _accentColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: EdgeInsets.all(10),
        ),
      );
    }
  }

  void editExpense(AppState appState, List<Map<String, dynamic>> currentExpensesList, int index, String category) {
    if (index < 0 || index >= currentExpensesList.length) {
      return;
    }

    TextEditingController editAmountController =
    TextEditingController(text: currentExpensesList[index]['amount'].toString());
    final expenseName = currentExpensesList[index]['name'] ?? 'Chi phí không tên';

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Chỉnh sửa: $expenseName",
            style: TextStyle(color: _textColorPrimary, fontWeight: FontWeight.bold)),
        content: _buildModernDialogTextField(
            controller: editAmountController,
            labelText: "Nhập số tiền mới (VNĐ)",
            keyboardType: TextInputType.number,
            prefixIcon: Icons.monetization_on_outlined),
        actionsPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          TextButton(
              onPressed: () {
                Navigator.pop(dialogCtx);
              },
              child: Text("Hủy", style: TextStyle(color: _textColorSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _headerColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              double newAmount =
                  double.tryParse(editAmountController.text) ?? currentExpensesList[index]['amount'];
              if (newAmount >= 0) {
                List<Map<String, dynamic>> modifiableExpenses = List.from(currentExpensesList);
                modifiableExpenses[index]['amount'] = newAmount;

                if (category == 'Chi phí cố định') {
                  appState.fixedExpenseList.value = List.from(modifiableExpenses);
                  ExpenseManager.saveFixedExpenses(appState, modifiableExpenses);
                } else {
                  appState.variableExpenseList.value = List.from(modifiableExpenses);
                  ExpenseManager.saveVariableExpenses(appState, modifiableExpenses);
                }
                appState.loadExpenseValues();
                Navigator.pop(dialogCtx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Đã cập nhật chi phí: $expenseName'),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      margin: EdgeInsets.all(10),
                    ),
                  );
                }
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text("Số tiền không thể âm"),
                          backgroundColor: Colors.orangeAccent,
                          behavior: SnackBarBehavior.floating));
                }
              }
            },
            child: const Text("Lưu"),
          ),
        ],
      ),
    ).then((_) {
      print('ExpenseScreen: Edit expense dialog closed for: $expenseName');
    });
  }


  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final appState = context.watch<AppState>(); // listen:false is fine here as we use ValueListenableBuilders

    // This callback ensures animations run after the first frame is built and data is ready.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (appState.dataReadyListenable.value && mounted && !_hasAnimated) {
        _runAnimation();
      }
    });

    return Scaffold(
      backgroundColor: _secondaryColor,
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
              child: _buildNavigationActions(),
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
              colors: [_headerColor.withOpacity(0.95), _headerColor.withOpacity(0.75)],
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
                        child: ValueListenableBuilder<DateTime>( // Listen to selectedDate for updates
                          valueListenable: appState.selectedDateListenable,
                          builder: (context, selectedDate, _) => Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Chào, ${user?.displayName?.split(' ').first ?? 'bạn'}",
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                              const SizedBox(height: 2),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.30),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  DateFormat('dd MMMM, yyyy', 'vi').format(selectedDate), // Corrected date format
                                  style: const TextStyle(fontSize: 12.5, color: Colors.white, fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
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

  Widget _buildTotalExpenseSection(AppState appState) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardBackgroundColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.15),
            spreadRadius: 2, blurRadius: 10, offset: Offset(0, 5),
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
              Icon(Icons.trending_down_rounded, color: _accentColor, size: 24),
              SizedBox(width: 10),
              Text(
                'Tổng chi phí ngày',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: _textColorSecondary,
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          ValueListenableBuilder<double>( // Listen to fixed expense for daily total
              valueListenable: appState.fixedExpenseListenable, // Assuming this holds daily fixed total
              builder: (context, fixedDailyExpense, _) {
                // Assuming variableExpense is also a ValueListenable or fetched appropriately
                // For simplicity, if variableExpense is not a ValueListenable but a direct value in AppState:
                final totalDailyExpense = fixedDailyExpense + appState.variableExpense;
                return Text(
                  currencyFormat.format(totalDailyExpense),
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: _accentColor,
                  ),
                  textAlign: TextAlign.center,
                );
              }
          ),
        ],
      ),
    );
  }


  Widget _buildNavigationActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildModernNavigationIcon(
          icon: Icons.account_balance_wallet_outlined,
          label: 'Cố định',
          onTap: () => _navigateToEditExpense('Cố định ngày'),
        ),
        _buildModernNavigationIcon(
          icon: Icons.transform_outlined,
          label: 'Biến đổi',
          onTap: () => _navigateToEditExpense('Biến đổi ngày'),
        ),
        _buildModernNavigationIcon(
          icon: Icons.calendar_month_outlined,
          label: 'CĐ Tháng',
          onTap: () => _navigateToEditExpense('Cố định tháng'),
        ),
        _buildModernNavigationIcon(
          icon: Icons.playlist_add_check_outlined,
          label: 'DS BĐổi',
          onTap: () => _navigateToEditExpense('Danh sách biến đổi'), // Ensure this category is handled
        ),
      ],
    );
  }

  Widget _buildModernNavigationIcon(
      {required IconData icon,
        required String label,
        required VoidCallback onTap}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _cardBackgroundColor,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1, blurRadius: 8, offset: Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              icon,
              size: 28,
              color: _accentColor,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(color: _textColorSecondary, fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildExpenseCategorySelector(BuildContext context, AppState appState) {
    return GestureDetector(
      onTap: () => _showExpenseCategoryBottomSheet(context),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
        decoration: BoxDecoration(
          color: _cardBackgroundColor,
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
                    color: _textColorPrimary,
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
                      color: _accentColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              color: _textColorSecondary,
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
        valueListenable: selectedExpenseCategory == 'Chi phí cố định'
            ? appState.fixedExpenseList
            : appState.variableExpenseList, //
        builder: (context, expenses, _) {
          if (expenses.isEmpty) { //
            return SliverFillRemaining( //
              hasScrollBody: false, //
              child: FadeTransition(
                opacity: _fadeAnimation, //
                child: Center( //
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center, //
                    children: [
                      Icon(Icons.receipt_long_outlined, size: 60, color: Colors.grey.shade400), //
                      SizedBox(height: 16), //
                      Text(
                        'Không có chi phí nào',
                        style: TextStyle(fontSize: 17, color: _textColorSecondary), //
                      ),
                      SizedBox(height: 8), //
                      Text(
                        'Thêm chi phí mới để theo dõi.', //
                        textAlign: TextAlign.center, //
                        style: TextStyle(fontSize: 14, color: Colors.grey.shade500), //
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          // <<<< LOGIC MỚI BẮT ĐẦU TỪ ĐÂY >>>>

          final bool isVariableCategory = selectedExpenseCategory == 'Chi phí biến đổi';
          final List<dynamic> displayItems = isVariableCategory ? _groupVariableExpenses(expenses) : expenses;

          return SliverList(
            delegate: SliverChildBuilderDelegate(
                  (context, index) {
                final item = displayItems[index];

                // --- A. Render một nhóm chi phí ---
                if (isVariableCategory && item is Map && item['isGroup'] == true) {
                  return FadeTransition(
                    opacity: _fadeAnimation,
                    child: _buildGroupedExpenseCard(item as Map<String, dynamic>),
                  );
                }

                // --- B. Render một chi phí đơn lẻ (cố định hoặc biến đổi thủ công) ---
                final expense = item as Map<String, dynamic>;
                bool isAutoCogs = expense['sourceSalesTransactionId'] != null; //
                IconData expenseItemIcon;
                Color iconColorInList;

                if (selectedExpenseCategory == 'Chi phí cố định') {
                  expenseItemIcon = Icons.shield_outlined; //
                  iconColorInList = _buttonPrimaryColor.withOpacity(0.8); //
                } else {
                  expenseItemIcon = Icons.local_fire_department_outlined; //
                  iconColorInList = Colors.orange.shade700; //
                }

                // Tìm index gốc để các hàm edit/remove không bị lỗi
                final originalIndex = expenses.indexOf(expense);

                return FadeTransition(
                  opacity: _fadeAnimation, //
                  child: Slidable(
                    key: Key(expense['id']?.toString() ?? expense['name']?.toString() ?? UniqueKey().toString()), //
                    endActionPane: isAutoCogs
                        ? ActionPane( //
                      motion: const StretchMotion(), //
                      children: [
                        SlidableAction( //
                          onPressed: (context) {
                            ScaffoldMessenger.of(context).showSnackBar( //
                              SnackBar(
                                content: Text('Đây là giá vốn tự động, quản lý qua giao dịch doanh thu.'), //
                                backgroundColor: _textColorSecondary, //
                              ),
                            );
                          },
                          backgroundColor: Colors.grey.shade300, //
                          foregroundColor: _textColorPrimary, //
                          icon: Icons.info_outline, //
                          label: 'Chi tiết', //
                          borderRadius: BorderRadius.circular(12), //
                        ),
                      ],
                    )
                        : ActionPane( //
                      motion: const StretchMotion(), //
                      children: [
                        SlidableAction( //
                          onPressed: (context) {
                            if (originalIndex != -1) {
                              editExpense(appState, expenses, originalIndex, selectedExpenseCategory);
                            }
                          },
                          backgroundColor: _buttonPrimaryColor, //
                          foregroundColor: Colors.white, //
                          icon: Icons.edit_outlined, //
                          label: 'Sửa', //
                          borderRadius: BorderRadius.circular(12), //
                        ),
                        SlidableAction( //
                          onPressed: (context) async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (dialogCtx) => AlertDialog(
                                // ... (Giữ nguyên Dialog xác nhận xóa) ...
                              ),
                            );
                            if (confirm == true) { //
                              if (originalIndex != -1) {
                                removeExpense(appState, expenses, originalIndex, selectedExpenseCategory);
                              }
                            }
                          },
                          backgroundColor: _accentColor.withOpacity(0.9), //
                          foregroundColor: Colors.white, //
                          icon: Icons.delete_outline, //
                          label: 'Xóa', //
                          borderRadius: BorderRadius.circular(12), //
                        ),
                      ],
                    ),
                    child: Card(
                      elevation: 1.5, //
                      margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 0), //
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), //
                      color: _cardBackgroundColor, //
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), //
                        leading: Container(
                          padding: EdgeInsets.all(10), //
                          decoration: BoxDecoration( //
                              color: iconColorInList.withOpacity(0.1), //
                              borderRadius: BorderRadius.circular(10)), //
                          child: Icon( //
                            expenseItemIcon,
                            color: iconColorInList, //
                            size: 24, //
                          ),
                        ),
                        title: Text(
                          expense['name']?.toString() ?? 'Không xác định', //
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: _textColorPrimary), //
                          overflow: TextOverflow.ellipsis, //
                        ),
                        subtitle: Text(
                          '${currencyFormat.format(expense['amount'] ?? 0.0)}', //
                          style: TextStyle(fontSize: 14, color: _textColorSecondary.withOpacity(0.9), fontWeight: FontWeight.w500), //
                          overflow: TextOverflow.ellipsis, //
                        ),
                      ),
                    ),
                  ),
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
    const Color itemPrimaryColor = _ExpenseScreenState._accentColor;
    const Color itemTextColorPrimary = _ExpenseScreenState._textColorPrimary;

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
                        color: itemPrimaryColor.withOpacity(0.1), // Consistent styling
                        borderRadius: BorderRadius.circular(10) // Consistent styling
                    ),
                    child: Icon(icon, size: 24, color: itemPrimaryColor), // Consistent icon styling
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: itemTextColorPrimary), // Consistent text styling
                      ),
                      const SizedBox(height: 5),
                      Text(
                        currencyFormat.format(amount),
                        style: TextStyle(
                          fontSize: 16.5, // Consistent text styling
                          fontWeight: FontWeight.bold,
                          color: itemPrimaryColor,
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