import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart'; //
import 'package:hive/hive.dart'; //
import 'package:intl/intl.dart'; //
import 'package:provider/provider.dart'; //
import '../state/app_state.dart'; //
import '/screens/expense_manager.dart'; //
import 'package:fingrowth/screens/report_screen.dart';

class EditVariableExpenseScreen extends StatefulWidget {
  const EditVariableExpenseScreen({Key? key}) : super(key: key); //

  @override
  _EditVariableExpenseScreenState createState() =>
      _EditVariableExpenseScreenState(); //
}

class _EditVariableExpenseScreenState extends State<EditVariableExpenseScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController amountController = TextEditingController(); //
  final currencyFormat =
  NumberFormat.currency(locale: 'vi_VN', symbol: 'VNĐ'); //
  final NumberFormat _inputPriceFormatter = NumberFormat("#,##0", "vi_VN"); //
  final TextEditingController nameController = TextEditingController();
  late AppState appState; //

  final FocusNode _amountFocusNode = FocusNode(); //

  late AnimationController _animationController; //
  late Animation<Offset> _slideAnimation; //
  late Animation<double> _fadeAnimation; //
  late Animation<double> _totalFadeAnimation; //
  late Animation<double> _buttonScaleAnimation; //

  List<Map<String, dynamic>> variableExpenses = []; //
  bool isLoading = true; //
  bool hasError = false; //

  @override
  void initState() {
    super.initState();
    appState = Provider.of<AppState>(context, listen: false);
    _animationController = AnimationController(
        duration: const Duration(milliseconds: 700), vsync: this); //
    _slideAnimation = Tween<Offset>(
        begin: const Offset(0, 0.5), end: Offset.zero)
        .animate(CurvedAnimation(
        parent: _animationController, curve: Curves.easeOut)); //
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _animationController, curve: Curves.easeIn)); //
    _totalFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
            parent: _animationController,
            curve: const Interval(0.3, 1.0, curve: Curves.easeIn))); //
    _buttonScaleAnimation = TweenSequence([
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.95), weight: 50),
      TweenSequenceItem(tween: Tween<double>(begin: 0.95, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(
        parent: _animationController, curve: Curves.easeInOut)); //

    _loadInitialData(); //
    amountController.addListener(_onAmountChanged); //
    appState.productsUpdated.addListener(_onExpensesUpdated);
  }

  void _onExpensesUpdated() {
    // Khi AppState báo có cập nhật (từ một trong hai listener),
    // chúng ta sẽ tải lại toàn bộ dữ liệu cho màn hình này.
    print("Nhận tín hiệu cập nhật chi phí, đang tải lại dữ liệu...");
    if (mounted) {
      _loadInitialData();
    }
  }

  void _onAmountChanged() {
    // Future use: update estimated total or similar live feedback
  }

  Future<void> _loadInitialData() async {
    if (!mounted) return;
    setState(() {
      isLoading = true;
      hasError = false;
    });

    try {
      final appState = Provider.of<AppState>(context, listen: false);
      // Chỉ cần tải danh sách các chi phí đã nhập trong ngày
      final dailyExpenses = await ExpenseManager.loadVariableExpenses(appState);

      if (mounted) {
        setState(() {
          variableExpenses = dailyExpenses;
          appState.variableExpenseList.value = List.from(dailyExpenses);
          isLoading = false;
          _animationController.forward();
          _resetFormFields();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          hasError = true;
          isLoading = false;
        });
        _showStyledSnackBar("Lỗi tải dữ liệu. Vui lòng thử lại.", isError: true);
      }
      print("Error loading expenses in EditVariableExpenseScreen: $e");
    }
  }

  @override
  void dispose() {
    appState.productsUpdated.removeListener(_onExpensesUpdated);
    nameController.dispose();
    amountController.dispose(); //
    _amountFocusNode.dispose(); //
    _animationController.dispose(); //
    super.dispose(); //
  }

  void _resetFormFields() {
    if (!mounted) return;
    setState(() {
      nameController.clear(); // <-- THAY ĐỔI Ở ĐÂY
      amountController.text = _inputPriceFormatter.format(0);
      if (_amountFocusNode.hasFocus) {
      _amountFocusNode.unfocus();
      }
    });
  }

  void _showStyledSnackBar(String message, {bool isError = false}) {
    if (!mounted) return; //
    ScaffoldMessenger.of(context).showSnackBar( //
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: isError ? AppColors.chartRed : AppColors.chartRed,
        behavior: SnackBarBehavior.floating, //
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), //
        margin: const EdgeInsets.all(10), //
      ),
    );
  }

  void addExpense(AppState appState) {
    final String expenseName = nameController.text.trim();
    if (expenseName.isEmpty) {
      _showStyledSnackBar("Vui lòng nhập tên khoản chi phí!", isError: true);
      return;
    }

    double amountToUse = double.tryParse(
        amountController.text.replaceAll('.', '').replaceAll(',', '')) ??
        0.0;

    if (amountToUse <= 0) {
    _showStyledSnackBar("Số tiền phải lớn hơn 0!", isError: true);
    return;
    }

    if (!mounted) return;

    setState(() {
      List<Map<String, dynamic>> currentVariableExpenses =
      List.from(appState.variableExpenseList.value);

      currentVariableExpenses.add({
        "name": expenseName, // <-- THAY ĐỔI: Lấy từ nameController
        "amount": amountToUse,
        "date": DateTime.now().toIso8601String(),
        "createdBy": appState.authUserId,
      });

      appState.variableExpenseList.value = currentVariableExpenses;
      variableExpenses = List.from(currentVariableExpenses);

      ExpenseManager.saveVariableExpenses(appState, currentVariableExpenses)
          .then((_) {
      return ExpenseManager.updateTotalVariableExpense(
      appState, currentVariableExpenses);
      }).then((total) {
      appState.setExpenses(appState.fixedExpense, total);
      _showStyledSnackBar("Đã thêm: $expenseName");
      _resetFormFields();
      }).catchError((e) {
      _showStyledSnackBar("Lỗi khi lưu chi phí: $e", isError: true);
      });
    });
    FocusScope.of(context).unfocus();
  }

  void removeExpense(int index, AppState appState) {
    if (index < 0 || index >= appState.variableExpenseList.value.length) return; //
    if (!mounted) return; //
    final removedExpenseName =
    appState.variableExpenseList.value[index]['name']; //
    setState(() { //
      List<Map<String, dynamic>> currentVariableExpenses =
      List.from(appState.variableExpenseList.value); //
      currentVariableExpenses.removeAt(index); //
      appState.variableExpenseList.value = currentVariableExpenses; //
      variableExpenses = List.from(currentVariableExpenses); //
      ExpenseManager.saveVariableExpenses(appState, currentVariableExpenses) //
          .then((_) {
        return ExpenseManager.updateTotalVariableExpense( //
            appState, currentVariableExpenses);
      }).then((total) {
        appState.setExpenses(appState.fixedExpense, total); //
        _showStyledSnackBar("Đã xóa: $removedExpenseName"); //
      }).catchError((e) { //
        _showStyledSnackBar("Lỗi khi xóa chi phí: $e", isError: true); //
      });
    });
  }

  void editExpense(int index, AppState appState) {
    if (index < 0 || index >= appState.variableExpenseList.value.length) return; //

    final expenseToEdit = appState.variableExpenseList.value[index]; //
    final TextEditingController editAmountController = TextEditingController(
        text: _inputPriceFormatter.format(expenseToEdit['amount'] ?? 0.0)); //

    showDialog(
      context: context, //
      builder: (dialogContext) => GestureDetector( //
        onTap: () => FocusScope.of(dialogContext).unfocus(), //
        behavior: HitTestBehavior.opaque, //
        child: AlertDialog( //
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)), //
          title: Text( //
            "Chỉnh sửa: ${expenseToEdit['name']}", //
            overflow: TextOverflow.ellipsis, //
            maxLines: 1, //
            style: GoogleFonts.poppins( //
                fontWeight: FontWeight.w600, color: AppColors.getTextColor(context)),
          ),
          content: TextField( //
            controller: editAmountController,
            keyboardType: TextInputType.numberWithOptions(decimal: false), //
            inputFormatters: [ //
              FilteringTextInputFormatter.digitsOnly, //
              TextInputFormatter.withFunction( //
                    (oldValue, newValue) {
                  if (newValue.text.isEmpty) return newValue.copyWith(text: '0'); //
                  final String plainNumberText = newValue.text //
                      .replaceAll('.', '')
                      .replaceAll(',', '');
                  final number = int.tryParse(plainNumberText); //
                  if (number == null) return oldValue; //
                  final formattedText = _inputPriceFormatter.format(number); //
                  return newValue.copyWith( //
                    text: formattedText, //
                    selection: //
                    TextSelection.collapsed(offset: formattedText.length),
                  );
                },
              ),
            ],
            decoration: InputDecoration( //
                labelText: "Nhập số tiền mới", //
                labelStyle: GoogleFonts.poppins(color: AppColors.getTextSecondaryColor(context)), //
                border: OutlineInputBorder( //
                    borderRadius: BorderRadius.circular(12.0)),
                filled: true, //
                fillColor: AppColors.getBackgroundColor(context).withOpacity(0.7), //
                prefixIcon: Icon(Icons.monetization_on_outlined, //
                    color: AppColors.chartRed)), //
            maxLines: 1, //
            maxLength: 15, //
          ),
          actionsPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 10), //
          actions: [ //
            TextButton( //
              onPressed: () {
                Navigator.pop(dialogContext); //
              },
              child: Text("Hủy", //
                  style: GoogleFonts.poppins( //
                      color: AppColors.getTextSecondaryColor(context),
                      fontWeight: FontWeight.w500)),
            ),
            ElevatedButton( //
              style: ElevatedButton.styleFrom( //
                backgroundColor: AppColors.chartRed, //
                foregroundColor: Colors.white, //
                shape: RoundedRectangleBorder( //
                    borderRadius: BorderRadius.circular(10.0)),
                padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 10), //
              ),
              onPressed: () { //
                double newAmount = double.tryParse(editAmountController.text
                    .replaceAll('.', '')
                    .replaceAll(',', '')) ??
                    0.0; //
                if (newAmount <= 0) { //
                  ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(
                      content: Text("Số tiền phải lớn hơn 0!",
                          style: GoogleFonts.poppins()),
                      backgroundColor: AppColors.chartRed)); //
                } else { //
                  if (!mounted) return; //
                  setState(() { //
                    List<Map<String, dynamic>> currentVariableExpenses =
                    List.from(appState.variableExpenseList.value); //
                    currentVariableExpenses[index]['amount'] = newAmount; //
                    appState.variableExpenseList.value =
                        currentVariableExpenses; //
                    variableExpenses = List.from(currentVariableExpenses); //
                    ExpenseManager.saveVariableExpenses( //
                        appState, currentVariableExpenses)
                        .then((_) {
                      return ExpenseManager.updateTotalVariableExpense( //
                          appState, currentVariableExpenses);
                    }).then((total) {
                      appState.setExpenses(appState.fixedExpense, total); //
                      Navigator.pop(dialogContext); //
                      _showStyledSnackBar(
                          "Đã cập nhật: ${expenseToEdit['name']}"); //
                    }).catchError((e) { //
                      _showStyledSnackBar("Lỗi khi cập nhật: $e", //
                          isError: true);
                      Navigator.pop(dialogContext); //
                    });
                  });
                }
              },
              child: Text("Lưu", style: GoogleFonts.poppins()), //
            ),
          ],
        ),
      ),
    );
  }

  // ===================================================================
  // CÁC HÀM HELPER MỚI CHO VIỆC NHÓM VÀ RENDER DANH SÁCH CHI PHÍ
  // ===================================================================

  /// Hàm xử lý và nhóm các chi phí.
  List<dynamic> _groupExpenses(List<Map<String, dynamic>> expenses) {
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

    // Xử lý và thêm các nhóm COGS
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
          'transactionId': transactionId,
          'groupTitle': "Giá vốn cho: $productName",
          'items': items,
          'totalAmount': items.fold(0.0, (sum, item) => sum + (item['amount'] as num? ?? 0.0)),
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
  Widget _buildGroupCard(Map<String, dynamic> group) {
    final String title = group['groupTitle'];
    final double totalAmount = group['totalAmount'];
    final List<Map<String, dynamic>> items = group['items'];

    return Card(
      elevation: 2.0,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
          side: BorderSide(color: AppColors.chartRed.withOpacity(0.4), width: 1)),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.chartRed.withOpacity(0.15),
          radius: 20,
          child: Icon(Icons.link, color: AppColors.chartRed.withOpacity(0.8), size: 20),
        ),
        title: Text(
          title,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: AppColors.getTextColor(context),
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          "Tổng: ${currencyFormat.format(totalAmount)}",
          style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.getTextSecondaryColor(context)),
        ),
        childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
        expandedAlignment: Alignment.centerLeft,
        children: items.map((expense) {
          return ListTile(
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
            title: Text(
              expense['name'] ?? 'Không có tên', // SỬA Ở ĐÂY: Hiển thị tên đầy đủ
              style: GoogleFonts.poppins(fontSize: 14),
            ),
            trailing: Text(
              currencyFormat.format((expense['amount'] as num?)?.toDouble() ?? 0.0),
              style: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 14),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Widget để render một tile cho chi phí (tái cấu trúc từ code gốc)
  Widget _buildExpenseTile(Map<String, dynamic> expense, int originalIndex, {required bool isAutoCogs}) {
    final double amount = (expense['amount'] as num?)?.toDouble() ?? 0.0;
    final appState = context.read<AppState>();

    return Card(
      elevation: 1.5,
      margin: const EdgeInsets.symmetric(vertical: 6.0), //
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)), //
      color: AppColors.getCardColor(context), //
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0), //
        leading: CircleAvatar( //
          backgroundColor: AppColors.chartRed.withOpacity(0.15), //
          radius: 20, //
          child: isAutoCogs
              ? Icon(Icons.link, color: AppColors.chartRed.withOpacity(0.7), size: 20)
              : Icon(Icons.flare_outlined, color: AppColors.chartRed, size: 22), //
        ),
        title: Text(
          expense['name'] ?? 'Không có tên', //
          style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.getTextColor(context)), //
          overflow: TextOverflow.ellipsis, //
        ),
        subtitle: Text( //
          currencyFormat.format(amount), //
          style: GoogleFonts.poppins(
              fontSize: 14.5,
              fontWeight: FontWeight.w500,
              color: AppColors.getTextSecondaryColor(context).withOpacity(0.9)),
        ),
        trailing: isAutoCogs
            ? Tooltip(
          message: "Giá vốn tự động, quản lý qua giao dịch doanh thu",
          child: Icon(Icons.info_outline, color: AppColors.getTextSecondaryColor(context), size: 22),
        )
            : Row( //
          mainAxisSize: MainAxisSize.min, //
          children: [
            IconButton( //
              icon: Icon(Icons.edit_note_outlined, color: AppColors.primaryBlue, size: 22), //
              onPressed: () {
                if (originalIndex != -1) {
                  editExpense(originalIndex, appState);
                }
              },
              splashRadius: 20, //
              tooltip: "Chỉnh sửa", //
            ),
            IconButton( //
              icon: Icon(Icons.delete_outline_rounded, color: AppColors.chartRed, size: 22), //
              onPressed: () {
                if (originalIndex != -1) {
                  removeExpense(originalIndex, appState);
                }
              },
              splashRadius: 20, //
              tooltip: "Xóa", //
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>(); //
    final screenWidth = MediaQuery.of(context).size.width; //
    return GestureDetector( //
      onTap: () => FocusScope.of(context).unfocus(), //
      behavior: HitTestBehavior.opaque, //
      child: Scaffold(
        backgroundColor: AppColors.getBackgroundColor(context), //
        body: Stack( //
          children: [
            Container( //
              height: MediaQuery.of(context).size.height * 0.25, //
              color: AppColors.chartRed.withOpacity(0.9), //
            ),
            SafeArea( //
              child: SingleChildScrollView( //
                keyboardDismissBehavior:
                ScrollViewKeyboardDismissBehavior.onDrag, //
                child: Column( //
                  crossAxisAlignment: CrossAxisAlignment.start, //
                  children: [
                    Padding( //
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 8.0), //
                      child: Row( //
                        children: [
                          IconButton( //
                            icon: const Icon(Icons.arrow_back_ios_new, //
                                color: Colors.white), //
                            onPressed: () => Navigator.pop(context), //
                            splashRadius: 20, //
                          ),
                          const SizedBox(width: 8), //
                          Flexible( //
                            child: Column( //
                              crossAxisAlignment: CrossAxisAlignment.start, //
                              children: [
                                Text( //
                                  "Chi phí biến đổi", //
                                  style: GoogleFonts.poppins( //
                                      fontSize: 22, //
                                      fontWeight: FontWeight.w600, //
                                      color: Colors.white), //
                                  overflow: TextOverflow.ellipsis, //
                                ),
                                Container( //
                                  padding: const EdgeInsets.symmetric( //
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration( //
                                    color: Colors.white.withOpacity(0.25), //
                                    borderRadius: BorderRadius.circular(8), //
                                  ),
                                  child: Text( //
                                    "Ngày ${DateFormat('d MMMM y', 'vi').format(appState.selectedDate)}", //
                                    style: GoogleFonts.poppins( //
                                        fontSize: 12, //
                                        color: Colors.white, //
                                        fontWeight: FontWeight.w500), //
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16), //
                    Padding( //
                      padding: const EdgeInsets.symmetric(horizontal: 16.0), //
                      child: isLoading //
                          ? Center(
                          child: Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: CircularProgressIndicator(
                                  color: AppColors.chartRed))) //
                          : hasError //
                          ? Center(
                          child: Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Text(
                                  "Có lỗi xảy ra khi tải dữ liệu",
                                  style: GoogleFonts.poppins(
                                      color: AppColors.getTextSecondaryColor(context))))) //
                          : Column( //
                        children: [
                          FadeTransition( //
                            opacity: _totalFadeAnimation, //
                            child: Card( //
                              elevation: 4, //
                              shape: RoundedRectangleBorder( //
                                  borderRadius:
                                  BorderRadius.circular(15)),
                              color: AppColors.getCardColor(context), //
                              child: Padding( //
                                padding: const EdgeInsets.all(16.0), //
                                child: Row( //
                                  mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween, //
                                  children: [
                                    Text( //
                                      'Tổng chi phí biến đổi', //
                                      style: GoogleFonts.poppins( //
                                          fontSize: 17, //
                                          fontWeight: FontWeight.w600, //
                                          color: AppColors.getTextColor(context)),
                                    ),
                                    Flexible( //
                                      child: Text( //
                                        currencyFormat.format(
                                            appState.variableExpense), //
                                        style: GoogleFonts.poppins( //
                                          fontSize: 20, //
                                          fontWeight: FontWeight.bold, //
                                          color: AppColors.chartRed, //
                                        ),
                                        overflow:
                                        TextOverflow.ellipsis, //
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20), //
                          Card( //
                            elevation: 3, //
                            shape: RoundedRectangleBorder( //
                                borderRadius:
                                BorderRadius.circular(16)),
                            color: AppColors.getCardColor(context), //
                            child: Padding( //
                              padding: const EdgeInsets.all(20.0), //
                              child: Column( //
                                crossAxisAlignment:
                                CrossAxisAlignment.start, //
                                children: [
                                  Text( //
                                    "Thêm chi phí mới", //
                                    style: GoogleFonts.poppins( //
                                        fontSize: 18, //
                                        fontWeight: FontWeight.w700, //
                                        color: AppColors.chartRed), //
                                  ),
                                  const SizedBox(height: 16), //
                                  _buildModernTextField(
                                    context: context,
                                    controller: nameController,
                                    labelText: "Tên khoản chi",
                                    prefixIconData: Icons.edit_note_outlined,
                                    keyboardType: TextInputType.text,
                                    maxLength: 50,
                                  ),
                                  const SizedBox(height: 16),
                                  _buildModernTextField( //
                                    context: context,
                                    controller: amountController, //
                                    labelText: "Nhập số tiền", //
                                    prefixIconData: Icons
                                        .monetization_on_outlined, //
                                    keyboardType: TextInputType
                                        .numberWithOptions(
                                        decimal: false), //
                                    inputFormatters: [ //
                                      FilteringTextInputFormatter
                                          .digitsOnly, //
                                      TextInputFormatter.withFunction( //
                                            (oldValue, newValue) {
                                          if (newValue.text.isEmpty) {
                                            return newValue.copyWith(
                                                text: '0'); //
                                          }
                                          final String
                                          plainNumberText =
                                          newValue.text
                                              .replaceAll(
                                              '.', '')
                                              .replaceAll(',',
                                              ''); //
                                          final number = int.tryParse(
                                              plainNumberText); //
                                          if (number == null)
                                            return oldValue; //
                                          final formattedText =
                                          _inputPriceFormatter
                                              .format(number); //
                                          return newValue.copyWith( //
                                            text: formattedText, //
                                            selection: TextSelection
                                                .collapsed(
                                                offset:
                                                formattedText
                                                    .length), //
                                          );
                                        },
                                      ),
                                    ],
                                    maxLength: 15, //
                                    focusNode: _amountFocusNode,
                                  ),
                                  const SizedBox(height: 24), //
                                  Center( //
                                    child: ScaleTransition( //
                                      scale: _buttonScaleAnimation, //
                                      child: ElevatedButton( //
                                        style: ElevatedButton
                                            .styleFrom( //
                                          backgroundColor:
                                          AppColors.chartRed, //
                                          foregroundColor:
                                          Colors.white, //
                                          shape:
                                          RoundedRectangleBorder(
                                              borderRadius:
                                              BorderRadius
                                                  .circular(
                                                  12)), //
                                          minimumSize: Size(
                                              screenWidth * 0.8,
                                              52), //
                                          padding: const EdgeInsets
                                              .symmetric(
                                              vertical: 14), //
                                        ),
                                        onPressed: () =>
                                            addExpense(appState), //
                                        child: Text( //
                                          "Thêm chi phí", //
                                          style: GoogleFonts.poppins(
                                              fontSize: 16.5,
                                              fontWeight:
                                              FontWeight.w600), //
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20), //
                          if (variableExpenses.isNotEmpty) //
                            Padding( //
                              padding: const EdgeInsets.only(
                                  bottom: 8.0, top: 10.0), //
                              child: Text( //
                                "Chi phí đã thêm trong ngày", //
                                style: GoogleFonts.poppins(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.getTextColor(context)), //
                              ),
                            ),
                          // <<<< PHẦN CODE ĐƯỢC CẬP NHẬT >>>>
                          SlideTransition( //
                            position: _slideAnimation, //
                            child: FadeTransition( //
                              opacity: _fadeAnimation, //
                              child: variableExpenses.isEmpty //
                                  ? Padding( //
                                padding:
                                const EdgeInsets.symmetric(
                                    vertical: 30.0), //
                                child: Center( //
                                  child: Column( //
                                    children: [
                                      Icon(
                                          Icons
                                              .hourglass_empty_rounded,
                                          size: 50,
                                          color: AppColors.getTextSecondaryColor(context)), //
                                      const SizedBox(
                                          height: 10), //
                                      Text( //
                                        "Chưa có chi phí biến đổi nào được thêm hôm nay.", //
                                        textAlign:
                                        TextAlign.center, //
                                        style: GoogleFonts
                                            .poppins(
                                            fontSize: 16,
                                            color:
                                            AppColors.getTextSecondaryColor(context)), //
                                      ),
                                    ],
                                  ),
                                ),
                              )
                                  : Builder(
                                builder: (context) {
                                  final List<dynamic>
                                  displayItems =
                                  _groupExpenses(
                                      variableExpenses);

                                  return ListView.builder(
                                    shrinkWrap: true, //
                                    physics: const NeverScrollableScrollPhysics(), //
                                    itemCount: displayItems.length,
                                    itemBuilder:
                                        (context, index) {
                                      final item =
                                      displayItems[index];

                                      if (item is Map &&
                                          item['isGroup'] ==
                                              true) {
                                        return _buildGroupCard(item as Map<String, dynamic>);
                                      } else {
                                        final expense = item
                                        as Map<String,
                                            dynamic>;
                                        final originalIndex = appState
                                            .variableExpenseList
                                            .value
                                            .indexOf(expense);

                                        return _buildExpenseTile(
                                            expense,
                                            originalIndex,
                                            isAutoCogs: false);
                                      }
                                    },
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernTextField({
    required BuildContext context,
    required TextEditingController controller,
    required String labelText,
    TextInputType keyboardType = TextInputType.text, //
    List<TextInputFormatter>? inputFormatters, //
    int? maxLength, //
    IconData? prefixIconData, //
    bool enabled = true,
    FocusNode? focusNode,
  }) {
    return TextField(
      controller: controller, //
      keyboardType: keyboardType, //
      inputFormatters: inputFormatters, //
      maxLength: maxLength, //
      enabled: enabled,
      focusNode: focusNode,
      style: GoogleFonts.poppins( //
          color: AppColors.getTextColor(context),
          fontWeight: FontWeight.w500,
          fontSize: 16),
      decoration: InputDecoration( //
        labelText: labelText, //
        labelStyle: GoogleFonts.poppins(color: AppColors.getTextSecondaryColor(context)), //
        prefixIcon: prefixIconData != null //
            ? Icon(prefixIconData, color: AppColors.chartRed, size: 22) //
            : null,
        border: OutlineInputBorder( //
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.getBorderColor(context))),
        enabledBorder: OutlineInputBorder( //
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.getBorderColor(context))),
        focusedBorder: OutlineInputBorder( //
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.chartRed, width: 1.5)),
        filled: true, //
        fillColor: enabled
            ? AppColors.getBackgroundColor(context).withOpacity(0.5)
            : AppColors.getBorderColor(context),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 14), //
        counterText: "", //
      ),
      maxLines: 1, //
    );
  }
}