import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
// import 'package:marquee/marquee.dart'; // Marquee can be removed if not desired for total display
import '../state/app_state.dart';
import '/screens/expense_manager.dart'; // Ensure this path is correct
import 'package:google_fonts/google_fonts.dart';

class EditVariableExpenseScreen extends StatefulWidget {
  const EditVariableExpenseScreen({Key? key}) : super(key: key);

  @override
  _EditVariableExpenseScreenState createState() =>
      _EditVariableExpenseScreenState();
}

class _EditVariableExpenseScreenState extends State<EditVariableExpenseScreen>
    with SingleTickerProviderStateMixin {
  String? selectedExpense;
  final TextEditingController amountController = TextEditingController();
  final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'VNĐ');
  final NumberFormat _inputPriceFormatter = NumberFormat("#,##0", "vi_VN");


  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _totalFadeAnimation;
  late Animation<double> _buttonScaleAnimation;

  List<Map<String, dynamic>> variableExpenses = []; // Stores expenses for the current day
  List<Map<String, dynamic>> availableExpenses = []; // Stores predefined expense names

  bool isLoading = true;
  bool hasError = false;

  // Updated Color Palette (Consistent with other expense screens)
  static const Color _appBarColor = Color(0xFFE53935); // Red for Expense header area
  static const Color _accentColor = Color(0xFFD32F2F); // Deep Red for emphasis/delete
  static const Color _secondaryColor = Color(0xFFF1F5F9); // Light background
  static const Color _textColorPrimary = Color(0xFF1D2D3A);
  static const Color _textColorSecondary = Color(0xFF6E7A8A);
  static const Color _cardBackgroundColor = Colors.white;
  static const Color _editButtonColor = Color(0xFF0A7AFF); // Blue for edit actions

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
        duration: const Duration(milliseconds: 700), vsync: this);
    _slideAnimation = Tween<Offset>(
        begin: const Offset(0, 0.5), end: Offset.zero)
        .animate(CurvedAnimation(
        parent: _animationController, curve: Curves.easeOut));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _animationController, curve: Curves.easeIn));
    _totalFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
            parent: _animationController,
            curve: const Interval(0.3, 1.0, curve: Curves.easeIn)));
    _buttonScaleAnimation = TweenSequence([
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.95), weight: 50),
      TweenSequenceItem(tween: Tween<double>(begin: 0.95, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(
        parent: _animationController, curve: Curves.easeInOut));

    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    if (!mounted) return;
    setState(() {
      isLoading = true;
      hasError = false;
    });
    try {
      final appState = Provider.of<AppState>(context, listen: false);
      final results = await Future.wait([
        ExpenseManager.loadVariableExpenses(appState),
        ExpenseManager.loadAvailableVariableExpenses(appState),
      ]);
      if (mounted) {
        setState(() {
          variableExpenses = results[0];
          availableExpenses = results[1];
          appState.variableExpenseList.value = List.from(results[0]);
          isLoading = false;
          _animationController.forward();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          hasError = true;
          isLoading = false;
        });
        // Thử tải từ Hive
        final appState = Provider.of<AppState>(context, listen: false);
        final String dateKey = DateFormat('yyyy-MM-dd').format(appState.selectedDate);
        final String monthKey = DateFormat('yyyy-MM').format(appState.selectedDate);
        final String hiveVariableKey = '${appState.userId}-variableExpenses-$dateKey';
        final String hiveListKey = '${appState.userId}-variableExpenseList-$monthKey';
        final variableExpensesBox = Hive.box('variableExpensesBox');
        final variableExpenseListBox = Hive.box('variableExpenseListBox');
        final rawCachedVariable = variableExpensesBox.get(hiveVariableKey) ?? [];
        final rawCachedList = variableExpenseListBox.get(hiveListKey) ?? [];

        List<Map<String, dynamic>> castedVariableExpenses = [];
        List<Map<String, dynamic>> castedAvailableExpenses = [];

        if (rawCachedVariable != null && rawCachedVariable is List) {
          for (var item in rawCachedVariable) {
            if (item is Map) {
              castedVariableExpenses.add(
                  Map<String, dynamic>.fromEntries(
                      item.entries.map((entry) => MapEntry(entry.key.toString(), entry.value))
                  )
              );
            }
          }
        }

        if (rawCachedList != null && rawCachedList is List) {
          for (var item in rawCachedList) {
            if (item is Map) {
              castedAvailableExpenses.add(
                  Map<String, dynamic>.fromEntries(
                      item.entries.map((entry) => MapEntry(entry.key.toString(), entry.value))
                  )
              );
            }
          }
        }


        if (castedVariableExpenses.isNotEmpty || castedAvailableExpenses.isNotEmpty) { // [cite: 28] // Điều kiện có thể giữ nguyên hoặc chỉ cần một trong hai có dữ liệu
          if (mounted) {
            setState(() {
              variableExpenses = castedVariableExpenses; // [cite: 28]
              availableExpenses = castedAvailableExpenses; // [cite: 28]
              appState.variableExpenseList.value = List.from(castedVariableExpenses); // [cite: 28] // Cập nhật AppState
              isLoading = false; // [cite: 28]
              hasError = false; // Quan trọng: đặt lại hasError thành false
              _animationController.forward(); // [cite: 28]
            });
          }
        }
      }
      print("Error loading expenses in EditVariableExpenseScreen: $e");
      if (mounted && hasError) {
        _showStyledSnackBar("Lỗi tải dữ liệu chi phí.", isError: true);
      }
    }
  }


  @override
  void dispose() {
    amountController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _showStyledSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: isError ? _accentColor : _appBarColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(10),
      ),
    );
  }

  void addExpense(AppState appState) {
    if (selectedExpense == null) {
      _showStyledSnackBar("Vui lòng chọn một khoản chi phí!", isError: true);
      return;
    }
    if (amountController.text.isEmpty) {
      _showStyledSnackBar("Vui lòng nhập số tiền!", isError: true);
      return;
    }

    double amount = double.tryParse(amountController.text.replaceAll('.', '').replaceAll(',', '')) ?? 0.0;
    if (amount <= 0) {
      _showStyledSnackBar("Số tiền phải lớn hơn 0!", isError: true);
      return;
    }

    if (!mounted) return;

    setState(() {
      // Operate on a copy of appState's list to avoid direct modification issues with ValueNotifier
      List<Map<String, dynamic>> currentVariableExpenses = List.from(appState.variableExpenseList.value);
      int existingIndex = currentVariableExpenses.indexWhere((e) => e['name'] == selectedExpense);

      if (existingIndex != -1) {
        currentVariableExpenses[existingIndex]['amount'] = (currentVariableExpenses[existingIndex]['amount'] ?? 0.0) + amount;
      } else {
        currentVariableExpenses.add({"name": selectedExpense, "amount": amount, "date": DateTime.now().toIso8601String()});
      }

      appState.variableExpenseList.value = currentVariableExpenses; // Update AppState
      variableExpenses = List.from(currentVariableExpenses); // Update local list for UI

      ExpenseManager.saveVariableExpenses(appState, currentVariableExpenses).then((_) {
        return ExpenseManager.updateTotalVariableExpense(appState, currentVariableExpenses);
      }).then((total) {
        appState.setExpenses(appState.fixedExpense, total); // Update total in AppState
        _showStyledSnackBar("Đã thêm: $selectedExpense");
        if(mounted) {
          setState(() {
            selectedExpense = null; // Reset dropdown
            amountController.clear();
          });
        }
      }).catchError((e) {
        _showStyledSnackBar("Lỗi khi lưu chi phí: $e", isError: true);
      });
    });
    FocusScope.of(context).unfocus();
  }

  void removeExpense(int index, AppState appState) {
    if (index < 0 || index >= appState.variableExpenseList.value.length) return;
    if (!mounted) return;

    final removedExpenseName = appState.variableExpenseList.value[index]['name'];

    setState(() {
      List<Map<String, dynamic>> currentVariableExpenses = List.from(appState.variableExpenseList.value);
      currentVariableExpenses.removeAt(index);

      appState.variableExpenseList.value = currentVariableExpenses;
      variableExpenses = List.from(currentVariableExpenses);

      ExpenseManager.saveVariableExpenses(appState, currentVariableExpenses).then((_) {
        return ExpenseManager.updateTotalVariableExpense(appState, currentVariableExpenses);
      }).then((total) {
        appState.setExpenses(appState.fixedExpense, total);
        _showStyledSnackBar("Đã xóa: $removedExpenseName");
      }).catchError((e) {
        _showStyledSnackBar("Lỗi khi xóa chi phí: $e", isError: true);
      });
    });
  }

  void editExpense(int index, AppState appState) {
    if (index < 0 || index >= appState.variableExpenseList.value.length) return;
    final expenseToEdit = appState.variableExpenseList.value[index];
    amountController.text = _inputPriceFormatter.format(expenseToEdit['amount'] ?? 0.0);

    showDialog(
      context: context,
      builder: (dialogContext) => GestureDetector(
        onTap: () => FocusScope.of(dialogContext).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
          title: Text(
            "Chỉnh sửa: ${expenseToEdit['name']}",
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: _textColorPrimary),
          ),
          content: TextField(
            controller: amountController,
            keyboardType: TextInputType.numberWithOptions(decimal: false),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              TextInputFormatter.withFunction(
                    (oldValue, newValue) {
                  if (newValue.text.isEmpty) return newValue;
                  final String plainNumberText = newValue.text.replaceAll('.', '').replaceAll(',', '');
                  final number = int.tryParse(plainNumberText);
                  if (number == null) return oldValue;
                  final formattedText = _inputPriceFormatter.format(number);
                  return newValue.copyWith(
                    text: formattedText,
                    selection: TextSelection.collapsed(offset: formattedText.length),
                  );
                },
              ),
            ],
            decoration: InputDecoration(
                labelText: "Nhập số tiền mới",
                labelStyle: GoogleFonts.poppins(color: _textColorSecondary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0)),
                filled: true,
                fillColor: _secondaryColor.withOpacity(0.7),
                prefixIcon: Icon(Icons.monetization_on_outlined, color: _appBarColor)
            ),
            maxLines: 1,
            maxLength: 15,
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          actions: [
            TextButton(
              onPressed: () {
                amountController.clear();
                Navigator.pop(dialogContext);
              },
              child: Text("Hủy", style: GoogleFonts.poppins(color: _textColorSecondary, fontWeight: FontWeight.w500)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _appBarColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              onPressed: () {
                double newAmount = double.tryParse(amountController.text.replaceAll('.', '').replaceAll(',', '')) ?? 0.0;
                if (newAmount <= 0) {
                  _showStyledSnackBar("Số tiền phải lớn hơn 0!", isError: true);
                } else {
                  if (!mounted) return;
                  setState(() {
                    List<Map<String, dynamic>> currentVariableExpenses = List.from(appState.variableExpenseList.value);
                    currentVariableExpenses[index]['amount'] = newAmount;

                    appState.variableExpenseList.value = currentVariableExpenses;
                    variableExpenses = List.from(currentVariableExpenses);

                    ExpenseManager.saveVariableExpenses(appState, currentVariableExpenses).then((_) {
                      return ExpenseManager.updateTotalVariableExpense(appState, currentVariableExpenses);
                    }).then((total) {
                      appState.setExpenses(appState.fixedExpense, total);
                      amountController.clear();
                      Navigator.pop(dialogContext);
                      _showStyledSnackBar("Đã cập nhật: ${expenseToEdit['name']}");
                    }).catchError((e){
                      _showStyledSnackBar("Lỗi khi cập nhật: $e", isError: true);
                      Navigator.pop(dialogContext);
                    });
                  });
                }
              },
              child: Text("Lưu", style: GoogleFonts.poppins()),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>(); // listen:false if only using for actions
    final screenWidth = MediaQuery.of(context).size.width;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        backgroundColor: _secondaryColor,
        body: Stack(
          children: [
            Container(
              height: MediaQuery.of(context).size.height * 0.25,
              color: _appBarColor.withOpacity(0.9), // Use expense color
            ),
            SafeArea(
              child: SingleChildScrollView( // Ensures content is scrollable
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                            splashRadius: 20,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Chi phí biến đổi",
                                  style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w600, color: Colors.white),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.25),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    "Ngày ${DateFormat('d MMMM y', 'vi').format(appState.selectedDate)}",
                                    style: GoogleFonts.poppins(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: isLoading
                          ? Center(child: Padding(padding: const EdgeInsets.all(20.0), child: CircularProgressIndicator(color: _appBarColor)))
                          : hasError
                          ? Center(child: Padding(padding: const EdgeInsets.all(20.0),child: Text("Có lỗi xảy ra khi tải dữ liệu", style: GoogleFonts.poppins(color: _textColorSecondary))))
                          : Column( // Main content column
                        children: [
                          // Total Expense Card
                          FadeTransition(
                            opacity: _totalFadeAnimation,
                            child: Card(
                              elevation: 4,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                              color: _cardBackgroundColor,
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Tổng chi phí biến đổi',
                                      style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w600, color: _textColorPrimary),
                                    ),
                                    Flexible(
                                      child: Text( // Using Text directly for total
                                        currencyFormat.format(appState.variableExpense), // Directly use variableExpense from AppState
                                        style: GoogleFonts.poppins(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: _accentColor, // Expense accent color
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Input Section Card
                          Card(
                            elevation: 3,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            color: _cardBackgroundColor,
                            child: Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Thêm chi phí mới",
                                    style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: _appBarColor),
                                  ),
                                  const SizedBox(height: 16),
                                  DropdownButtonFormField<String>(
                                    value: selectedExpense,
                                    hint: Text("Chọn khoản chi phí", style: GoogleFonts.poppins(color: _textColorSecondary)),
                                    isExpanded: true,
                                    decoration: InputDecoration(
                                      prefixIcon: Icon(Icons.category_outlined, color: _appBarColor, size: 22),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                      filled: true,
                                      fillColor: _secondaryColor.withOpacity(0.5),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                    ),
                                    items: availableExpenses.isEmpty
                                        ? [
                                      const DropdownMenuItem<String>(
                                        value: null,
                                        child: Text("Chưa có khoản chi phí nào", style: TextStyle(fontStyle: FontStyle.italic)),
                                      )
                                    ]
                                        : availableExpenses.map((expense) => DropdownMenuItem<String>(
                                      value: expense['name'],
                                      child: Text(expense['name'], overflow: TextOverflow.ellipsis, style: GoogleFonts.poppins(color: _textColorPrimary)),
                                    ))
                                        .toList(),
                                    onChanged: (String? newValue) => setState(() => selectedExpense = newValue),
                                    style: GoogleFonts.poppins(color: _textColorPrimary, fontSize: 16),
                                    icon: Icon(Icons.arrow_drop_down_circle_outlined, color: _appBarColor),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  const SizedBox(height: 16),
                                  _buildModernTextField(
                                    controller: amountController,
                                    labelText: "Nhập số tiền",
                                    prefixIconData: Icons.monetization_on_outlined,
                                    keyboardType: TextInputType.numberWithOptions(decimal: false),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      TextInputFormatter.withFunction(
                                            (oldValue, newValue) {
                                          if (newValue.text.isEmpty) return newValue;
                                          final String plainNumberText = newValue.text.replaceAll('.', '').replaceAll(',', '');
                                          final number = int.tryParse(plainNumberText);
                                          if (number == null) return oldValue;
                                          final formattedText = _inputPriceFormatter.format(number);
                                          return newValue.copyWith(
                                            text: formattedText,
                                            selection: TextSelection.collapsed(offset: formattedText.length),
                                          );
                                        },
                                      ),
                                    ],
                                    maxLength: 15,
                                  ),
                                  const SizedBox(height: 24),
                                  Center(
                                    child: ScaleTransition(
                                      scale: _buttonScaleAnimation,
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: _appBarColor,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          minimumSize: Size(screenWidth * 0.8, 52), // Make button wider
                                          padding: const EdgeInsets.symmetric(vertical: 14),
                                        ),
                                        onPressed: () => addExpense(appState),
                                        child: Text(
                                          "Thêm chi phí",
                                          style: GoogleFonts.poppins(fontSize: 16.5, fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          // History List Section Title
                          if (variableExpenses.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8.0, top: 10.0),
                              child: Text(
                                "Chi phí đã thêm trong ngày",
                                style: GoogleFonts.poppins(fontSize: 19, fontWeight: FontWeight.w700, color: _textColorPrimary),
                              ),
                            ),
                          // History List
                          SlideTransition(
                            position: _slideAnimation,
                            child: FadeTransition(
                              opacity: _fadeAnimation,
                              child: variableExpenses.isEmpty
                                  ? Padding( // Show message if list is empty but not loading
                                padding: const EdgeInsets.symmetric(vertical: 30.0),
                                child: Center(
                                  child: Column(
                                    children: [
                                      Icon(Icons.hourglass_empty_rounded, size: 50, color: Colors.grey.shade400),
                                      SizedBox(height:10),
                                      Text(
                                        "Chưa có chi phí biến đổi nào được thêm hôm nay.",
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.poppins(fontSize: 16, color: _textColorSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                                  : ListView.builder( // No outer card, each item is a card
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: variableExpenses.length,
                                itemBuilder: (context, index) {
                                  final expense = variableExpenses[index];
                                  double amount = expense['amount'] ?? 0.0;
                                  return Card(
                                    elevation: 1.5,
                                    margin: const EdgeInsets.symmetric(vertical: 6.0),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                                    color: _cardBackgroundColor,
                                    child: ListTile(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                                      visualDensity: VisualDensity.adaptivePlatformDensity,
                                      leading: CircleAvatar(
                                        backgroundColor: _appBarColor.withOpacity(0.15),
                                        child: Icon(Icons.flare_outlined, color: _appBarColor, size: 22),
                                        radius: 20,
                                      ),
                                      title: Text(
                                        expense['name'],
                                        style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: _textColorPrimary),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      subtitle: Text(
                                        currencyFormat.format(amount),
                                        style: GoogleFonts.poppins(
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w500,
                                          color: _textColorSecondary.withOpacity(0.9),
                                        ),
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          ScaleTransition(
                                            scale: _buttonScaleAnimation,
                                            child: IconButton(
                                              icon: Icon(Icons.edit_note_outlined, color: _editButtonColor, size: 22),
                                              onPressed: () => editExpense(index, appState),
                                              splashRadius: 20,
                                              tooltip: "Chỉnh sửa",
                                            ),
                                          ),
                                          ScaleTransition(
                                            scale: _buttonScaleAnimation,
                                            child: IconButton(
                                              icon: Icon(Icons.delete_outline_rounded, color: _accentColor, size: 22),
                                              onPressed: () => removeExpense(index, appState),
                                              splashRadius: 20,
                                              tooltip: "Xóa",
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
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

  Widget _buildModernTextField({ // Helper for consistency in this screen
    required TextEditingController controller,
    required String labelText,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    int? maxLength,
    IconData? prefixIconData,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLength: maxLength,
      style: GoogleFonts.poppins(color: _textColorPrimary, fontWeight: FontWeight.w500, fontSize: 16),
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: GoogleFonts.poppins(color: _textColorSecondary),
        prefixIcon: prefixIconData != null ? Icon(prefixIconData, color: _appBarColor, size: 22) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _appBarColor, width: 1.5)),
        filled: true,
        fillColor: _secondaryColor.withOpacity(0.5), // Slightly different fill
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        counterText: "",
      ),
      maxLines: 1,
    );
  }
}
