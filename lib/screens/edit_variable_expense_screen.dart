import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart'; //
import 'package:hive/hive.dart'; //
import 'package:intl/intl.dart'; //
import 'package:provider/provider.dart'; //
import '../state/app_state.dart'; //
import '/screens/expense_manager.dart'; //

class EditVariableExpenseScreen extends StatefulWidget {
  const EditVariableExpenseScreen({Key? key}) : super(key: key); //

  @override
  _EditVariableExpenseScreenState createState() =>
      _EditVariableExpenseScreenState(); //
}

class _EditVariableExpenseScreenState extends State<EditVariableExpenseScreen>
    with SingleTickerProviderStateMixin {
  String? selectedExpenseName; //
  final TextEditingController amountController = TextEditingController(); //
  final currencyFormat =
  NumberFormat.currency(locale: 'vi_VN', symbol: 'VNĐ'); //
  final NumberFormat _inputPriceFormatter = NumberFormat("#,##0", "vi_VN"); //
  late AppState appState; //

  // State variables mới
  double selectedPriceFromDropdown = 0.0; //
  final FocusNode _amountFocusNode = FocusNode(); //

  late AnimationController _animationController; //
  late Animation<Offset> _slideAnimation; //
  late Animation<double> _fadeAnimation; //
  late Animation<double> _totalFadeAnimation; //
  late Animation<double> _buttonScaleAnimation; //

  List<Map<String, dynamic>> variableExpenses = []; //
  List<Map<String, dynamic>> availableExpenses = []; //
  bool isLoading = true; //
  bool hasError = false; //

  static const Color _appBarColor = Color(0xFFE53935); //
  static const Color _accentColor = Color(0xFFD32F2F); //
  static const Color _secondaryColor = Color(0xFFF1F5F9); //
  static const Color _textColorPrimary = Color(0xFF1D2D3A); //
  static const Color _textColorSecondary = Color(0xFF6E7A8A); //
  static const Color _cardBackgroundColor = Colors.white; //
  static const Color _editButtonColor = Color(0xFF0A7AFF); //

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Lưu trữ tham chiếu đến AppState
    appState = Provider.of<AppState>(context, listen: false); //
    // Di chuyển logic khởi tạo listener vào đây
    appState.productsUpdated.addListener(_onProductOrExpenseListUpdated); //
  }

  @override
  void initState() {
    super.initState(); //
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
  }

  void _onProductOrExpenseListUpdated() {
    if (mounted) {
      _loadInitialData(); //
    }
  }

  void _onAmountChanged() {
    // Future use: update estimated total or similar live feedback
  }

  Future<void> _loadInitialData() async {
    if (!mounted) return; //
    setState(() {
      isLoading = true; //
      hasError = false; //
    });

    try {
      final appState = Provider.of<AppState>(context, listen: false);
      final results = await Future.wait([
        ExpenseManager.loadVariableExpenses(appState),
        ExpenseManager.loadAvailableVariableExpenses(appState),
      ]);

      // ===================== PHẦN THÊM MỚI =====================
      // Lọc danh sách chi phí có sẵn để chỉ lấy những chi phí không được gắn sản phẩm.
      final List<Map<String, dynamic>> allAvailableExpenses = results[1];
      final List<Map<String, dynamic>> unlinkedExpenses = allAvailableExpenses
          .where((expense) => expense['linkedProductId'] == null)
          .toList();
      // ========================================================

      if (mounted) {
        setState(() {
          variableExpenses = results[0];
          // Sử dụng danh sách đã được lọc
          availableExpenses = unlinkedExpenses;
          appState.variableExpenseList.value = List.from(results[0]);
          isLoading = false;
          _animationController.forward();
          _resetFormFields();
        });
      }
    } catch (e) { //
      if (mounted) { //
        setState(() {
          hasError = true; //
          isLoading = false; //
        });
        final appState = Provider.of<AppState>(context, listen: false); //
        final String dateKey = DateFormat('yyyy-MM-dd').format(appState.selectedDate); //
        final String monthKey = DateFormat('yyyy-MM').format(appState.selectedDate); //
        final String firestoreDailyVariableDocId =
        appState.getKey('variableTransactionHistory_$dateKey'); //
        final String hiveVariableKey =
            '${appState.userId}-variableExpenses-$firestoreDailyVariableDocId'; //
        final String hiveListKey =
            '${appState.userId}-variableExpenseList-$monthKey'; //
        final variableExpensesBox = Hive.box('variableExpensesBox'); //
        final variableExpenseListBox = Hive.box('variableExpenseListBox'); //
        final rawCachedVariable = variableExpensesBox.get(hiveVariableKey) ?? []; //
        final rawCachedList = variableExpenseListBox.get(hiveListKey) ?? []; //
        List<Map<String, dynamic>> castedVariableExpenses = []; //
        List<Map<String, dynamic>> castedAvailableExpenses = []; //

        if (rawCachedVariable is List) { //
          for (var item in rawCachedVariable) { //
            if (item is Map) { //
              castedVariableExpenses.add( //
                  Map<String, dynamic>.fromEntries(item.entries.map( //
                          (entry) => MapEntry(entry.key.toString(), entry.value)))); //
            }
          }
        }
        if (rawCachedList is List) { //
          for (var item in rawCachedList) { //
            if (item is Map) { //
              castedAvailableExpenses.add(Map<String, dynamic>.fromEntries( //
                  item.entries.map((entry) => //
                  MapEntry(entry.key.toString(), entry.value)))); //
            }
          }
        }
        if (mounted &&
            (castedVariableExpenses.isNotEmpty ||
                castedAvailableExpenses.isNotEmpty)) { //
          setState(() {
            variableExpenses = castedVariableExpenses; //
            availableExpenses = castedAvailableExpenses; //
            appState.variableExpenseList.value =
                List.from(castedVariableExpenses); //
            isLoading = false; //
            hasError = false; //
            _animationController.forward(); //
            _resetFormFields(); //
          });
        } else if (mounted) {
          _showStyledSnackBar("Lỗi tải dữ liệu và không có cache.", //
              isError: true); //
        }
      }
      print("Error loading expenses in EditVariableExpenseScreen: $e"); //
    }
  }

  @override
  void dispose() {
    appState.productsUpdated.removeListener(_onProductOrExpenseListUpdated); //
    amountController.removeListener(_onAmountChanged); //
    amountController.dispose(); //
    _amountFocusNode.dispose(); //
    _animationController.dispose(); //
    super.dispose(); //
  }

  void _updateAmountControllerBasedOnSelection() {
    if (!mounted) return;
    if (selectedExpenseName != null) {
      final selectedExpenseData = availableExpenses.firstWhere(
              (exp) => exp['name'] == selectedExpenseName,
          orElse: () => {'price': 0.0});
      selectedPriceFromDropdown =
          (selectedExpenseData['price'] as num? ?? 0.0).toDouble();
      amountController.text =
          _inputPriceFormatter.format(selectedPriceFromDropdown);
    } else {
      selectedPriceFromDropdown = 0.0;
      amountController.text = _inputPriceFormatter.format(0);
    }
  }

  void _resetFormFields() {
    if (!mounted) return;
    setState(() {
      selectedExpenseName = null;
      selectedPriceFromDropdown = 0.0;
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
        content: Text(message, style: GoogleFonts.poppins(color: Colors.white)), //
        backgroundColor: isError ? _accentColor : _appBarColor, //
        behavior: SnackBarBehavior.floating, //
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), //
        margin: const EdgeInsets.all(10), //
      ),
    );
  }

  void addExpense(AppState appState) {
    if (selectedExpenseName == null) {
      _showStyledSnackBar("Vui lòng chọn một khoản chi phí!", isError: true);
      return;
    }

    // Luôn lấy số tiền từ ô nhập liệu
    double amountToUse = double.tryParse(
        amountController.text.replaceAll('.', '').replaceAll(',', '')) ??
        0.0;

    if (amountToUse <= 0) {
      _showStyledSnackBar("Số tiền phải lớn hơn 0!", isError: true);
      return;
    }

    if (!mounted) return;

    // Giữ nguyên phần logic lưu dữ liệu ở sau
    setState(() {
      List<Map<String, dynamic>> currentVariableExpenses =
      List.from(appState.variableExpenseList.value);
      currentVariableExpenses.add({
        "name": selectedExpenseName,
        "amount": amountToUse,
        "date": DateTime.now().toIso8601String()
      });
      appState.variableExpenseList.value = currentVariableExpenses; //
      variableExpenses = List.from(currentVariableExpenses);
      ExpenseManager.saveVariableExpenses(appState, currentVariableExpenses)
          .then((_) {
        return ExpenseManager.updateTotalVariableExpense(
            appState, currentVariableExpenses); //
      }).then((total) {
        appState.setExpenses(appState.fixedExpense, total);
        _showStyledSnackBar("Đã thêm: $selectedExpenseName");
        _resetFormFields();
      }).catchError((e) {
        _showStyledSnackBar("Lỗi khi lưu chi phí: $e", isError: true);
      });
    });
    FocusScope.of(context).unfocus(); //
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
                fontWeight: FontWeight.w600, color: _textColorPrimary),
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
                labelStyle: GoogleFonts.poppins(color: _textColorSecondary), //
                border: OutlineInputBorder( //
                    borderRadius: BorderRadius.circular(12.0)),
                filled: true, //
                fillColor: _secondaryColor.withOpacity(0.7), //
                prefixIcon: Icon(Icons.monetization_on_outlined, //
                    color: _appBarColor)), //
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
                      color: _textColorSecondary,
                      fontWeight: FontWeight.w500)),
            ),
            ElevatedButton( //
              style: ElevatedButton.styleFrom( //
                backgroundColor: _appBarColor, //
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
                      backgroundColor: _accentColor)); //
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
          side: BorderSide(color: _accentColor.withOpacity(0.4), width: 1)),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: _appBarColor.withOpacity(0.15),
          radius: 20,
          child: Icon(Icons.link, color: _appBarColor.withOpacity(0.8), size: 20),
        ),
        title: Text(
          title,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: _textColorPrimary,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          "Tổng: ${currencyFormat.format(totalAmount)}",
          style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: _textColorSecondary),
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
      color: _cardBackgroundColor, //
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0), //
        leading: CircleAvatar( //
          backgroundColor: _appBarColor.withOpacity(0.15), //
          radius: 20, //
          child: isAutoCogs
              ? Icon(Icons.link, color: _appBarColor.withOpacity(0.7), size: 20)
              : Icon(Icons.flare_outlined, color: _appBarColor, size: 22), //
        ),
        title: Text(
          expense['name'] ?? 'Không có tên', //
          style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _textColorPrimary), //
          overflow: TextOverflow.ellipsis, //
        ),
        subtitle: Text( //
          currencyFormat.format(amount), //
          style: GoogleFonts.poppins(
              fontSize: 14.5,
              fontWeight: FontWeight.w500,
              color: _textColorSecondary.withOpacity(0.9)),
        ),
        trailing: isAutoCogs
            ? Tooltip(
          message: "Giá vốn tự động, quản lý qua giao dịch doanh thu",
          child: Icon(Icons.info_outline, color: Colors.grey.shade400, size: 22),
        )
            : Row( //
          mainAxisSize: MainAxisSize.min, //
          children: [
            IconButton( //
              icon: Icon(Icons.edit_note_outlined, color: _editButtonColor, size: 22), //
              onPressed: () {
                if (originalIndex != -1) {
                  editExpense(originalIndex, appState);
                }
              },
              splashRadius: 20, //
              tooltip: "Chỉnh sửa", //
            ),
            IconButton( //
              icon: Icon(Icons.delete_outline_rounded, color: _accentColor, size: 22), //
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
        backgroundColor: _secondaryColor, //
        body: Stack( //
          children: [
            Container( //
              height: MediaQuery.of(context).size.height * 0.25, //
              color: _appBarColor.withOpacity(0.9), //
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
                                  color: _appBarColor))) //
                          : hasError //
                          ? Center(
                          child: Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Text(
                                  "Có lỗi xảy ra khi tải dữ liệu",
                                  style: GoogleFonts.poppins(
                                      color: _textColorSecondary)))) //
                          : Column( //
                        children: [
                          FadeTransition( //
                            opacity: _totalFadeAnimation, //
                            child: Card( //
                              elevation: 4, //
                              shape: RoundedRectangleBorder( //
                                  borderRadius:
                                  BorderRadius.circular(15)),
                              color: _cardBackgroundColor, //
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
                                          color: _textColorPrimary),
                                    ),
                                    Flexible( //
                                      child: Text( //
                                        currencyFormat.format(
                                            appState.variableExpense), //
                                        style: GoogleFonts.poppins( //
                                          fontSize: 20, //
                                          fontWeight: FontWeight.bold, //
                                          color: _accentColor, //
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
                            color: _cardBackgroundColor, //
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
                                        color: _appBarColor), //
                                  ),
                                  const SizedBox(height: 16), //
                                  DropdownButtonFormField<String>( //
                                    value: selectedExpenseName,
                                    hint: Text("Chọn khoản chi phí",
                                        style: GoogleFonts.poppins(
                                            color:
                                            _textColorSecondary)), //
                                    isExpanded: true, //
                                    decoration: InputDecoration( //
                                      prefixIcon: Icon(
                                          Icons.category_outlined,
                                          color: _appBarColor,
                                          size: 22), //
                                      border: OutlineInputBorder(
                                          borderRadius:
                                          BorderRadius.circular(
                                              12)), //
                                      filled: true, //
                                      fillColor: _secondaryColor
                                          .withOpacity(0.5), //
                                      contentPadding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 14), //
                                    ),
                                    items:
                                    availableExpenses.isEmpty //
                                        ? [
                                      const DropdownMenuItem<
                                          String>( //
                                        value: null, //
                                        child: Text( //
                                            "Chưa có khoản chi phí nào", //
                                            style: TextStyle(
                                                fontStyle: FontStyle
                                                    .italic)), //
                                      )
                                    ]
                                        : availableExpenses.map(
                                            (expense) =>
                                            DropdownMenuItem<
                                                String>(
                                              value: expense[
                                              'name'], //
                                              child: Text(
                                                  expense['name'], //
                                                  overflow:
                                                  TextOverflow
                                                      .ellipsis, //
                                                  style: GoogleFonts
                                                      .poppins(
                                                      color:
                                                      _textColorPrimary)), //
                                            )).toList(), //
                                    onChanged: (String? newValue) { //
                                      setState(() {
                                        selectedExpenseName =
                                            newValue;
                                        _updateAmountControllerBasedOnSelection(); //
                                      });
                                    },
                                    style: GoogleFonts.poppins(
                                        color: _textColorPrimary,
                                        fontSize: 16), //
                                    icon: Icon(Icons
                                        .arrow_drop_down_circle_outlined,
                                        color: _appBarColor), //
                                    borderRadius:
                                    BorderRadius.circular(12), //
                                  ),
                                  const SizedBox(height: 16),
                                  _buildModernTextField( //
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
                                          _appBarColor, //
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
                                    color: _textColorPrimary), //
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
                                          color: Colors
                                              .grey.shade400), //
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
                                            _textColorSecondary), //
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
          color: _textColorPrimary,
          fontWeight: FontWeight.w500,
          fontSize: 16),
      decoration: InputDecoration( //
        labelText: labelText, //
        labelStyle: GoogleFonts.poppins(color: _textColorSecondary), //
        prefixIcon: prefixIconData != null //
            ? Icon(prefixIconData, color: _appBarColor, size: 22) //
            : null,
        border: OutlineInputBorder( //
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder( //
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder( //
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: _appBarColor, width: 1.5)),
        filled: true, //
        fillColor: enabled
            ? _secondaryColor.withOpacity(0.5)
            : Colors.grey.shade200, //
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 14), //
        counterText: "", //
      ),
      maxLines: 1, //
    );
  }
}