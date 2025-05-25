import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart'; // Giả định đường dẫn này đúng
import 'package:intl/intl.dart';
import 'user_setting_screen.dart'; // Giả định đường dẫn này đúng
import 'skeleton_loading.dart'; // Giả định đường dẫn này đúng

// Định nghĩa màu sắc tập trung
class AppColors {
  // === MÀU CHỦ ĐẠO MỚI ===
  static const Color primaryBlue = Color(0xFF0A7AFF);
  static const Color primaryBlueLight = Color(0x1A2F81D7); // Blue with opacity for backgrounds

  static const Color textPrimaryLight = Color(0xFF1D1D1F);
  static const Color textSecondaryLight = Color(0xFF6E6E73);
  static const Color backgroundLight = Color(0xFFF9F9F9);
  static const Color cardLight = Colors.white;
  static const Color borderLight = Color(0xFFE0E0E0);
  static const Color dividerLight = Color(0xFFEDEDED);

  static const Color textPrimaryDark = Color(0xFFFFFFFF);
  static const Color textSecondaryDark = Color(0xFFA0A0A0);
  static const Color backgroundDark = Color(0xFF121212);
  static const Color cardDark = Color(0xFF1E1E1E);
  static const Color borderDark = Color(0xFF2C2C2E);
  static const Color dividerDark = Color(0xFF2C2C2E);

  // Chart Colors
  static const Color chartGreen = Color(0xFF34C759);
  static const Color chartRed = Color(0xFFFF3B30);
  // Sử dụng màu chủ đạo cho chartBlue
  static const Color chartBlue = primaryBlue; // <--- CẬP NHẬT Ở ĐÂY
  static const Color chartOrange = Color(0xFFFF9500);
  static const Color chartTeal = Color(0xFF5AC8FA); // Có thể giữ hoặc thay đổi nếu cần
  static const Color chartPurple = Color(0xFFAF52DE);
  static const Color chartYellow = Color(0xFFFFCC00);
  static const Color chartPink = Color(0xFFFF2D55);


  static List<Color> get pieChartColors => [
    chartGreen, chartBlue, chartOrange, chartTeal, chartPurple, chartYellow, chartPink,
    chartGreen.withOpacity(0.7), chartBlue.withOpacity(0.7), chartOrange.withOpacity(0.7),
    chartTeal.withOpacity(0.7), chartPurple.withOpacity(0.7), chartYellow.withOpacity(0.7),
    chartPink.withOpacity(0.7),
  ];

  static Color getPieChartColor(String key, int index) {
    return pieChartColors[index % pieChartColors.length];
  }

  // Helper để lấy màu dựa trên theme
  static Color getTextColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? textPrimaryDark : textPrimaryLight;
  }
  static Color getTextSecondaryColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? textSecondaryDark : textSecondaryLight;
  }
  static Color getCardColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? cardDark : cardLight;
  }
  static Color getBackgroundColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? backgroundDark : backgroundLight;
  }
  static Color getBorderColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? borderDark : borderLight;
  }
  static Color getDividerColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? dividerDark : dividerLight;
  }
}


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
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
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
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primaryBlue, // header background color
              onPrimary: Colors.white, // header text color
              onSurface: AppColors.getTextColor(context), // body text color
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryBlue, // button text color
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != selectedDateRange) {
      setState(() {
        selectedDateRange = picked;
        // Khi ngày thay đổi, cũng nên reset và forward animation để có hiệu ứng
        _controller.reset();
        _controller.forward();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.getBackgroundColor(context),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, user, isDarkMode),
            _buildSegmentedControls(isDarkMode),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Consumer<AppState>(
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

  Widget _buildHeader(BuildContext context, User? user, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
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
                    border: Border.all(color: AppColors.primaryBlue.withOpacity(0.5), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      )
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.getCardColor(context),
                    backgroundImage: user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
                    child: user?.photoURL == null
                        ? Icon(Icons.person, size: 30, color: AppColors.primaryBlue)
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                "Báo Cáo",
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: AppColors.getTextColor(context),
                ),
              ),
            ],
          ),
          GestureDetector(
            onTap: () => _selectDateRange(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.getCardColor(context),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.getBorderColor(context)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.primaryBlue),
                  const SizedBox(width: 6),
                  Text(
                    selectedDateRange != null
                        ? "${DateFormat('dd/MM').format(selectedDateRange!.start)} - ${DateFormat('dd/MM').format(selectedDateRange!.end)}"
                        : "Chọn ngày",
                    style: TextStyle(
                        color: AppColors.primaryBlue,
                        fontWeight: FontWeight.w500,
                        fontSize: 13
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

  Widget _buildSegmentedControls(bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'Tổng Quan', label: Text('Tổng Quan'), icon: Icon(Icons.dashboard_outlined)),
            ButtonSegment(value: 'Chi Phí', label: Text('Chi Phí'), icon: Icon(Icons.receipt_long_outlined)),
            ButtonSegment(value: 'Doanh Thu', label: Text('Doanh Thu'), icon: Icon(Icons.trending_up_outlined)),
            ButtonSegment(value: 'Doanh Thu Theo Sản Phẩm', label: Text('Sản Phẩm'), icon: Icon(Icons.inventory_2_outlined)),
          ],
          selected: {selectedReport},
          onSelectionChanged: (newSelection) {
            setState(() {
              selectedReport = newSelection.first;
              _controller.reset();
              _controller.forward();
            });
          },
          style: SegmentedButton.styleFrom(
              backgroundColor: AppColors.getCardColor(context),
              foregroundColor: AppColors.getTextSecondaryColor(context),
              selectedForegroundColor: Colors.white,
              selectedBackgroundColor: AppColors.primaryBlue, // <-- Sử dụng màu chủ đạo
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              side: BorderSide(color: AppColors.getBorderColor(context)),
              padding: const EdgeInsets.symmetric(horizontal:12, vertical: 8)
          ),
        ),
      ),
    );
  }


  Widget _buildReportContent(AppState appState) {
    if (selectedDateRange == null) return const SizedBox.shrink();

    Widget content;
    // Key để đảm bảo widget được rebuild hoàn toàn khi selectedReport hoặc selectedDateRange thay đổi, giúp animation chạy lại
    Key contentKey = ValueKey<String>('$selectedReport-${selectedDateRange.toString()}');

    switch (selectedReport) {
      case 'Tổng Quan':
        content = _buildOverviewReport(appState, key: contentKey);
        break;
      case 'Chi Phí':
        content = _buildExpenseReport(appState, key: contentKey);
        break;
      case 'Doanh Thu':
        content = _buildRevenueReport(appState, key: contentKey);
        break;
      case 'Doanh Thu Theo Sản Phẩm':
        content = _buildProductRevenueReport(appState, key: contentKey);
        break;
      default:
        content = const SizedBox.shrink();
    }
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: content,
      ),
    );
  }

  // --- Báo cáo Tổng Quan ---
  Widget _buildOverviewReport(AppState appState, {Key? key}) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return FutureBuilder<Map<String, double>>(
      key: key, // Thêm key ở đây
      future: appState.getOverviewForRange(selectedDateRange!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const ReportSkeleton();
        }
        if (snapshot.hasError) {
          return Center(child: Text('Lỗi tải dữ liệu: ${snapshot.error}'));
        }
        if (snapshot.hasData && snapshot.data!.isNotEmpty) {
          final data = snapshot.data!;
          double totalRevenue = data['totalRevenue'] ?? 0.0;
          double totalExpense = data['totalExpense'] ?? 0.0;
          double profit = data['profit'] ?? 0.0;
          double averageProfitMargin = data['averageProfitMargin'] ?? 0.0;
          double avgRevenuePerDay = data['avgRevenuePerDay'] ?? 0.0;
          double avgExpensePerDay = data['avgExpensePerDay'] ?? 0.0;
          double avgProfitPerDay = data['avgProfitPerDay'] ?? 0.0;
          double expenseToRevenueRatio = data['expenseToRevenueRatio'] ?? 0.0;

          return SingleChildScrollView(
            padding: const EdgeInsets.only(top: 16, bottom: 16),
            child: Column(
              children: [
                _buildModernInfoCard('Tổng Doanh Thu', totalRevenue, Icons.monetization_on_outlined, AppColors.chartGreen),
                const SizedBox(height: 12),
                _buildModernInfoCard('Tổng Chi Phí', totalExpense, Icons.receipt_long_outlined, AppColors.chartRed),
                const SizedBox(height: 12),
                _buildModernInfoCard('Lợi Nhuận', profit, Icons.show_chart_outlined, AppColors.chartBlue), // <-- chartBlue đã là màu chủ đạo
                const SizedBox(height: 20),
                _buildSectionCard(
                    title: 'Chỉ số KPI',
                    isDarkMode: isDarkMode,
                    child: Column(
                      children: [
                        _buildModernKpiItem('Doanh Thu TB/Ngày', avgRevenuePerDay, Icons.assessment_outlined, isDarkMode: isDarkMode),
                        _buildModernKpiItem('Chi Phí TB/Ngày', avgExpensePerDay, Icons.pie_chart_outline, isDarkMode: isDarkMode),
                        _buildModernKpiItem('Lợi Nhuận TB/Ngày', avgProfitPerDay, Icons.insights_outlined, isDarkMode: isDarkMode),
                        _buildModernKpiItem('Tỷ Lệ Chi Phí/Doanh Thu', expenseToRevenueRatio, Icons.percent_outlined, isPercentage: true, isDarkMode: isDarkMode),
                        _buildModernKpiItem('Biên Lợi Nhuận TB', averageProfitMargin, Icons.score_outlined, isPercentage: true, isDarkMode: isDarkMode),
                      ],
                    )
                ),
                const SizedBox(height: 20),
                _buildSectionCard(
                    title: 'Xu hướng',
                    isDarkMode: isDarkMode,
                    child: Column(
                      children: [
                        _buildLegend(isDarkMode, overview: true),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.35,
                          child: FutureBuilder<List<Map<String, double>>>(
                            future: appState.getDailyOverviewForRange(selectedDateRange!),
                            builder: (context, trendSnapshot) {
                              if (trendSnapshot.connectionState == ConnectionState.waiting) {
                                return const Center(child: ReportSkeleton());
                              }
                              if (trendSnapshot.hasError) {
                                return Center(child: Text('Lỗi tải dữ liệu xu hướng: ${trendSnapshot.error}'));
                              }
                              if (trendSnapshot.hasData && trendSnapshot.data!.isNotEmpty) {
                                return _buildOverviewTrendChart(appState, selectedDateRange!, trendSnapshot.data!);
                              }
                              return const Center(child: Text('Không có dữ liệu xu hướng'));
                            },
                          ),
                        ),
                      ],
                    )
                ),
              ],
            ),
          );
        }
        return const Center(child: Text('Không có dữ liệu tổng quan'));
      },
    );
  }

  Widget _buildOverviewTrendChart(AppState appState, DateTimeRange range, List<Map<String, double>> dailyData) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    double maxVal = dailyData.isNotEmpty
        ? dailyData.map((e) {
      final revenue = e['totalRevenue'] ?? 0;
      final expense = e['totalExpense'] ?? 0;
      final profit = e['profit'] ?? 0;
      return [revenue.abs(), expense.abs(), profit.abs()].reduce((max, val) => val > max ? val : max); // abs for potential negative profit
    }).reduce((max, val) => val > max ? val : max)
        : 1000000;

    double horizontalInterval = (maxVal / 4).roundToDouble();
    horizontalInterval = horizontalInterval > 0 ? horizontalInterval : 100000;

    return LineChart(
      LineChartData(
        lineBarsData: [
          _buildLineData(dailyData, 'totalRevenue', AppColors.chartGreen, isDarkMode),
          _buildLineData(dailyData, 'totalExpense', AppColors.chartRed, isDarkMode),
          _buildLineData(dailyData, 'profit', AppColors.chartBlue, isDarkMode), // <-- chartBlue đã là màu chủ đạo
        ],
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 35,
              interval: 1,
              getTitlesWidget: (value, meta) {
                int days = range.end.difference(range.start).inDays + 1;
                if (value.toInt() >= 0 && value.toInt() < days) {
                  DateTime date = range.start.add(Duration(days: value.toInt()));
                  if (days > 7 && value.toInt() % (days ~/ 7) != 0 && value.toInt() != days -1 && value.toInt() !=0) {
                    return const SizedBox.shrink();
                  }
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    space: 8,
                    child: Text(
                      DateFormat('dd/MM').format(date),
                      style: TextStyle(fontSize: 10, color: AppColors.getTextSecondaryColor(context)),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 50,
              getTitlesWidget: (value, meta) => Text(
                formatNumberCompact(value),
                style: TextStyle(fontSize: 10, color: AppColors.getTextSecondaryColor(context)),
              ),
              interval: horizontalInterval,
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
            color: AppColors.getBorderColor(context).withOpacity(0.5),
            strokeWidth: 1,
            dashArray: [3, 3],
          ),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            tooltipBgColor: AppColors.getCardColor(context).withOpacity(0.9),
            tooltipRoundedRadius: 8,
            getTooltipItems: (touchedSpots) => touchedSpots.map((spot) {
              String label = spot.barIndex == 0 ? 'Doanh Thu'
                  : spot.barIndex == 1 ? 'Chi Phí' : 'Lợi Nhuận';
              Color spotColor = spot.barIndex == 0 ? AppColors.chartGreen
                  : spot.barIndex == 1 ? AppColors.chartRed : AppColors.chartBlue; // <-- chartBlue
              return LineTooltipItem(
                '$label: ${currencyFormat.format(spot.y)}',
                TextStyle(
                  color: spotColor,
                  fontWeight: FontWeight.bold,
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }


  // --- Báo cáo Chi Phí ---
  Widget _buildExpenseReport(AppState appState, {Key? key}) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return FutureBuilder<Map<String, double>>(
      key: key, // Thêm key
      future: appState.getExpensesForRange(selectedDateRange!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const ReportSkeleton();
        if (snapshot.hasError) return Center(child: Text('Lỗi tải dữ liệu: ${snapshot.error}'));
        if (snapshot.hasData && snapshot.data!.isNotEmpty) {
          final data = snapshot.data!;
          double fixedExpense = data['fixedExpense'] ?? 0.0;
          double variableExpense = data['variableExpense'] ?? 0.0;
          double totalExpense = data['totalExpense'] ?? 0.0;

          return SingleChildScrollView(
            padding: const EdgeInsets.only(top: 16, bottom: 16),
            child: Column(
              children: [
                _buildModernInfoCard('Chi Phí Cố Định', fixedExpense, Icons.lock_outline, AppColors.chartBlue), // <-- chartBlue
                const SizedBox(height: 12),
                _buildModernInfoCard('Chi Phí Biến Đổi', variableExpense, Icons.compare_arrows_outlined, AppColors.chartOrange),
                const SizedBox(height: 12),
                _buildModernInfoCard('Tổng Chi Phí', totalExpense, Icons.receipt_long_outlined, AppColors.chartRed),
                const SizedBox(height: 20),
                _buildSectionCard(
                    title: 'Phân Tích Chi Phí',
                    isDarkMode: isDarkMode,
                    child: SizedBox(
                      height: 250,
                      child: FutureBuilder<Map<String, double>>(
                        future: appState.getExpenseBreakdown(selectedDateRange!),
                        builder: (context, breakdownSnapshot) {
                          if (breakdownSnapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: ReportSkeleton());
                          }
                          if (breakdownSnapshot.hasError) return Center(child: Text('Lỗi: ${breakdownSnapshot.error}'));
                          if (breakdownSnapshot.hasData && breakdownSnapshot.data!.isNotEmpty) {
                            return _buildModernPieChart(breakdownSnapshot.data!, isDarkMode);
                          }
                          return const Center(child: Text('Không có dữ liệu chi tiết'));
                        },
                      ),
                    )
                ),
                const SizedBox(height: 20),
                _buildSectionCard(
                    title: 'Xu hướng chi phí',
                    isDarkMode: isDarkMode,
                    child: Column(
                      children: [
                        _buildLegend(isDarkMode, expense: true),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.35,
                          child: FutureBuilder<List<Map<String, double>>>(
                            future: appState.getDailyExpensesForRange(selectedDateRange!),
                            builder: (context, trendSnapshot) {
                              if (trendSnapshot.connectionState == ConnectionState.waiting) {
                                return const Center(child: ReportSkeleton());
                              }
                              if (trendSnapshot.hasError) return Center(child: Text('Lỗi: ${trendSnapshot.error}'));
                              if (trendSnapshot.hasData && trendSnapshot.data!.isNotEmpty) {
                                return _buildExpenseTrendChart(appState, selectedDateRange!, trendSnapshot.data!);
                              }
                              return const Center(child: Text('Không có dữ liệu xu hướng'));
                            },
                          ),
                        ),
                      ],
                    )
                ),
              ],
            ),
          );
        }
        return const Center(child: Text('Không có dữ liệu chi phí'));
      },
    );
  }

  Widget _buildExpenseTrendChart(AppState appState, DateTimeRange range, List<Map<String, double>> dailyData) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    double maxVal = dailyData.isNotEmpty
        ? dailyData.map((e) {
      final fixed = e['fixedExpense'] ?? 0;
      final variable = e['variableExpense'] ?? 0;
      final total = e['totalExpense'] ?? 0;
      return [fixed.abs(), variable.abs(), total.abs()].reduce((max, val) => val > max ? val : max);
    }).reduce((max, val) => val > max ? val : max)
        : 1000000;


    double horizontalInterval = (maxVal / 4).roundToDouble();
    horizontalInterval = horizontalInterval > 0 ? horizontalInterval : 100000;

    return LineChart(
      LineChartData(
        lineBarsData: [
          _buildLineData(dailyData, 'fixedExpense', AppColors.chartBlue, isDarkMode, dashArray: [5, 5]), // <-- chartBlue
          _buildLineData(dailyData, 'variableExpense', AppColors.chartOrange, isDarkMode, dashArray: [5, 5]),
          _buildLineData(dailyData, 'totalExpense', AppColors.chartRed, isDarkMode),
        ],
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 35,
              interval: 1,
              getTitlesWidget: (value, meta) {
                int days = range.end.difference(range.start).inDays + 1;
                if (value.toInt() >= 0 && value.toInt() < days) {
                  DateTime date = range.start.add(Duration(days: value.toInt()));
                  if (days > 7 && value.toInt() % (days ~/ 7) != 0 && value.toInt() != days -1 && value.toInt() !=0) {
                    return const SizedBox.shrink();
                  }
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    space: 8,
                    child: Text(
                      DateFormat('dd/MM').format(date),
                      style: TextStyle(fontSize: 10, color: AppColors.getTextSecondaryColor(context)),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 50,
              getTitlesWidget: (value, meta) => Text(
                formatNumberCompact(value),
                style: TextStyle(fontSize: 10, color: AppColors.getTextSecondaryColor(context)),
              ),
              interval: horizontalInterval,
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
            color: AppColors.getBorderColor(context).withOpacity(0.5),
            strokeWidth: 1,
            dashArray: [3, 3],
          ),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            tooltipBgColor: AppColors.getCardColor(context).withOpacity(0.9),
            tooltipRoundedRadius: 8,
            getTooltipItems: (touchedSpots) => touchedSpots.map((spot) {
              String label = spot.barIndex == 0 ? 'Cố Định' : spot.barIndex == 1 ? 'Biến Đổi' : 'Tổng';
              Color color = spot.barIndex == 0 ? AppColors.chartBlue : spot.barIndex == 1 ? AppColors.chartOrange : AppColors.chartRed; // <-- chartBlue
              return LineTooltipItem(
                '$label: ${currencyFormat.format(spot.y)}',
                TextStyle(color: color, fontWeight: FontWeight.bold),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }


  // --- Báo cáo Doanh Thu ---
  Widget _buildRevenueReport(AppState appState, {Key? key}) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return FutureBuilder<Map<String, double>>(
      key: key, // Thêm key
      future: appState.getRevenueForRange(selectedDateRange!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const ReportSkeleton();
        if (snapshot.hasError) return Center(child: Text('Lỗi tải dữ liệu: ${snapshot.error}'));
        if (snapshot.hasData && snapshot.data!.isNotEmpty) {
          final data = snapshot.data!;
          double mainRevenue = data['mainRevenue'] ?? 0.0;
          double secondaryRevenue = data['secondaryRevenue'] ?? 0.0;
          double otherRevenue = data['otherRevenue'] ?? 0.0;
          double totalRevenue = data['totalRevenue'] ?? 0.0;

          return SingleChildScrollView(
            padding: const EdgeInsets.only(top: 16, bottom: 16),
            child: Column(
              children: [
                _buildModernInfoCard('Doanh Thu Chính', mainRevenue, Icons.attach_money_outlined, AppColors.chartGreen),
                const SizedBox(height: 12),
                _buildModernInfoCard('Doanh Thu Phụ', secondaryRevenue, Icons.account_balance_wallet_outlined, AppColors.chartBlue), // <-- chartBlue
                const SizedBox(height: 12),
                _buildModernInfoCard('Doanh Thu Khác', otherRevenue, Icons.add_circle_outline_outlined, AppColors.chartOrange),
                const SizedBox(height: 12),
                _buildModernInfoCard('Tổng Doanh Thu', totalRevenue, Icons.bar_chart_outlined, AppColors.chartTeal),
                const SizedBox(height: 20),
                _buildSectionCard(
                    title: 'Xu hướng doanh thu',
                    isDarkMode: isDarkMode,
                    child: Column(
                      children: [
                        _buildLegend(isDarkMode, revenue: true),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.35,
                          child: FutureBuilder<List<Map<String, double>>>(
                            future: appState.getDailyRevenueForRange(selectedDateRange!),
                            builder: (context, trendSnapshot) {
                              if (trendSnapshot.connectionState == ConnectionState.waiting) {
                                return const Center(child: ReportSkeleton());
                              }
                              if (trendSnapshot.hasError) return Center(child: Text('Lỗi: ${trendSnapshot.error}'));
                              if (trendSnapshot.hasData && trendSnapshot.data!.isNotEmpty) {
                                return _buildRevenueTrendChart(appState, selectedDateRange!, trendSnapshot.data!);
                              }
                              return const Center(child: Text('Không có dữ liệu xu hướng'));
                            },
                          ),
                        ),
                      ],
                    )
                ),
              ],
            ),
          );
        }
        return const Center(child: Text('Không có dữ liệu doanh thu'));
      },
    );
  }

  Widget _buildRevenueTrendChart(AppState appState, DateTimeRange range, List<Map<String, double>> dailyData) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    double maxVal = dailyData.isNotEmpty
        ? dailyData
        .map((e) => (e['mainRevenue'] ?? 0) + (e['secondaryRevenue'] ?? 0) + (e['otherRevenue'] ?? 0))
        .reduce((a, b) => a > b ? a : b)
        : 1000000;
    double horizontalInterval = (maxVal / 4).roundToDouble();
    horizontalInterval = horizontalInterval > 0 ? horizontalInterval : 100000;

    final barWidth = 8.0;

    return BarChart(
      BarChartData(
        barGroups: dailyData.asMap().entries.map((entry) {
          int index = entry.key;
          var data = entry.value;
          return BarChartGroupData(
            x: index,
            barsSpace: 4,
            barRods: [
              BarChartRodData(
                toY: data['mainRevenue'] ?? 0.0,
                color: AppColors.chartGreen,
                width: barWidth,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
              BarChartRodData(
                toY: data['secondaryRevenue'] ?? 0.0,
                color: AppColors.chartBlue, // <-- chartBlue
                width: barWidth,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
              BarChartRodData(
                toY: data['otherRevenue'] ?? 0.0,
                color: AppColors.chartOrange,
                width: barWidth,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ],
          );
        }).toList(),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 35,
              getTitlesWidget: (value, meta) {
                int days = range.end.difference(range.start).inDays + 1;
                if (value.toInt() >= 0 && value.toInt() < days) {
                  DateTime date = range.start.add(Duration(days: value.toInt()));
                  if (days > 7 && value.toInt() % (days ~/ 7) != 0 && value.toInt() != days -1 && value.toInt() !=0) {
                    return const SizedBox.shrink();
                  }
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    space: 8,
                    child: Text(
                      DateFormat('dd/MM').format(date),
                      style: TextStyle(fontSize: 10, color: AppColors.getTextSecondaryColor(context)),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 50,
              getTitlesWidget: (value, meta) => Text(
                formatNumberCompact(value),
                style: TextStyle(fontSize: 10, color: AppColors.getTextSecondaryColor(context)),
              ),
              interval: horizontalInterval,
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
            color: AppColors.getBorderColor(context).withOpacity(0.5),
            strokeWidth: 1,
            dashArray: [3, 3],
          ),
        ),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            tooltipBgColor: AppColors.getCardColor(context).withOpacity(0.9),
            tooltipRoundedRadius: 8,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              String label = rodIndex == 0 ? 'Chính'
                  : rodIndex == 1 ? 'Phụ' : 'Khác';
              Color color = rodIndex == 0 ? AppColors.chartGreen
                  : rodIndex == 1 ? AppColors.chartBlue : AppColors.chartOrange; // <-- chartBlue
              return BarTooltipItem(
                '$label: ${currencyFormat.format(rod.toY)}',
                TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              );
            },
          ),
        ),
      ),
    );
  }


  // --- Báo cáo Doanh Thu Theo Sản Phẩm ---
  Widget _buildProductRevenueReport(AppState appState, {Key? key}) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return FutureBuilder<Map<String, Map<String, double>>>(
      key: key, // Thêm key
      future: appState.getProductRevenueDetails(selectedDateRange!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const ReportSkeleton();
        if (snapshot.hasError) return Center(child: Text('Lỗi tải dữ liệu: ${snapshot.error}'));
        if (snapshot.hasData && snapshot.data!.isNotEmpty) {
          final productDetails = snapshot.data!;
          double totalRevenue = productDetails.values.fold(0.0, (sum, value) => sum + (value['total'] ?? 0.0));
          var sortedProducts = productDetails.entries.toList()
            ..sort((a, b) => (b.value['total'] ?? 0.0).compareTo(a.value['total'] ?? 0.0));

          Map<String, double> pieData = {
            for (var entry in sortedProducts.take(6))
              entry.key: entry.value['total'] ?? 0.0
          };
          if (sortedProducts.length > 6) {
            double otherTotal = sortedProducts.skip(6).fold(0.0, (sum, e) => sum + (e.value['total'] ?? 0.0));
            if (otherTotal > 0) pieData['Khác'] = otherTotal;
          }


          return SingleChildScrollView(
            padding: const EdgeInsets.only(top: 16, bottom: 16),
            child: Column(
              children: [
                _buildModernInfoCard('Tổng Doanh Thu SP', totalRevenue, Icons.inventory_2_outlined, AppColors.chartTeal),
                const SizedBox(height: 20),
                _buildSectionCard(
                    title: 'Phân Tích Doanh Thu Theo Sản Phẩm',
                    isDarkMode: isDarkMode,
                    child: SizedBox(
                      height: 250,
                      child: _buildModernPieChart(pieData, isDarkMode),
                    )
                ),
                const SizedBox(height: 20),
                _buildSectionCard(
                  title: 'Chi Tiết Sản Phẩm',
                  isDarkMode: isDarkMode,
                  child: Column(
                    children: sortedProducts.map((entry) {
                      return _buildModernKpiItem(
                        entry.key,
                        entry.value['total']!,
                        Icons.production_quantity_limits_outlined,
                        quantity: (entry.value['quantity'] ?? 0.0).toInt(),
                        isDarkMode: isDarkMode,
                        // Sử dụng màu chủ đạo cho icon của từng sản phẩm nếu muốn
                        // iconColor: AppColors.primaryBlue
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          );
        }
        return const Center(child: Text('Không có dữ liệu sản phẩm'));
      },
    );
  }

  // --- Hàm hỗ trợ (Widgets Reutilizables) ---

  Widget _buildSectionCard({required String title, required Widget child, required bool isDarkMode}) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: AppColors.getCardColor(context),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.getTextColor(context),
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }


  Widget _buildModernInfoCard(String label, double value, IconData icon, Color iconColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.getCardColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.getBorderColor(context), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 24, color: iconColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 15, color: AppColors.getTextSecondaryColor(context), fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            currencyFormat.format(value),
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.getTextColor(context)),
          ),
        ],
      ),
    );
  }

  Widget _buildModernKpiItem(String label, double value, IconData icon, {bool isPercentage = false, int? quantity, required bool isDarkMode, Color? iconColor}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 0),
      leading: Icon(icon, size: 22, color: iconColor ?? AppColors.primaryBlue), // <-- Sử dụng màu chủ đạo cho icon KPI
      title: Text(label, style: TextStyle(fontSize: 15, color: AppColors.getTextColor(context))),
      trailing: Text(
        isPercentage
            ? '${value.toStringAsFixed(2)}%'
            : quantity != null
            ? '${currencyFormat.format(value)} ($quantity sp)'
            : currencyFormat.format(value),
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppColors.getTextColor(context),
        ),
      ),
    );
  }


  LineChartBarData _buildLineData(List<Map<String, double>> dailyData, String key, Color color, bool isDarkMode, {List<int>? dashArray}) {
    return LineChartBarData(
      spots: dailyData.asMap().entries.map((entry) {
        return FlSpot(entry.key.toDouble(), entry.value[key] ?? 0.0);
      }).toList(),
      isCurved: true,
      color: color,
      barWidth: 3,
      dashArray: dashArray,
      isStrokeCapRound: true,
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
          radius: 3.5,
          color: color,
          strokeWidth: 1.5,
          strokeColor: AppColors.getCardColor(context),
        ),
      ),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          colors: [color.withOpacity(0.3), color.withOpacity(0.0)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
    );
  }

  Widget _buildModernPieChart(Map<String, double> data, bool isDarkMode) {
    if (data.isEmpty) return const Center(child: Text("Không có dữ liệu cho biểu đồ tròn."));
    double total = data.values.fold(0.0, (sum, value) => sum + value);
    final List<MapEntry<String, double>> sortedData = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));


    return PieChart(
      PieChartData(
        sections: sortedData.asMap().entries.map((indexedEntry) {
          int index = indexedEntry.key;
          MapEntry<String, double> entry = indexedEntry.value;
          double percentage = total > 0 ? (entry.value / total) * 100 : 0.0;
          final color = AppColors.getPieChartColor(entry.key, index);
          return PieChartSectionData(
            value: entry.value,
            title: percentage > 5 ? '${percentage.toStringAsFixed(1)}%' : '',
            color: color,
            radius: 90,
            titleStyle: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                shadows: [Shadow(color:Colors.black.withOpacity(0.5) , blurRadius: 2)]
            ),
            titlePositionPercentageOffset: 0.65,
          );
        }).toList(),
        sectionsSpace: 2,
        centerSpaceRadius: 35,
        pieTouchData: PieTouchData(
          touchCallback: (FlTouchEvent event, pieTouchResponse) {
            if (!event.isInterestedForInteractions || pieTouchResponse == null || pieTouchResponse.touchedSection == null) {
              return;
            }
            int touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
            if (touchedIndex < 0 || touchedIndex >= sortedData.length) return;
            String touchedCategory = sortedData.elementAt(touchedIndex).key;
            double touchedValue = sortedData.elementAt(touchedIndex).value;

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$touchedCategory: ${currencyFormat.format(touchedValue)}'),
                duration: const Duration(seconds: 2),
                backgroundColor: AppColors.getCardColor(context), // Thay đổi màu nền SnackBar
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                // Thay đổi màu chữ SnackBar
                action: SnackBarAction(
                  label: 'Đóng',
                  textColor: AppColors.primaryBlue, // Hoặc màu khác phù hợp
                  onPressed: () {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLegend(bool isDarkMode, {bool overview = false, bool expense = false, bool revenue = false}) {
    List<Widget> items = [];
    if (overview) {
      items.addAll([
        _buildLegendItem('Doanh Thu', AppColors.chartGreen, isDarkMode),
        _buildLegendItem('Chi Phí', AppColors.chartRed, isDarkMode),
        _buildLegendItem('Lợi Nhuận', AppColors.chartBlue, isDarkMode), // <-- chartBlue
      ]);
    } else if (expense) {
      items.addAll([
        _buildLegendItem('Cố Định', AppColors.chartBlue, isDarkMode), // <-- chartBlue
        _buildLegendItem('Biến Đổi', AppColors.chartOrange, isDarkMode),
        _buildLegendItem('Tổng', AppColors.chartRed, isDarkMode),
      ]);
    } else if (revenue) {
      items.addAll([
        _buildLegendItem('Doanh Thu Chính', AppColors.chartGreen, isDarkMode),
        _buildLegendItem('Doanh Thu Phụ', AppColors.chartBlue, isDarkMode), // <-- chartBlue
        _buildLegendItem('Doanh Thu Khác', AppColors.chartOrange, isDarkMode),
      ]);
    }

    return Wrap(
      spacing: 16,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: items,
    );
  }

  Widget _buildLegendItem(String label, Color color, bool isDarkMode) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: AppColors.getTextSecondaryColor(context)),
        ),
      ],
    );
  }
}