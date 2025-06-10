import 'package:firebase_auth/firebase_auth.dart'; // [cite: 1]
import 'package:flutter/material.dart'; // [cite: 1]
import 'package:fl_chart/fl_chart.dart'; // [cite: 1]
import 'package:provider/provider.dart'; // [cite: 1]
import '../state/app_state.dart'; // Giả định đường dẫn này đúng // [cite: 1]
import 'package:intl/intl.dart'; // [cite: 1]
import 'account_switcher.dart';
import 'user_setting_screen.dart'; // [cite: 1]
// Giả định đường dẫn này đúng
import 'skeleton_loading.dart'; // Giả định đường dẫn này đúng // [cite: 2]

// Định nghĩa màu sắc tập trung
class AppColors {
  static const Color primaryBlue = Color(0xFF0A7AFF); // [cite: 2]
  static const Color primaryBlueLight = Color(0x1A2F81D7); // Blue with opacity for backgrounds // [cite: 3]
  static const Color textPrimaryLight = Color(0xFF1D1D1F); // [cite: 3]
  static const Color textSecondaryLight = Color(0xFF6E6E73); // [cite: 4]
  static const Color backgroundLight = Color(0xFFF9F9F9); // [cite: 4]
  static const Color cardLight = Colors.white; // [cite: 5]
  static const Color borderLight = Color(0xFFE0E0E0); // [cite: 5]
  static const Color dividerLight = Color(0xFFEDEDED); // [cite: 6]
  static const Color textPrimaryDark = Color(0xFFFFFFFF); // [cite: 6]
  static const Color textSecondaryDark = Color(0xFFA0A0A0); // [cite: 7]
  static const Color backgroundDark = Color(0xFF121212); // [cite: 7]
  static const Color cardDark = Color(0xFF1E1E1E); // [cite: 8]
  static const Color borderDark = Color(0xFF2C2C2E); // [cite: 8]
  static const Color dividerDark = Color(0xFF2C2C2E); // [cite: 9]
  // Chart Colors
  static const Color chartGreen = Color(0xFF34C759); // [cite: 9]
  static const Color chartRed = Color(0xFFFF3B30); // [cite: 10]
  static const Color chartBlue = primaryBlue; // [cite: 10]
  // Sử dụng màu chủ đạo
  static const Color chartOrange = Color(0xFFFF9500); // [cite: 11]
  static const Color chartTeal = Color(0xFF5AC8FA); // [cite: 12]
  static const Color chartPurple = Color(0xFFAF52DE); // [cite: 12]
  static const Color chartYellow = Color(0xFFFFCC00); // [cite: 13]
  static const Color chartPink = Color(0xFFFF2D55); // [cite: 13]

  static List<Color> get pieChartColors => [ // [cite: 14]
    chartGreen, chartBlue, chartOrange, chartTeal, chartPurple, chartYellow, chartPink, // [cite: 14]
    chartGreen.withOpacity(0.7), chartBlue.withOpacity(0.7), chartOrange.withOpacity(0.7), // [cite: 14]
    chartTeal.withOpacity(0.7), chartPurple.withOpacity(0.7), chartYellow.withOpacity(0.7), // [cite: 14]
    chartPink.withOpacity(0.7), // [cite: 14]
  ];
  static Color getPieChartColor(String key, int index) {
    return pieChartColors[index % pieChartColors.length]; // [cite: 15]
  }

  // Helper để lấy màu dựa trên theme
  static Color getTextColor(BuildContext context) { // [cite: 16]
    return Theme.of(context).brightness == Brightness.dark ? textPrimaryDark : textPrimaryLight; // [cite: 16, 17]
  }

  static Color getTextSecondaryColor(BuildContext context) { // [cite: 18]
    return Theme.of(context).brightness == Brightness.dark ? textSecondaryDark : textSecondaryLight; // [cite: 18, 19]
  }

  static Color getCardColor(BuildContext context) { // [cite: 19]
    return Theme.of(context).brightness == Brightness.dark ? cardDark : cardLight; // [cite: 19, 20]
  }

  static Color getBackgroundColor(BuildContext context) { // [cite: 21]
    return Theme.of(context).brightness == Brightness.dark ? backgroundDark : backgroundLight; // [cite: 21, 22]
  }

  static Color getBorderColor(BuildContext context) { // [cite: 22]
    return Theme.of(context).brightness == Brightness.dark ? borderDark : borderLight; // [cite: 22, 23]
  }

  static Color getDividerColor(BuildContext context) { // [cite: 24]
    return Theme.of(context).brightness == Brightness.dark ? dividerDark : dividerLight; // [cite: 24, 25]
  }
}

class ReportScreen extends StatefulWidget {
  @override
  _ReportScreenState createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> with SingleTickerProviderStateMixin {
  String selectedReport = 'Tổng Quan'; // [cite: 25]
  final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ'); // [cite: 26]
  DateTimeRange? selectedDateRange;
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  String formatNumberCompact(double value) { // [cite: 27]
    if (value >= 1e6) {
      return '${(value / 1e6).toStringAsFixed(value / 1e6 >= 10 ? 0 : 1)}M'; // [cite: 27]
    } else if (value >= 1e3) {
      return '${(value / 1e3).toStringAsFixed(value / 1e3 >= 10 ? 0 : 1)}K'; // [cite: 28]
    } else {
      return value.toStringAsFixed(0); // [cite: 29]
    }
  }

  @override
  void initState() {
    super.initState(); // [cite: 30]
    selectedDateRange = DateTimeRange( // [cite: 31]
      start: DateTime.now().subtract(const Duration(days: 6)), // [cite: 31]
      end: DateTime.now(), // [cite: 31]
    );
    _controller = AnimationController( // [cite: 32]
      duration: const Duration(milliseconds: 700), // [cite: 32]
      vsync: this, // [cite: 32]
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero) // [cite: 33]
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut)); // [cite: 33]
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0) // [cite: 34]
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn)); // [cite: 34]
    _controller.forward(); // [cite: 34]
  }

  @override
  void dispose() {
    _controller.dispose(); // [cite: 35]
    super.dispose(); // [cite: 35]
  }

  Future<void> _selectDateRange(BuildContext context) async { // [cite: 36]
    final DateTimeRange? picked = await showDateRangePicker( // [cite: 36, 37]
      context: context, // [cite: 37]
      initialDateRange: selectedDateRange, // [cite: 37]
      firstDate: DateTime(2020), // [cite: 37]
      lastDate: DateTime(2030), // [cite: 37]
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primaryBlue, // [cite: 37]
              onPrimary: Colors.white, // [cite: 38]
              onSurface: AppColors.getTextColor(context), // [cite: 38]
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryBlue, // [cite: 38]
              ),
            ),
          ),
          child: child!, // [cite: 39]
        );
      },
    );
    if (picked != null && picked != selectedDateRange) { // [cite: 40]
      setState(() {
        selectedDateRange = picked; // [cite: 40]
        _controller.reset(); // [cite: 40]
        _controller.forward(); // [cite: 40]
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser; // [cite: 41]
    final isDarkMode = Theme.of(context).brightness == Brightness.dark; // [cite: 42]
    return Scaffold(
      backgroundColor: AppColors.getBackgroundColor(context), // [cite: 42]
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, user, isDarkMode),
            _buildSegmentedControls(isDarkMode),
            Expanded(
              child: Padding( // [cite: 42]
                padding: const EdgeInsets.symmetric(horizontal: 16.0), // [cite: 43]
                child: Consumer<AppState>( // [cite: 43]
                  builder: (context, appState, child) {
                    return _buildReportContent(appState);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, User? user, bool isDarkMode) { // [cite: 45]
    return Padding(
      padding: const EdgeInsets.all(16.0), // [cite: 45]
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween, // [cite: 45]
        children: [
          Row(
            children: [
              GestureDetector( // [cite: 45]
                onTap: () { // [cite: 46]
                  Navigator.push( // [cite: 46]
                    context,
                    MaterialPageRoute(builder: (context) => UserSettingsScreen()), // [cite: 46]
                  );
                },
                child: Container( // [cite: 47]
                  decoration: BoxDecoration( // [cite: 47]
                    shape: BoxShape.circle, // [cite: 47]
                    border: Border.all(color: AppColors.primaryBlue.withOpacity(0.5), width: 2), // [cite: 47]
                    boxShadow: [ // [cite: 48]
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1), // [cite: 48]
                        blurRadius: 5, // [cite: 48]
                        offset: const Offset(0, 2), // [cite: 49]
                      )
                    ],
                  ),
                  child: CircleAvatar( // [cite: 49]
                    radius: 24, // [cite: 50]
                    backgroundColor: AppColors.getCardColor(context), // [cite: 50, 51]
                    backgroundImage: user?.photoURL != null ? NetworkImage(user!.photoURL!) : null, // [cite: 51, 52]
                    child: user?.photoURL == null // [cite: 52]
                        ? Icon(Icons.person, size: 30, color: AppColors.primaryBlue) // [cite: 53]
                        : null, // [cite: 53]
                  ),
                ),
              ),
              const SizedBox(width: 12), // [cite: 53]
              AccountSwitcher(),
            ],
          ),
          GestureDetector(
            onTap: () => _selectDateRange(context), // [cite: 55, 56]
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), // [cite: 56]
              decoration: BoxDecoration(
                color: AppColors.getCardColor(context), // [cite: 56]
                borderRadius: BorderRadius.circular(20), // [cite: 56]
                border: Border.all(color: AppColors.getBorderColor(context)), // [cite: 57]
                boxShadow: [ // [cite: 57]
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05), // [cite: 57, 58]
                    blurRadius: 4, // [cite: 58]
                    offset: const Offset(0, 2), // [cite: 58]
                  )
                ],
              ),
              child: Row( // [cite: 59]
                mainAxisSize: MainAxisSize.min, // [cite: 59]
                children: [
                  Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.primaryBlue), // [cite: 59]
                  const SizedBox(width: 6), // [cite: 59]
                  Text( // [cite: 60]
                    selectedDateRange != null
                        ? "${DateFormat('dd/MM').format(selectedDateRange!.start)} - ${DateFormat('dd/MM').format(selectedDateRange!.end)}"
                        : "Chọn ngày", // [cite: 60]
                    style: TextStyle( // [cite: 61]
                        color: AppColors.primaryBlue, // [cite: 61]
                        fontWeight: FontWeight.w500, // [cite: 61]
                        fontSize: 13), // [cite: 61]
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentedControls(bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0), // [cite: 63]
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal, // [cite: 63]
        child: SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'Tổng Quan', label: Text('Tổng Quan'), icon: Icon(Icons.dashboard_outlined)), // [cite: 63]
            ButtonSegment(value: 'Chi Phí', label: Text('Chi Phí'), icon: Icon(Icons.receipt_long_outlined)), // [cite: 63]
            ButtonSegment(value: 'Doanh Thu', label: Text('Doanh Thu'), icon: Icon(Icons.trending_up_outlined)), // [cite: 64]
          ],
          selected: {selectedReport}, // [cite: 64]
          onSelectionChanged: (newSelection) {
            setState(() {
              selectedReport = newSelection.first; // [cite: 65]
              _controller.reset(); // [cite: 65]
              _controller.forward(); // [cite: 65]
            });
          },
          style: SegmentedButton.styleFrom( // [cite: 66]
              backgroundColor: AppColors.getCardColor(context), // [cite: 67]
              foregroundColor: AppColors.getTextSecondaryColor(context), // [cite: 67]
              selectedForegroundColor: Colors.white, // [cite: 67]
              selectedBackgroundColor: AppColors.primaryBlue, // [cite: 67]
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), // [cite: 67]
              side: BorderSide(color: AppColors.getBorderColor(context)), // [cite: 67, 68]
              padding: const EdgeInsets.symmetric(horizontal:12, vertical: 8)), // [cite: 68]
        ),
      ),
    );
  }

  Widget _buildReportContent(AppState appState) {
    if (selectedDateRange == null) return const SizedBox.shrink(); // [cite: 69]
    Widget content;
    Key contentKey = ValueKey<String>('$selectedReport-${selectedDateRange.toString()}-${appState.activeUserId}');
    switch (selectedReport) {
      case 'Tổng Quan':
        content = _buildOverviewReport(appState, key: contentKey); // [cite: 70]
        break; // [cite: 71]
      case 'Chi Phí':
        content = _buildExpenseReport(appState, key: contentKey); // [cite: 71]
        break;
      case 'Doanh Thu':
        content = _buildRevenueReport(appState, key: contentKey); // [cite: 72]
        break;
      default:
        content = const SizedBox.shrink(); // [cite: 74]
    }
    return SlideTransition( // [cite: 75]
      position: _slideAnimation, // [cite: 75]
      child: FadeTransition( // [cite: 75]
        opacity: _fadeAnimation, // [cite: 75]
        child: content, // [cite: 75]
      ),
    );
  }

  // --- Báo cáo Tổng Quan ---
  Widget _buildOverviewReport(AppState appState, {Key? key}) { // [cite: 76]
    final isDarkMode = Theme.of(context).brightness == Brightness.dark; // [cite: 76, 77]
    return FutureBuilder<Map<String, double>>(
      key: key, // [cite: 77]
      future: appState.getOverviewForRange(selectedDateRange!), // [cite: 77]
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const ReportSkeleton(); // [cite: 77]
        }
        if (snapshot.hasError) {
          return Center(child: Text('Lỗi tải dữ liệu: ${snapshot.error}')); // [cite: 77]
        }
        if (snapshot.hasData && snapshot.data!.isNotEmpty) { // [cite: 78]
          final data = snapshot.data!; // [cite: 78]
          double totalRevenue = data['totalRevenue'] ?? 0.0; // [cite: 78]
          double totalExpense = data['totalExpense'] ?? 0.0; // [cite: 78]
          double profit = data['profit'] ?? 0.0; // [cite: 78]
          double averageProfitMargin = data['averageProfitMargin'] ?? 0.0; // [cite: 78]
          double avgRevenuePerDay = data['avgRevenuePerDay'] ?? 0.0; // [cite: 78]
          double avgExpensePerDay = data['avgExpensePerDay'] ?? 0.0; // [cite: 79]
          double avgProfitPerDay = data['avgProfitPerDay'] ?? 0.0; // [cite: 79]
          double expenseToRevenueRatio = data['expenseToRevenueRatio'] ?? 0.0; // [cite: 79]
          return SingleChildScrollView( // [cite: 80]
            padding: const EdgeInsets.only(top: 16, bottom: 16), // [cite: 80]
            child: Column(
              children: [
                _buildModernInfoCard('Tổng Doanh Thu', totalRevenue, Icons.monetization_on_outlined, AppColors.chartGreen), // [cite: 80]
                const SizedBox(height: 12), // [cite: 80]
                _buildModernInfoCard('Tổng Chi Phí', totalExpense, Icons.receipt_long_outlined, AppColors.chartRed), // [cite: 81]
                const SizedBox(height: 12), // [cite: 81]
                _buildModernInfoCard('Lợi Nhuận', profit, Icons.show_chart_outlined, AppColors.chartBlue), // [cite: 81]
                const SizedBox(height: 20), // [cite: 81]
                _buildSectionCard( // [cite: 81]
                    title: 'Chỉ số KPI', // [cite: 82]
                    isDarkMode: isDarkMode, // [cite: 82]
                    child: Column(
                      children: [
                        _buildModernKpiItem('Doanh Thu TB/Ngày', avgRevenuePerDay, Icons.assessment_outlined, isDarkMode: isDarkMode), // [cite: 83]
                        _buildModernKpiItem('Chi Phí TB/Ngày', avgExpensePerDay, Icons.pie_chart_outline, isDarkMode: isDarkMode), // [cite: 83, 84]
                        _buildModernKpiItem('Lợi Nhuận TB/Ngày', avgProfitPerDay, Icons.insights_outlined, isDarkMode: isDarkMode), // [cite: 84]
                        _buildModernKpiItem('Tỷ Lệ Chi Phí/Doanh Thu', expenseToRevenueRatio, Icons.percent_outlined, isPercentage: true, isDarkMode: isDarkMode), // [cite: 84]
                        _buildModernKpiItem('Biên Lợi Nhuận TB', averageProfitMargin, Icons.score_outlined, isPercentage: true, isDarkMode: isDarkMode), // [cite: 84, 85]
                      ],
                    )),
                const SizedBox(height: 20), // [cite: 85]
                _buildSectionCard( // [cite: 85]
                    title: 'Xu hướng', // [cite: 86]
                    isDarkMode: isDarkMode, // [cite: 86]
                    child: Column(
                      children: [
                        _buildLegend(isDarkMode, overview: true), // [cite: 86]
                        const SizedBox(height: 16), // [cite: 87]
                        SizedBox( // [cite: 87]
                          height: MediaQuery.of(context).size.height * 0.35, // [cite: 87]
                          child: FutureBuilder<List<Map<String, double>>>( // [cite: 88]
                            future: appState.getDailyOverviewForRange(selectedDateRange!), // [cite: 88]
                            builder: (context, trendSnapshot) {
                              if (trendSnapshot.connectionState == ConnectionState.waiting) { // [cite: 88]
                                return const Center(child: ReportSkeleton()); // [cite: 89]
                              }
                              if (trendSnapshot.hasError) { // [cite: 90]
                                return Center(child: Text('Lỗi tải dữ liệu xu hướng: ${trendSnapshot.error}')); // [cite: 90]
                              }
                              if (trendSnapshot.hasData && trendSnapshot.data!.isNotEmpty) { // [cite: 91]
                                return _buildOverviewTrendChart(appState, selectedDateRange!, trendSnapshot.data!); // [cite: 91]
                              }
                              return const Center(child: Text('Không có dữ liệu xu hướng')); // [cite: 92]
                            },
                          ),
                        ),
                      ],
                    )),
              ],
            ),
          );
        }
        return const Center(child: Text('Không có dữ liệu tổng quan')); // [cite: 95]
      },
    );
  }

  Widget _buildOverviewTrendChart(AppState appState, DateTimeRange range, List<Map<String, double>> dailyData) { // [cite: 96]
    final isDarkMode = Theme.of(context).brightness == Brightness.dark; // [cite: 96, 97]
    double maxVal = dailyData.isNotEmpty // [cite: 97]
        ? dailyData.map((e) { // [cite: 98]
      final revenue = e['totalRevenue'] ?? 0; // [cite: 98]
      final expense = e['totalExpense'] ?? 0; // [cite: 98]
      final profit = e['profit'] ?? 0; // [cite: 98]
      return [revenue.abs(), expense.abs(), profit.abs()].reduce((max, val) => val > max ? val : max); // [cite: 98]
    }).reduce((max, val) => val > max ? val : max)
        : 1000000; // [cite: 98]
    double horizontalInterval = (maxVal / 4).roundToDouble(); // [cite: 99]
    horizontalInterval = horizontalInterval > 0 ? horizontalInterval : 100000; // [cite: 99]
    return LineChart( // [cite: 100]
      LineChartData(
        lineBarsData: [
          _buildLineData(dailyData, 'totalRevenue', AppColors.chartGreen, isDarkMode), // [cite: 100]
          _buildLineData(dailyData, 'totalExpense', AppColors.chartRed, isDarkMode), // [cite: 100]
          _buildLineData(dailyData, 'profit', AppColors.chartBlue, isDarkMode), // [cite: 100]
        ],
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles( // [cite: 100]
            sideTitles: SideTitles(
              showTitles: true, // [cite: 101]
              reservedSize: 35, // [cite: 101]
              interval: 1, // [cite: 101]
              getTitlesWidget: (value, meta) {
                int days = range.end.difference(range.start).inDays + 1; // [cite: 101]
                if (value.toInt() >= 0 && value.toInt() < days) { // [cite: 102]
                  DateTime date = range.start.add(Duration(days: value.toInt())); // [cite: 102]
                  if (days > 7 && value.toInt() % (days ~/ 7) != 0 && value.toInt() != days - 1 && value.toInt() !=0) { // [cite: 102]
                    return const SizedBox.shrink(); // [cite: 102]
                  }
                  return SideTitleWidget( // [cite: 103]
                    axisSide: meta.axisSide, // [cite: 103]
                    space: 8, // [cite: 103]
                    child: Text( // [cite: 103]
                      DateFormat('dd/MM').format(date), // [cite: 104]
                      style: TextStyle(fontSize: 10, color: AppColors.getTextSecondaryColor(context)), // [cite: 104, 105]
                    ),
                  );
                }
                return const SizedBox.shrink(); // [cite: 106]
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true, // [cite: 107]
              reservedSize: 50, // [cite: 107]
              getTitlesWidget: (value, meta) => Text( // [cite: 107]
                formatNumberCompact(value), // [cite: 108]
                style: TextStyle(fontSize: 10, color: AppColors.getTextSecondaryColor(context)), // [cite: 108]
              ),
              interval: horizontalInterval, // [cite: 108]
            ),
          ),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)), // [cite: 108]
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)), // [cite: 109]
        ),
        gridData: FlGridData(
          show: true, // [cite: 109]
          drawVerticalLine: false, // [cite: 109]
          horizontalInterval: horizontalInterval, // [cite: 109]
          getDrawingHorizontalLine: (value) => FlLine( // [cite: 109]
            color: AppColors.getBorderColor(context).withOpacity(0.5), // [cite: 109]
            strokeWidth: 1, // [cite: 109, 110]
            dashArray: [3, 3], // [cite: 110]
          ),
        ),
        borderData: FlBorderData(show: false), // [cite: 110]
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            tooltipBgColor: AppColors.getCardColor(context).withOpacity(0.9), // [cite: 110, 111]
            tooltipRoundedRadius: 8, // [cite: 111]
            getTooltipItems: (touchedSpots) => touchedSpots.map((spot) {
              String label = spot.barIndex == 0 ? 'Doanh Thu' // [cite: 111]
                  : spot.barIndex == 1 ? 'Chi Phí' : 'Lợi Nhuận'; // [cite: 111]
              Color spotColor = spot.barIndex == 0 ? AppColors.chartGreen // [cite: 111]
                  : spot.barIndex == 1 ? AppColors.chartRed : AppColors.chartBlue; // [cite: 112]
              return LineTooltipItem( // [cite: 112]
                '$label: ${currencyFormat.format(spot.y)}', // [cite: 112]
                TextStyle( // [cite: 112]
                  color: spotColor, // [cite: 112]
                  fontWeight: FontWeight.bold, // [cite: 113]
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  // --- Báo cáo Chi Phí ---
  Widget _buildExpenseReport(AppState appState, {Key? key}) { // [cite: 114]
    final isDarkMode = Theme.of(context).brightness == Brightness.dark; // [cite: 114, 115]
    return FutureBuilder<Map<String, double>>(
      key: key, // [cite: 115]
      future: appState.getExpensesForRange(selectedDateRange!), // [cite: 115]
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const ReportSkeleton(); // [cite: 115]
        if (snapshot.hasError) return Center(child: Text('Lỗi tải dữ liệu: ${snapshot.error}')); // [cite: 115]
        if (snapshot.hasData && snapshot.data!.isNotEmpty) { // [cite: 115]
          final data = snapshot.data!; // [cite: 115]
          double fixedExpense = data['fixedExpense'] ?? 0.0; // [cite: 115]
          double variableExpense = data['variableExpense'] ?? 0.0; // [cite: 116]
          double totalExpense = data['totalExpense'] ?? 0.0; // [cite: 116]
          return SingleChildScrollView( // [cite: 116]
            padding: const EdgeInsets.only(top: 16, bottom: 16), // [cite: 116]
            child: Column(
              children: [
                _buildModernInfoCard('Chi Phí Cố Định', fixedExpense, Icons.lock_outline, AppColors.chartBlue), // [cite: 116, 117]
                const SizedBox(height: 12), // [cite: 117]
                _buildModernInfoCard('Chi Phí Biến Đổi', variableExpense, Icons.compare_arrows_outlined, AppColors.chartOrange), // [cite: 117, 118]
                const SizedBox(height: 12), // [cite: 118]
                _buildModernInfoCard('Tổng Chi Phí', totalExpense, Icons.receipt_long_outlined, AppColors.chartRed), // [cite: 118]
                const SizedBox(height: 20), // [cite: 118]
                _buildSectionCard( // [cite: 118]
                    title: 'Phân Tích Chi Phí', // [cite: 119]
                    isDarkMode: isDarkMode, // [cite: 119]
                    child: FutureBuilder<Map<String, double>>(
                      future: appState.getExpenseBreakdown(selectedDateRange!), // [cite: 119]
                      builder: (context, breakdownSnapshot) {
                        if (breakdownSnapshot.connectionState == ConnectionState.waiting) { // [cite: 120]
                          return const SizedBox(height: 250 + 50, child: Center(child: ReportSkeleton())); // +50 cho legend (ước lượng) // [cite: 120]
                        }
                        if (breakdownSnapshot.hasError) return Center(child: Text('Lỗi: ${breakdownSnapshot.error}')); // [cite: 121]
                        if (breakdownSnapshot.hasData && breakdownSnapshot.data!.isNotEmpty) { // [cite: 121]
                          final pieData = breakdownSnapshot.data!; // [cite: 121]
                          return Column( // [cite: 122]
                            children: [
                              SizedBox( // [cite: 122]
                                height: 250, // [cite: 122]
                                child: _buildModernPieChart(pieData, isDarkMode, enableTouchInteraction: false), // [cite: 123]
                              ),
                              const SizedBox(height: 16), // [cite: 123]
                              _buildPieChartLegend(pieData, isDarkMode), // [cite: 124]
                            ],
                          );
                        }
                        return const Center(child: Text('Không có dữ liệu chi tiết')); // [cite: 125]
                      },
                    )),
                const SizedBox(height: 20), // [cite: 126]
                _buildSectionCard( // [cite: 126]
                    title: 'Xu hướng chi phí', // [cite: 126]
                    isDarkMode: isDarkMode, // [cite: 126]
                    child: Column(
                      children: [
                        _buildLegend(isDarkMode, expense: true), // [cite: 127]
                        const SizedBox(height: 16), // [cite: 127]
                        SizedBox( // [cite: 128]
                          height: MediaQuery.of(context).size.height * 0.35, // [cite: 128]
                          child: FutureBuilder<List<Map<String, double>>>( // [cite: 128]
                            future: appState.getDailyExpensesForRange(selectedDateRange!), // [cite: 129]
                            builder: (context, trendSnapshot) {
                              if (trendSnapshot.connectionState == ConnectionState.waiting) { // [cite: 129]
                                return const Center(child: ReportSkeleton()); // [cite: 130]
                              }
                              if (trendSnapshot.hasError) return Center(child: Text('Lỗi: ${trendSnapshot.error}')); // [cite: 130]
                              if (trendSnapshot.hasData && trendSnapshot.data!.isNotEmpty) { // [cite: 131]
                                return _buildExpenseTrendChart(appState, selectedDateRange!, trendSnapshot.data!); // [cite: 131]
                              }
                              return const Center(child: Text('Không có dữ liệu xu hướng')); // [cite: 132]
                            },
                          ),
                        ),
                      ],
                    )),
              ],
            ),
          );
        }
        return const Center(child: Text('Không có dữ liệu chi phí')); // [cite: 135]
      },
    );
  }

  Widget _buildExpenseTrendChart(AppState appState, DateTimeRange range, List<Map<String, double>> dailyData) { // [cite: 136]
    final isDarkMode = Theme.of(context).brightness == Brightness.dark; // [cite: 136, 137]
    double maxVal = dailyData.isNotEmpty // [cite: 137]
        ? dailyData.map((e) { // [cite: 138]
      final fixed = e['fixedExpense'] ?? 0; // [cite: 138]
      final variable = e['variableExpense'] ?? 0; // [cite: 138]
      final total = e['totalExpense'] ?? 0; // [cite: 138]
      return [fixed.abs(), variable.abs(), total.abs()].reduce((max, val) => val > max ? val : max); // [cite: 138]
    }).reduce((max, val) => val > max ? val : max)
        : 1000000; // [cite: 138]
    double horizontalInterval = (maxVal / 4).roundToDouble(); // [cite: 139]
    horizontalInterval = horizontalInterval > 0 ? horizontalInterval : 100000; // [cite: 139]
    return LineChart( // [cite: 140]
      LineChartData(
        lineBarsData: [
          _buildLineData(dailyData, 'fixedExpense', AppColors.chartBlue, isDarkMode, dashArray: [5, 5]), // [cite: 140]
          _buildLineData(dailyData, 'variableExpense', AppColors.chartOrange, isDarkMode, dashArray: [5, 5]), // [cite: 140]
          _buildLineData(dailyData, 'totalExpense', AppColors.chartRed, isDarkMode), // [cite: 140]
        ],
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles( // [cite: 140]
            sideTitles: SideTitles(
              showTitles: true, // [cite: 141]
              reservedSize: 35, // [cite: 141]
              interval: 1, // [cite: 141]
              getTitlesWidget: (value, meta) {
                int days = range.end.difference(range.start).inDays + 1; // [cite: 141]
                if (value.toInt() >= 0 && value.toInt() < days) { // [cite: 142]
                  DateTime date = range.start.add(Duration(days: value.toInt())); // [cite: 142]
                  if (days > 7 && value.toInt() % (days ~/ 7) != 0 && value.toInt() != days - 1 && value.toInt() !=0) { // [cite: 142]
                    return const SizedBox.shrink(); // [cite: 142]
                  }
                  return SideTitleWidget( // [cite: 143]
                    axisSide: meta.axisSide, // [cite: 143]
                    space: 8, // [cite: 143]
                    child: Text( // [cite: 143]
                      DateFormat('dd/MM').format(date), // [cite: 144]
                      style: TextStyle(fontSize: 10, color: AppColors.getTextSecondaryColor(context)), // [cite: 144, 145]
                    ),
                  );
                }
                return const SizedBox.shrink(); // [cite: 146]
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true, // [cite: 147]
              reservedSize: 50, // [cite: 147]
              getTitlesWidget: (value, meta) => Text( // [cite: 147]
                formatNumberCompact(value), // [cite: 148]
                style: TextStyle(fontSize: 10, color: AppColors.getTextSecondaryColor(context)), // [cite: 148]
              ),
              interval: horizontalInterval, // [cite: 148]
            ),
          ),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)), // [cite: 148]
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)), // [cite: 149]
        ),
        gridData: FlGridData(
          show: true, // [cite: 149]
          drawVerticalLine: false, // [cite: 149]
          horizontalInterval: horizontalInterval, // [cite: 149]
          getDrawingHorizontalLine: (value) => FlLine( // [cite: 149]
            color: AppColors.getBorderColor(context).withOpacity(0.5), // [cite: 149]
            strokeWidth: 1, // [cite: 149, 150]
            dashArray: [3, 3], // [cite: 150]
          ),
        ),
        borderData: FlBorderData(show: false), // [cite: 150]
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            tooltipBgColor: AppColors.getCardColor(context).withOpacity(0.9), // [cite: 150, 151]
            tooltipRoundedRadius: 8, // [cite: 151]
            getTooltipItems: (touchedSpots) => touchedSpots.map((spot) {
              String label = spot.barIndex == 0 ? 'Cố Định' : spot.barIndex == 1 ? 'Biến Đổi' : 'Tổng'; // [cite: 151]
              Color color = spot.barIndex == 0 ? AppColors.chartBlue : spot.barIndex == 1 ? AppColors.chartOrange : AppColors.chartRed; // [cite: 151]
              return LineTooltipItem( // [cite: 152]
                '$label: ${currencyFormat.format(spot.y)}', // [cite: 152]
                TextStyle(color: color, fontWeight: FontWeight.bold), // [cite: 152]
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  // --- Báo cáo Doanh Thu ---
  Widget _buildRevenueReport(AppState appState, {Key? key}) { // [cite: 153]
    final isDarkMode = Theme.of(context).brightness == Brightness.dark; // [cite: 153, 154]
    return FutureBuilder<Map<String, double>>(
      key: key, // [cite: 154]
      future: appState.getRevenueForRange(selectedDateRange!), // [cite: 154]
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const ReportSkeleton(); // [cite: 154]
        if (snapshot.hasError) return Center(child: Text('Lỗi tải dữ liệu: ${snapshot.error}')); // [cite: 154]
        if (snapshot.hasData && snapshot.data!.isNotEmpty) { // [cite: 154]
          final data = snapshot.data!; // [cite: 154]
          double mainRevenue = data['mainRevenue'] ?? 0.0; // [cite: 154]
          double secondaryRevenue = data['secondaryRevenue'] ?? 0.0; // [cite: 155]
          double otherRevenue = data['otherRevenue'] ?? 0.0; // [cite: 155]
          double totalRevenue = data['totalRevenue'] ?? 0.0; // [cite: 155]
          return SingleChildScrollView( // [cite: 155]
            padding: const EdgeInsets.only(top: 16, bottom: 16), // [cite: 155]
            child: Column(
              children: [ // [cite: 155]
                _buildModernInfoCard('Doanh Thu Chính', mainRevenue, Icons.attach_money_outlined, AppColors.chartGreen), // [cite: 156]
                const SizedBox(height: 12), // [cite: 156]
                _buildModernInfoCard('Doanh Thu Phụ', secondaryRevenue, Icons.account_balance_wallet_outlined, AppColors.chartBlue), // [cite: 156, 157]
                const SizedBox(height: 12), // [cite: 157]
                _buildModernInfoCard('Doanh Thu Khác', otherRevenue, Icons.add_circle_outline_outlined, AppColors.chartOrange), // [cite: 157]
                const SizedBox(height: 12), // [cite: 157]
                _buildModernInfoCard('Tổng Doanh Thu', totalRevenue, Icons.bar_chart_outlined, AppColors.chartTeal), // [cite: 157]
                const SizedBox(height: 20), // [cite: 158]
                _buildSectionCard( // [cite: 158]
                    title: 'Xu hướng doanh thu', // [cite: 158]
                    isDarkMode: isDarkMode, // [cite: 158]
                    child: Column( // [cite: 158]
                      children: [
                        _buildLegend(isDarkMode, revenue: true), // [cite: 159]
                        const SizedBox(height: 16), // [cite: 159]
                        SizedBox( // [cite: 159]
                          height: MediaQuery.of(context).size.height * 0.35, // [cite: 160]
                          child: FutureBuilder<List<Map<String, double>>>(
                            future: appState.getDailyRevenueForRange(selectedDateRange!), // [cite: 160]
                            builder: (context, trendSnapshot) { // [cite: 161]
                              if (trendSnapshot.connectionState == ConnectionState.waiting) { // [cite: 161]
                                return const Center(child: ReportSkeleton()); // [cite: 161]
                              }
                              if (trendSnapshot.hasError) return Center(child: Text('Lỗi: ${trendSnapshot.error}')); // [cite: 162]
                              if (trendSnapshot.hasData && trendSnapshot.data!.isNotEmpty) { // [cite: 163]
                                // *** THAY ĐỔI: Gọi _buildRevenueTrendChartLine thay vì BarChart ***
                                return _buildRevenueTrendChartLine(appState, selectedDateRange!, trendSnapshot.data!); // [cite: 163]
                              }
                              return const Center(child: Text('Không có dữ liệu xu hướng')); // [cite: 164]
                            },
                          ),
                        ),
                      ],
                    )),
                const SizedBox(height: 20), // [cite: 166]
                // *** THÊM MỚI: Phần chi tiết sản phẩm cho Báo cáo Doanh thu ***
                _buildSectionCard( // [cite: 166]
                  title: 'Chi Tiết Doanh Thu Sản Phẩm', // [cite: 166]
                  isDarkMode: isDarkMode, // [cite: 166]
                  child: FutureBuilder<Map<String, Map<String, double>>>( // [cite: 167]
                    future: appState.getProductRevenueDetails(selectedDateRange!), // [cite: 167]
                    builder: (context, productSnapshot) {
                      if (productSnapshot.connectionState == ConnectionState.waiting) { // [cite: 167]
                        return const SizedBox(height: 200, child: Center(child: ReportSkeleton())); // [cite: 168]
                      }
                      if (productSnapshot.hasError) { // [cite: 168]
                        return Center(child: Text('Lỗi tải chi tiết sản phẩm: ${productSnapshot.error}')); // [cite: 168]
                      }
                      if (productSnapshot.hasData && productSnapshot.data!.isNotEmpty) { // [cite: 169]
                        final productDetails = productSnapshot.data!; // [cite: 169]
                        var sortedProducts = productDetails.entries.toList() // [cite: 170]
                          ..sort((a, b) => (b.value['total'] ?? 0.0).compareTo(a.value['total'] ?? 0.0)); // [cite: 170]
                        if (sortedProducts.isEmpty) { // [cite: 171]
                          return const Center(child: Text('Không có dữ liệu chi tiết sản phẩm')); // [cite: 171]
                        }
                        return Column( // [cite: 172]
                          children: sortedProducts.map((entry) { // [cite: 172]
                            return _buildModernKpiItem( // [cite: 172]
                              entry.key, // [cite: 173]
                              entry.value['total']!, // [cite: 173]
                              Icons.production_quantity_limits_outlined, // [cite: 173]
                              quantity: (entry.value['quantity'] ?? 0.0).toInt(), // [cite: 174]
                              isDarkMode: isDarkMode, // [cite: 174]
                            );
                          }).toList(),
                        );
                      }
                      return const Center(child: Text('Không có dữ liệu chi tiết sản phẩm')); // [cite: 176]
                    },
                  ),
                ),
              ],
            ),
          );
        }
        return const Center(child: Text('Không có dữ liệu doanh thu')); // [cite: 178]
      },
    );
  }

  // *** THAY ĐỔI: _buildRevenueTrendChart thành _buildRevenueTrendChartLine để vẽ LineChart ***
  Widget _buildRevenueTrendChartLine(AppState appState, DateTimeRange range, List<Map<String, double>> dailyData) { // [cite: 179]
    final isDarkMode = Theme.of(context).brightness == Brightness.dark; // [cite: 179, 180]
    double maxVal = 0;
    if (dailyData.isNotEmpty) { // [cite: 180]
      maxVal = dailyData.map((e) { // [cite: 180]
        final main = e['mainRevenue'] ?? 0; // [cite: 180]
        final secondary = e['secondaryRevenue'] ?? 0; // [cite: 180]
        final other = e['otherRevenue'] ?? 0; // [cite: 180]
        return [main.abs(), secondary.abs(), other.abs()].reduce((max, val) => val > max ? val : max); // [cite: 180]
      }).reduce((max, val) => val > max ? val : max); // [cite: 180]
    }
    maxVal = maxVal > 0 ? maxVal : 1000000; // [cite: 181]
    // Giá trị mặc định nếu không có dữ liệu hoặc maxVal = 0
    double horizontalInterval = (maxVal / 4).roundToDouble(); // [cite: 182]
    horizontalInterval = horizontalInterval > 0 ? horizontalInterval : 100000; // [cite: 183]
    return LineChart( // [cite: 183]
      LineChartData(
        lineBarsData: [
          _buildLineData(dailyData, 'mainRevenue', AppColors.chartGreen, isDarkMode), // [cite: 183]
          _buildLineData(dailyData, 'secondaryRevenue', AppColors.chartBlue, isDarkMode), // [cite: 183]
          _buildLineData(dailyData, 'otherRevenue', AppColors.chartOrange, isDarkMode), // [cite: 183]
        ],
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles( // [cite: 183]
            sideTitles: SideTitles(
              showTitles: true, // [cite: 184]
              reservedSize: 35, // [cite: 184]
              interval: 1, // [cite: 184]
              getTitlesWidget: (value, meta) {
                int days = range.end.difference(range.start).inDays + 1; // [cite: 184]
                if (value.toInt() >= 0 && value.toInt() < days) { // [cite: 185]
                  DateTime date = range.start.add(Duration(days: value.toInt())); // [cite: 185]
                  if (days > 7 && value.toInt() % (days ~/ 7) != 0 && value.toInt() != days - 1 && value.toInt() !=0) { // [cite: 185]
                    return const SizedBox.shrink(); // [cite: 185, 186]
                  }
                  return SideTitleWidget( // [cite: 186]
                    axisSide: meta.axisSide, // [cite: 186]
                    space: 8, // [cite: 186]
                    child: Text( // [cite: 187]
                      DateFormat('dd/MM').format(date), // [cite: 187]
                      style: TextStyle(fontSize: 10, color: AppColors.getTextSecondaryColor(context)), // [cite: 187, 188]
                    ),
                  );
                }
                return const SizedBox.shrink(); // [cite: 189]
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true, // [cite: 190]
              reservedSize: 50, // [cite: 190]
              getTitlesWidget: (value, meta) => Text( // [cite: 190]
                formatNumberCompact(value), // [cite: 191]
                style: TextStyle(fontSize: 10, color: AppColors.getTextSecondaryColor(context)), // [cite: 191]
              ),
              interval: horizontalInterval, // [cite: 191]
            ),
          ),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)), // [cite: 191]
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)), // [cite: 192]
        ),
        gridData: FlGridData(
          show: true, // [cite: 192]
          drawVerticalLine: false, // [cite: 192]
          horizontalInterval: horizontalInterval, // [cite: 192]
          getDrawingHorizontalLine: (value) => FlLine( // [cite: 192]
            color: AppColors.getBorderColor(context).withOpacity(0.5), // [cite: 192]
            strokeWidth: 1, // [cite: 192, 193]
            dashArray: [3, 3], // [cite: 193]
          ),
        ),
        borderData: FlBorderData(show: false), // [cite: 193]
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            tooltipBgColor: AppColors.getCardColor(context).withOpacity(0.9), // [cite: 193, 194]
            tooltipRoundedRadius: 8, // [cite: 194]
            getTooltipItems: (touchedSpots) => touchedSpots.map((spot) {
              String label; // [cite: 194]
              Color spotColor; // [cite: 194]
              switch (spot.barIndex) {
                case 0: // [cite: 194]
                  label = 'Doanh Thu Chính'; // [cite: 195]
                  spotColor = AppColors.chartGreen; // [cite: 195]
                  break;
                case 1:
                  label = 'Doanh Thu Phụ'; // [cite: 195]
                  spotColor = AppColors.chartBlue; // [cite: 196]
                  break;
                case 2:
                  label = 'Doanh Thu Khác'; // [cite: 196]
                  spotColor = AppColors.chartOrange; // [cite: 196]
                  break; // [cite: 197]
                default:
                  label = ''; // [cite: 197]
                  spotColor = Colors.grey; // [cite: 197]
              }
              return LineTooltipItem( // [cite: 197, 198]
                '$label: ${currencyFormat.format(spot.y)}', // [cite: 198]
                TextStyle( // [cite: 198]
                  color: spotColor, // [cite: 198]
                  fontWeight: FontWeight.bold, // [cite: 198]
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  // --- HÀM ĐÃ XÓA: _buildProductRevenueReport ---

  // --- Hàm hỗ trợ (Widgets Reutilizables) ---
  Widget _buildSectionCard({required String title, required Widget child, required bool isDarkMode}) { // [cite: 212]
    return Card(
      elevation: 2, // [cite: 212]
      margin: const EdgeInsets.symmetric(vertical: 8), // [cite: 212]
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), // [cite: 212]
      color: AppColors.getCardColor(context), // [cite: 212]
      child: Padding(
        padding: const EdgeInsets.all(16.0), // [cite: 212]
        child: Column( // [cite: 212]
          crossAxisAlignment: CrossAxisAlignment.start, // [cite: 213]
          children: [
            Text( // [cite: 213]
              title, // [cite: 213]
              style: TextStyle(
                fontFamily: 'Poppins', // [cite: 213]
                fontSize: 18, // [cite: 213]
                fontWeight: FontWeight.w600, // [cite: 214]
                color: AppColors.getTextColor(context), // [cite: 214]
              ),
            ),
            const SizedBox(height: 12), // [cite: 214]
            child, // [cite: 214]
          ],
        ),
      ),
    );
  }

  Widget _buildModernInfoCard(String label, double value, IconData icon, Color iconColor) { // [cite: 215]
    return Container(
      padding: const EdgeInsets.all(16), // [cite: 215]
      decoration: BoxDecoration(
        color: AppColors.getCardColor(context), // [cite: 215]
        borderRadius: BorderRadius.circular(12), // [cite: 215]
        border: Border.all(color: AppColors.getBorderColor(context), width: 1), // [cite: 215]
        boxShadow: [ // [cite: 215]
          BoxShadow( // [cite: 215]
            color: Colors.black.withOpacity(0.03), // [cite: 216]
            blurRadius: 10, // [cite: 216]
            offset: const Offset(0, 4), // [cite: 216]
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10), // [cite: 216]
            decoration: BoxDecoration( // [cite: 217]
              color: iconColor.withOpacity(0.15), // [cite: 217]
              shape: BoxShape.circle, // [cite: 217]
            ),
            child: Icon(icon, size: 24, color: iconColor), // [cite: 217]
          ),
          const SizedBox(width: 16), // [cite: 217]
          Expanded( // [cite: 218]
            child: Text( // [cite: 218]
              label, // [cite: 218]
              style: TextStyle(fontSize: 15, color: AppColors.getTextSecondaryColor(context), fontWeight: FontWeight.w500), // [cite: 218, 219]
            ),
          ),
          Text( // [cite: 219]
            currencyFormat.format(value), // [cite: 219]
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.getTextColor(context)), // [cite: 219]
          ),
        ],
      ),
    );
  }

  Widget _buildModernKpiItem(String label, double value, IconData icon, {bool isPercentage = false, int? quantity, required bool isDarkMode, Color? iconColor}) { // [cite: 220]
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 0), // [cite: 220]
      leading: Icon(icon, size: 22, color: iconColor ?? AppColors.primaryBlue), // [cite: 220]
      title: Text(label, style: TextStyle(fontSize: 15, color: AppColors.getTextColor(context))), // [cite: 220]
      trailing: Text(
        isPercentage
            ? '${value.toStringAsFixed(2)}%'
            : quantity != null // [cite: 220]
            ? '${currencyFormat.format(value)} ($quantity sp)' // [cite: 221]
            : currencyFormat.format(value), // [cite: 221]
        style: TextStyle( // [cite: 221]
          fontSize: 15, // [cite: 221]
          fontWeight: FontWeight.w600, // [cite: 221]
          color: AppColors.getTextColor(context), // [cite: 221]
        ),
      ),
    );
  }

  LineChartBarData _buildLineData(List<Map<String, double>> dailyData, String key, Color color, bool isDarkMode, {List<int>? dashArray}) { // [cite: 222]
    return LineChartBarData(
      spots: dailyData.asMap().entries.map((entry) { // [cite: 222]
        return FlSpot(entry.key.toDouble(), entry.value[key] ?? 0.0); // [cite: 222]
      }).toList(),
      isCurved: true, // [cite: 222]
      color: color, // [cite: 222]
      barWidth: 3, // [cite: 222]
      dashArray: dashArray, // [cite: 222]
      isStrokeCapRound: true, // [cite: 222]
      dotData: FlDotData( // [cite: 222]
        show: true, // [cite: 222]
        getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter( // [cite: 223]
          radius: 3.5, // [cite: 223]
          color: color, // [cite: 223]
          strokeWidth: 1.5, // [cite: 223]
          strokeColor: AppColors.getCardColor(context), // [cite: 223]
        ),
      ),
      belowBarData: BarAreaData( // [cite: 223]
        show: true, // [cite: 223]
        gradient: LinearGradient( // [cite: 223]
          colors: [color.withOpacity(0.3), color.withOpacity(0.0)], // [cite: 224]
          begin: Alignment.topCenter, // [cite: 224]
          end: Alignment.bottomCenter, // [cite: 224]
        ),
      ),
    );
  }

  Widget _buildModernPieChart(Map<String, double> data, bool isDarkMode, {bool enableTouchInteraction = true}) { // [cite: 225]
    if (data.isEmpty) return const Center(child: Text("Không có dữ liệu cho biểu đồ tròn.")); // [cite: 225]
    double total = data.values.fold(0.0, (sum, value) => sum + value); // [cite: 226]
    final List<MapEntry<String, double>> sortedData = data.entries.toList() // [cite: 227]
      ..sort((aMapEntry, bMapEntry) => bMapEntry.value.compareTo(aMapEntry.value)); // [cite: 227]
    return PieChart( // [cite: 228]
      PieChartData(
        sections: sortedData.asMap().entries.map((entry) { // [cite: 228]
          int index = entry.key; // [cite: 228]
          MapEntry<String, double> entryData = entry.value; // [cite: 228]
          double percentage = total > 0 ? (entryData.value / total) * 100 : 0.0; // [cite: 228]
          final color = AppColors.getPieChartColor(entryData.key, index); // [cite: 228]
          return PieChartSectionData( // [cite: 228]
            value: entryData.value, // [cite: 229]
            title: percentage > 5 ? '${percentage.toStringAsFixed(1)}%' : '', // [cite: 229]
            color: color, // [cite: 229]
            radius: 90, // [cite: 229]
            titleStyle: TextStyle( // [cite: 229]
              fontSize: 11, // [cite: 229]
              fontWeight: FontWeight.bold, // [cite: 229]
              color: Colors.white, // [cite: 230]
              shadows: [Shadow(color: Colors.black.withOpacity(0.5), blurRadius: 2)], // [cite: 230]
            ),
            titlePositionPercentageOffset: 0.65, // [cite: 230]
          );
        }).toList(),
        sectionsSpace: 2, // [cite: 230]
        centerSpaceRadius: 35, // [cite: 230]
        pieTouchData: PieTouchData( // [cite: 231]
          touchCallback: (FlTouchEvent event, pieTouchResponse) {
            if (!enableTouchInteraction) return; // [cite: 231]
            if (!event.isInterestedForInteractions || pieTouchResponse == null || pieTouchResponse.touchedSection == null) { // [cite: 232]
              return; // [cite: 232]
            }
            int touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex; // [cite: 233]
            if (touchedIndex < 0 || touchedIndex >= sortedData.length) return; // [cite: 234]
            String touchedCategory = sortedData.elementAt(touchedIndex).key; // [cite: 234]
            double touchedValue = sortedData.elementAt(touchedIndex).value; // [cite: 234]
            if (mounted) { // [cite: 235]
              ScaffoldMessenger.of(context).showSnackBar( // [cite: 235, 236]
                SnackBar(
                  content: Text('$touchedCategory: ${currencyFormat.format(touchedValue)}'), // [cite: 236]
                  duration: const Duration(seconds: 2), // [cite: 236]
                  backgroundColor: AppColors.getCardColor(context), // [cite: 236]
                  behavior: SnackBarBehavior.floating, // [cite: 236]
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), // [cite: 237]
                  action: SnackBarAction( // [cite: 237]
                    label: 'Đóng', // [cite: 237]
                    textColor: AppColors.primaryBlue, // [cite: 237]
                    onPressed: () { // [cite: 238]
                      ScaffoldMessenger.of(context).hideCurrentSnackBar(); // [cite: 238]
                    },
                  ),
                ),
              );
            }
          },
        ),
      ),
    );
  }

  Widget _buildLegend(bool isDarkMode, {bool overview = false, bool expense = false, bool revenue = false}) { // [cite: 240]
    List<Widget> items = []; // [cite: 240]
    if (overview) { // [cite: 241]
      items.addAll([
        _buildLegendItem('Doanh Thu', AppColors.chartGreen, isDarkMode), // [cite: 241]
        _buildLegendItem('Chi Phí', AppColors.chartRed, isDarkMode), // [cite: 241]
        _buildLegendItem('Lợi Nhuận', AppColors.chartBlue, isDarkMode), // [cite: 241]
      ]);
    } else if (expense) { // [cite: 242]
      items.addAll([
        _buildLegendItem('Cố Định', AppColors.chartBlue, isDarkMode), // [cite: 242]
        _buildLegendItem('Biến Đổi', AppColors.chartOrange, isDarkMode), // [cite: 242]
        _buildLegendItem('Tổng', AppColors.chartRed, isDarkMode), // [cite: 242]
      ]);
    } else if (revenue) { // [cite: 243]
      items.addAll([
        _buildLegendItem('Doanh Thu Chính', AppColors.chartGreen, isDarkMode), // [cite: 243]
        _buildLegendItem('Doanh Thu Phụ', AppColors.chartBlue, isDarkMode), // [cite: 243]
        _buildLegendItem('Doanh Thu Khác', AppColors.chartOrange, isDarkMode), // [cite: 243]
      ]);
    }
    return Wrap( // [cite: 244]
      spacing: 16, // [cite: 244]
      runSpacing: 8, // [cite: 244]
      alignment: WrapAlignment.center, // [cite: 244]
      children: items, // [cite: 244]
    );
  }

  Widget _buildLegendItem(String label, Color color, bool isDarkMode) { // [cite: 245]
    return Row(
      mainAxisSize: MainAxisSize.min, // [cite: 245]
      children: [
        Container( // [cite: 245]
          width: 10, // [cite: 245]
          height: 10, // [cite: 245]
          decoration: BoxDecoration( // [cite: 245]
            color: color, // [cite: 245]
            shape: BoxShape.circle, // [cite: 245]
          ),
        ),
        const SizedBox(width: 6), // [cite: 246]
        Text( // [cite: 246]
          label, // [cite: 246]
          style: TextStyle(fontSize: 12, color: AppColors.getTextSecondaryColor(context)), // [cite: 246]
        ),
      ],
    );
  }

  // MỚI: Hàm xây dựng Legend cho Pie Chart
  Widget _buildPieChartLegend(Map<String, double> data, bool isDarkMode) { // [cite: 247]
    if (data.isEmpty) return const SizedBox.shrink(); // [cite: 247]
    final List<MapEntry<String, double>> sortedData = data.entries.toList() // [cite: 248]
      ..sort((aMapEntry, bMapEntry) => bMapEntry.value.compareTo(aMapEntry.value)); // [cite: 248]
    List<Widget> legendItems = []; // [cite: 248]
    sortedData.asMap().forEach((index, entry) { // [cite: 249]
      legendItems.add(_buildLegendItem( // [cite: 249]
          entry.key, // [cite: 249]
          AppColors.getPieChartColor(entry.key, index), // [cite: 249]
          isDarkMode // [cite: 249]
      ));
    });
    return Wrap( // [cite: 250]
      spacing: 12.0, // [cite: 250]
      runSpacing: 4.0, // [cite: 250]
      alignment: WrapAlignment.center, // [cite: 250]
      children: legendItems, // [cite: 250]
    );
  }
}