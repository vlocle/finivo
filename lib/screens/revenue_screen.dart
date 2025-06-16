import 'package:fingrowth/screens/report_screen.dart';
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
import '/screens/account_switcher.dart'; // Thay your_app_name bằng tên package của bạn


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
  AppState? _appState; // Biến để lưu tham chiếu đến AppState


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
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppColors.primaryBlue,
              onPrimary: Colors.white,
              surface: AppColors.getCardColor(context),
              onSurface: AppColors.getTextColor(context),
            ),
            dialogBackgroundColor: AppColors.getCardColor(context),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryBlue,
              ),
            ),
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
              color: AppColors.getCardColor(context),
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
                      color: AppColors.getTextColor(context)
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
                      color: isSelected ? AppColors.primaryBlue : AppColors.getTextColor(context),
                    ),
                  ),
                  trailing: isSelected
                      ? Icon(Icons.check_circle, color: AppColors.primaryBlue)
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
                  tileColor: isSelected ? AppColors.primaryBlue.withOpacity(0.1) : Colors.transparent,
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }

  // Dán để thay thế hàm _removeTransaction cũ trong class _RevenueScreenState

  void _removeTransaction(
      AppState appState,
      List<Map<String, dynamic>> transactions,
      int index,
      String category,
      ) {
    // Kiểm tra chỉ số hợp lệ
    if (index < 0 || index >= transactions.length) return;

    // Lấy thông tin giao dịch cần xóa để hiển thị thông báo
    final transactionToRemove = transactions[index];
    final removedItemName =
        transactionToRemove['name'] as String? ?? "Giao dịch không rõ";

    // THAY ĐỔI CỐT LÕI:
    // Toàn bộ logic xóa COGS, xóa doanh thu, cập nhật notifier...
    // đã được chuyển vào hàm removeTransactionAndUpdateState trong AppState.
    // Giờ đây, chúng ta chỉ cần gọi một hàm duy nhất.
    appState
        .removeTransactionAndUpdateState(
      category: category,
      transactionToRemove: transactionToRemove,
    )
        .then((_) {
      // Chỉ hiển thị thông báo sau khi logic đã chạy xong
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã xóa giao dịch: $removedItemName'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: EdgeInsets.all(10),
          ),
        );
      }
    }).catchError((e) {
      // Xử lý nếu có lỗi xảy ra trong quá trình cập nhật
      if (mounted) {
        _showStyledSnackBar("Lỗi khi xóa giao dịch: $e", isError: true);
      }
    });
  }

  // Bên trong class _RevenueScreenState

  // Thêm hàm này vào trong class _RevenueScreenState
  // Dành cho file revenue_screen.docx

  void _editTransaction(AppState appState,
      List<Map<String, dynamic>> transactions, int index, String category) {
    if (index < 0 || index >= transactions.length) return;

    final transactionToEdit = transactions[index];
    final String? salesTransactionId = transactionToEdit['id'] as String?;
    final String originalProductName =
        transactionToEdit['name'] as String? ?? "Giao dịch không rõ";
    final String originalTransactionDate =
        transactionToEdit['date'] as String? ?? DateTime.now().toIso8601String();

    final TextEditingController editQuantityController = TextEditingController(
        text: (transactionToEdit['quantity'] as num? ?? 1).toString());
    final NumberFormat internalPriceFormatter = NumberFormat("#,##0", "vi_VN");
    bool canHandleCogs =
    (category == 'Doanh thu chính' || category == 'Doanh thu phụ');

    showDialog(
      context: context,
      builder: (dialogContext) => GestureDetector(
        onTap: () => FocusScope.of(dialogContext).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text("Chỉnh sửa: $originalProductName",
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600, color: AppColors.getTextColor(context))),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  keyboardType: TextInputType.number,
                  controller: editQuantityController,
                  decoration: InputDecoration(
                      labelText: "Nhập số lượng mới",
                      labelStyle:
                      GoogleFonts.poppins(color: AppColors.getTextSecondaryColor(context)),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: AppColors.getBackgroundColor(context),
                      prefixIcon: Icon(
                          Icons.production_quantity_limits_outlined,
                          color: AppColors.primaryBlue)),
                  maxLines: 1,
                  maxLength: 5,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly
                  ],
                ),
                if (canHandleCogs) ...[
                  const SizedBox(height: 16),
                  TextField(
                    enabled: false,
                    controller: TextEditingController(
                        text: internalPriceFormatter
                            .format(transactionToEdit['unitVariableCost'] ?? 0.0)),
                    decoration: InputDecoration(
                        labelText: "Chi phí biến đổi/ĐV (Không đổi)",
                        labelStyle:
                        GoogleFonts.poppins(color: AppColors.getTextSecondaryColor(context)),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.grey.shade200,
                        prefixIcon: Icon(Icons.local_atm_outlined,
                            color: AppColors.primaryBlue)),
                    maxLines: 1,
                  ),
                ]
              ],
            ),
          ),
          actionsPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text("Hủy",
                  style: GoogleFonts.poppins(
                      color: AppColors.getTextSecondaryColor(context),
                      fontWeight: FontWeight.w500)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              onPressed: () {
                // PHẦN 1: CHUẨN BỊ DỮ LIỆU
                int newQuantity = int.tryParse(editQuantityController.text) ??
                    (transactionToEdit['quantity'] as int? ?? 1);
                if (newQuantity <= 0) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(
                      content: Text("Số lượng phải lớn hơn 0",
                          style: GoogleFonts.poppins(color: Colors.white)),
                      backgroundColor: AppColors.chartGreen,
                      behavior: SnackBarBehavior.floating));
                  return;
                }

                Map<String, dynamic> updatedTransaction =
                Map.from(transactionToEdit);
                List<Map<String, dynamic>> newAutoGeneratedCogs = [];

                double price =
                (transactionToEdit['price'] as num? ?? 0.0).toDouble();
                double unitVariableCost =
                (transactionToEdit['unitVariableCost'] as double? ?? 0.0);

                updatedTransaction['quantity'] = newQuantity;
                updatedTransaction['total'] = price * newQuantity;
                updatedTransaction['totalVariableCost'] =
                    unitVariableCost * newQuantity;

                if (salesTransactionId != null && canHandleCogs) {
                  final String? originalCogsSourceType = (category ==
                      'Doanh thu phụ'
                      ? updatedTransaction['cogsSourceType_Secondary']
                      : updatedTransaction['cogsSourceType']) as String?;
                  final List<dynamic>? rawCogs = (category == 'Doanh thu phụ'
                      ? updatedTransaction['cogsComponentsUsed_Secondary']
                      : updatedTransaction['cogsComponentsUsed']) as List<dynamic>?;
                  final List<Map<String, dynamic>>? components = rawCogs
                      ?.map((i) => Map<String, dynamic>.from(i as Map))
                      .toList();

                  if (components != null && components.isNotEmpty) {
                    for (var component in components) {
                      // SỬA LỖI Ở ĐÂY: Thêm .toDouble()
                      double cost = (component['cost'] as num? ?? 0.0).toDouble();
                      newAutoGeneratedCogs.add({
                        "name":
                        "${component['name']} (Cho: $originalProductName)",
                        "amount": cost * newQuantity,
                        "date": originalTransactionDate,
                        "source": originalCogsSourceType,
                        "sourceSalesTransactionId": salesTransactionId
                      });
                    }
                  } else if (unitVariableCost > 0) {
                    newAutoGeneratedCogs.add({
                      "name": "Giá vốn hàng bán: $originalProductName",
                      "amount": unitVariableCost * newQuantity,
                      "date": originalTransactionDate,
                      "source": originalCogsSourceType,
                      "sourceSalesTransactionId": salesTransactionId
                    });
                  }
                }

                // PHẦN 2: GỌI HÀM CẬP NHẬT TẬP TRUNG
                appState
                    .editTransactionAndUpdateState(
                  category: category,
                  updatedTransaction: updatedTransaction,
                  newCogsTransactions: newAutoGeneratedCogs,
                )
                    .then((_) {
                  if (mounted) {
                    _showStyledSnackBar("Đã cập nhật: $originalProductName");
                  }
                }).catchError((e) {
                  if (mounted) {
                    _showStyledSnackBar("Lỗi khi cập nhật: $e", isError: true);
                  }
                });

                Navigator.pop(dialogContext);
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
        backgroundColor: isError ? Colors.redAccent : AppColors.primaryBlue,
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
    final bool canEditRevenue = appState.hasPermission('canEditRevenue');
    final bool canManageProducts = appState.hasPermission('canManageProducts');

    return Scaffold(
      backgroundColor: AppColors.getBackgroundColor(context),
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(user, appState),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 20.0, bottom: 10),
              child: _buildCombinedRevenueCard(appState),
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
      backgroundColor: AppColors.primaryBlue,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primaryBlue.withOpacity(0.9), AppColors.primaryBlue.withOpacity(0.7)],
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
                                size: 32, color: AppColors.primaryBlue.withOpacity(0.9))
                                : null,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // WIDGET MỚI ĐẶT Ở ĐÂY
                            AccountSwitcher(textColor: Colors.white),

                            // Giữ nguyên phần hiển thị ngày
                            const SizedBox(height: 4),
                            ValueListenableBuilder<DateTime>(
                              valueListenable: appState.selectedDateListenable,
                              builder: (context, selectedDate, _) => Text(
                                "Ngày ${DateFormat('dd MMMM, yyyy', 'vi').format(selectedDate)}",
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: Colors.white.withOpacity(0.9),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
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

  // Phương án 4: Thẻ có Dải màu trang trí
  Widget _buildCombinedRevenueCard(AppState appState) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      // Sử dụng ClipRRect để bo góc cả container
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.getCardColor(context),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.15),
                spreadRadius: 2,
                blurRadius: 10,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                // Dải màu trang trí bên trái
                Container(
                  width: 10, // Chiều rộng của dải màu
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primaryBlue, Colors.blue.shade300],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
                // Phần nội dung
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Mục Tổng doanh thu
                        Text('Tổng doanh thu', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.getTextSecondaryColor(context))),
                        SizedBox(height: 4),
                        ValueListenableBuilder<double>(
                          valueListenable: appState.totalRevenueListenable,
                          builder: (context, value, _) {
                            return Text(currencyFormat.format(value), style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primaryBlue));
                          },
                        ),
                        Divider(height: 24),
                        // Mục Lợi nhuận
                        Text('Lợi nhuận hôm nay', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.getTextSecondaryColor(context))),
                        SizedBox(height: 4),
                        ValueListenableBuilder<double>(
                          valueListenable: appState.profitListenable,
                          builder: (context, value, _) {
                            final color = value < 0 ? Colors.red : AppColors.chartGreen;
                            return Text(currencyFormat.format(value), style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color));
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
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
              color: AppColors.getCardColor(context),
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
              color: AppColors.primaryBlue,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(color: AppColors.getTextSecondaryColor(context), fontSize: 13, fontWeight: FontWeight.w500),
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
          color: AppColors.getCardColor(context),
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
                      color: AppColors.getTextColor(context)
                  ),
                ),
                SizedBox(height: 4),
                ValueListenableBuilder<List<Map<String, dynamic>>>(
                  valueListenable: _getCurrentCategoryTransactions(appState),
                  builder: (context, transactions, _) => Text(
                    'Tổng: ${currencyFormat.format(_calculateTotal(transactions))}',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.primaryBlue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppColors.getTextSecondaryColor(context),
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
          if (transactions.isNotEmpty) {
            // Thu thập tất cả các UID duy nhất từ danh sách giao dịch
            final uids = transactions
                .map((t) => t['createdBy'] as String?)
                .whereType<String>()
                .toSet();
            // Yêu cầu AppState tải tên của các UID này (nếu chưa có trong cache)
            if (uids.isNotEmpty) {
              // Dùng WidgetsBinding để tránh gọi setState trong lúc build
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if(context.mounted) {
                  context.read<AppState>().fetchDisplayNames(uids);
                }
              });
            }
          }
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
                        style: TextStyle(fontSize: 17, color: AppColors.getTextSecondaryColor(context)),
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
                final String? creatorUid = transaction['createdBy'] as String?;
                final String? dateTimeString = transaction['date'];
                final String formattedTime = dateTimeString != null
                    ? dateTimeFormat.format(DateTime.parse(dateTimeString))
                    : 'N/A';
                final double totalRevenue = (transaction['total'] as num? ?? 0.0).toDouble();
                final double totalVariableCost = (transaction['totalVariableCost'] as num? ?? 0.0).toDouble();
                final double grossProfit = totalRevenue - totalVariableCost;
                final List<dynamic>? cogsComponents = _selectedTransactionCategory == 'Doanh thu phụ'
                    ? transaction['cogsComponentsUsed_Secondary'] as List<dynamic>?
                    : transaction['cogsComponentsUsed'] as List<dynamic>?;
                IconData transactionIcon;
                Color iconColor;
                if (_selectedTransactionCategory == 'Doanh thu chính') {
                  transactionIcon = Icons.business_center_outlined;
                  iconColor = AppColors.primaryBlue;
                } else if (_selectedTransactionCategory == 'Doanh thu phụ') {
                  transactionIcon = Icons.work_outline_outlined;
                  iconColor = Colors.orange.shade700;
                } else {
                  transactionIcon = Icons.widgets_outlined;
                  iconColor = Colors.purple.shade600;
                }

                // BỌC WIDGET BẰNG VALUELLISTENABLEBUILDER
                return ValueListenableBuilder<int>(
                  valueListenable: appState.permissionVersion,
                  builder: (context, permissionVersion, child) {
                    // Logic kiểm tra quyền được chuyển vào đây
                    final bool isCreator = (transaction['createdBy'] ?? "") == appState.authUserId;
                    final bool canModify = appState.isOwner() || (appState.hasPermission('canEditRevenue') && isCreator);

                    return FadeTransition(
                      opacity: _fadeAnimation,
                      child: Slidable(
                        key: Key(transaction['id']?.toString() ?? UniqueKey().toString()),
                        endActionPane: canModify // Sử dụng biến `canModify` đã được cập nhật real-time
                            ? ActionPane(
                          motion: const StretchMotion(),
                          children: [
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
                                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: AppColors.getTextColor(context)),
                                    ),
                                    content: Text(
                                      'Bạn có chắc chắn muốn xóa giao dịch "${transaction['name']}" không? Hành động này không thể hoàn tác.',
                                      style: GoogleFonts.poppins(color: AppColors.getTextSecondaryColor(context)),
                                    ),
                                    actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, false),
                                        child: Text(
                                            'Hủy',
                                            style: GoogleFonts.poppins(color: AppColors.getTextSecondaryColor(context), fontWeight: FontWeight.w500)
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
                        )
                            : null,
                        child: Card(
                          elevation: 2,
                          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15)
                          ),
                          color: AppColors.getCardColor(context),
                          child: ExpansionTile(
                            leading: Container(
                              padding: EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                  color: iconColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12)
                              ),
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
                                  color: AppColors.getTextColor(context)),
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Tổng DT: ${currencyFormat.format(totalRevenue)}',
                                  style: TextStyle(
                                      fontSize: 14,
                                      color: AppColors.getTextSecondaryColor(context),
                                      fontWeight: FontWeight.w500),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (creatorUid != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 3.0),
                                    child: Consumer<AppState>(
                                      builder: (context, appStateConsumer, child) {
                                        return Text(
                                          "Tạo bởi: ${appStateConsumer.getUserDisplayName(creatorUid)}",
                                          style: GoogleFonts.poppins(
                                              fontSize: 11.5,
                                              color: AppColors.getTextSecondaryColor(context).withOpacity(0.8),
                                              fontStyle: FontStyle.italic),
                                        );
                                      },
                                    ),
                                  ),
                              ],
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
                                      fontSize: 13, color: AppColors.getTextSecondaryColor(context)),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  formattedTime,
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey.shade500),
                                ),
                              ],
                            ),
                            children: <Widget>[
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0).copyWith(left: 70),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Divider(height: 1, color: Colors.grey.shade200),
                                    SizedBox(height: 8),
                                    _buildProfitDetailRow(
                                        'Tổng CP Biến đổi:',
                                        currencyFormat.format(totalVariableCost),
                                        Colors.red.shade600),
                                    SizedBox(height: 4),
                                    _buildProfitDetailRow(
                                        'Lợi nhuận gộp:',
                                        currencyFormat.format(grossProfit),
                                        Colors.green.shade700
                                    ),
                                    if (cogsComponents != null && cogsComponents.isNotEmpty) ...[
                                      SizedBox(height: 8),
                                      Divider(height: 1, color: Colors.grey.shade200),
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
                                        child: Text(
                                          'Chi tiết giá vốn:',
                                          style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.getTextSecondaryColor(context)),
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
                                              Text('  • $name', style: TextStyle(color: AppColors.getTextSecondaryColor(context))),
                                              Text(currencyFormat.format(cost), style: TextStyle(color: AppColors.getTextSecondaryColor(context))),
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
            color: AppColors.getTextSecondaryColor(context),
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
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.getTextColor(context)),
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