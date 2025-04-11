import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../state/app_state.dart';
import '/screens/expense_manager.dart';

class UpdateExpenseListScreen extends StatefulWidget {
  final String category;

  const UpdateExpenseListScreen({Key? key, required this.category}) : super(key: key);

  @override
  _UpdateExpenseListScreenState createState() => _UpdateExpenseListScreenState();
}

class _UpdateExpenseListScreenState extends State<UpdateExpenseListScreen> with SingleTickerProviderStateMixin {
  final ValueNotifier<List<TextEditingController>> controllers = ValueNotifier([]);
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _buttonScaleAnimation;

  @override
  void initState() {
    super.initState();
    if (widget.category != "Chi phí biến đổi") {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Danh sách chi phí cố định được quản lý trong 'Thêm cố định tháng'")));
      });
    }

    _controller = AnimationController(duration: const Duration(milliseconds: 700), vsync: this);
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));
    _buttonScaleAnimation = TweenSequence([
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.95), weight: 50),
      TweenSequenceItem(tween: Tween<double>(begin: 0.95, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _controller.forward();
  }

  @override
  void dispose() {
    for (var controller in controllers.value) {
      controller.dispose();
    }
    _controller.dispose();
    super.dispose();
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                            splashRadius: 20,
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Chi phí biến đổi", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Colors.white)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                                child: Text("Tháng ${DateFormat('MMMM y', 'vi').format(appState.selectedDate)}", style: const TextStyle(fontSize: 12, color: Colors.white)),
                              ),
                            ],
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.add, color: Colors.white),
                        onPressed: () {
                          _controller.reset();
                          _controller.forward();
                          controllers.value.add(TextEditingController());
                          controllers.notifyListeners();
                        },
                        splashRadius: 20,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: FutureBuilder<List<Map<String, dynamic>>>(
                      future: ExpenseManager.loadAvailableVariableExpenses(appState),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (snapshot.hasData) {
                          controllers.value = snapshot.data!.map((item) => TextEditingController(text: item['name'])).toList();
                          if (controllers.value.isEmpty) controllers.value.add(TextEditingController());
                          return Column(
                            children: [
                              Expanded(
                                child: SlideTransition(
                                  position: _slideAnimation,
                                  child: FadeTransition(
                                    opacity: _fadeAnimation,
                                    child: ValueListenableBuilder(
                                      valueListenable: controllers,
                                      builder: (context, List<TextEditingController> controllerList, _) {
                                        return Card(
                                          elevation: 10,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                          child: controllerList.isEmpty
                                              ? const Center(child: Text("Chưa có mục chi phí biến đổi", style: TextStyle(fontSize: 16, color: Colors.grey)))
                                              : ListView.builder(
                                            itemCount: controllerList.length,
                                            itemBuilder: (context, index) {
                                              return Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                                                child: Row(
                                                  children: [
                                                    const Icon(Icons.list, size: 24, color: Color(0xFF1976D2)),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: TextField(
                                                        controller: controllerList[index],
                                                        decoration: InputDecoration(
                                                          labelText: "Chi phí biến đổi ${index + 1}",
                                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                                          focusedBorder: OutlineInputBorder(
                                                            borderRadius: BorderRadius.circular(8),
                                                            borderSide: const BorderSide(color: Color(0xFF1976D2)),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    ScaleTransition(
                                                      scale: _buttonScaleAnimation,
                                                      child: IconButton(
                                                        icon: const Icon(Icons.delete, color: Colors.red),
                                                        onPressed: () {
                                                          _controller.reset();
                                                          _controller.forward();
                                                          controllerList[index].dispose();
                                                          controllerList.removeAt(index);
                                                          controllers.notifyListeners();
                                                        },
                                                        splashRadius: 20,
                                                      ),
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
                              const SizedBox(height: 16),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 16.0),
                                child: ScaleTransition(
                                  scale: _buttonScaleAnimation,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF42A5F5),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      minimumSize: const Size(double.infinity, 50),
                                    ),
                                    onPressed: () => saveUpdatedList(appState),
                                    child: const Text("Lưu danh sách", style: TextStyle(color: Colors.white, fontSize: 16)),
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

  void saveUpdatedList(AppState appState) async {
    var box = Hive.box('expenseBox');
    String monthKey = DateFormat('yyyy-MM').format(appState.selectedDate);
    String key = appState.getKey('variableExpenseList_$monthKey');

    List<Map<String, dynamic>> updatedList = controllers.value
        .where((controller) => controller.text.isNotEmpty)
        .map((controller) => {'name': controller.text, 'amount': 0.0})
        .toList();

    List<String> jsonList = updatedList.map((item) => jsonEncode(item)).toList();
    await box.put(key, jsonList);

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Đã lưu danh sách chi phí biến đổi cho tháng")));
    Navigator.pop(context, updatedList);
  }
}