import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  List<TextEditingController> controllers = [];
  List<FocusNode> focusNodes = [];
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Danh sách chi phí cố định được quản lý trong 'Thêm cố định tháng'")),
        );
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

    // Khởi tạo controllers và focusNodes
    final appState = Provider.of<AppState>(context, listen: false);
    ExpenseManager.loadAvailableVariableExpenses(appState).then((data) {
      setState(() {
        controllers = data.map((item) => TextEditingController(text: item['name'])).toList();
        focusNodes = data.map((_) => FocusNode()).toList();
        if (controllers.isEmpty) {
          controllers.add(TextEditingController());
          focusNodes.add(FocusNode());
        }
      });
    });
  }

  @override
  void dispose() {
    for (var controller in controllers) {
      controller.dispose();
    }
    for (var focusNode in focusNodes) {
      focusNode.dispose();
    }
    _controller.dispose();
    super.dispose();
  }

  void addController() {
    setState(() {
      _controller.reset();
      _controller.forward();
      controllers.add(TextEditingController());
      focusNodes.add(FocusNode());
    });
  }

  void removeController(int index) {
    setState(() {
      _controller.reset();
      _controller.forward();
      controllers[index].dispose();
      focusNodes[index].dispose();
      controllers.removeAt(index);
      focusNodes.removeAt(index);
    });
  }

  void saveUpdatedList(AppState appState) async {
    try {
      if (appState.userId == null) throw Exception('User ID không tồn tại');
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      String monthKey = DateFormat('yyyy-MM').format(appState.selectedDate);
      String key = appState.getKey('variableExpenseList_$monthKey');
      List<Map<String, dynamic>> updatedList = controllers
          .asMap()
          .entries
          .where((entry) => entry.value.text.isNotEmpty)
          .map((entry) => {'name': entry.value.text, 'amount': 0.0})
          .toList();
      await firestore
          .collection('users')
          .doc(appState.userId)
          .collection('expenses')
          .doc('variableList')
          .collection('monthly')
          .doc(key)
          .set({
        'products': updatedList,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Đã lưu danh sách chi phí biến đổi cho tháng")),
      );
      Navigator.pop(context, updatedList);
    } catch (e) {
      print("Error saving variable expense list: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Lỗi khi lưu dữ liệu: $e")),
      );
    }
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
                                          "Tháng ${DateFormat('MMMM y', 'vi').format(appState.selectedDate)}",
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
                          IconButton(
                            icon: const Icon(Icons.add, color: Colors.white, size: 18),
                            onPressed: addController,
                            splashRadius: 20,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: Card(
                            elevation: 10,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: controllers.isEmpty
                                ? const Center(
                              child: Text(
                                "Chưa có mục chi phí biến đổi",
                                style: TextStyle(fontSize: 16, color: Colors.grey),
                              ),
                            )
                                : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                              itemCount: controllers.length,
                              itemBuilder: (context, index) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Flexible(
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.list,
                                              size: 24,
                                              color: Color(0xFF1976D2),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: TextField(
                                                controller: controllers[index],
                                                focusNode: focusNodes[index],
                                                decoration: InputDecoration(
                                                  labelText: "Chi phí biến đổi ${index + 1}",
                                                  border: OutlineInputBorder(
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  focusedBorder: OutlineInputBorder(
                                                    borderRadius: BorderRadius.circular(8),
                                                    borderSide: const BorderSide(color: Color(0xFF1976D2)),
                                                  ),
                                                ),
                                                maxLines: 1,
                                                maxLength: 50,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      ScaleTransition(
                                        scale: _buttonScaleAnimation,
                                        child: IconButton(
                                          icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                                          onPressed: () => removeController(index),
                                          splashRadius: 20,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: ScaleTransition(
                          scale: _buttonScaleAnimation,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF42A5F5),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              minimumSize: Size(screenWidth - 32, 50),
                            ),
                            onPressed: () => saveUpdatedList(appState),
                            child: const Text(
                              "Lưu danh sách",
                              style: TextStyle(color: Colors.white, fontSize: 16),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
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