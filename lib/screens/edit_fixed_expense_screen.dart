import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../state/app_state.dart';
import '/screens/expense_manager.dart';

class EditFixedExpenseScreen extends StatefulWidget {
  const EditFixedExpenseScreen({Key? key}) : super(key: key);

  @override
  _EditFixedExpenseScreenState createState() => _EditFixedExpenseScreenState();
}

class _EditFixedExpenseScreenState extends State<EditFixedExpenseScreen> with SingleTickerProviderStateMixin {
  final TextEditingController amountController = TextEditingController();
  final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'VNĐ');
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _totalFadeAnimation;
  late Animation<double> _buttonScaleAnimation;

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
  }

  @override
  void dispose() {
    amountController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void showEditAmountDialog(int index, AppState appState) {
    amountController.text = appState.fixedExpenseList.value[index]['amount'].toString();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          "Chỉnh sửa số tiền - ${appState.fixedExpenseList.value[index]['name']}",
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        content: TextField(
          controller: amountController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: "Nhập số tiền",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          maxLines: 1,
          maxLength: 15, // Giới hạn số ký tự
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Hủy", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              double newAmount = double.tryParse(amountController.text) ?? 0.0;
              if (newAmount >= 0) {
                appState.fixedExpenseList.value[index]['amount'] = newAmount;
                await ExpenseManager.saveFixedExpenses(appState, appState.fixedExpenseList.value);
                double total = await ExpenseManager.updateTotalFixedExpense(appState, appState.fixedExpenseList.value);
                appState.setExpenses(total, appState.variableExpense);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Đã cập nhật số tiền")));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Số tiền không thể âm")));
              }
            },
            child: const Text("Lưu", style: TextStyle(color: Color(0xFF1976D2))),
          ),
        ],
      ),
    );
  }

  Future<void> deleteExpenseItem(int index, AppState appState) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Xác nhận xóa"),
        content: Text(
          "Bạn có chắc muốn xóa '${appState.fixedExpenseList.value[index]['name']}' không?",
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Hủy", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Xóa", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      appState.fixedExpenseList.value.removeAt(index);
      await ExpenseManager.saveFixedExpenses(appState, appState.fixedExpenseList.value);
      double total = await ExpenseManager.updateTotalFixedExpense(appState, appState.fixedExpenseList.value);
      appState.setExpenses(total, appState.variableExpense);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Đã xóa khoản chi phí")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      body: Stack(
        children: [
          Container(
            height: MediaQuery.of(context).size.height * 0.25,
            color: const Color(0xFF1976D2).withOpacity(0.9),
          ),
          SafeArea(
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
                                    "Chi phí cố định",
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
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: FutureBuilder<List<Map<String, dynamic>>>(
                      future: ExpenseManager.loadFixedExpenses(appState),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (snapshot.hasData) {
                          appState.fixedExpenseList.value = snapshot.data!;
                          return Column(
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
                                          'Tổng chi phí cố định',
                                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Flexible(
                                          child: Text(
                                            currencyFormat.format(appState.fixedExpense),
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
                              Expanded(
                                child: SlideTransition(
                                  position: _slideAnimation,
                                  child: FadeTransition(
                                    opacity: _fadeAnimation,
                                    child: ValueListenableBuilder(
                                      valueListenable: appState.fixedExpenseList,
                                      builder: (context, List<Map<String, dynamic>> expenses, _) {
                                        return Card(
                                          elevation: 10,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                          child: expenses.isEmpty
                                              ? const Center(
                                            child: Text(
                                              "Chưa có chi phí cố định",
                                              style: TextStyle(fontSize: 16, color: Colors.grey),
                                            ),
                                          )
                                              : ListView.builder(
                                            itemCount: expenses.length,
                                            itemBuilder: (context, index) {
                                              double amount = expenses[index]['amount'] ?? 0.0;
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
                                                              expenses[index]['name'],
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
                                                            onPressed: () => showEditAmountDialog(index, appState),
                                                          ),
                                                        ),
                                                        ScaleTransition(
                                                          scale: _buttonScaleAnimation,
                                                          child: IconButton(
                                                            icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                                                            onPressed: () => deleteExpenseItem(index, appState),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }
                        return const Center(child: Text("Không có dữ liệu"));
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}