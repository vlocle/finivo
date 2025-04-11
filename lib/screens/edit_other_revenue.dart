import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '/screens/revenue_manager.dart';

class EditOtherRevenueScreen extends StatefulWidget {
  final VoidCallback onUpdate;
  EditOtherRevenueScreen({required this.onUpdate});

  @override
  _EditOtherRevenueScreenState createState() => _EditOtherRevenueScreenState();
}

class _EditOtherRevenueScreenState extends State<EditOtherRevenueScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 700), vsync: this);
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));
    _controller.forward();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _addTransaction(AppState appState) {
    double amount = double.tryParse(_amountController.text) ?? 0.0;
    String description = _descriptionController.text.trim();
    if (amount > 0 && description.isNotEmpty) {
      // Tạo danh sách mới để kích hoạt ValueNotifier
      appState.otherRevenueTransactions.value = [
        ...appState.otherRevenueTransactions.value,
        {'amount': amount, 'description': description}
      ];
      RevenueManager.saveOtherRevenueTransactions(appState, appState.otherRevenueTransactions.value);
      _amountController.clear();
      _descriptionController.clear();
    }
  }

  void _editTransaction(AppState appState, int index) {
    _amountController.text = appState.otherRevenueTransactions.value[index]['amount'].toString();
    _descriptionController.text = appState.otherRevenueTransactions.value[index]['description'];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chỉnh sửa giao dịch'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _amountController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Số tiền')),
            TextField(controller: _descriptionController, decoration: const InputDecoration(labelText: 'Mô tả')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          TextButton(
            onPressed: () {
              double newAmount = double.tryParse(_amountController.text) ?? 0.0;
              String newDescription = _descriptionController.text.trim();
              if (newAmount > 0 && newDescription.isNotEmpty) {
                appState.otherRevenueTransactions.value = [
                  for (int i = 0; i < appState.otherRevenueTransactions.value.length; i++)
                    i == index ? {'amount': newAmount, 'description': newDescription} : appState.otherRevenueTransactions.value[i]
                ];
                RevenueManager.saveOtherRevenueTransactions(appState, appState.otherRevenueTransactions.value);
                Navigator.pop(context);
              }
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  void _deleteTransaction(AppState appState, int index) {
    appState.otherRevenueTransactions.value = [
      for (int i = 0; i < appState.otherRevenueTransactions.value.length; i++)
        if (i != index) appState.otherRevenueTransactions.value[i]
    ];
    RevenueManager.saveOtherRevenueTransactions(appState, appState.otherRevenueTransactions.value);
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    return Scaffold(
      body: Stack(
        children: [
          Container(height: MediaQuery.of(context).size.height * 0.25, color: const Color(0xFF1976D2).withOpacity(0.9)),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
                      const SizedBox(width: 12),
                      const Text("Chỉnh sửa Doanh thu khác", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Colors.white)),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: Card(
                          elevation: 10,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextField(
                                  controller: _amountController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(labelText: 'Số tiền', border: OutlineInputBorder()),
                                ),
                                const SizedBox(height: 10),
                                TextField(
                                  controller: _descriptionController,
                                  decoration: const InputDecoration(labelText: 'Mô tả', border: OutlineInputBorder()),
                                ),
                                const SizedBox(height: 20),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF42A5F5),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    minimumSize: const Size(double.infinity, 50),
                                  ),
                                  onPressed: () => _addTransaction(appState),
                                  child: const Text("Thêm giao dịch", style: TextStyle(color: Colors.white, fontSize: 16)),
                                ),
                                const SizedBox(height: 20),
                                const Divider(thickness: 2),
                                Expanded(
                                  child: ValueListenableBuilder(
                                    valueListenable: appState.otherRevenueTransactions,
                                    builder: (context, List<Map<String, dynamic>> transactions, _) {
                                      return ListView.builder(
                                        itemCount: transactions.length,
                                        itemBuilder: (context, index) {
                                          return Card(
                                            child: ListTile(
                                              title: Text(currencyFormat.format(transactions[index]['amount']), style: const TextStyle(fontWeight: FontWeight.bold)),
                                              subtitle: Text(transactions[index]['description']),
                                              trailing: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  IconButton(
                                                    icon: const Icon(Icons.edit, color: Colors.blue),
                                                    onPressed: () => _editTransaction(appState, index),
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(Icons.delete, color: Colors.red),
                                                    onPressed: () => _deleteTransaction(appState, index),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
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