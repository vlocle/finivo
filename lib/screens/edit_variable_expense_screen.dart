import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../state/app_state.dart';
import '/screens/expense_manager.dart';

class EditVariableExpenseScreen extends StatefulWidget {
  const EditVariableExpenseScreen({Key? key}) : super(key: key);

  @override
  _EditVariableExpenseScreenState createState() => _EditVariableExpenseScreenState();
}

class _EditVariableExpenseScreenState extends State<EditVariableExpenseScreen> with SingleTickerProviderStateMixin {
  String? selectedExpense;
  final TextEditingController amountController = TextEditingController();
  final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'VNĐ');
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _totalFadeAnimation;
  late Animation<double> _buttonScaleAnimation;
  List<Map<String, dynamic>> variableExpenses = [];
  List<Map<String, dynamic>> availableExpenses = [];
  bool isLoading = true;
  bool hasError = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 700), vsync: this);
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));
    _totalFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _controller, curve: const Interval(0.3, 1.0, curve: Curves.easeIn)));
    _buttonScaleAnimation = TweenSequence([
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.95), weight: 50),
      TweenSequenceItem(tween: Tween<double>(begin: 0.95, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _controller.forward();

    // Tải dữ liệu trong initState
    final appState = Provider.of<AppState>(context, listen: false);
    Future.wait([
      ExpenseManager.loadVariableExpenses(appState),
      ExpenseManager.loadAvailableVariableExpenses(appState),
    ]).then((data) {
      setState(() {
        variableExpenses = data[0];
        availableExpenses = data[1];
        appState.variableExpenseList.value = data[0];
        isLoading = false;
      });
    }).catchError((e) {
      setState(() {
        hasError = true;
        isLoading = false;
      });
      print("Error loading expenses: $e");
    });
  }

  @override
  void dispose() {
    amountController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void addExpense(AppState appState) {
    if (selectedExpense == null || amountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Vui lòng chọn khoản chi phí và nhập số tiền!")));
      return;
    }
    double amount = double.tryParse(amountController.text) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Số tiền phải lớn hơn 0!")));
      return;
    }
    setState(() {
      int existingIndex = appState.variableExpenseList.value.indexWhere((e) => e['name'] == selectedExpense);
      if (existingIndex != -1) {
        appState.variableExpenseList.value[existingIndex]['amount'] += amount;
      } else {
        appState.variableExpenseList.value.add({"name": selectedExpense, "amount": amount});
      }
      variableExpenses = List.from(appState.variableExpenseList.value);
      ExpenseManager.saveVariableExpenses(appState, appState.variableExpenseList.value);
      ExpenseManager.updateTotalVariableExpense(appState, appState.variableExpenseList.value).then((total) {
        appState.setExpenses(appState.fixedExpense, total);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Đã thêm khoản chi phí: $selectedExpense")));
        selectedExpense = null;
        amountController.clear();
      });
    });
  }

  void removeExpense(int index, AppState appState) {
    setState(() {
      appState.variableExpenseList.value.removeAt(index);
      variableExpenses = List.from(appState.variableExpenseList.value);
      ExpenseManager.saveVariableExpenses(appState, appState.variableExpenseList.value);
      ExpenseManager.updateTotalVariableExpense(appState, appState.variableExpenseList.value).then((total) {
        appState.setExpenses(appState.fixedExpense, total);
      });
    });
  }

  void editExpense(int index, AppState appState) {
    amountController.text = appState.variableExpenseList.value[index]['amount'].toString();
    showDialog(
      context: context,
      builder: (context) => GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text(
            "Chỉnh sửa số tiền - ${appState.variableExpenseList.value[index]['name']}",
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          content: TextField(
            controller: amountController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: "Nhập số tiền mới",
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            maxLines: 1,
            maxLength: 15,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Hủy", style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                double newAmount = double.tryParse(amountController.text) ?? 0.0;
                if (newAmount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Số tiền phải lớn hơn 0!")));
                } else {
                  setState(() {
                    appState.variableExpenseList.value[index]['amount'] = newAmount;
                    variableExpenses = List.from(appState.variableExpenseList.value);
                    ExpenseManager.saveVariableExpenses(appState, appState.variableExpenseList.value);
                    ExpenseManager.updateTotalVariableExpense(appState, appState.variableExpenseList.value).then((total) {
                      appState.setExpenses(appState.fixedExpense, total);
                      Navigator.pop(context);
                    });
                  });
                }
              },
              child: const Text("Lưu", style: TextStyle(color: Color(0xFF1976D2))),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final screenWidth = MediaQuery.of(context).size.width;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        body: Stack(
          children: [
            Container(
              height: MediaQuery.of(context).size.height * 0.25,
              color: const Color(0xFF1976D2).withOpacity(0.9),
            ),
            SafeArea(
              child: SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                                  onPressed: () => Navigator.pop(context),
                                  splashRadius: 20,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        "Chi phí biến đổi",
                                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Colors.white),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          "Ngày ${DateFormat('d MMMM y', 'vi').format(appState.selectedDate)}",
                                          style: const TextStyle(fontSize: 12, color: Colors.white),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      ),
                                    ],
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
                          ? const Center(child: CircularProgressIndicator())
                          : hasError
                          ? const Center(child: Text("Có lỗi xảy ra khi tải dữ liệu"))
                          : Column(
                        children: [
                          FadeTransition(
                            opacity: _totalFadeAnimation,
                            child: Card(
                              elevation: 6,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Tổng chi phí biến đổi',
                                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Flexible(
                                      child: Text(
                                        currencyFormat.format(appState.variableExpense),
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF1976D2),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                DropdownButton<String>(
                                  value: selectedExpense,
                                  hint: const Text(
                                    "Chọn khoản chi phí",
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  isExpanded: true,
                                  onChanged: (String? newValue) => setState(() => selectedExpense = newValue),
                                  items: availableExpenses.isEmpty
                                      ? [
                                    const DropdownMenuItem<String>(
                                      value: null,
                                      child: Text(
                                        "Chưa có khoản chi phí nào",
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    )
                                  ]
                                      : availableExpenses
                                      .map(
                                        (expense) => DropdownMenuItem<String>(
                                      value: expense['name'],
                                      child: Text(
                                        expense['name'],
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ),
                                  )
                                      .toList(),
                                ),
                                const SizedBox(height: 16),
                                TextField(
                                  controller: amountController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: "Nhập số tiền",
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  maxLines: 1,
                                  maxLength: 15,
                                ),
                                const SizedBox(height: 16),
                                Center(
                                  child: ScaleTransition(
                                    scale: _buttonScaleAnimation,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF42A5F5),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        minimumSize: Size(screenWidth - 32, 50),
                                      ),
                                      onPressed: () => addExpense(appState),
                                      child: const Text(
                                        "Thêm chi phí",
                                        style: TextStyle(color: Colors.white, fontSize: 16),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SlideTransition(
                            position: _slideAnimation,
                            child: FadeTransition(
                              opacity: _fadeAnimation,
                              child: Card(
                                elevation: 10,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                child: variableExpenses.isEmpty
                                    ? const Center(
                                  child: Text(
                                    "Chưa có chi phí biến đổi",
                                    style: TextStyle(fontSize: 16, color: Colors.grey),
                                  ),
                                )
                                    : ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                                  itemCount: variableExpenses.length,
                                  itemBuilder: (context, index) {
                                    double amount = variableExpenses[index]['amount'] ?? 0.0;
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Flexible(
                                            child: Row(
                                              children: [
                                                const Icon(
                                                  Icons.attach_money,
                                                  size: 24,
                                                  color: Color(0xFF1976D2),
                                                ),
                                                const SizedBox(width: 12),
                                                Flexible(
                                                  child: Text(
                                                    variableExpenses[index]['name'],
                                                    style: const TextStyle(fontSize: 16),
                                                    overflow: TextOverflow.ellipsis,
                                                    maxLines: 1,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  currencyFormat.format(amount),
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                  maxLines: 1,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              ScaleTransition(
                                                scale: _buttonScaleAnimation,
                                                child: IconButton(
                                                  icon: const Icon(Icons.edit, color: Color(0xFF1976D2), size: 18),
                                                  onPressed: () => editExpense(index, appState),
                                                ),
                                              ),
                                              ScaleTransition(
                                                scale: _buttonScaleAnimation,
                                                child: IconButton(
                                                  icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                                                  onPressed: () => removeExpense(index, appState),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
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
}