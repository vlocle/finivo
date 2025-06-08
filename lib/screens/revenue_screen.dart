import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:google_fonts/google_fonts.dart';

// Assuming these are your existing imports
import '../state/app_state.dart';
import 'edit_main_revenue_screen.dart';
import 'edit_secondary_revenue_screen.dart';
import 'edit_other_revenue.dart';
import 'expense_manager.dart';
import 'product_service_screen.dart';
import 'user_setting_screen.dart';
import '/screens/revenue_manager.dart'; // Make sure this path is correct

class RevenueScreen extends StatefulWidget {
  @override
  _RevenueScreenState createState() => _RevenueScreenState();
}

class _RevenueScreenState extends State<RevenueScreen>
    with SingleTickerProviderStateMixin {
  final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'VND');
  final dateTimeFormat = DateFormat('HH:mm', 'vi_VN');
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _hasAnimated = false;
  String _selectedTransactionCategory = 'Doanh thu chính';
  final PageController _pageController = PageController();
  AppState? _appState; // Biến để lưu tham chiếu đến AppState

  // Define a modern color palette
  static const Color _primaryColor = Color(0xFF0A7AFF); // A vibrant blue
  static const Color _secondaryColor = Color(0xFFF0F4F8); // Light background
  static const Color _accentColor = Color(0xFF34C759); // Green for positive actions
  static const Color _textColorPrimary = Color(0xFF1D2D3A); // Dark text
  static const Color _textColorSecondary = Color(0xFF6E7A8A); // Lighter text
  static const Color _cardBackgroundColor = Colors.white;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
        duration: const Duration(milliseconds: 700), vsync: this);
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _animationController, curve: Curves.easeIn));

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _appState = Provider.of<AppState>(context, listen: false);
      if (!_appState!.dataReadyListenable.value) {
        await _appState!.initializeData();
      }
      if (mounted) {
        _runAnimation();
      }
      _appState!.dataReadyListenable.addListener(_onDataReady);
    });
  }

  void _onDataReady() {
    if (!mounted) {
      print("RevenueScreen: _onDataReady called but widget is unmounted. Skipping.");
      return;
    }

    if (_appState != null && _appState!.dataReadyListenable.value) {
      print("RevenueScreen: Data is ready (via _appState). Resetting and running animation.");
      _resetAnimation();
      _runAnimation();
    }
  }

  void _runAnimation() {
    if (!_hasAnimated && mounted) {
      _animationController.forward();
      _hasAnimated = true;
      print('RevenueScreen: Animation triggered at ${DateTime.now().toIso8601String()}');
    } else if (_hasAnimated && mounted && _animationController.status == AnimationStatus.dismissed) {
      // If animation was reset and _hasAnimated is still true (e.g. from a quick reset/run)
      // ensure it still forwards.
      _animationController.forward();
      print('RevenueScreen: Animation re-triggered (forward) at ${DateTime.now().toIso8601String()}');
    }
  }

  void _resetAnimation() {
    if (mounted) {
      _animationController.reset();
      _hasAnimated = false; // Allow animation to run again
      print('RevenueScreen: Animation reset at ${DateTime.now().toIso8601String()}');
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pageController.dispose();
    // Sử dụng _appState thay vì Provider.of
    _appState?.dataReadyListenable.removeListener(_onDataReady);
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final appState = Provider.of<AppState>(context, listen: false);
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: appState.selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: _primaryColor,
              onPrimary: Colors.white,
              onSurface: _textColorPrimary,
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != appState.selectedDate) {
      appState.setSelectedDate(picked);
      // _resetAnimation(); // _onDataReady will handle resetting and running animation
      print('RevenueScreen: Date selected: $picked. AppState will trigger _onDataReady.');
    }
  }

  void _navigateToEditRevenue(String category) {
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => category == 'Doanh thu khác'
            ? EditOtherRevenueScreen(onUpdate: () {
          if (mounted) {
            print("RevenueScreen: Returned from EditOtherRevenueScreen with onUpdate.");
            _resetAnimation();
            _runAnimation();
          }
        })
            : category == 'Doanh thu chính'
            ? const EditMainRevenueScreen()
            : category == 'Doanh thu phụ'
            ? const EditSecondaryRevenueScreen()
            : ProductServiceScreen(),
      ),
    ).then((_) {
      // This block executes when returning from ANY of the pushed screens.
      if (mounted) {
        print("RevenueScreen: Returned from a pushed screen. Resetting and running animation.");
        _resetAnimation();
        _runAnimation();
      }
    });
  }

  double _calculateTotal(List<Map<String, dynamic>> transactions) {
    return transactions.fold(
        0.0, (sum, transaction) => sum + (transaction['total'] ?? 0.0));
  }

  void _showTransactionCategoryBottomSheet(BuildContext context) {
    final appState = Provider.of<AppState>(context, listen: false);
    final categories = [
      'Doanh thu chính',
      'Doanh thu phụ',
      'Doanh thu khác'
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          decoration: BoxDecoration(
              color: _cardBackgroundColor,
              borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: Offset(0, -5),
                )
              ]
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0, left: 8),
                child: Text(
                  'Chọn loại doanh thu',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _textColorPrimary,
                  ),
                ),
              ),
              ...categories.map((category) {
                bool isSelected = _selectedTransactionCategory == category;
                return ListTile(
                  title: Text(
                    category,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? _primaryColor : _textColorPrimary,
                    ),
                  ),
                  trailing: isSelected
                      ? Icon(Icons.check_circle, color: _primaryColor)
                      : null,
                  onTap: () {
                    if (mounted) {
                      setState(() {
                        _selectedTransactionCategory = category;
                      });
                      print("RevenueScreen: Category changed. Resetting and running animation.");
                      _resetAnimation(); // Reset animation for new category list
                      _runAnimation();   // Run animation to show the new list
                    }
                    Navigator.pop(context);
                  },
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)
                  ),
                  tileColor: isSelected ? _primaryColor.withOpacity(0.1) : Colors.transparent,
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }

  void _removeTransaction(AppState appState,
      List<Map<String, dynamic>> transactions, int index, String category) {
    if (index < 0 || index >= transactions.length) return;

    final transactionToRemove = transactions[index];
    final String? salesTransactionId = transactionToRemove['id'] as String?;
    final String removedItemName = transactionToRemove['name'] as String? ?? "Giao dịch không rõ";

    // Tạo bản sao để thao tác an toàn
    List<Map<String, dynamic>> modifiableTransactions = List.from(transactions);

    // ----- BẮT ĐẦU LOGIC XỬ LÝ XÓA COGS LIÊN QUAN -----
    List<Map<String, dynamic>> currentDailyVariableExpenses = List.from(appState.variableExpenseList.value);
    int initialVariableExpenseCount = currentDailyVariableExpenses.length;

    if (salesTransactionId != null) {
      if (category == 'Doanh thu chính') {
        currentDailyVariableExpenses.removeWhere((expense) =>
        expense['sourceSalesTransactionId'] == salesTransactionId &&
            (expense['source'] == 'AUTO_COGS_OVERRIDE' ||
                expense['source'] == 'AUTO_COGS_COMPONENT' ||
                expense['source'] == 'AUTO_COGS_ESTIMATED'));
      } else if (category == 'Doanh thu phụ') {
        currentDailyVariableExpenses.removeWhere((expense) =>
        expense['sourceSalesTransactionId'] == salesTransactionId &&
            (expense['source'] == 'AUTO_COGS_OVERRIDE_SECONDARY' ||
                expense['source'] == 'AUTO_COGS_COMPONENT_SECONDARY' ||
                expense['source'] == 'AUTO_COGS_ESTIMATED_SECONDARY'));
      }
      // "Doanh thu khác" thường không có COGS tự động, nên không cần xử lý ở đây

      if (currentDailyVariableExpenses.length < initialVariableExpenseCount) {
        appState.variableExpenseList.value = List.from(currentDailyVariableExpenses);
        ExpenseManager.saveVariableExpenses(appState, currentDailyVariableExpenses)
            .then((_) {
          double newTotalVariableExpense = currentDailyVariableExpenses.fold(0.0, (sum, item) => sum + (item['amount'] as num? ?? 0.0));
          appState.setExpenses(appState.fixedExpense, newTotalVariableExpense);
        })
            .catchError((e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi khi cập nhật chi phí sau khi xóa COGS: $e'), backgroundColor: _accentColor),
          );
        });
      }
    } else {
      print("Cảnh báo: Giao dịch ($category - $removedItemName) không có ID, không thể tự động xóa COGS liên quan.");
      // Có thể hiển thị SnackBar thông báo cho người dùng nếu cần
    }
    // ----- KẾT THÚC LOGIC XỬ LÝ XÓA COGS -----

    // Xóa giao dịch doanh thu khỏi danh sách cục bộ
    modifiableTransactions.removeAt(index);

    // Lưu lại danh sách giao dịch doanh thu đã cập nhật
    RevenueManager.saveTransactionHistory(appState, category, modifiableTransactions);
    // Cập nhật ValueNotifier để UI tự động rebuild
    _updateTransactionNotifier(appState, category, modifiableTransactions);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã xóa giao dịch: $removedItemName'),
        backgroundColor: Colors.redAccent, // Giữ màu gốc hoặc _accentColor
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: EdgeInsets.all(10),
      ),
    );
  }

  // Bên trong class _RevenueScreenState

  // Thêm hàm này vào trong class _RevenueScreenState
  void _editTransaction(AppState appState, List<Map<String, dynamic>> transactions, int index, String category) {
    // Kiểm tra chỉ số hợp lệ
    if (index < 0 || index >= transactions.length) return;

    final transactionToEdit = transactions[index];
    final String? salesTransactionId = transactionToEdit['id'] as String?;
    final String originalProductName = transactionToEdit['name'] as String? ?? "Giao dịch không rõ";
    final String originalTransactionDate = transactionToEdit['date'] as String? ?? DateTime.now().toIso8601String();

    // Khởi tạo các controller cho dialog
    final TextEditingController editQuantityController =
    TextEditingController(text: (transactionToEdit['quantity'] as num? ?? 1).toString());
    final NumberFormat internalPriceFormatter = NumberFormat("#,##0", "vi_VN");

    // Chỉ cho phép sửa logic giá vốn nếu là Doanh thu chính hoặc phụ
    bool canHandleCogs = (category == 'Doanh thu chính' || category == 'Doanh thu phụ');

    showDialog(
      context: context,
      builder: (dialogContext) => GestureDetector(
        onTap: () => FocusScope.of(dialogContext).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text("Chỉnh sửa: $originalProductName",
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: _textColorPrimary)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  keyboardType: TextInputType.number,
                  controller: editQuantityController,
                  decoration: InputDecoration(
                      labelText: "Nhập số lượng mới",
                      labelStyle: GoogleFonts.poppins(color: _textColorSecondary),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: _secondaryColor,
                      prefixIcon: Icon(Icons.production_quantity_limits_outlined, color: _primaryColor)),
                  maxLines: 1,
                  maxLength: 5,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                // Chỉ hiển thị trường giá vốn nếu có thể xử lý
                if (canHandleCogs) ...[
                  const SizedBox(height: 16),
                  TextField(
                    // Trường này chỉ để hiển thị, không cho sửa
                    enabled: false,
                    controller: TextEditingController(
                        text: internalPriceFormatter.format(transactionToEdit['unitVariableCost'] ?? 0.0)),
                    decoration: InputDecoration(
                        labelText: "Chi phí biến đổi/ĐV (Không đổi)",
                        labelStyle: GoogleFonts.poppins(color: _textColorSecondary),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.grey.shade200,
                        prefixIcon: Icon(Icons.local_atm_outlined, color: _primaryColor)),
                    maxLines: 1,
                  ),
                ]
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text("Hủy", style: GoogleFonts.poppins(color: _textColorSecondary, fontWeight: FontWeight.w500)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              onPressed: () {
                int newQuantity = int.tryParse(editQuantityController.text) ??
                    (transactionToEdit['quantity'] as int? ?? 1);

                if (newQuantity <= 0) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(
                      content: Text("Số lượng phải lớn hơn 0", style: GoogleFonts.poppins(color: Colors.white)),
                      backgroundColor: _accentColor,
                      behavior: SnackBarBehavior.floating));
                  return;
                }

                // Lấy các giá trị gốc để tính toán lại
                double price = (transactionToEdit['price'] as num? ?? 0.0).toDouble();
                double unitVariableCost = (transactionToEdit['unitVariableCost'] as double? ?? 0.0);

                // Tạo bản sao của danh sách chi phí và doanh thu để chỉnh sửa
                List<Map<String, dynamic>> currentDailyVariableExpenses = List.from(appState.variableExpenseList.value);
                List<Map<String, dynamic>> modifiableTransactions = List.from(transactions);
                Map<String, dynamic> updatedTransaction = Map<String, dynamic>.from(transactionToEdit);

                // *** LOGIC CỐT LÕI: XÓA VÀ TẠO LẠI GIÁ VỐN ***
                if (salesTransactionId != null && canHandleCogs) {
                  // 1. XÓA GIÁ VỐN (COGS) CŨ
                  // Xác định các loại source cần xóa dựa trên category
                  List<String> cogsSourcesToRemove = [];
                  if (category == 'Doanh thu chính') {
                    cogsSourcesToRemove = ['AUTO_COGS_OVERRIDE', 'AUTO_COGS_COMPONENT', 'AUTO_COGS_ESTIMATED', 'AUTO_COGS_COMPONENT_OVERRIDE'];
                  } else if (category == 'Doanh thu phụ') {
                    cogsSourcesToRemove = ['AUTO_COGS_OVERRIDE_SECONDARY', 'AUTO_COGS_COMPONENT_SECONDARY', 'AUTO_COGS_ESTIMATED_SECONDARY', 'AUTO_COGS_COMPONENT_OVERRIDE_SECONDARY'];
                  }
                  currentDailyVariableExpenses.removeWhere((expense) =>
                  expense['sourceSalesTransactionId'] == salesTransactionId &&
                      cogsSourcesToRemove.contains(expense['source']));
                }

                // 2. CẬP NHẬT GIAO DỊCH DOANH THU
                updatedTransaction['quantity'] = newQuantity;
                updatedTransaction['total'] = price * newQuantity;
                if (canHandleCogs) {
                  updatedTransaction['totalVariableCost'] = unitVariableCost * newQuantity;
                }

                // 3. TẠO LẠI GIÁ VỐN (COGS) MỚI VỚI SỐ LƯỢNG MỚI
                List<Map<String, dynamic>> newAutoGeneratedCogs = [];
                if (salesTransactionId != null && canHandleCogs && unitVariableCost > 0) {
                  // Lấy thông tin về cách giá vốn được tạo ban đầu
                  final String? originalCogsSourceType = updatedTransaction['cogsSourceType'] as String?;
                  final List<dynamic>? rawOriginalCogsComponents = updatedTransaction['cogsComponentsUsed'] as List<dynamic>?;
                  final List<Map<String, dynamic>>? originalCogsComponents = rawOriginalCogsComponents?.map((item) => Map<String, dynamic>.from(item as Map)).toList();

                  // Nếu giá vốn được tạo từ các thành phần chi tiết
                  if (originalCogsComponents != null && originalCogsComponents.isNotEmpty) {
                    double totalNewCost = 0;
                    for (var component in originalCogsComponents) {
                      double componentCost = (component['cost'] as num? ?? 0.0).toDouble();
                      double newComponentAmount = componentCost * newQuantity;
                      totalNewCost += newComponentAmount;
                      if (newComponentAmount > 0) {
                        newAutoGeneratedCogs.add({
                          "name": "${component['name']} (Cho: $originalProductName)",
                          "amount": newComponentAmount,
                          "date": originalTransactionDate,
                          "source": originalCogsSourceType, // Giữ lại source type gốc
                          "sourceSalesTransactionId": salesTransactionId
                        });
                      }
                    }
                    // Cập nhật lại tổng chi phí biến đổi cho chính xác
                    updatedTransaction['totalVariableCost'] = totalNewCost;

                  } else { // Nếu giá vốn được tạo từ một con số tổng ước tính/ghi đè
                    double totalNewVariableCostForSale = unitVariableCost * newQuantity;
                    newAutoGeneratedCogs.add({
                      "name": "Giá vốn hàng bán: $originalProductName",
                      "amount": totalNewVariableCostForSale,
                      "date": originalTransactionDate,
                      "source": originalCogsSourceType, // Giữ lại source type gốc
                      "sourceSalesTransactionId": salesTransactionId
                    });
                  }
                }

                // 4. LƯU TẤT CẢ THAY ĐỔI
                // Thêm COGS mới vào danh sách chi phí
                currentDailyVariableExpenses.addAll(newAutoGeneratedCogs);
                // Cập nhật giao dịch trong danh sách doanh thu
                modifiableTransactions[index] = updatedTransaction;

                // Lưu chi phí biến đổi
                ExpenseManager.saveVariableExpenses(appState, currentDailyVariableExpenses)
                    .then((_) {
                  double newTotalVariableExpense = currentDailyVariableExpenses.fold(
                      0.0, (sum, item) => sum + (item['amount'] as num? ?? 0.0));
                  appState.setExpenses(appState.fixedExpense, newTotalVariableExpense);
                }).catchError((e) {
                  _showStyledSnackBar("Lỗi khi cập nhật chi phí biến đổi: $e", isError: true);
                });

                // Lưu lịch sử doanh thu
                RevenueManager.saveTransactionHistory(appState, category, modifiableTransactions);
                _updateTransactionNotifier(appState, category, modifiableTransactions);

                // Đóng dialog và hiển thị thông báo
                Navigator.pop(dialogContext);
                _showStyledSnackBar("Đã cập nhật: $originalProductName");
              },
              child: Text("Lưu", style: GoogleFonts.poppins()),
            ),
          ],
        ),
      ),
    );
  }

  void _showStyledSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins(color: Colors.white)),
        // Sử dụng màu đỏ cho lỗi và màu chính của màn hình cho các thông báo khác
        backgroundColor: isError ? Colors.redAccent : _primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(10),
      ),
    );
  }

  void _updateTransactionNotifier(AppState appState, String category,
      List<Map<String, dynamic>> newTransactionsList) {
    // ValueNotifier requires a new list instance to detect change.
    // The 'newTransactionsList' is already a new list from saveTransactionHistory or local modification.
    if (category == 'Doanh thu chính') {
      appState.mainRevenueTransactions.value = newTransactionsList;
    } else if (category == 'Doanh thu phụ') {
      appState.secondaryRevenueTransactions.value = newTransactionsList;
    } else {
      appState.otherRevenueTransactions.value = newTransactionsList;
    }
  }

  ValueNotifier<List<Map<String, dynamic>>> _getCurrentCategoryTransactions(
      AppState appState) {
    switch (_selectedTransactionCategory) {
      case 'Doanh thu chính':
        return appState.mainRevenueTransactions;
      case 'Doanh thu phụ':
        return appState.secondaryRevenueTransactions;
      case 'Doanh thu khác':
      default:
        return appState.otherRevenueTransactions;
    }
  }

  @override
  Widget build(BuildContext context) {
    print('RevenueScreen: build method called at ${DateTime.now().toIso8601String()}');
    final user = FirebaseAuth.instance.currentUser;
    final appState = Provider.of<AppState>(context, listen: false);

    return Scaffold(
      backgroundColor: _secondaryColor,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(user, appState),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 20.0, bottom: 10),
              child: _buildTotalRevenueSection(appState),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
              child: _buildNavigationActions(),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
              child: _buildTransactionCategorySelector(context, appState),
            ),
          ),
          _buildTransactionList(appState),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(User? user, AppState appState) {
    return SliverAppBar(
      expandedHeight: 120.0,
      floating: false,
      pinned: true,
      elevation: 2,
      backgroundColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_primaryColor.withOpacity(0.9), _primaryColor.withOpacity(0.7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 10,
                left: 16,
                right: 16,
                bottom: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Flexible(
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          if (!mounted) return;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => UserSettingsScreen()),
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withOpacity(0.8), width: 2.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: CircleAvatar(
                            radius: 26,
                            backgroundColor: Colors.white,
                            backgroundImage: user?.photoURL != null
                                ? NetworkImage(user!.photoURL!)
                                : null,
                            child: user?.photoURL == null
                                ? Icon(Icons.person_outline,
                                size: 32, color: _primaryColor.withOpacity(0.9))
                                : null,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Flexible(
                        child: ValueListenableBuilder<DateTime>(
                          valueListenable: appState.selectedDateListenable,
                          builder: (context, selectedDate, _) => Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Chào, ${user?.displayName?.split(' ').first ?? 'Bạn'}",
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "Ngày ${DateFormat('dd MMMM, yyyy', 'vi').format(selectedDate)}",
                                style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.white.withOpacity(0.9),
                                    fontWeight: FontWeight.w500
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.calendar_month_outlined,
                      color: Colors.white, size: 28),
                  onPressed: () => _selectDate(context),
                  splashRadius: 24,
                  tooltip: "Chọn ngày",
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTotalRevenueSection(AppState appState) {
    return SizedBox(
      height: 120,
      child: Column(
        children: [
          Expanded(
            child: PageView(
              controller: _pageController,
              children: [
                _buildRevenueCard(
                  title: 'Tổng doanh thu',
                  valueListenable: appState.totalRevenueListenable,
                  appState: appState,
                  icon: Icons.account_balance_wallet_outlined,
                ),
                _buildRevenueCard(
                  title: 'Lợi nhuận hôm nay',
                  valueListenable: appState.profitListenable,
                  appState: appState,
                  icon: Icons.trending_up_outlined,
                  isProfit: true,
                ),
              ],
            ),
          ),
          SizedBox(height: 12),
          SmoothPageIndicator(
            controller: _pageController,
            count: 2,
            effect: ExpandingDotsEffect(
              activeDotColor: _primaryColor,
              dotColor: Colors.grey.shade300,
              dotHeight: 8,
              dotWidth: 8,
              spacing: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueCard({
    required String title,
    required ValueNotifier<double> valueListenable,
    required AppState appState,
    required IconData icon,
    bool isProfit = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBackgroundColor, // [cite: 113]
        borderRadius: BorderRadius.circular(20), // [cite: 113]
        boxShadow: [ // [cite: 113]
          BoxShadow( // [cite: 114]
            color: Colors.grey.withOpacity(0.15), // [cite: 114]
            spreadRadius: 2, // [cite: 114]
            blurRadius: 10, // [cite: 114]
            offset: Offset(0, 5), // [cite: 114]
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center, // [cite: 114]
        crossAxisAlignment: CrossAxisAlignment.center, // [cite: 115]
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center, // [cite: 115]
            children: [
              Icon(icon, color: isProfit ? _accentColor : _primaryColor, size: 22), // [cite: 115]
              SizedBox(width: 8), // [cite: 115]
              Text( // [cite: 116]
                title, // [cite: 116]
                style: TextStyle( // [cite: 116]
                  fontSize: 16, // [cite: 116]
                  fontWeight: FontWeight.w600, // [cite: 116]
                  color: _textColorSecondary, // [cite: 116]
                ),
              ),
            ],
          ),
          SizedBox(height: 8), // [cite: 117]
          ValueListenableBuilder<double>(
            valueListenable: valueListenable, // [cite: 117]
            builder: (context, value, _) {
              Color valueColor;
              if (isProfit) {
                if (value < 0) {
                  valueColor = Colors.red; // Màu đỏ cho số tiền âm
                } else {
                  valueColor = _accentColor; // Màu xanh lá cho số tiền dương [cite: 7, 119]
                }
              } else {
                valueColor = _textColorPrimary; // [cite: 8, 119]
              }
              return Text(
                currencyFormat.format(value), // [cite: 118]
                style: TextStyle( // [cite: 118]
                  fontSize: 26, // [cite: 118]
                  fontWeight: FontWeight.bold, // [cite: 118]
                  color: valueColor, //Sử dụng màu đã được xác định
                ),
                textAlign: TextAlign.center, // [cite: 119]
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildModernNavigationIcon(
          icon: Icons.monetization_on_outlined,
          label: 'Chính',
          onTap: () => _navigateToEditRevenue('Doanh thu chính'),
        ),
        _buildModernNavigationIcon(
          icon: Icons.account_balance_wallet_outlined,
          label: 'Phụ',
          onTap: () => _navigateToEditRevenue('Doanh thu phụ'),
        ),
        _buildModernNavigationIcon(
          icon: Icons.add_business_outlined,
          label: 'Khác',
          onTap: () => _navigateToEditRevenue('Doanh thu khác'),
        ),
        _buildModernNavigationIcon(
          icon: Icons.inventory_2_outlined,
          label: 'Sản phẩm',
          onTap: () => _navigateToEditRevenue('Sản phẩm'),
        ),
      ],
    );
  }

  Widget _buildModernNavigationIcon(
      {required IconData icon,
        required String label,
        required VoidCallback onTap}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _cardBackgroundColor,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              icon,
              size: 28,
              color: _primaryColor,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(color: _textColorSecondary, fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildTransactionCategorySelector(
      BuildContext context, AppState appState) {
    return GestureDetector(
      onTap: () => _showTransactionCategoryBottomSheet(context),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
        decoration: BoxDecoration(
          color: _cardBackgroundColor,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedTransactionCategory,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: _textColorPrimary,
                  ),
                ),
                SizedBox(height: 4),
                ValueListenableBuilder<List<Map<String, dynamic>>>(
                  valueListenable: _getCurrentCategoryTransactions(appState),
                  builder: (context, transactions, _) => Text(
                    'Tổng: ${currencyFormat.format(_calculateTotal(transactions))}',
                    style: TextStyle(
                      fontSize: 14,
                      color: _primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              color: _textColorSecondary,
              size: 28,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionList(AppState appState) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      sliver: ValueListenableBuilder<List<Map<String, dynamic>>>(
        valueListenable: _getCurrentCategoryTransactions(appState),
        builder: (context, transactions, _) {
          if (transactions.isEmpty) {
            return SliverFillRemaining(
              hasScrollBody: false,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long_outlined, size: 60, color: Colors.grey.shade400),
                      SizedBox(height: 16),
                      Text(
                        'Không có giao dịch nào',
                        style: TextStyle(fontSize: 17, color: _textColorSecondary),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Thêm giao dịch mới để bắt đầu theo dõi.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
          return SliverList(
            delegate: SliverChildBuilderDelegate(
                  (context, index) {
                final transaction = transactions[index];
                final String? dateTimeString = transaction['date'];
                final String formattedTime = dateTimeString != null
                    ? dateTimeFormat.format(DateTime.parse(dateTimeString))
                    : 'N/A';

                // <<< MỚI: Tính toán các giá trị cần thiết >>>
                final double totalRevenue = (transaction['total'] as num? ?? 0.0).toDouble();
                final double totalVariableCost = (transaction['totalVariableCost'] as num? ?? 0.0).toDouble();
                final double grossProfit = totalRevenue - totalVariableCost;
                final List<dynamic>? cogsComponents = transaction['cogsComponentsUsed'] as List<dynamic>?;

                IconData transactionIcon;
                Color iconColor;
                if (_selectedTransactionCategory == 'Doanh thu chính') {
                  transactionIcon = Icons.business_center_outlined;
                  iconColor = _primaryColor;
                } else if (_selectedTransactionCategory == 'Doanh thu phụ') {
                  transactionIcon = Icons.work_outline_outlined;
                  iconColor = Colors.orange.shade700;
                } else {
                  transactionIcon = Icons.widgets_outlined;
                  iconColor = Colors.purple.shade600;
                }

                return FadeTransition(
                  opacity: _fadeAnimation,
                  child: Slidable(
                    key: Key(transaction['id']?.toString() ?? UniqueKey().toString()),
                    endActionPane: ActionPane(
                      motion: const StretchMotion(),
                      children: [
                        // Các SlidableAction (Sửa, Xóa) giữ nguyên
                        SlidableAction(
                          onPressed: (context) {
                            _editTransaction(appState, transactions, index, _selectedTransactionCategory);
                          },
                          backgroundColor: Colors.blueAccent.shade400,
                          foregroundColor: Colors.white,
                          icon: Icons.edit_outlined,
                          label: 'Sửa',
                          borderRadius: BorderRadius.circular(12),
                        ),
                        SlidableAction(
                          onPressed: (context) async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                title: Text(
                                  'Xác nhận xóa',
                                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: _textColorPrimary),
                                ),
                                content: Text(
                                  'Bạn có chắc chắn muốn xóa giao dịch "${transaction['name']}" không? Hành động này không thể hoàn tác.',
                                  style: GoogleFonts.poppins(color: _textColorSecondary),
                                ),
                                actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: Text(
                                        'Hủy',
                                        style: GoogleFonts.poppins(color: _textColorSecondary, fontWeight: FontWeight.w500)
                                    ),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.redAccent,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    onPressed: () => Navigator.pop(context, true),
                                    child: Text('Xóa', style: GoogleFonts.poppins()),
                                  ),
                                ],
                              ),
                            );

                            if (confirm == true) {
                              _removeTransaction(appState, transactions, index, _selectedTransactionCategory);
                            }
                          },
                          backgroundColor: Colors.redAccent.shade400,
                          foregroundColor: Colors.white,
                          icon: Icons.delete_outline,
                          label: 'Xóa',
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ],
                    ),
                    child: Card(
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15)),
                      color: _cardBackgroundColor,
                      // <<< MỚI: Thay thế ListTile bằng ExpansionTile >>>
                      child: ExpansionTile(
                        leading: Container(
                          padding: EdgeInsets.all(10),
                          decoration: BoxDecoration(
                              color: iconColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12)),
                          child: Icon(
                            transactionIcon,
                            color: iconColor,
                            size: 26,
                          ),
                        ),
                        title: Text(
                          transaction['name']?.toString() ?? 'Không xác định',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: _textColorPrimary),
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          'Tổng DT: ${currencyFormat.format(totalRevenue)}',
                          style: TextStyle(
                              fontSize: 14,
                              color: _textColorSecondary,
                              fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              transaction['quantity'] != null
                                  ? 'SL: ${transaction['quantity']}'
                                  : '',
                              style: TextStyle(
                                  fontSize: 13, color: _textColorSecondary),
                            ),
                            SizedBox(height: 4),
                            Text(
                              formattedTime,
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                        // <<< MỚI: Phần nội dung được mở rộng >>>
                        children: <Widget>[
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0).copyWith(left: 70), // Căn lề với title
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Divider(height: 1, color: Colors.grey.shade200),
                                SizedBox(height: 8),
                                _buildProfitDetailRow(
                                    'Tổng CP Biến đổi:',
                                    currencyFormat.format(totalVariableCost),
                                    Colors.red.shade600
                                ),
                                SizedBox(height: 4),
                                _buildProfitDetailRow(
                                    'Lợi nhuận gộp:',
                                    currencyFormat.format(grossProfit),
                                    Colors.green.shade700
                                ),
                                // Hiển thị các thành phần chi phí nếu có
                                if (cogsComponents != null && cogsComponents.isNotEmpty) ...[
                                  SizedBox(height: 8),
                                  Divider(height: 1, color: Colors.grey.shade200),
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
                                    child: Text(
                                      'Chi tiết giá vốn:',
                                      style: TextStyle(fontWeight: FontWeight.w600, color: _textColorSecondary),
                                    ),
                                  ),
                                  ...cogsComponents.map((component) {
                                    final name = component['name'] ?? 'Thành phần không rõ';
                                    final cost = (component['cost'] as num? ?? 0.0);
                                    return Padding(
                                      padding: const EdgeInsets.only(left: 8.0, top: 2.0, bottom: 2.0),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('  • $name', style: TextStyle(color: _textColorSecondary)),
                                          Text(currencyFormat.format(cost), style: TextStyle(color: _textColorSecondary)),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ],
                                SizedBox(height: 8),
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                );
              },
              childCount: transactions.length,
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfitDetailRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: _textColorSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            color: valueColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

// Dummy RevenueCategoryItem - not directly used in RevenueScreen's main layout anymore
// but kept for potential other uses or if it was part of an older design.
class RevenueCategoryItem extends StatelessWidget {
  final String title;
  final double amount;
  final IconData icon;
  final VoidCallback onTap;
  final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'VND');

  RevenueCategoryItem(
      {required this.title,
        required this.amount,
        required this.icon,
        required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 1,
        margin: const EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10)
                    ),
                    child: Icon(icon, size: 24, color: Theme.of(context).primaryColor),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w600, color: _RevenueScreenState._textColorPrimary),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        currencyFormat.format(amount),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ],
              ),
              Icon(Icons.arrow_forward_ios,
                  size: 18, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}