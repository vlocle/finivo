import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:month_picker_dialog/month_picker_dialog.dart';
import '/screens/expense_manager.dart';
import 'update_expense_list_screen.dart';
import 'edit_fixed_expense_screen.dart';
import 'edit_variable_expense_screen.dart';
import 'user_setting_screen.dart';

class ExpenseScreen extends StatefulWidget {
  @override
  _ExpenseScreenState createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends State<ExpenseScreen> with SingleTickerProviderStateMixin {
  final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'VNĐ');
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _totalFadeAnimation;
  late Animation<double> _buttonScaleAnimation;
  DateTime _selectedMonth = DateTime.now();
  final TextEditingController _newExpenseController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final appState = Provider.of<AppState>(context, listen: false);
    _selectedMonth = appState.selectedDate;
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
    _controller.dispose();
    _newExpenseController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: Provider.of<AppState>(context, listen: false).selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      Provider.of<AppState>(context, listen: false).setSelectedDate(picked);
    }
  }

  void _navigateToEditExpense(String category) {
    final appState = Provider.of<AppState>(context, listen: false);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => category == "Chi phí cố định" ? const EditFixedExpenseScreen() : const EditVariableExpenseScreen(),
      ),
    ).then((_) => appState.loadExpenseValues());
  }

  Future<void> _selectMonth(BuildContext context) async {
    final DateTime? picked = await showMonthPicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => _selectedMonth = picked);
    }
  }

  void _showMonthlyFixedExpenseDialog(AppState appState) {
    final daysInMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day;
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setStateDialog) => FutureBuilder<Map<String, dynamic>>(
          future: Future.wait([
            ExpenseManager.loadFixedExpenseList(appState),
            ExpenseManager.loadMonthlyFixedAmounts(appState, _selectedMonth),
          ]).then((results) => {
            'fixedExpenses': results[0],
            'monthlyAmounts': results[1],
          }),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const AlertDialog(
                content: SizedBox(
                  height: 100,
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }
            if (snapshot.hasError) {
              return const AlertDialog(content: Text("Có lỗi xảy ra khi tải dữ liệu"));
            }
            if (snapshot.hasData) {
              List<Map<String, dynamic>> fixedExpenses = snapshot.data!['fixedExpenses'] as List<Map<String, dynamic>>;
              Map<String, double> savedMonthlyAmounts = snapshot.data!['monthlyAmounts'] as Map<String, double>;
              List<TextEditingController> monthlyControllers = fixedExpenses.map((_) => TextEditingController()).toList();
              for (int i = 0; i < fixedExpenses.length; i++) {
                final name = fixedExpenses[i]['name'];
                if (savedMonthlyAmounts.containsKey(name)) {
                  monthlyControllers[i].text = savedMonthlyAmounts[name]?.toString() ?? '';
                }
              }
              return AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      DateFormat('MMMM y', 'vi').format(_selectedMonth),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.calendar_month, color: Color(0xFF1976D2)),
                      onPressed: () async {
                        await _selectMonth(context);
                        setStateDialog(() {});
                      },
                      splashRadius: 20,
                    ),
                  ],
                ),
                content: SizedBox(
                  width: double.maxFinite,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _newExpenseController,
                              decoration: InputDecoration(
                                labelText: "Thêm khoản chi phí mới",
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add, color: Color(0xFF1976D2)),
                            onPressed: () async {
                              if (_newExpenseController.text.isNotEmpty) {
                                fixedExpenses.add({'name': _newExpenseController.text});
                                monthlyControllers.add(TextEditingController());
                                await ExpenseManager.saveFixedExpenseList(appState, fixedExpenses);
                                _newExpenseController.clear();
                                setStateDialog(() {});
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Đã thêm khoản chi phí")));
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      fixedExpenses.isEmpty
                          ? const Text("Chưa có danh sách chi phí cố định", style: TextStyle(color: Colors.grey))
                          : SizedBox(
                        height: 200,
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: fixedExpenses.length,
                          itemBuilder: (context, index) {
                            final name = fixedExpenses[index]['name'];
                            final savedAmount = savedMonthlyAmounts[name] ?? 0.0;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Row(
                                children: [
                                  Expanded(child: Text(name, style: const TextStyle(fontSize: 16))),
                                  savedAmount == 0
                                      ? Row(
                                    children: [
                                      SizedBox(
                                        width: 120,
                                        child: TextField(
                                          controller: monthlyControllers[index],
                                          keyboardType: TextInputType.number,
                                          decoration: InputDecoration(
                                            labelText: "Tháng (VNĐ)",
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(8),
                                              borderSide: const BorderSide(color: Color(0xFF1976D2)),
                                            ),
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.done, color: Colors.green, size: 20),
                                        onPressed: () async {
                                          final amount = double.tryParse(monthlyControllers[index].text) ?? 0.0;
                                          if (amount > 0) {
                                            showDialog(
                                              context: context,
                                              barrierDismissible: false,
                                              builder: (context) => AlertDialog(
                                                content: SizedBox(
                                                  height: 120,
                                                  child: Column(
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    children: const [
                                                      CircularProgressIndicator(),
                                                      SizedBox(height: 16),
                                                      Text("Đang lưu...", style: TextStyle(fontSize: 16)),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            );
                                            try {
                                              await ExpenseManager.saveMonthlyFixedAmount(appState, name, amount, _selectedMonth);
                                              Navigator.pop(context);
                                              setStateDialog(() => monthlyControllers[index].clear());
                                              await appState.loadExpenseValues();
                                              setState(() {});
                                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Đã lưu số tiền")));
                                            } catch (e) {
                                              Navigator.pop(context);
                                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Lỗi: $e")));
                                            }
                                          }
                                        },
                                      ),
                                    ],
                                  )
                                      : Row(
                                    children: [
                                      Text(
                                        currencyFormat.format(savedAmount),
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: const Icon(Icons.edit, color: Color(0xFF1976D2), size: 20),
                                        onPressed: () {
                                          setStateDialog(() => monthlyControllers[index].text = savedAmount.toString());
                                          showDialog(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                              title: Text("Chỉnh sửa số tiền - $name"),
                                              content: TextField(
                                                controller: monthlyControllers[index],
                                                keyboardType: TextInputType.number,
                                                decoration: InputDecoration(
                                                  labelText: "Nhập số tiền",
                                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                                ),
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.pop(context),
                                                  child: const Text("Hủy", style: TextStyle(color: Colors.grey)),
                                                ),
                                                TextButton(
                                                  onPressed: () async {
                                                    final amount = double.tryParse(monthlyControllers[index].text) ?? 0.0;
                                                    if (amount > 0) {
                                                      showDialog(
                                                        context: context,
                                                        barrierDismissible: false,
                                                        builder: (context) => AlertDialog(
                                                          content: SizedBox(
                                                            height: 120,
                                                            child: Column(
                                                              mainAxisAlignment: MainAxisAlignment.center,
                                                              children: const [
                                                                CircularProgressIndicator(),
                                                                SizedBox(height: 16),
                                                                Text("Đang lưu...", style: TextStyle(fontSize: 16)),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      );
                                                      try {
                                                        await ExpenseManager.saveMonthlyFixedAmount(appState, name, amount, _selectedMonth);
                                                        Navigator.pop(context);
                                                        Navigator.pop(context);
                                                        setStateDialog(() {});
                                                        await appState.loadExpenseValues();
                                                        setState(() {});
                                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Đã cập nhật số tiền")));
                                                      } catch (e) {
                                                        Navigator.pop(context);
                                                        Navigator.pop(context);
                                                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Lỗi: $e")));
                                                      }
                                                    } else {
                                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Số tiền không hợp lệ")));
                                                    }
                                                  },
                                                  child: const Text("Lưu", style: TextStyle(color: Color(0xFF1976D2))),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                    onPressed: () async {
                                      bool? confirm = await showDialog(
                                        context: dialogContext,
                                        builder: (context) => AlertDialog(
                                          title: const Text("Xác nhận xóa"),
                                          content: Text("Bạn có chắc muốn xóa '$name' không? Dữ liệu phân bổ theo ngày sẽ bị xóa."),
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
                                        showDialog(
                                          context: context,
                                          barrierDismissible: false,
                                          builder: (context) => AlertDialog(
                                            content: SizedBox(
                                              height: 120,
                                              child: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: const [
                                                  CircularProgressIndicator(),
                                                  SizedBox(height: 16),
                                                  Text("Đang xóa...", style: TextStyle(fontSize: 16)),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                        try {
                                          await ExpenseManager.deleteMonthlyFixedExpense(appState, name, _selectedMonth);
                                          fixedExpenses.removeAt(index);
                                          monthlyControllers.removeAt(index);
                                          await ExpenseManager.saveFixedExpenseList(appState, fixedExpenses);
                                          Navigator.pop(context);
                                          await appState.loadExpenseValues();
                                          setStateDialog(() {});
                                          setState(() {});
                                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Đã xóa khoản chi phí")));
                                        } catch (e) {
                                          Navigator.pop(context);
                                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Lỗi: $e")));
                                        }
                                      }
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Sẽ được phân bổ đều cho $daysInMonth ngày",
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text("Đóng", style: TextStyle(color: Color(0xFF1976D2))),
                  ),
                ],
              );
            }
            return const AlertDialog(content: Text("Không có dữ liệu"));
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final user = FirebaseAuth.instance.currentUser;
    double totalExpense = appState.getTotalFixedAndVariableExpense();
    final screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      body: Stack(
        children: [
          Container(
            height: MediaQuery.of(context).size.height * 0.25,
            color: const Color(0xFF1976D2).withOpacity(0.9),
          ),
          SafeArea(
            child: SingleChildScrollView( // Thêm SingleChildScrollView để tránh overflow
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
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => UserSettingsScreen()),
                                  );
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: CircleAvatar(
                                    radius: screenWidth < 360 ? 20 : 24,
                                    backgroundColor: Colors.white,
                                    backgroundImage: user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
                                    child: user?.photoURL == null
                                        ? Icon(
                                      Icons.person,
                                      size: screenWidth < 360 ? 24 : 30,
                                      color: const Color(0xFF1976D2),
                                    )
                                        : null,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "${user?.displayName ?? 'Finivo'}",
                                      style: TextStyle(
                                        fontSize: screenWidth < 360 ? 18 : 22,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
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
                        IconButton(
                          icon: const Icon(Icons.calendar_today, color: Colors.white),
                          onPressed: () => _selectDate(context),
                          splashRadius: 20,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      children: [
                        SlideTransition(
                          position: _slideAnimation,
                          child: FadeTransition(
                            opacity: _fadeAnimation,
                            child: Card(
                              elevation: 10,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  children: [
                                    ExpenseCategoryItem(
                                      title: "Chi phí cố định",
                                      amount: appState.fixedExpense,
                                      icon: Icons.lock,
                                      onTap: () => _navigateToEditExpense("Chi phí cố định"),
                                    ),
                                    const Divider(height: 1, color: Colors.grey),
                                    ExpenseCategoryItem(
                                      title: "Chi phí biến đổi",
                                      amount: appState.variableExpense,
                                      icon: Icons.trending_up,
                                      onTap: () => _navigateToEditExpense("Chi phí biến đổi"),
                                    ),
                                    const Divider(height: 1, color: Colors.grey),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text(
                                            'Tổng chi phí',
                                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                          ),
                                          Text(
                                            currencyFormat.format(totalExpense),
                                            style: const TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF1976D2),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: Card(
                            elevation: 6,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Tỷ lệ chi phí",
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    height: 150,
                                    child: PieChart(
                                      PieChartData(
                                        sections: [
                                          PieChartSectionData(
                                            value: appState.fixedExpense,
                                            color: const Color(0xFF1976D2),
                                            title: "Cố định",
                                            radius: 50,
                                            titleStyle: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                          PieChartSectionData(
                                            value: appState.variableExpense,
                                            color: Colors.orange,
                                            title: "Biến đổi",
                                            radius: 50,
                                            titleStyle: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                        sectionsSpace: 2,
                                        centerSpaceRadius: 40,
                                      ),
                                    ),
                                  ),
                                ],
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
                                minimumSize: Size(screenWidth - 32, 50),
                                padding: const EdgeInsets.symmetric(horizontal: 16), // Thêm padding để tránh tràn
                              ),
                              onPressed: () {
                                _controller.reset();
                                _controller.forward();
                                _showMonthlyFixedExpenseDialog(appState);
                              },
                              child: FittedBox( // Sử dụng FittedBox để tự động điều chỉnh kích thước văn bản
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  "Thêm cố định tháng",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: screenWidth < 360 ? 14 : 16, // Giảm fontSize trên màn hình nhỏ
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: ScaleTransition(
                            scale: _buttonScaleAnimation,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF42A5F5),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                minimumSize: Size(screenWidth - 32, 50),
                                padding: const EdgeInsets.symmetric(horizontal: 16), // Thêm padding để tránh tràn
                              ),
                              onPressed: () {
                                _controller.reset();
                                _controller.forward();
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => UpdateExpenseListScreen(category: "Chi phí biến đổi"),
                                  ),
                                );
                              },
                              child: FittedBox( // Sử dụng FittedBox để tự động điều chỉnh kích thước văn bản
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  "Quản lý chi phí biến đổi",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: screenWidth < 360 ? 14 : 16, // Giảm fontSize trên màn hình nhỏ
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
          ),
        ],
      ),
    );
  }
}

class ExpenseCategoryItem extends StatelessWidget {
  final String title;
  final double amount;
  final IconData icon;
  final VoidCallback onTap;
  final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'VNĐ');

  ExpenseCategoryItem({required this.title, required this.amount, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, size: 24, color: const Color(0xFF1976D2)),
                const SizedBox(width: 12),
                Text(title, style: const TextStyle(fontSize: 16)),
              ],
            ),
            Row(
              children: [
                Text(
                  currencyFormat.format(amount),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
              ],
            ),
          ],
        ),
      ),
    );
  }
}