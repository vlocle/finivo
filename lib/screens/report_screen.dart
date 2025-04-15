import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import 'package:intl/intl.dart';
import 'user_setting_screen.dart';

class ReportScreen extends StatefulWidget {
  @override
  _ReportScreenState createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> with SingleTickerProviderStateMixin {
  String selectedReport = 'Tổng Quan';
  final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
  DateTimeRange? selectedDateRange;
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  String formatNumberCompact(double value) {
    if (value >= 1e6) {
      return '${(value / 1e6).toStringAsFixed(value / 1e6 >= 10 ? 0 : 1)}M';
    } else if (value >= 1e3) {
      return '${(value / 1e3).toStringAsFixed(value / 1e3 >= 10 ? 0 : 1)}K';
    } else {
      return value.toStringAsFixed(0);
    }
  }

  @override
  void initState() {
    super.initState();
    selectedDateRange = DateTimeRange(
      start: DateTime.now().subtract(const Duration(days: 6)),
      end: DateTime.now(),
    );
    _controller = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: selectedDateRange,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != selectedDateRange) {
      setState(() {
        selectedDateRange = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          Container(
            height: MediaQuery.of(context).size.height * 0.25,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFF1976D2), const Color(0xFF1976D2).withOpacity(0.9)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
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
                                  )
                                ],
                              ),
                              child: CircleAvatar(
                                radius: 24,
                                backgroundColor: Colors.white,
                                backgroundImage: user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
                                child: user?.photoURL == null
                                    ? const Icon(Icons.person, size: 30, color: Color(0xFF1976D2))
                                    : null,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            "Báo Cáo",
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () => _selectDateRange(context),
                        child: Chip(
                          label: Text(
                            "${DateFormat('dd/MM').format(selectedDateRange!.start)} - ${DateFormat('dd/MM').format(selectedDateRange!.end)}",
                            style: TextStyle(color: isDarkMode ? Colors.white : const Color(0xFF1976D2)),
                          ),
                          backgroundColor: isDarkMode ? Colors.grey[800] : Colors.white,
                          elevation: 2,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDarkMode
                            ? [Colors.grey[900]!, Colors.grey[850]!]
                            : [const Color(0xFFE3F2FD), const Color(0xFFBBDEFB)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Consumer<AppState>(
                        builder: (context, appState, child) {
                          return Column(
                            children: [
                              const SizedBox(height: 16),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: SegmentedButton<String>(
                                  segments: const [
                                    ButtonSegment(value: 'Tổng Quan', label: Text('Tổng Quan')),
                                    ButtonSegment(value: 'Chi Phí', label: Text('Chi Phí')),
                                    ButtonSegment(value: 'Doanh Thu', label: Text('Doanh Thu')),
                                    ButtonSegment(value: 'Doanh Thu Theo Sản Phẩm', label: Text('Sản Phẩm')),
                                  ],
                                  selected: {selectedReport},
                                  onSelectionChanged: (newSelection) {
                                    setState(() {
                                      selectedReport = newSelection.first;
                                      _controller.reset();
                                      _controller.forward();
                                    });
                                  },
                                  style: ButtonStyle(
                                    backgroundColor: WidgetStateProperty.resolveWith(
                                          (states) => states.contains(WidgetState.selected)
                                          ? const Color(0xFF1976D2)
                                          : isDarkMode
                                          ? Colors.grey[700]
                                          : Colors.white,
                                    ),
                                    foregroundColor: WidgetStateProperty.resolveWith(
                                          (states) => states.contains(WidgetState.selected)
                                          ? Colors.white
                                          : isDarkMode
                                          ? Colors.white70
                                          : const Color(0xFF1976D2),
                                    ),
                                    shape: WidgetStateProperty.all(
                                      RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Expanded(
                                child: _buildReportContent(appState),
                              ),
                            ],
                          );
                        },
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

  Widget _buildReportContent(AppState appState) {
    if (selectedDateRange == null) return const SizedBox();
    if (selectedReport == 'Tổng Quan') return _buildOverviewReport(appState);
    if (selectedReport == 'Chi Phí') return _buildExpenseReport(appState);
    if (selectedReport == 'Doanh Thu') return _buildRevenueReport(appState);
    if (selectedReport == 'Doanh Thu Theo Sản Phẩm') return _buildProductRevenueReport(appState);
    return const SizedBox();
  }

  // Báo cáo Tổng Quan
  Widget _buildOverviewReport(AppState appState) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return FutureBuilder<Map<String, double>>(
      future: appState.getOverviewForRange(selectedDateRange!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasData) {
          final data = snapshot.data!;
          double totalRevenue = data['totalRevenue'] ?? 0.0;
          double totalExpense = data['totalExpense'] ?? 0.0;
          double profit = data['profit'] ?? 0.0;
          double averageProfitMargin = data['averageProfitMargin'] ?? 0.0;
          double avgRevenuePerDay = data['avgRevenuePerDay'] ?? 0.0;
          double avgExpensePerDay = data['avgExpensePerDay'] ?? 0.0;
          double avgProfitPerDay = data['avgProfitPerDay'] ?? 0.0;
          double expenseToRevenueRatio = data['expenseToRevenueRatio'] ?? 0.0;
          return SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Card(
                      elevation: 10,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      color: isDarkMode ? Colors.grey[800] : Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            _buildInfoCard('Tổng Doanh Thu', totalRevenue, Icons.attach_money, Colors.green),
                            const SizedBox(height: 12),
                            _buildInfoCard('Tổng Chi Phí', totalExpense, Icons.money_off, Colors.red),
                            const SizedBox(height: 12),
                            _buildInfoCard('Lợi Nhuận', profit, Icons.trending_up, Colors.blue),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      elevation: 6,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      color: isDarkMode ? Colors.grey[800] : Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Chỉ số KPI',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDarkMode ? Colors.white : const Color(0xFF1976D2),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildKpiItem('Doanh Thu TB/Ngày', avgRevenuePerDay, Icons.bar_chart),
                            _buildKpiItem('Chi Phí TB/Ngày', avgExpensePerDay, Icons.pie_chart),
                            _buildKpiItem('Lợi Nhuận TB/Ngày', avgProfitPerDay, Icons.show_chart),
                            _buildKpiItem('Tỷ Lệ Chi Phí/Doanh Thu', expenseToRevenueRatio, Icons.percent,
                                isPercentage: true),
                            _buildKpiItem('Biên Lợi Nhuận TB', averageProfitMargin, Icons.trending_up,
                                isPercentage: true),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      elevation: 6,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      color: isDarkMode ? Colors.grey[800] : Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Xu hướng',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDarkMode ? Colors.white : const Color(0xFF1976D2),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildLegend(),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: MediaQuery.of(context).size.height * 0.4,
                              child: _buildOverviewTrendChart(appState, selectedDateRange!),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return const Center(child: Text('Không có dữ liệu'));
      },
    );
  }

  Widget _buildOverviewTrendChart(AppState appState, DateTimeRange range) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return FutureBuilder<List<Map<String, double>>>(
      future: appState.getDailyOverviewForRange(range),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        }
        if (snapshot.hasData) {
          final dailyData = snapshot.data!;
          double maxRevenue = dailyData.isNotEmpty
              ? dailyData.map((e) => e['totalRevenue'] ?? 0).reduce((a, b) => a > b ? a : b)
              : 1000000;
          double horizontalInterval = (maxRevenue / 5).roundToDouble();
          horizontalInterval = horizontalInterval > 0 ? horizontalInterval : 100000;
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDarkMode
                    ? [Colors.grey[900]!, Colors.grey[850]!]
                    : [Colors.grey.withOpacity(0.1), Colors.white],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: LineChart(
              LineChartData(
                lineBarsData: [
                  _buildLineData(dailyData, 'totalRevenue', Colors.green),
                  _buildLineData(dailyData, 'totalExpense', Colors.red),
                  _buildLineData(dailyData, 'profit', Colors.blue),
                ],
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, _) {
                        int days = range.end.difference(range.start).inDays + 1;
                        if (value.toInt() >= 0 && value.toInt() < days) {
                          DateTime date = range.start.add(Duration(days: value.toInt()));
                          return Transform.rotate(
                            angle: -45 * 3.14159 / 180,
                            child: Text(
                              DateFormat('dd/MM').format(date),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: isDarkMode ? Colors.white70 : Colors.black87,
                              ),
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 50,
                      getTitlesWidget: (value, _) => Text(
                        formatNumberCompact(value),
                        style: TextStyle(fontSize: 14, color: isDarkMode ? Colors.white70 : Colors.black87),
                      ),
                    ),
                  ),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: horizontalInterval,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: isDarkMode ? Colors.white.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
                    strokeWidth: 1,
                    dashArray: [5, 5],
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    tooltipBgColor: isDarkMode ? Colors.grey[800]! : Colors.black.withOpacity(0.9),
                    tooltipRoundedRadius: 8,
                    tooltipPadding: const EdgeInsets.all(8),
                    getTooltipItems: (touchedSpots) => touchedSpots.map((spot) {
                      String label = spot.barIndex == 0 ? 'Doanh Thu' : spot.barIndex == 1 ? 'Chi Phí' : 'Lợi Nhuận';
                      return LineTooltipItem(
                        '$label: ${currencyFormat.format(spot.y)}',
                        TextStyle(
                          color: isDarkMode ? Colors.white : Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          );
        }
        return const Text('Không có dữ liệu');
      },
    );
  }

  // Báo cáo Chi Phí
  Widget _buildExpenseReport(AppState appState) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return FutureBuilder<Map<String, double>>(
      future: appState.getExpensesForRange(selectedDateRange!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasData) {
          final data = snapshot.data!;
          double fixedExpense = data['fixedExpense'] ?? 0.0;
          double variableExpense = data['variableExpense'] ?? 0.0;
          double totalExpense = data['totalExpense'] ?? 0.0;
          return SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Card(
                      elevation: 10,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      color: isDarkMode ? Colors.grey[800] : Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            _buildInfoCard('Chi Phí Cố Định', fixedExpense, Icons.lock, Colors.blue),
                            const SizedBox(height: 12),
                            _buildInfoCard('Chi Phí Biến Đổi', variableExpense, Icons.trending_up, Colors.orange),
                            const SizedBox(height: 12),
                            _buildInfoCard('Tổng Chi Phí', totalExpense, Icons.money_off, Colors.red),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      elevation: 6,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      color: isDarkMode ? Colors.grey[800] : Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Phân Tích Chi Phí',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDarkMode ? Colors.white : const Color(0xFF1976D2),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 250,
                              child: FutureBuilder<Map<String, double>>(
                                future: appState.getExpenseBreakdown(selectedDateRange!),
                                builder: (context, breakdownSnapshot) {
                                  if (breakdownSnapshot.connectionState == ConnectionState.waiting) {
                                    return const Center(child: CircularProgressIndicator());
                                  }
                                  if (breakdownSnapshot.hasData && breakdownSnapshot.data!.isNotEmpty) {
                                    return _buildPieChart(breakdownSnapshot.data!);
                                  }
                                  return const Center(child: Text('Không có dữ liệu chi tiết'));
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      elevation: 6,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      color: isDarkMode ? Colors.grey[800] : Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Xu hướng',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDarkMode ? Colors.white : const Color(0xFF1976D2),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildExpenseLegend(),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: MediaQuery.of(context).size.height * 0.4,
                              child: _buildExpenseTrendChart(appState, selectedDateRange!),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return const Center(child: Text('Không có dữ liệu'));
      },
    );
  }

  Widget _buildExpenseTrendChart(AppState appState, DateTimeRange range) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return FutureBuilder<List<Map<String, double>>>(
      future: appState.getDailyExpensesForRange(range),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        }
        if (snapshot.hasData) {
          final dailyData = snapshot.data!;
          double maxExpense = dailyData.isNotEmpty
              ? dailyData.map((e) => e['totalExpense'] ?? 0).reduce((a, b) => a > b ? a : b)
              : 1000000;
          double horizontalInterval = (maxExpense / 5).roundToDouble();
          horizontalInterval = horizontalInterval > 0 ? horizontalInterval : 100000;
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDarkMode
                    ? [Colors.grey[900]!, Colors.grey[850]!]
                    : [Colors.grey.withOpacity(0.1), Colors.white],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: LineChart(
              LineChartData(
                lineBarsData: [
                  _buildLineData(dailyData, 'fixedExpense', Colors.blue, dashArray: [5, 5]),
                  _buildLineData(dailyData, 'variableExpense', Colors.orange, dashArray: [5, 5]),
                  _buildLineData(dailyData, 'totalExpense', Colors.red),
                ],
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, _) {
                        int days = range.end.difference(range.start).inDays + 1;
                        if (value.toInt() >= 0 && value.toInt() < days) {
                          DateTime date = range.start.add(Duration(days: value.toInt()));
                          return Transform.rotate(
                            angle: -45 * 3.14159 / 180,
                            child: Text(
                              DateFormat('dd/MM').format(date),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: isDarkMode ? Colors.white70 : Colors.black87,
                              ),
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 50,
                      getTitlesWidget: (value, _) => Text(
                        formatNumberCompact(value),
                        style: TextStyle(fontSize: 14, color: isDarkMode ? Colors.white70 : Colors.black87),
                      ),
                    ),
                  ),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: horizontalInterval,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: isDarkMode ? Colors.white.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
                    strokeWidth: 1,
                    dashArray: [5, 5],
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    tooltipBgColor: isDarkMode ? Colors.grey[800]! : Colors.white,
                    tooltipBorder: BorderSide(color: isDarkMode ? Colors.grey[600]! : Colors.grey, width: 1),
                    tooltipRoundedRadius: 8,
                    tooltipPadding: const EdgeInsets.all(8),
                    getTooltipItems: (touchedSpots) => touchedSpots.map((spot) {
                      String label = spot.barIndex == 0 ? 'Cố Định' : spot.barIndex == 1 ? 'Biến Đổi' : 'Tổng';
                      Color color = spot.barIndex == 0 ? Colors.blue : spot.barIndex == 1 ? Colors.orange : Colors.red;
                      return LineTooltipItem(
                        '$label: ${currencyFormat.format(spot.y)}',
                        TextStyle(color: color, fontWeight: FontWeight.bold),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          );
        }
        return const Text('Không có dữ liệu');
      },
    );
  }

  // Báo cáo Doanh Thu
  Widget _buildRevenueReport(AppState appState) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return FutureBuilder<Map<String, double>>(
      future: appState.getRevenueForRange(selectedDateRange!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasData) {
          final data = snapshot.data!;
          double mainRevenue = data['mainRevenue'] ?? 0.0;
          double secondaryRevenue = data['secondaryRevenue'] ?? 0.0;
          double otherRevenue = data['otherRevenue'] ?? 0.0;
          double totalRevenue = data['totalRevenue'] ?? 0.0;
          return SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Card(
                      elevation: 10,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      color: isDarkMode ? Colors.grey[800] : Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            _buildInfoCard('Doanh Thu Chính', mainRevenue, Icons.attach_money, Colors.green),
                            const SizedBox(height: 12),
                            _buildInfoCard('Doanh Thu Phụ', secondaryRevenue, Icons.account_balance_wallet, Colors.blue),
                            const SizedBox(height: 12),
                            _buildInfoCard('Doanh Thu Khác', otherRevenue, Icons.add_circle_outline, Colors.orange),
                            const SizedBox(height: 12),
                            _buildInfoCard('Tổng Doanh Thu', totalRevenue, Icons.bar_chart, Colors.teal),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      elevation: 6,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      color: isDarkMode ? Colors.grey[800] : Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Xu hướng',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDarkMode ? Colors.white : const Color(0xFF1976D2),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildRevenueLegend(),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: MediaQuery.of(context).size.height * 0.4,
                              child: _buildRevenueTrendChart(appState, selectedDateRange!),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return const Center(child: Text('Không có dữ liệu'));
      },
    );
  }

  Widget _buildRevenueTrendChart(AppState appState, DateTimeRange range) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return FutureBuilder<List<Map<String, double>>>(
      future: appState.getDailyRevenueForRange(range),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        }
        if (snapshot.hasData) {
          final dailyData = snapshot.data!;
          double maxRevenue = dailyData.isNotEmpty
              ? dailyData
              .map((e) => (e['mainRevenue'] ?? 0) + (e['secondaryRevenue'] ?? 0) + (e['otherRevenue'] ?? 0))
              .reduce((a, b) => a > b ? a : b)
              : 1000000;
          double horizontalInterval = (maxRevenue / 5).roundToDouble();
          horizontalInterval = horizontalInterval > 0 ? horizontalInterval : 100000;
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDarkMode
                    ? [Colors.grey[900]!, Colors.grey[850]!]
                    : [Colors.grey.withOpacity(0.1), Colors.white],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: BarChart(
              BarChartData(
                barGroups: dailyData.asMap().entries.map((entry) {
                  int index = entry.key;
                  var data = entry.value;
                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: data['mainRevenue'] ?? 0.0,
                        gradient: const LinearGradient(colors: [Colors.green, Colors.greenAccent]),
                        width: 12,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: 0,
                          color: isDarkMode ? Colors.grey[700] : Colors.grey.withOpacity(0.2),
                        ),
                      ),
                      BarChartRodData(
                        toY: data['secondaryRevenue'] ?? 0.0,
                        gradient: const LinearGradient(colors: [Colors.blue, Colors.blueAccent]),
                        width: 12,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: 0,
                          color: isDarkMode ? Colors.grey[700] : Colors.grey.withOpacity(0.2),
                        ),
                      ),
                      BarChartRodData(
                        toY: data['otherRevenue'] ?? 0.0,
                        gradient: const LinearGradient(colors: [Colors.orange, Colors.orangeAccent]),
                        width: 12,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: 0,
                          color: isDarkMode ? Colors.grey[700] : Colors.grey.withOpacity(0.2),
                        ),
                      ),
                    ],
                    barsSpace: 6,
                  );
                }).toList(),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, _) {
                        int days = range.end.difference(range.start).inDays + 1;
                        if (value.toInt() >= 0 && value.toInt() < days) {
                          DateTime date = range.start.add(Duration(days: value.toInt()));
                          return Transform.rotate(
                            angle: -45 * 3.14159 / 180,
                            child: Text(
                              DateFormat('dd/MM').format(date),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: isDarkMode ? Colors.white70 : Colors.black87,
                              ),
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 50,
                      getTitlesWidget: (value, _) => Text(
                        formatNumberCompact(value),
                        style: TextStyle(fontSize: 14, color: isDarkMode ? Colors.white70 : Colors.black87),
                      ),
                    ),
                  ),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: horizontalInterval,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: isDarkMode ? Colors.white.withOpacity(0.2) : Colors.grey.withOpacity(0.3),
                    strokeWidth: 1,
                    dashArray: [5, 5],
                  ),
                ),
                borderData: FlBorderData(show: false),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    tooltipBgColor: isDarkMode ? Colors.grey[800]! : Colors.black.withOpacity(0.9),
                    tooltipRoundedRadius: 8,
                    tooltipPadding: const EdgeInsets.all(8),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      String label = rodIndex == 0 ? 'Chính' : rodIndex == 1 ? 'Phụ' : 'Khác';
                      return BarTooltipItem(
                        '$label: ${currencyFormat.format(rod.toY)}',
                        TextStyle(
                          color: isDarkMode ? Colors.white : Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          );
        }
        return const Text('Không có dữ liệu');
      },
    );
  }

  // Báo cáo Doanh Thu Theo Sản Phẩm
  Widget _buildProductRevenueReport(AppState appState) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return FutureBuilder<Map<String, Map<String, double>>>(
      future: appState.getProductRevenueDetails(selectedDateRange!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasData) {
          final productDetails = snapshot.data!;
          double totalRevenue = productDetails.values.fold(0.0, (sum, value) => sum + value['total']!);
          var sortedProducts = productDetails.entries.toList()
            ..sort((a, b) => b.value['total']!.compareTo(a.value['total']!));
          return SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Card(
                      elevation: 10,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      color: isDarkMode ? Colors.grey[800] : Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            _buildInfoCard('Tổng Doanh Thu', totalRevenue, Icons.bar_chart, Colors.teal),
                            const SizedBox(height: 12),
                            ...sortedProducts.map((entry) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6.0),
                              child: _buildKpiItem(
                                entry.key,
                                entry.value['total']!,
                                Icons.production_quantity_limits,
                                quantity: entry.value['quantity']!.toInt(),
                              ),
                            )),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      elevation: 6,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      color: isDarkMode ? Colors.grey[800] : Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Phân Tích Doanh Thu',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDarkMode ? Colors.white : const Color(0xFF1976D2),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 250,
                              child: _buildPieChart({for (var entry in sortedProducts) entry.key: entry.value['total']!}),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return const Center(child: Text('Không có dữ liệu'));
      },
    );
  }

  // Hàm hỗ trợ
  Widget _buildInfoCard(String label, double value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.7), color],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 28, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 16, color: Colors.white),
            ),
          ),
          Text(
            currencyFormat.format(value),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiItem(String label, double value, IconData icon, {bool isPercentage = false, int? quantity}) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: isDarkMode ? Colors.white70 : const Color(0xFF1976D2)),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: TextStyle(fontSize: 16, color: isDarkMode ? Colors.white : Colors.black))),
          Text(
            isPercentage
                ? '${value.toStringAsFixed(2)}%'
                : quantity != null
                ? '${currencyFormat.format(value)} ($quantity sp)'
                : currencyFormat.format(value),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  LineChartBarData _buildLineData(List<Map<String, double>> dailyData, String key, Color color, {List<int>? dashArray}) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return LineChartBarData(
      spots: dailyData.asMap().entries.map((entry) {
        return FlSpot(entry.key.toDouble(), entry.value[key] ?? 0.0);
      }).toList(),
      isCurved: true,
      gradient: LinearGradient(
        colors: [color.withOpacity(0.5), color],
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
      ),
      barWidth: 4,
      dashArray: dashArray,
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
          radius: 4,
          color: color,
          strokeWidth: 2,
          strokeColor: isDarkMode ? (Colors.grey[700] ?? Colors.grey) : Colors.white,
        ),
      ),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          colors: [color.withOpacity(0.4), color.withOpacity(0)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
    );
  }

  Widget _buildPieChart(Map<String, double> data) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    double total = data.values.fold(0.0, (sum, value) => sum + value);
    return PieChart(
      PieChartData(
        sections: data.entries.map((entry) {
          double percentage = total > 0 ? (entry.value / total) * 100 : 0.0;
          return PieChartSectionData(
            value: entry.value,
            title: '${entry.key}\n${percentage.toStringAsFixed(1)}%',
            color: _getRandomColor(entry.key).withOpacity(0.8),
            radius: 100,
            titleStyle: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
            titlePositionPercentageOffset: 0.55,
          );
        }).toList(),
        sectionsSpace: 2,
        centerSpaceRadius: 40,
        pieTouchData: PieTouchData(
          touchCallback: (FlTouchEvent event, pieTouchResponse) {
            if (!event.isInterestedForInteractions || pieTouchResponse == null || pieTouchResponse.touchedSection == null) {
              return;
            }
            int touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
            String touchedCategory = data.keys.elementAt(touchedIndex);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$touchedCategory: ${currencyFormat.format(data[touchedCategory]!)}'),
                duration: const Duration(seconds: 2),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLegend() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildLegendItem('Doanh Thu', Colors.green),
        const SizedBox(width: 16),
        _buildLegendItem('Chi Phí', Colors.red),
        const SizedBox(width: 16),
        _buildLegendItem('Lợi Nhuận', Colors.blue),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [color.withOpacity(0.7), color]),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: isDarkMode ? Colors.white70 : Colors.black87),
        ),
      ],
    );
  }

  Widget _buildExpenseLegend() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildLegendItem('Cố Định', Colors.blue),
        const SizedBox(width: 16),
        _buildLegendItem('Biến Đổi', Colors.orange),
        const SizedBox(width: 16),
        _buildLegendItem('Tổng', Colors.red),
      ],
    );
  }

  Widget _buildRevenueLegend() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildLegendItem('Doanh Thu Chính', Colors.green),
        const SizedBox(width: 16),
        _buildLegendItem('Doanh Thu Phụ', Colors.blue),
      ],
    );
  }

  Color _getRandomColor(String key) {
    final colors = [Colors.blue, Colors.red, Colors.green, Colors.orange, Colors.purple, Colors.cyan];
    return colors[key.hashCode % colors.length];
  }
}