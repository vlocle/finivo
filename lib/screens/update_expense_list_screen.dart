import 'dart:convert'; // Not directly used in this file's current logic, but often seen with Firestore
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For input formatters if needed
import 'package:hive/hive.dart'; // Used in _loadProducts
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../state/app_state.dart';
import '/screens/expense_manager.dart'; // Ensure this path is correct
import 'package:google_fonts/google_fonts.dart';

class UpdateExpenseListScreen extends StatefulWidget {
  final String category;
  const UpdateExpenseListScreen({Key? key, required this.category})
      : super(key: key);

  @override
  _UpdateExpenseListScreenState createState() =>
      _UpdateExpenseListScreenState();
}

class _UpdateExpenseListScreenState extends State<UpdateExpenseListScreen>
    with SingleTickerProviderStateMixin {
  List<TextEditingController> controllers = [];
  List<FocusNode> focusNodes = [];
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _buttonScaleAnimation;
  bool _isLoading = true;
  bool hasError = false; // Ensure this declaration exists

  // Consistent color palette (themed for expenses)
  static const Color _appBarColor = Color(0xFFE53935); // Red for Expense header area
  static const Color _accentColor = Color(0xFFD32F2F); // Deep Red for delete/emphasis
  static const Color _secondaryColor = Color(0xFFF1F5F9); // Light background
  static const Color _textColorPrimary = Color(0xFF1D2D3A);
  static const Color _textColorSecondary = Color(0xFF6E7A8A);
  static const Color _cardBackgroundColor = Colors.white; // For input field backgrounds

  @override
  void initState() {
    super.initState();
    if (widget.category != "Chi phí biến đổi") {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    "Danh sách chi phí cố định được quản lý trong 'Thêm cố định tháng'",
                    style: GoogleFonts.poppins())),
          );
        }
      });
      _isLoading = false;
    }

    _animationController = AnimationController(
        duration: const Duration(milliseconds: 700), vsync: this);
    _slideAnimation = Tween<Offset>(
        begin: const Offset(0, 0.5), end: Offset.zero)
        .animate(CurvedAnimation(
        parent: _animationController, curve: Curves.easeOut));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _animationController, curve: Curves.easeIn));
    _buttonScaleAnimation = TweenSequence([
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.95), weight: 50),
      TweenSequenceItem(tween: Tween<double>(begin: 0.95, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(
        parent: _animationController, curve: Curves.easeInOut));

    if (widget.category == "Chi phí biến đổi") {
      _loadInitialExpenseNames();
    }
  }

  Future<void> _loadInitialExpenseNames() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      hasError = false;
    });
    try {
      final appState = Provider.of<AppState>(context, listen: false);
      final data = await ExpenseManager.loadAvailableVariableExpenses(appState);
      if (mounted) {
        setState(() {
          controllers = data.map((item) => TextEditingController(text: item['name']?.toString() ?? '')).toList();
          focusNodes = data.map((_) => FocusNode()).toList();
          if (controllers.isEmpty) {
            _addControllerInternal();
          }
          _isLoading = false;
          _animationController.forward();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          hasError = true;
        });
        // Thử tải từ Hive
        final appState = Provider.of<AppState>(context, listen: false);
        final String monthKey = DateFormat('yyyy-MM').format(appState.selectedDate);
        final String hiveKey = '${appState.userId}-variableExpenseList-$monthKey';
        final variableExpenseListBox = Hive.box('variableExpenseListBox');
        final cachedData = variableExpenseListBox.get(hiveKey);
        if (cachedData != null && mounted) {
          setState(() {
            controllers = List<Map<String, dynamic>>.from(cachedData)
                .map((item) => TextEditingController(text: item['name']?.toString() ?? ''))
                .toList();
            focusNodes = List<Map<String, dynamic>>.from(cachedData).map((_) => FocusNode()).toList();
            if (controllers.isEmpty) {
              _addControllerInternal();
            }
            _isLoading = false;
            hasError = false;
            _animationController.forward();
          });
        }
      }
      print("Error in _loadInitialExpenseNames: $e");
      if (hasError) {
        _showStyledSnackBar("Lỗi tải danh sách chi phí: $e", isError: true);
      }
    }
  }


  @override
  void dispose() {
    for (var controller in controllers) {
      controller.dispose();
    }
    for (var focusNode in focusNodes) {
      focusNode.dispose();
    }
    _animationController.dispose();
    super.dispose();
  }

  void _addControllerInternal() {
    controllers.add(TextEditingController());
    focusNodes.add(FocusNode());
  }

  void addController() {
    if (!mounted) return;
    setState(() {
      _animationController.reset();
      _animationController.forward();
      controllers.add(TextEditingController());
      focusNodes.add(FocusNode());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (focusNodes.isNotEmpty && mounted) {
        FocusScope.of(context).requestFocus(focusNodes.last);
      }
    });
  }

  void removeController(int index) {
    if (!mounted || index < 0 || index >= controllers.length) return;
    setState(() {
      controllers[index].dispose();
      focusNodes[index].dispose();
      controllers.removeAt(index);
      focusNodes.removeAt(index);
      if (controllers.isEmpty) {
        addController();
      }
    });
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

  void saveUpdatedList(AppState appState) async {
    if (!mounted) return;
    FocusScope.of(context).unfocus(); // [cite: 42]

    List<Map<String, dynamic>> updatedList = controllers
        .asMap()
        .entries
        .where((entry) => entry.value.text.trim().isNotEmpty)
        .map((entry) => {'name': entry.value.text.trim(), 'amount': 0.0}) // 'amount' có thể không cần thiết nếu Hive chỉ lưu 'name' cho danh sách này
        .toList(); // [cite: 43]

    final Set<String> names = {};
    for (final item in updatedList) {
      if (!names.add(item['name'].toString().toLowerCase())) {
        _showStyledSnackBar("Tên khoản chi '${item['name']}' bị trùng lặp. Vui lòng sửa lại.", isError: true); // [cite: 44]
        return; // [cite: 45]
      }
    }

    if (updatedList.isEmpty && controllers.any((c) => c.text.trim().isNotEmpty)) {
      _showStyledSnackBar("Vui lòng nhập ít nhất một tên chi phí hợp lệ.", isError: true); // [cite: 45]
      return; // [cite: 46]
    }
    if (updatedList.isEmpty && controllers.every((c) => c.text.trim().isEmpty)) {
      _showStyledSnackBar("Danh sách trống, không có gì để lưu.", isError: false); // [cite: 46]
      return; // [cite: 47]
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        content: Row(
          children: [
            CircularProgressIndicator(color: _appBarColor), // [cite: 47]
            const SizedBox(width: 20),
            Text("Đang lưu...", style: GoogleFonts.poppins(color: _textColorSecondary)), // [cite: 47, 48]
          ],
        ),
      ),
    );

    try {
      if (appState.userId == null) throw Exception('User ID không tồn tại'); // [cite: 49]
      final FirebaseFirestore firestore = FirebaseFirestore.instance; // [cite: 50]
      String monthKey = DateFormat('yyyy-MM').format(appState.selectedDate); // [cite: 50]
      String firestoreDocKey = appState.getKey('variableExpenseList_$monthKey'); // [cite: 50]

      await firestore
          .collection('users')
          .doc(appState.userId)
          .collection('expenses')
          .doc('variableList')
          .collection('monthly')
          .doc(firestoreDocKey)
          .set({
        'products': updatedList, // Danh sách này chứa các Map {'name': ..., 'amount': 0.0}
        'updatedAt': FieldValue.serverTimestamp(),
      }); // [cite: 51]

      // === BẮT ĐẦU THAY ĐỔI: CẬP NHẬT HIVE SAU KHI LƯU FIRESTORE ===
      final String hiveBoxKey = '${appState.userId}-variableExpenseList-$monthKey'; // [cite: 27] (Key dùng để đọc trong _loadInitialExpenseNames)
      final variableExpenseListBox = Hive.box('variableExpenseListBox'); // [cite: 27]

      await variableExpenseListBox.put(hiveBoxKey, updatedList);
      // === KẾT THÚC THAY ĐỔI ===

      Navigator.pop(context); // Đóng dialog "Đang lưu..." [cite: 52]
      _showStyledSnackBar("Đã lưu danh sách chi phí biến đổi cho tháng"); // [cite: 52]
      Navigator.pop(context, true);

    } catch (e) {
      Navigator.pop(context); // Đóng dialog "Đang lưu..." [cite: 53]
      print("Error saving variable expense list: $e"); // [cite: 53]
      _showStyledSnackBar("Lỗi khi lưu dữ liệu: $e", isError: true); // [cite: 54]
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context, listen: false);
    final screenWidth = MediaQuery.of(context).size.width;

    if (widget.category != "Chi phí biến đổi") {
      return Scaffold(
        body: Center(child: Text("Loại chi phí không hợp lệ cho màn hình này.", style: GoogleFonts.poppins())),
      );
    }

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        backgroundColor: _secondaryColor,
        body: Stack(
          children: [
            Container(
              height: MediaQuery.of(context).size.height * 0.22,
              color: _appBarColor.withOpacity(0.95),
            ),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.arrow_back_ios_new,
                                    color: Colors.white),
                                onPressed: () => Navigator.pop(context),
                                splashRadius: 20,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "DS Chi phí biến đổi",
                                      style: GoogleFonts.poppins(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.25),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        "Tháng ${DateFormat('MMMM y', 'vi').format(appState.selectedDate)}",
                                        style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            color: Colors.white,
                                            fontWeight: FontWeight.w500),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        ScaleTransition(
                          scale: _buttonScaleAnimation,
                          child: IconButton(
                            icon: const Icon(Icons.add_circle_outline,
                                color: Colors.white, size: 28),
                            onPressed: addController,
                            tooltip: "Thêm mục chi phí",
                            splashRadius: 22,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: _isLoading
                          ? Center(child: CircularProgressIndicator(color: _appBarColor))
                          : hasError // Check hasError here
                          ? Center(child: Text("Không thể tải danh sách.", style: GoogleFonts.poppins(color: _textColorSecondary)))
                          : controllers.isEmpty && !_isLoading
                          ? Center(
                        child: Text(
                          "Nhấn (+) để thêm mục chi phí biến đổi.",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(fontSize: 16, color: _textColorSecondary),
                        ),
                      )
                          : SlideTransition(
                        position: _slideAnimation,
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: ListView.builder(
                            padding: const EdgeInsets.only(top: 8, bottom: 16),
                            shrinkWrap: true,
                            itemCount: controllers.length,
                            itemBuilder: (context, index) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6.0),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: controllers[index],
                                        focusNode: focusNodes[index],
                                        style: GoogleFonts.poppins(color: _textColorPrimary, fontWeight: FontWeight.w500),
                                        decoration: InputDecoration(
                                          hintText: "Tên khoản chi ${index + 1}",
                                          hintStyle: GoogleFonts.poppins(color: _textColorSecondary.withOpacity(0.7)),
                                          prefixIcon: Icon(Icons.edit_note_outlined, color: _appBarColor.withOpacity(0.8), size: 22),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            borderSide: BorderSide(color: Colors.grey.shade300),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            borderSide: BorderSide(color: Colors.grey.shade300),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            borderSide: BorderSide(color: _appBarColor, width: 1.5),
                                          ),
                                          filled: true,
                                          fillColor: _cardBackgroundColor,
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                          counterText: "",
                                        ),
                                        maxLines: 1,
                                        maxLength: 50,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    ScaleTransition(
                                      scale: _buttonScaleAnimation,
                                      child: IconButton(
                                        icon: Icon(Icons.remove_circle_outline, color: _accentColor, size: 26),
                                        onPressed: () => removeController(index),
                                        tooltip: "Xóa mục này",
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
                  if (!_isLoading)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: ScaleTransition(
                        scale: _buttonScaleAnimation,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _appBarColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            minimumSize: Size(screenWidth, 52),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 2,
                          ),
                          onPressed: () => saveUpdatedList(appState),
                          icon: Icon(Icons.save_alt_outlined, size: 20),
                          label: Text(
                            "Lưu danh sách",
                            style: GoogleFonts.poppins(
                                fontSize: 16.5, fontWeight: FontWeight.w600),
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