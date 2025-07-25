import 'package:fingrowth/screens/subscription_screen.dart';
import 'package:fingrowth/screens/subscription_service.dart';
import 'package:firebase_auth/firebase_auth.dart'; // [cite: 1]
import 'package:flutter/material.dart'; // [cite: 1]
import 'package:fl_chart/fl_chart.dart'; // [cite: 1]
import 'package:provider/provider.dart'; // [cite: 1]
import '../state/app_state.dart'; // Giả định đường dẫn này đúng // [cite: 1]
import 'package:intl/intl.dart'; // [cite: 1]
import 'account_switcher.dart';
import 'user_setting_screen.dart'; // [cite: 1]
// Giả định đường dẫn này đúng
import 'skeleton_loading.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../screens/chart_data_models.dart';

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
      start: DateTime.now().subtract(const Duration(days: 2)), // [cite: 31]
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

  Future<void> _selectDateRange(BuildContext context) async {
    final subscriptionService = context.read<SubscriptionService>();
    if (!subscriptionService.isSubscribed) {
      // Bạn có thể dùng lại hàm _showUpgradeDialog tương tự như trên
      // Hoặc hiển thị một SnackBar
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text("Nâng cấp Premium để xem báo cáo với khoảng thời gian tùy chọn!"),
        action: SnackBarAction(
          label: "Nâng Cấp",
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionScreen()));
          },
        ),
      ));
      return; // Dừng hàm tại đây
    }
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

  Widget _buildHeader(BuildContext context, User? user, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.all(16.0), //
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween, //
        crossAxisAlignment: CrossAxisAlignment.center, // Căn chỉnh các item theo chiều dọc
        children: [
          // Bọc Row chứa avatar và tên bằng Flexible để nó có thể co giãn
          Flexible(
            child: Row(
              // Row này chỉ chiếm không gian cần thiết, không đẩy các widget khác
              mainAxisSize: MainAxisSize.min, //
              children: [
                GestureDetector( //
                  onTap: () { //
                    Navigator.push( //
                      context,
                      MaterialPageRoute(builder: (context) => UserSettingsScreen()), //
                    );
                  },
                  child: Container( //
                    decoration: BoxDecoration( //
                      shape: BoxShape.circle, //
                      border: Border.all(color: AppColors.primaryBlue.withOpacity(0.5), width: 2), //
                      boxShadow: [ //
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1), //
                          blurRadius: 5, //
                          offset: const Offset(0, 2), //
                        )
                      ],
                    ),
                    child: CircleAvatar( //
                      radius: 24, //
                      backgroundColor: AppColors.getCardColor(context), //
                      backgroundImage: user?.photoURL != null ? NetworkImage(user!.photoURL!) : null, //
                      child: user?.photoURL == null //
                          ? Icon(Icons.person, size: 30, color: AppColors.primaryBlue) //
                          : null, //
                    ),
                  ),
                ),
                const SizedBox(width: 12), //
                // Bọc AccountSwitcher bằng Flexible để tên có thể co lại
                Flexible(
                  child: AccountSwitcher(textColor: AppColors.getTextColor(context)),
                ),
              ],
            ),
          ),

          // Phần chọn ngày được giữ nguyên
          GestureDetector( //
            onTap: () => _selectDateRange(context), //
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), //
              decoration: BoxDecoration(
                color: AppColors.getCardColor(context), //
                borderRadius: BorderRadius.circular(20), //
                border: Border.all(color: AppColors.getBorderColor(context)), //
                boxShadow: [ //
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05), //
                    blurRadius: 4, //
                    offset: const Offset(0, 2), //
                  )
                ],
              ),
              child: Row( //
                mainAxisSize: MainAxisSize.min, //
                children: [
                  Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.primaryBlue), //
                  const SizedBox(width: 6), //
                  Text( //
                    selectedDateRange != null
                        ? "${DateFormat('dd/MM').format(selectedDateRange!.start)} - ${DateFormat('dd/MM').format(selectedDateRange!.end)}" //
                        : "Chọn ngày", //
                    style: TextStyle( //
                        color: AppColors.primaryBlue, //
                        fontWeight: FontWeight.w500, //
                        fontSize: 13), //
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
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.35,
                          // THAY ĐỔI FUTUREBUILDER DƯỚI ĐÂY
                          child: FutureBuilder<Map<String, List<TimeSeriesChartData>>>( // Sửa kiểu dữ liệu ở đây
                            future: appState.getDailyOverviewForRange(selectedDateRange!),
                            builder: (context, trendSnapshot) {
                              if (trendSnapshot.connectionState == ConnectionState.waiting) {
                                return const Center(child: ReportSkeleton());
                              }
                              if (trendSnapshot.hasError) {
                                return Center(child: Text('Lỗi tải dữ liệu xu hướng: ${trendSnapshot.error}'));
                              }
                              if (trendSnapshot.hasData && trendSnapshot.data!.isNotEmpty) {
                                // Gọi widget Syncfusion mới
                                return _buildSyncfusionOverviewChart(context, trendSnapshot.data!);
                              }
                              return const Center(child: Text('Không có dữ liệu xu hướng'));
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

  // --- Báo cáo Chi Phí ---
  Widget _buildExpenseReport(AppState appState, {Key? key}) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return FutureBuilder<Map<String, double>>(
      key: key,
      future: appState.getExpensesForRange(selectedDateRange!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const ReportSkeleton();
        if (snapshot.hasError) return Center(child: Text('Lỗi tải dữ liệu: ${snapshot.error}'));
        if (snapshot.hasData && snapshot.data!.isNotEmpty) {
          final data = snapshot.data!;
          double fixedExpense = data['fixedExpense'] ?? 0.0;
          double variableExpense = data['variableExpense'] ?? 0.0;
          double otherExpense = data['otherExpense'] ?? 0.0; // <<< LẤY DỮ LIỆU MỚI
          double totalExpense = data['totalExpense'] ?? 0.0;

          return SingleChildScrollView(
            padding: const EdgeInsets.only(top: 16, bottom: 16),
            child: Column(
              children: [
                _buildModernInfoCard('Chi Phí Cố Định', fixedExpense, Icons.lock_outline, AppColors.chartBlue),
                const SizedBox(height: 12),
                _buildModernInfoCard('Chi Phí Biến Đổi', variableExpense, Icons.compare_arrows_outlined, AppColors.chartOrange),
                const SizedBox(height: 12),
                // <<< THÊM THẺ THÔNG TIN CHO CHI PHÍ KHÁC >>>
                _buildModernInfoCard('Chi Phí Khác', otherExpense, Icons.receipt_long_outlined, AppColors.chartPurple),
                const SizedBox(height: 12),
                _buildModernInfoCard('Tổng Chi Phí', totalExpense, Icons.functions, AppColors.chartRed),
                const SizedBox(height: 20),
                _buildSectionCard(
                    title: 'Phân Tích Chi Phí',
                    isDarkMode: isDarkMode,
                    // <<< CẬP NHẬT FUTUREBUILDER CHO BIỂU ĐỒ TRÒN >>>
                    child: FutureBuilder<List<Map<String, dynamic>>>( // Sửa kiểu dữ liệu Future
                      future: appState.getExpenseBreakdown(selectedDateRange!),
                      builder: (context, breakdownSnapshot) {
                        if (breakdownSnapshot.connectionState == ConnectionState.waiting) {
                          return const SizedBox(height: 250, child: Center(child: ReportSkeleton()));
                        }
                        if (breakdownSnapshot.hasError) return Center(child: Text('Lỗi: ${breakdownSnapshot.error}'));
                        if (breakdownSnapshot.hasData && breakdownSnapshot.data!.isNotEmpty) {

                          // --- LOGIC GỘP NHÓM "CHI PHÍ KHÁC" ---
                          final detailedData = breakdownSnapshot.data!;
                          final Map<String, double> pieChartMap = {};
                          double otherExpensesTotal = 0.0;

                          for (var item in detailedData) {
                            if (item['type'] == 'other') {
                              otherExpensesTotal += item['amount'] as double;
                            } else {
                              final name = item['name'] as String;
                              final amount = item['amount'] as double;
                              pieChartMap[name] = (pieChartMap[name] ?? 0) + amount;
                            }
                          }

                          if (otherExpensesTotal > 0) {
                            pieChartMap['Chi phí khác'] = otherExpensesTotal;
                          }

                          final List<CategoryChartData> pieChartData = pieChartMap.entries.map((entry) {
                            return CategoryChartData(entry.key, entry.value);
                          }).toList();

                          // Sắp xếp để các mục lớn hơn hiển thị trước
                          pieChartData.sort((a, b) => b.value.compareTo(a.value));

                          return SizedBox(
                            height: 300,
                            child: _buildSyncfusionExpensePieChart(context, pieChartData),
                          );
                        }
                        return const Center(child: Text('Không có dữ liệu chi tiết'));
                      },
                    )
                ),
                const SizedBox(height: 20),
                _buildSectionCard(
                  title: 'Xu hướng chi phí',
                  isDarkMode: isDarkMode,
                  child: SizedBox(
                    height: MediaQuery.of(context).size.height * 0.35,
                    child: FutureBuilder<Map<String, List<TimeSeriesChartData>>>(
                      future: appState.getDailyExpensesForRange(selectedDateRange!),
                      builder: (context, trendSnapshot) {
                        if (trendSnapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: ReportSkeleton());
                        }

                        if (trendSnapshot.hasError) return Center(child: Text('Lỗi: ${trendSnapshot.error}'));

                        if (trendSnapshot.hasData && trendSnapshot.data!.isNotEmpty) {
                          return _buildSyncfusionExpenseTrendChart(context, trendSnapshot.data!);
                        }
                        return const Center(child: Text('Không có dữ liệu xu hướng'));
                      },
                    ),
                  ),
                )
              ],
            ),
          );
        }
        return const Center(child: Text('Không có dữ liệu chi phí'));
      },
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
                _buildSectionCard(
                  title: 'Xu hướng doanh thu',
                  isDarkMode: isDarkMode,
                  child: SizedBox(
                    height: MediaQuery.of(context).size.height * 0.35,
                    child: FutureBuilder<Map<String, List<TimeSeriesChartData>>>( // Sửa kiểu dữ liệu
                      future: appState.getDailyRevenueForRange(selectedDateRange!),
                      builder: (context, trendSnapshot) {
                        if (trendSnapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: ReportSkeleton());
                        }
                        if (trendSnapshot.hasError) return Center(child: Text('Lỗi: ${trendSnapshot.error}'));
                        if (trendSnapshot.hasData && trendSnapshot.data!.isNotEmpty) {
                          return _buildSyncfusionRevenueTrendChart(context, trendSnapshot.data!); // Gọi hàm mới
                        }
                        return const Center(child: Text('Không có dữ liệu xu hướng'));
                      },
                    ),
                  ),
                ),
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

  Widget _buildSyncfusionOverviewChart(BuildContext context, Map<String, List<TimeSeriesChartData>> data) {
    final List<TimeSeriesChartData> revenueData = data['revenueData'] ?? [];
    final List<TimeSeriesChartData> expenseData = data['expenseData'] ?? [];
    final List<TimeSeriesChartData> profitData = data['profitData'] ?? [];

    return SfCartesianChart(
      primaryXAxis: DateTimeAxis(
        dateFormat: DateFormat('dd/MM'),
        majorGridLines: const MajorGridLines(width: 0),
      ),
      primaryYAxis: NumericAxis(
        numberFormat: NumberFormat.compact(locale: 'vi_VN'),
        axisLine: const AxisLine(width: 0),
        majorTickLines: const MajorTickLines(color: Colors.transparent),
      ),
      legend: const Legend(isVisible: true, position: LegendPosition.top, overflowMode: LegendItemOverflowMode.wrap),
      trackballBehavior: TrackballBehavior(
        enable: true,
        activationMode: ActivationMode.singleTap,
        tooltipSettings: const InteractiveTooltip(enable: true, format: 'point.x\n{point.y}',),
        lineType: TrackballLineType.vertical,
      ),
      zoomPanBehavior: ZoomPanBehavior(
        enablePinching: true,
        enablePanning: true,
        zoomMode: ZoomMode.x,
      ),
      // *** SỬA LỖI Ở ĐÂY: Thay <ChartSeries> bằng <CartesianSeries> ***
      series: <CartesianSeries<TimeSeriesChartData, DateTime>>[
        LineSeries<TimeSeriesChartData, DateTime>(
          dataSource: revenueData,
          xValueMapper: (TimeSeriesChartData item, _) => item.x,
          yValueMapper: (TimeSeriesChartData item, _) => item.y,
          name: 'Doanh Thu',
          color: AppColors.chartGreen,
        ),
        LineSeries<TimeSeriesChartData, DateTime>(
          dataSource: expenseData,
          xValueMapper: (TimeSeriesChartData item, _) => item.x,
          yValueMapper: (TimeSeriesChartData item, _) => item.y,
          name: 'Chi Phí',
          color: AppColors.chartRed,
        ),
        LineSeries<TimeSeriesChartData, DateTime>(
          dataSource: profitData,
          xValueMapper: (TimeSeriesChartData item, _) => item.x,
          yValueMapper: (TimeSeriesChartData item, _) => item.y,
          name: 'Lợi Nhuận',
          color: AppColors.chartBlue,
        ),
      ],
    );
  }

  Widget _buildSyncfusionExpenseTrendChart(BuildContext context, Map<String, List<TimeSeriesChartData>> data) {
    final List<TimeSeriesChartData> fixedData = data['fixed'] ?? [];
    final List<TimeSeriesChartData> variableData = data['variable'] ?? [];
    final List<TimeSeriesChartData> otherData = data['other'] ?? []; // <<< THÊM MỚI
    final List<TimeSeriesChartData> totalData = data['total'] ?? [];

    return SfCartesianChart(
      primaryXAxis: DateTimeAxis(dateFormat: DateFormat('dd/MM'), majorGridLines: const MajorGridLines(width: 0)),
      primaryYAxis: NumericAxis(numberFormat: NumberFormat.compact(locale: 'vi_VN'), axisLine: const AxisLine(width: 0), majorTickLines: const MajorTickLines(color: Colors.transparent)),
      legend: const Legend(isVisible: true, position: LegendPosition.top, overflowMode: LegendItemOverflowMode.wrap),
      trackballBehavior: TrackballBehavior(enable: true, activationMode: ActivationMode.singleTap, tooltipSettings: const InteractiveTooltip(enable: true, format: 'point.x\n{point.y}')),
      zoomPanBehavior: ZoomPanBehavior(enablePinching: true, enablePanning: true, zoomMode: ZoomMode.x),
      series: <CartesianSeries<TimeSeriesChartData, DateTime>>[
        LineSeries<TimeSeriesChartData, DateTime>(
          dataSource: fixedData,
          xValueMapper: (TimeSeriesChartData item, _) => item.x,
          yValueMapper: (TimeSeriesChartData item, _) => item.y,
          name: 'Cố định',
          color: AppColors.chartBlue,
          dashArray: const <double>[5, 5],
        ),
        LineSeries<TimeSeriesChartData, DateTime>(
          dataSource: variableData,
          xValueMapper: (TimeSeriesChartData item, _) => item.x,
          yValueMapper: (TimeSeriesChartData item, _) => item.y,
          name: 'Biến đổi',
          color: AppColors.chartOrange,
          dashArray: const <double>[5, 5],
        ),
        // <<< THÊM MỚI: LINE CHO CHI PHÍ KHÁC >>>
        LineSeries<TimeSeriesChartData, DateTime>(
          dataSource: otherData,
          xValueMapper: (TimeSeriesChartData item, _) => item.x,
          yValueMapper: (TimeSeriesChartData item, _) => item.y,
          name: 'Khác',
          color: AppColors.chartPurple, // Chọn một màu mới
          dashArray: const <double>[5, 5],
        ),
        LineSeries<TimeSeriesChartData, DateTime>(
          dataSource: totalData,
          xValueMapper: (TimeSeriesChartData item, _) => item.x,
          yValueMapper: (TimeSeriesChartData item, _) => item.y,
          name: 'Tổng',
          color: AppColors.chartRed,
          width: 2.5, // Làm cho đường tổng đậm hơn
        ),
      ],
    );
  }

  Widget _buildSyncfusionRevenueTrendChart(BuildContext context, Map<String, List<TimeSeriesChartData>> data) {
    final List<TimeSeriesChartData> mainData = data['main'] ?? [];
    final List<TimeSeriesChartData> secondaryData = data['secondary'] ?? [];
    final List<TimeSeriesChartData> otherData = data['other'] ?? [];

    return SfCartesianChart(
      primaryXAxis: DateTimeAxis(dateFormat: DateFormat('dd/MM'), majorGridLines: const MajorGridLines(width: 0)),
      primaryYAxis: NumericAxis(numberFormat: NumberFormat.compact(locale: 'vi_VN'), axisLine: const AxisLine(width: 0), majorTickLines: const MajorTickLines(color: Colors.transparent)),
      legend: const Legend(isVisible: true, position: LegendPosition.top, overflowMode: LegendItemOverflowMode.wrap),
      trackballBehavior: TrackballBehavior(enable: true, activationMode: ActivationMode.singleTap, tooltipSettings: const InteractiveTooltip(enable: true, format: 'point.x\n{point.y}')),
      zoomPanBehavior: ZoomPanBehavior(enablePinching: true, enablePanning: true, zoomMode: ZoomMode.x),
      // *** SỬA LỖI Ở ĐÂY: Thay <ChartSeries> bằng <CartesianSeries> ***
      series: <CartesianSeries<TimeSeriesChartData, DateTime>>[
        LineSeries<TimeSeriesChartData, DateTime>(
          dataSource: mainData,
          xValueMapper: (TimeSeriesChartData item, _) => item.x,
          yValueMapper: (TimeSeriesChartData item, _) => item.y,
          name: 'Doanh Thu Chính',
          color: AppColors.chartGreen,
        ),
        LineSeries<TimeSeriesChartData, DateTime>(
          dataSource: secondaryData,
          xValueMapper: (TimeSeriesChartData item, _) => item.x,
          yValueMapper: (TimeSeriesChartData item, _) => item.y,
          name: 'Doanh Thu Phụ',
          color: AppColors.chartBlue,
        ),
        LineSeries<TimeSeriesChartData, DateTime>(
          dataSource: otherData,
          xValueMapper: (TimeSeriesChartData item, _) => item.x,
          yValueMapper: (TimeSeriesChartData item, _) => item.y,
          name: 'Doanh Thu Khác',
          color: AppColors.chartOrange,
        ),
      ],
    );
  }

  Widget _buildSyncfusionExpensePieChart(BuildContext context, List<CategoryChartData> data) {
    // *** BƯỚC 1: Tính tổng giá trị của tất cả các mục trước khi vẽ biểu đồ ***
    final double totalValue = data.fold(0, (previousValue, element) => previousValue + element.value);

    return SfCircularChart(
      legend: const Legend(isVisible: true, overflowMode: LegendItemOverflowMode.wrap, position: LegendPosition.bottom),
      tooltipBehavior: TooltipBehavior(enable: true, format: 'point.x: {point.y} đ'),
      series: <CircularSeries>[
        PieSeries<CategoryChartData, String>(
          dataSource: data,
          xValueMapper: (CategoryChartData item, _) => item.category,
          yValueMapper: (CategoryChartData item, _) => item.value,
          pointColorMapper: (CategoryChartData data, int index) =>
          AppColors.pieChartColors[index % AppColors.pieChartColors.length],
          dataLabelSettings: const DataLabelSettings(
            isVisible: true,
            labelPosition: ChartDataLabelPosition.outside,
            connectorLineSettings: ConnectorLineSettings(type: ConnectorType.curve),
          ),
          // *** BƯỚC 2: Sửa lại dataLabelMapper để sử dụng totalValue đã tính sẵn ***
          dataLabelMapper: (CategoryChartData data, _) {
            if (totalValue == 0) {
              return '0%';
            }
            final double percentage = (data.value / totalValue) * 100;
            // Chỉ hiển thị nhãn cho các phần có tỷ lệ lớn hơn 3% để tránh rối mắt
            return percentage > 5 ? '${percentage.toStringAsFixed(1)}%' : '';
          },
        )
      ],
    );
  }
}