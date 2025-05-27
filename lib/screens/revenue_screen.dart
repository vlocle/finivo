import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

// Assuming these are your existing imports
import '../state/app_state.dart';
import 'edit_main_revenue_screen.dart';
import 'edit_secondary_revenue_screen.dart';
import 'edit_other_revenue.dart';
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
  final dateTimeFormat = DateFormat('HH:mm a', 'vi_VN');
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _hasAnimated = false;
  String _selectedTransactionCategory = 'Doanh thu chính';
  final PageController _pageController = PageController();

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = Provider.of<AppState>(context, listen: false);
      if (appState.dataReadyListenable.value) {
        // Initial run if data is already there
        _runAnimation();
      }
      appState.dataReadyListenable.addListener(_onDataReady);
    });
  }

  void _onDataReady() {
    final appState = Provider.of<AppState>(context, listen: false);
    if (appState.dataReadyListenable.value && mounted) {
      print("RevenueScreen: Data is ready. Resetting and running animation.");
      _resetAnimation(); // Ensure animation plays from start for new data
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
    // Check if AppState is still accessible during dispose
    // Sometimes context might be an issue here if not careful
    if (mounted) {
      final appState = Provider.of<AppState>(context, listen: false);
      appState.dataReadyListenable.removeListener(_onDataReady);
    }
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
            // Consider if a setState is needed for other parts of the UI
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
        // This is crucial for making the list visible again.
        // Assumes AppState still holds the correct transaction data for the current date/category.
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
    // It's better to operate on a copy if `transactions` is directly from ValueNotifier.value
    List<Map<String, dynamic>> modifiableTransactions = List.from(transactions);
    modifiableTransactions.removeAt(index);

    RevenueManager.saveTransactionHistory(appState, category, modifiableTransactions);
    _updateTransactionNotifier(appState, category, modifiableTransactions);

    if (mounted) {
      // setState might not be needed if ValueListenableBuilder handles the list update
      // and animation is handled separately.
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã xóa giao dịch: ${transactionToRemove['name']}'),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: EdgeInsets.all(10),
      ),
    );
  }

  void _editTransaction(AppState appState,
      List<Map<String, dynamic>> transactions, int index, String category) {
    if (index < 0 || index >= transactions.length) return;

    TextEditingController editQuantityController =
    TextEditingController(text: transactions[index]['quantity'].toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.edit_note, color: _primaryColor),
            SizedBox(width: 10),
            Text("Chỉnh sửa số lượng", style: TextStyle(fontWeight: FontWeight.bold, color: _textColorPrimary)),
          ],
        ),
        content: TextField(
          keyboardType: TextInputType.number,
          controller: editQuantityController,
          decoration: InputDecoration(
            labelText: "Nhập số lượng mới",
            labelStyle: TextStyle(color: _textColorSecondary),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _primaryColor, width: 2)
            ),
            prefixIcon: Icon(Icons.production_quantity_limits, color: _primaryColor.withOpacity(0.7)),
          ),
          maxLines: 1,
          maxLength: 5,
        ),
        actionsPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Hủy", style: TextStyle(color: _textColorSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12)
            ),
            onPressed: () {
              // Operate on a copy for modification
              List<Map<String, dynamic>> modifiableTransactions = List.from(transactions);
              int newQuantity = int.tryParse(editQuantityController.text) ??
                  modifiableTransactions[index]['quantity'];
              modifiableTransactions[index]['quantity'] = newQuantity;
              modifiableTransactions[index]['total'] =
                  (modifiableTransactions[index]['price'] as num? ?? 0.0) * newQuantity;

              RevenueManager.saveTransactionHistory(
                  appState, category, modifiableTransactions);
              _updateTransactionNotifier(appState, category, modifiableTransactions);

              // if (mounted) {
              //   setState(() {}); // May not be needed
              // }
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Đã cập nhật số lượng cho: ${modifiableTransactions[index]['name']}'),
                  backgroundColor: _accentColor,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  margin: EdgeInsets.all(10),
                ),
              );
            },
            child: Text("Lưu"),
          ),
        ],
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
          print("RevenueScreen: TransactionList ValueListenableBuilder rebuilt. Transactions count: ${transactions.length}. Animation value: ${_fadeAnimation.value}");
          if (transactions.isEmpty) {
            return SliverFillRemaining(
              hasScrollBody: false,
              child: FadeTransition( // Also apply fade to empty state for consistency
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
                String? dateTimeString = transaction['date'];
                String formattedTime = dateTimeString != null
                    ? dateTimeFormat.format(DateTime.parse(dateTimeString))
                    : 'N/A';

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
                        SlidableAction(
                          onPressed: (context) {
                            _editTransaction(appState, transactions, index,
                                _selectedTransactionCategory);
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
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                title: Row(
                                  children: [
                                    Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
                                    SizedBox(width: 10),
                                    Text('Xác nhận xóa', style: TextStyle(fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                content: Text('Bạn có chắc chắn muốn xóa giao dịch này? Hành động này không thể hoàn tác.'),
                                actionsPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: Text('Hủy', style: TextStyle(color: _textColorSecondary)),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.redAccent,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                                    ),
                                    onPressed: () => Navigator.pop(context, true),
                                    child: Text('Xóa'),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              _removeTransaction(appState, transactions, index,
                                  _selectedTransactionCategory);
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
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 12),
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
                              fontWeight: FontWeight.w600, fontSize: 16, color: _textColorPrimary),
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          'Tổng: ${currencyFormat.format(transaction['total'] ?? 0.0)}',
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