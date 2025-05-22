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
  final TextEditingController _totalController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
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
    _totalController.dispose();
    _nameController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _addTransaction(AppState appState) {
    double total = double.tryParse(_totalController.text) ?? 0.0;
    String name = _nameController.text.trim();
    if (total > 0 && name.isNotEmpty) {
      appState.otherRevenueTransactions.value = [
        ...appState.otherRevenueTransactions.value,
        {'name': name, 'total': total, 'quantity': 1.0}
      ];
      RevenueManager.saveOtherRevenueTransactions(appState, appState.otherRevenueTransactions.value);
      _totalController.clear();
      _nameController.clear();
      widget.onUpdate(); // Gọi callback để cập nhật giao diện
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Vui lòng nhập đầy đủ thông tin: Tên và Số tiền phải hợp lệ')),
      );
    }
  }

  void _editTransaction(AppState appState, int index) {
    _totalController.text = (appState.otherRevenueTransactions.value[index]['total'] ?? appState.otherRevenueTransactions.value[index]['amount'] ?? 0.0).toString();
    _nameController.text = appState.otherRevenueTransactions.value[index]['name']?.toString() ?? appState.otherRevenueTransactions.value[index]['description']?.toString() ?? '';
    showDialog(
      context: context,
      builder: (context) => GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: AlertDialog(
          title: const Text('Chỉnh sửa giao dịch'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _totalController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Số tiền'),
                maxLines: 1,
                maxLength: 15,
              ),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Tên giao dịch'),
                maxLines: 2,
                maxLength: 100,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
            TextButton(
              onPressed: () {
                double newTotal = double.tryParse(_totalController.text) ?? 0.0;
                String newName = _nameController.text.trim();
                if (newTotal > 0 && newName.isNotEmpty) {
                  appState.otherRevenueTransactions.value = [
                    for (int i = 0; i < appState.otherRevenueTransactions.value.length; i++)
                      i == index ? {'name': newName, 'total': newTotal, 'quantity': 1.0} : appState.otherRevenueTransactions.value[i]
                  ];
                  RevenueManager.saveOtherRevenueTransactions(appState, appState.otherRevenueTransactions.value);
                  Navigator.pop(context);
                  widget.onUpdate(); // Gọi callback để cập nhật giao diện
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Vui lòng nhập đầy đủ thông tin: Tên và Số tiền phải hợp lệ')),
                  );
                }
              },
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteTransaction(AppState appState, int index) {
    appState.otherRevenueTransactions.value = [
      for (int i = 0; i < appState.otherRevenueTransactions.value.length; i++)
        if (i != index) appState.otherRevenueTransactions.value[i]
    ];
    RevenueManager.saveOtherRevenueTransactions(appState, appState.otherRevenueTransactions.value);
    widget.onUpdate(); // Gọi callback để cập nhật giao diện
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
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "Chỉnh sửa Doanh thu khác",
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Colors.white),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
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
                                    controller: _totalController,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'Số tiền',
                                      border: OutlineInputBorder(),
                                    ),
                                    maxLines: 1,
                                    maxLength: 15,
                                  ),
                                  const SizedBox(height: 10),
                                  TextField(
                                    controller: _nameController,
                                    decoration: const InputDecoration(
                                      labelText: 'Tên giao dịch',
                                      border: OutlineInputBorder(),
                                    ),
                                    maxLines: 2,
                                    maxLength: 100,
                                  ),
                                  const SizedBox(height: 20),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF42A5F5),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      minimumSize: Size(screenWidth - 32, 50),
                                    ),
                                    onPressed: () => _addTransaction(appState),
                                    child: const Text(
                                      "Thêm giao dịch",
                                      style: TextStyle(color: Colors.white, fontSize: 16),
                                      overflow: TextOverflow.ellipsis,
                                    ),
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
                                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                                title: Text(
                                                  currencyFormat.format(transactions[index]['total'] ?? transactions[index]['amount'] ?? 0.0),
                                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                                  overflow: TextOverflow.ellipsis,
                                                  maxLines: 1,
                                                ),
                                                subtitle: Text(
                                                  transactions[index]['name']?.toString() ?? transactions[index]['description']?.toString() ?? 'Không xác định',
                                                  overflow: TextOverflow.ellipsis,
                                                  maxLines: 2,
                                                ),
                                                trailing: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    IconButton(
                                                      icon: const Icon(Icons.edit, color: Colors.blue, size: 18),
                                                      onPressed: () => _editTransaction(appState, index),
                                                    ),
                                                    IconButton(
                                                      icon: const Icon(Icons.delete, color: Colors.red, size: 18),
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
      ),
    );
  }
}