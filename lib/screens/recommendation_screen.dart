import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import '../state/app_state.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AnalysisScreen extends StatefulWidget {
  @override
  _AnalysisScreenState createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> with SingleTickerProviderStateMixin {
  bool isLoading = false;
  String industry = '';
  DateTimeRange? selectedRange;
  final List<String> industrySuggestions = [
    'Bán lẻ',
    'F&B',
    'Dịch vụ',
    'Sản xuất',
    'Khác',
  ];
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _buttonScaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 700), vsync: this);
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));
    _buttonScaleAnimation = TweenSequence([
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.95), weight: 50),
      TweenSequenceItem(tween: Tween<double>(begin: 0.95, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _calculateStandardDeviation(List<double> values) {
    if (values.isEmpty) return 0.0;
    double mean = values.reduce((a, b) => a + b) / values.length;
    double variance = values
        .map((x) => (x - mean) * (x - mean))
        .reduce((a, b) => a + b) /
        values.length;
    return math.sqrt(variance);
  }

  Future<Map<String, dynamic>> _analyzeFinancialData(
      AppState appState, DateTimeRange range) async {
    try {
      // Dữ liệu hiện tại
      final revenueData = await appState.getRevenueForRange(range);
      final expenseData = await appState.getExpensesForRange(range);
      final overview = await appState.getOverviewForRange(range);
      final topProducts = await appState.getTopProductsByCategory(range);
      final dailyRevenues = await appState.getDailyRevenueForRange(range);
      final dailyExpenses = await appState.getDailyExpensesForRange(range);
      final expenseBreakdown = await appState.getExpenseBreakdown(range);
      final productRevenueBreakdown = await appState.getProductRevenueBreakdown(range);

      // Dữ liệu kỳ trước
      final int days = range.end.difference(range.start).inDays + 1;
      final previousRange = DateTimeRange(
        start: range.start.subtract(Duration(days: days)),
        end: range.end.subtract(Duration(days: days)),
      );
      final previousRevenueData = await appState.getRevenueForRange(previousRange);
      final previousExpenseData = await appState.getExpensesForRange(previousRange);
      final previousOverview = await appState.getOverviewForRange(previousRange);
      final previousDailyRevenues = await appState.getDailyRevenueForRange(previousRange);
      final previousDailyExpenses = await appState.getDailyExpensesForRange(previousRange);

      // Dữ liệu hiện tại
      double totalRevenue = (revenueData['totalRevenue'] as num?)?.toDouble() ?? 0.0;
      double mainRevenue = (revenueData['mainRevenue'] as num?)?.toDouble() ?? 0.0;
      double secondaryRevenue = (revenueData['secondaryRevenue'] as num?)?.toDouble() ?? 0.0;
      double otherRevenue = (revenueData['otherRevenue'] as num?)?.toDouble() ?? 0.0;
      double totalExpense = (expenseData['totalExpense'] as num?)?.toDouble() ?? 0.0;
      double fixedExpense = (expenseData['fixedExpense'] as num?)?.toDouble() ?? 0.0;
      double variableExpense = (expenseData['variableExpense'] as num?)?.toDouble() ?? 0.0;
      double profit = (overview['profit'] as num?)?.toDouble() ?? 0.0;
      double profitMargin = (overview['averageProfitMargin'] as num?)?.toDouble() ?? 0.0;

      // Dữ liệu kỳ trước
      double prevTotalRevenue = (previousRevenueData['totalRevenue'] as num?)?.toDouble() ?? 0.0;
      double prevTotalExpense = (previousExpenseData['totalExpense'] as num?)?.toDouble() ?? 0.0;
      double prevProfit = (previousOverview['profit'] as num?)?.toDouble() ?? 0.0;
      double prevProfitMargin = (previousOverview['averageProfitMargin'] as num?)?.toDouble() ?? 0.0;

      // So sánh với kỳ trước
      double revenueChange = prevTotalRevenue > 0 ? ((totalRevenue - prevTotalRevenue) / prevTotalRevenue * 100) : 0.0;
      double expenseChange = prevTotalExpense > 0 ? ((totalExpense - prevTotalExpense) / prevTotalExpense * 100) : 0.0;
      double profitChange = prevProfit != 0 ? ((profit - prevProfit) / prevProfit.abs() * 100) : 0.0;
      double profitMarginChange = profitMargin - prevProfitMargin;

      Map<String, double> revenueShares = {
        'Doanh thu chính': totalRevenue > 0 ? (mainRevenue / totalRevenue * 100) : 0.0,
        'Doanh thu phụ': totalRevenue > 0 ? (secondaryRevenue / totalRevenue * 100) : 0.0,
        'Doanh thu khác': totalRevenue > 0 ? (otherRevenue / totalRevenue * 100) : 0.0,
      };

      Map<String, double> expenseShares = {
        'Chi phí cố định': totalExpense > 0 ? (fixedExpense / totalExpense * 100) : 0.0,
        'Chi phí biến đổi': totalExpense > 0 ? (variableExpense / totalExpense * 100) : 0.0,
      };

      Map<String, String> topProductsSummary = {};
      topProducts.forEach((category, products) {
        List<MapEntry<String, double>> sortedProducts = products.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        topProductsSummary[category] = sortedProducts
            .take(2)
            .map((e) => '${e.key} (${NumberFormat.currency(locale: 'vi_VN', symbol: '').format(e.value)} VNĐ)')
            .join(', ');
      });

      List<double> revenueValues = dailyRevenues
          .map((day) => (day['totalRevenue'] as num?)?.toDouble() ?? 0.0)
          .toList();
      double revenueTrend = revenueValues.isNotEmpty
          ? ((revenueValues.last - revenueValues.first) / (revenueValues.first == 0 ? 1 : revenueValues.first) * 100)
          : 0.0;

      List<String> revenueAnomalies = [];
      List<String> revenueAnomalyDetails = [];
      if (revenueValues.isNotEmpty) {
        double revenueMean = revenueValues.reduce((a, b) => a + b) / revenueValues.length;
        double revenueStd = _calculateStandardDeviation(revenueValues);
        for (int i = 0; i < revenueValues.length && i < previousDailyRevenues.length; i++) {
          if ((revenueValues[i] - revenueMean).abs() > 2 * revenueStd) {
            String date = DateFormat('dd/MM').format(range.start.add(Duration(days: i)));
            double prevRevenue = (previousDailyRevenues[i]['totalRevenue'] as num?)?.toDouble() ?? 0.0;
            double change = prevRevenue > 0 ? ((revenueValues[i] - prevRevenue) / prevRevenue * 100) : 0.0;
            revenueAnomalies.add(
                'Ngày $date: ${NumberFormat.currency(locale: 'vi_VN', symbol: '').format(revenueValues[i])} VNĐ (${revenueValues[i] > revenueMean ? "cao" : "thấp"} bất thường, ${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)}% so với kỳ trước)');
            // Lấy chi tiết sản phẩm trong ngày bất thường
            String dateKey = DateFormat('yyyy-MM-dd').format(range.start.add(Duration(days: i)));
            DocumentSnapshot doc = await FirebaseFirestore.instance
                .collection('users')
                .doc(appState.userId)
                .collection('daily_data')
                .doc(appState.getKey(dateKey))
                .get();
            if (doc.exists) {
              List<dynamic> mainTrans = doc['mainRevenueTransactions'] ?? [];
              if (mainTrans.isNotEmpty) {
                var topProduct = mainTrans.reduce((a, b) => ((a['total'] as num?) ?? 0) > ((b['total'] as num?) ?? 0) ? a : b);
                revenueAnomalyDetails.add(
                    'Ngày $date: Sản phẩm chủ lực: ${topProduct['name']} (${NumberFormat.currency(locale: 'vi_VN', symbol: '').format((topProduct['total'] as num?)?.toDouble() ?? 0)} VNĐ)');
              }
            }
          }
        }
      }

      List<double> expenseValues = dailyExpenses
          .map((day) => (day['totalExpense'] as num?)?.toDouble() ?? 0.0)
          .toList();
      double expenseTrend = expenseValues.isNotEmpty
          ? ((expenseValues.last - expenseValues.first) / (expenseValues.first == 0 ? 1 : expenseValues.first) * 100)
          : 0.0;

      List<String> expenseAnomalies = [];
      List<String> expenseAnomalyDetails = [];
      if (expenseValues.isNotEmpty) {
        double expenseMean = expenseValues.reduce((a, b) => a + b) / expenseValues.length;
        double expenseStd = _calculateStandardDeviation(expenseValues);
        for (int i = 0; i < expenseValues.length && i < previousDailyExpenses.length; i++) {
          if ((expenseValues[i] - expenseMean).abs() > 2 * expenseStd) {
            String date = DateFormat('dd/MM').format(range.start.add(Duration(days: i)));
            double prevExpense = (previousDailyExpenses[i]['totalExpense'] as num?)?.toDouble() ?? 0.0;
            double change = prevExpense > 0 ? ((expenseValues[i] - prevExpense) / prevExpense * 100) : 0.0;
            expenseAnomalies.add(
                'Ngày $date: ${NumberFormat.currency(locale: 'vi_VN', symbol: '').format(expenseValues[i])} VNĐ (${expenseValues[i] > expenseMean ? "cao" : "thấp"} bất thường, ${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)}% so với kỳ trước)');
            // Lấy chi tiết chi phí
            String dateKey = DateFormat('yyyy-MM-dd').format(range.start.add(Duration(days: i)));
            DocumentSnapshot doc = await FirebaseFirestore.instance
                .collection('users')
                .doc(appState.userId)
                .collection('expenses')
                .doc('variable')
                .collection('daily')
                .doc(appState.getKey('variableTransactionHistory_$dateKey'))
                .get();
            if (doc.exists && doc['products'] != null) {
              List<dynamic> products = doc['products'];
              if (products.isNotEmpty) {
                var topExpense = products.reduce((a, b) => ((a['amount'] as num?) ?? 0) > ((b['amount'] as num?) ?? 0) ? a : b);
                expenseAnomalyDetails.add(
                    'Ngày $date: Chi phí chính: ${topExpense['name']} (${NumberFormat.currency(locale: 'vi_VN', symbol: '').format((topExpense['amount'] as num?)?.toDouble() ?? 0)} VNĐ)');
              }
            }
          }
        }
      }

      Map<String, double> categoryProfits = {
        'Doanh thu chính': mainRevenue - (variableExpense * (mainRevenue / (totalRevenue == 0 ? 1 : totalRevenue))),
        'Doanh thu phụ': secondaryRevenue - (variableExpense * (secondaryRevenue / (totalRevenue == 0 ? 1 : totalRevenue))),
        'Doanh thu khác': otherRevenue - (variableExpense * (otherRevenue / (totalRevenue == 0 ? 1 : totalRevenue))),
      };

      Map<String, double> categoryMargins = {
        'Doanh thu chính': mainRevenue > 0 ? (categoryProfits['Doanh thu chính']! / mainRevenue * 100) : 0.0,
        'Doanh thu phụ': secondaryRevenue > 0 ? (categoryProfits['Doanh thu phụ']! / secondaryRevenue * 100) : 0.0,
        'Doanh thu khác': otherRevenue > 0 ? (categoryProfits['Doanh thu khác']! / otherRevenue * 100) : 0.0,
      };

      List<double> dailyProfits = dailyRevenues
          .asMap()
          .entries
          .map((entry) {
        int index = entry.key;
        double revenue = (entry.value['totalRevenue'] as num?)?.toDouble() ?? 0.0;
        double expense = index < expenseValues.length ? expenseValues[index] : 0.0;
        return revenue > 0 ? ((revenue - expense) / revenue * 100) : 0.0;
      }).toList();

      double profitMarginTrend = dailyProfits.isNotEmpty
          ? (dailyProfits.last - dailyProfits.first)
          : 0.0;

      List<String> profitMarginAnomalies = [];
      if (dailyProfits.isNotEmpty) {
        double profitMarginMean = dailyProfits.reduce((a, b) => a + b) / dailyProfits.length;
        double profitMarginStd = _calculateStandardDeviation(dailyProfits);
        for (int i = 0; i < dailyProfits.length && i < previousDailyRevenues.length && i < previousDailyExpenses.length; i++) {
          if ((dailyProfits[i] - profitMarginMean).abs() > 2 * profitMarginStd) {
            String date = DateFormat('dd/MM').format(range.start.add(Duration(days: i)));
            double prevRevenue = (previousDailyRevenues[i]['totalRevenue'] as num?)?.toDouble() ?? 0.0;
            double prevExpense = (previousDailyExpenses[i]['totalExpense'] as num?)?.toDouble() ?? 0.0;
            double prevProfitMargin = prevRevenue > 0 ? ((prevRevenue - prevExpense) / prevRevenue * 100) : 0.0;
            double change = dailyProfits[i] - prevProfitMargin;
            profitMarginAnomalies.add(
                'Ngày $date: ${dailyProfits[i].toStringAsFixed(1)}% (${dailyProfits[i] > profitMarginMean ? "cao" : "thấp"} bất thường, ${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)}% so với kỳ trước)');
          }
        }
      }

      String expenseBreakdownSummary = expenseBreakdown.entries
          .map((e) => '${e.key}: ${NumberFormat.currency(locale: 'vi_VN', symbol: '').format(e.value)} VNĐ')
          .join(', ');

      String productRevenueSummary = productRevenueBreakdown.entries
          .map((e) => '${e.key}: ${e.value.toStringAsFixed(1)}%')
          .join(', ');

      String report = '''Phân tích ${range.end.difference(range.start).inDays + 1} ngày gần nhất (${DateFormat('dd/MM/yyyy').format(range.start)} - ${DateFormat('dd/MM/yyyy').format(range.end)}):
So sánh với kỳ trước (${DateFormat('dd/MM/yyyy').format(previousRange.start)} - ${DateFormat('dd/MM/yyyy').format(previousRange.end)}):
- Doanh thu: ${revenueChange >= 0 ? '+' : ''}${revenueChange.toStringAsFixed(1)}%
- Chi phí: ${expenseChange >= 0 ? '+' : ''}${expenseChange.toStringAsFixed(1)}%
- Lợi nhuận: ${profitChange >= 0 ? '+' : ''}${profitChange.toStringAsFixed(1)}%
- Biên lợi nhuận: ${profitMarginChange >= 0 ? '+' : ''}${profitMarginChange.toStringAsFixed(1)}%

- Doanh thu: ${NumberFormat.currency(locale: 'vi_VN', symbol: '').format(totalRevenue)} VNĐ (chính: ${revenueShares['Doanh thu chính']!.toStringAsFixed(1)}%, phụ: ${revenueShares['Doanh thu phụ']!.toStringAsFixed(1)}%, khác: ${revenueShares['Doanh thu khác']!.toStringAsFixed(1)}%).
  Top sản phẩm:
  + Doanh thu chính: ${topProductsSummary['Doanh thu chính'] ?? 'Không có'}
  + Doanh thu phụ: ${topProductsSummary['Doanh thu phụ'] ?? 'Không có'}
  + Doanh thu khác: ${topProductsSummary['Doanh thu khác'] ?? 'Không có'}
  Xu hướng: ${revenueTrend >= 0 ? '+' : ''}${revenueTrend.toStringAsFixed(1)}% so với ngày đầu kỳ.
  Điểm bất thường: ${revenueAnomalies.isNotEmpty ? revenueAnomalies.join('; ') : 'Không có'}.
  Chi tiết bất thường: ${revenueAnomalyDetails.isNotEmpty ? revenueAnomalyDetails.join('; ') : 'Không có'}.

- Chi phí: ${NumberFormat.currency(locale: 'vi_VN', symbol: '').format(totalExpense)} VNĐ (cố định: ${expenseShares['Chi phí cố định']!.toStringAsFixed(1)}%, biến đổi: ${expenseShares['Chi phí biến đổi']!.toStringAsFixed(1)}%).
  Phân bổ chi phí: ${expenseBreakdownSummary.isNotEmpty ? expenseBreakdownSummary : 'Không có'}.
  Xu hướng: ${expenseTrend >= 0 ? '+' : ''}${expenseTrend.toStringAsFixed(1)}% so với ngày đầu kỳ.
  Điểm bất thường: ${expenseAnomalies.isNotEmpty ? expenseAnomalies.join('; ') : 'Không có'}.
  Chi tiết bất thường: ${expenseAnomalyDetails.isNotEmpty ? expenseAnomalyDetails.join('; ') : 'Không có'}.

- Lợi nhuận: ${NumberFormat.currency(locale: 'vi_VN', symbol: '').format(profit)} VNĐ, biên lợi nhuận: ${profitMargin.toStringAsFixed(1)}%.
  Biên lợi nhuận theo danh mục:
  + Doanh thu chính: ${categoryMargins['Doanh thu chính']!.toStringAsFixed(1)}%
  + Doanh thu phụ: ${categoryMargins['Doanh thu phụ']!.toStringAsFixed(1)}%
  + Doanh thu khác: ${categoryMargins['Doanh thu khác']!.toStringAsFixed(1)}%
  Xu hướng biên lợi nhuận: ${profitMarginTrend >= 0 ? '+' : ''}${profitMarginTrend.toStringAsFixed(1)}%.
  Điểm bất thường: ${profitMarginAnomalies.isNotEmpty ? profitMarginAnomalies.join('; ') : 'Không có'}.
- Phân bổ doanh thu sản phẩm: ${productRevenueSummary.isNotEmpty ? productRevenueSummary : 'Không có'}.
- Ngành nghề: $industry.''';

      print('Báo cáo phân tích: $report');
      return {
        'report': report,
        'totalRevenue': totalRevenue,
        'profit': profit,
        'profitMargin': profitMargin,
      };
    } catch (e) {
      print('Lỗi khi phân tích dữ liệu: $e');
      return {
        'report': 'Không thể phân tích dữ liệu do lỗi hệ thống: $e',
        'totalRevenue': 0.0,
        'profit': 0.0,
        'profitMargin': 0.0,
      };
    }
  }

  Future<void> getAnalysis() async {
    setState(() {
      isLoading = true;
    });
    final appState = Provider.of<AppState>(context, listen: false);
    appState.setLastRecommendation("Đang phân tích dữ liệu...");
    try {
      final range = selectedRange ??
          DateTimeRange(
            start: DateTime.now().subtract(Duration(days: 7)),
            end: DateTime.now(),
          );
      final analysis = await _analyzeFinancialData(appState, range);
      String report = analysis['report'];

      String prompt = '''Bạn là chuyên gia tài chính trong ngành $industry. Dưới đây là phân tích dữ liệu kinh doanh:
$report
Hãy cung cấp một báo cáo phân tích chuyên sâu, bao gồm:
1. Tổng quan hiệu suất kinh doanh: Tóm tắt doanh thu, chi phí, lợi nhuận, và các thay đổi so với kỳ trước, giải thích ý nghĩa của các chỉ số trong ngành $industry.
2. Phân tích điểm bất thường:
   - Doanh thu: Giải thích lý do các điểm bất thường (dựa trên top sản phẩm, phân bổ doanh thu, và so sánh với kỳ trước), ví dụ: sản phẩm nào hoặc sự kiện nào gây ra tăng/giảm đột biến.
   - Chi phí: Xác định nguyên nhân các điểm bất thường (dựa trên phân bổ chi phí, chi tiết bất thường, và so sánh với kỳ trước), ví dụ: chi phí nào tăng/giảm và tại sao.
   - Biên lợi nhuận: Lý do các điểm bất thường xảy ra (dựa trên biên lợi nhuận theo danh mục, phân bổ doanh thu sản phẩm, và so sánh với kỳ trước).
3. Yếu tố ngành: Phân tích các yếu tố trong ngành $industry có thể ảnh hưởng đến xu hướng và điểm bất thường, ví dụ: mùa vụ, cạnh tranh, hoặc thay đổi thị trường.
Mỗi phần cần chi tiết, sử dụng dữ liệu từ báo cáo, đưa ra ví dụ thực tế, và phù hợp với ngành $industry.''';

      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();

      if (idToken == null) {
        appState.setLastRecommendation("❌ Bạn chưa đăng nhập. Vui lòng đăng nhập để sử dụng A.I.");
        setState(() {
          isLoading = false;
        });
        return;
      }

      final response = await http.post(
        Uri.parse("https://getairecommendation-agfn6a733a-uc.a.run.app"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $idToken",
        },
        body: jsonEncode({
          "prompt": prompt,
        }),
      );

      if (response.statusCode == 429) {
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData["error"] ?? "Bạn đã vượt quá số lượt gọi.";
        appState.setLastRecommendation("⚠️ $errorMessage");
        setState(() {
          isLoading = false;
        });
        return;
      }

      if (response.statusCode == 200) {
        var responseData = jsonDecode(utf8.decode(response.bodyBytes));
        String aiResponse = responseData["recommendation"];
        appState.setLastRecommendation("🤖 Phân tích tài chính:\n\n$aiResponse");
      } else {
        print('Lỗi gọi API: Status ${response.statusCode}');
        print('Phản hồi: ${response.body}');
        appState.setLastRecommendation("❌ Không thể nhận phân tích. Mã lỗi: ${response.statusCode}. Vui lòng thử lại.");
      }
    } catch (e) {
      appState.setLastRecommendation("⚠️ Bạn đã dùng hết số lần gọi hôm nay. Vui lòng thử lại vào ngày mai.");
    }
    setState(() {
      isLoading = false;
    });
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: selectedRange ??
          DateTimeRange(
            start: DateTime.now().subtract(Duration(days: 7)),
            end: DateTime.now(),
          ),
      locale: const Locale('vi', 'VN'),
    );
    if (picked != null && picked != selectedRange) {
      setState(() {
        selectedRange = picked;
      });
    }
  }

  void _resetInputs() {
    setState(() {
      industry = '';
      selectedRange = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF1976D2),
          title: Text(
            "Phân tích tài chính",
            style: TextStyle(
              fontSize: MediaQuery.of(context).size.width > 600 ? 22 : 20,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          actions: [
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                selectedRange == null
                    ? "7 ngày gần nhất"
                    : "${DateFormat('dd/MM/yy').format(selectedRange!.start)} - ${DateFormat('dd/MM/yy').format(selectedRange!.end)}",
                style: const TextStyle(fontSize: 12, color: Colors.white),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final padding = constraints.maxWidth > 600 ? 24.0 : 16.0;
              return CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.all(padding),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        Card(
                          elevation: 6,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Thông tin đầu vào",
                                  style: TextStyle(
                                    fontSize: constraints.maxWidth > 600 ? 18 : 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Autocomplete<String>(
                                  optionsBuilder: (TextEditingValue textEditingValue) {
                                    if (textEditingValue.text.isEmpty) {
                                      return industrySuggestions;
                                    }
                                    return industrySuggestions.where((option) =>
                                        option.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                                  },
                                  onSelected: (String selection) {
                                    setState(() {
                                      industry = selection;
                                    });
                                  },
                                  fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                                    return TextField(
                                      controller: controller,
                                      focusNode: focusNode,
                                      decoration: InputDecoration(
                                        labelText: "Ngành nghề (ví dụ: Bán lẻ, F&B)",
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                        isDense: true,
                                      ),
                                      onChanged: (value) {
                                        setState(() {
                                          industry = value;
                                        });
                                      },
                                      maxLines: 1,
                                      maxLength: 50,
                                    );
                                  },
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          selectedRange == null
                                              ? "Thời gian: 7 ngày gần nhất"
                                              : "Từ ${DateFormat('dd/MM/yyyy').format(selectedRange!.start)} đến ${DateFormat('dd/MM/yyyy').format(selectedRange!.end)}",
                                          style: TextStyle(fontSize: constraints.maxWidth > 600 ? 16 : 14),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 2,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.calendar_today, color: Color(0xFF1976D2), size: 20),
                                      onPressed: () => _selectDateRange(context),
                                      tooltip: "Chọn khoảng thời gian",
                                      splashRadius: 20,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ScaleTransition(
                                        scale: _buttonScaleAnimation,
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF42A5F5),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            minimumSize: const Size(double.infinity, 50),
                                          ),
                                          onPressed: industry.isEmpty
                                              ? null
                                              : () {
                                            _controller.forward(from: 0);
                                            getAnalysis();
                                          },
                                          child: Text(
                                            "Nhận phân tích từ A.I",
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: constraints.maxWidth > 600 ? 16 : 14,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.refresh, color: Color(0xFF1976D2), size: 18),
                                      onPressed: _resetInputs,
                                      tooltip: "Xóa dữ liệu",
                                      splashRadius: 18,
                                      padding: const EdgeInsets.all(8),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.grey.withOpacity(0.1),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        minimumSize: const Size(40, 40),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Card(
                          elevation: 8,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  industry.isEmpty ? "Kết quả phân tích" : "Phân tích tài chính cho ngành $industry",
                                  style: TextStyle(
                                    fontSize: constraints.maxWidth > 600 ? 18 : 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxHeight: constraints.maxHeight * 0.5,
                                  ),
                                  child: FadeTransition(
                                    opacity: _fadeAnimation,
                                    child: isLoading
                                        ? const Center(child: CircularProgressIndicator())
                                        : SingleChildScrollView(
                                      physics: const BouncingScrollPhysics(),
                                      child: SelectableText(
                                        appState.lastRecommendation,
                                        style: TextStyle(fontSize: constraints.maxWidth > 600 ? 16 : 14),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ]),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}