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

class _AnalysisScreenState extends State<AnalysisScreen>
    with SingleTickerProviderStateMixin {
  // Define a modern color palette
  static const Color _primaryColor = Color(0xFF0A7AFF);
  static const Color _secondaryColor = Color(0xFFF0F4F8);
  static const Color _textColorPrimary = Color(0xFF1D2D3A);
  static const Color _textColorSecondary = Color(0xFF6E7A8A);
  static const Color _cardBackgroundColor = Colors.white;

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
    _controller = AnimationController(
        duration: const Duration(milliseconds: 700), vsync: this);
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

  // Helper function to calculate linear regression slope
  double _calculateLinearRegressionSlope(List<double> yValues) {
    if (yValues.length < 2) {
      return 0.0; // Not enough data to calculate slope
    }
    int n = yValues.length;
    double sumX = 0;    // Sum of days (1, 2, ..., n)
    double sumY = 0;    // Sum of y values (revenue, expense, profit margin)
    double sumXY = 0;   // Sum of (day * y value)
    double sumXSquared = 0; // Sum of squares of days

    for (int i = 0; i < n; i++) {
      double x_i = (i + 1.0); // Day number (1-indexed)
      double y_i = yValues[i];

      sumX += x_i;
      sumY += y_i;
      sumXY += x_i * y_i;
      sumXSquared += x_i * x_i;
    }

    // Formula for slope: m = (N * Σ(xy) - Σx * Σy) / (N * Σ(x^2) - (Σx)^2)
    double denominator = (n * sumXSquared) - (sumX * sumX);

    if (denominator == 0) {
      // This case is rare if n >= 2 and x values are distinct (1, 2, ..., n).
      // Could happen if all yValues are identical (flat line, slope should be 0).
      if (yValues.every((val) => val == yValues.first)) return 0.0;
      return 0.0; // Default or handle error appropriately
    }
    return ((n * sumXY) - (sumX * sumY)) / denominator;
  }

  Future<Map<String, dynamic>> _analyzeFinancialData(
      AppState appState, DateTimeRange range) async {
    try {
      // Dữ liệu hiện tại
      final revenueData = await appState.getRevenueForRange(range);
      final expenseData = await appState.getExpensesForRange(range);
      final overview = await appState.getOverviewForRange(range);
      final topProducts = await appState.getTopProductsByCategory(range);
      final dailyRevenuesData = await appState.getDailyRevenueForRange(range); // Renamed for clarity
      final dailyExpensesData = await appState.getDailyExpensesForRange(range); // Renamed for clarity
      final expenseBreakdown = await appState.getExpenseBreakdown(range);
      final productRevenueBreakdown =
      await appState.getProductRevenueBreakdown(range);

      // Dữ liệu kỳ trước
      final int daysInPeriod = range.end.difference(range.start).inDays + 1;
      final previousRange = DateTimeRange(
        start: range.start.subtract(Duration(days: daysInPeriod)),
        end: range.end.subtract(Duration(days: daysInPeriod)),
      );
      final previousRevenueData =
      await appState.getRevenueForRange(previousRange);
      final previousExpenseData =
      await appState.getExpensesForRange(previousRange);
      final previousOverview = await appState.getOverviewForRange(previousRange);
      final previousDailyRevenuesData = // Renamed for clarity
      await appState.getDailyRevenueForRange(previousRange);
      final previousDailyExpensesData = // Renamed for clarity
      await appState.getDailyExpensesForRange(previousRange);

      // Dữ liệu hiện tại (Tổng hợp)
      double totalRevenue =
          (revenueData['totalRevenue'] as num?)?.toDouble() ?? 0.0;
      double mainRevenue =
          (revenueData['mainRevenue'] as num?)?.toDouble() ?? 0.0;
      double secondaryRevenue =
          (revenueData['secondaryRevenue'] as num?)?.toDouble() ?? 0.0;
      double otherRevenue =
          (revenueData['otherRevenue'] as num?)?.toDouble() ?? 0.0;
      double totalExpense =
          (expenseData['totalExpense'] as num?)?.toDouble() ?? 0.0;
      double fixedExpense =
          (expenseData['fixedExpense'] as num?)?.toDouble() ?? 0.0;
      double variableExpense =
          (expenseData['variableExpense'] as num?)?.toDouble() ?? 0.0;
      double profit = (overview['profit'] as num?)?.toDouble() ?? 0.0;
      double profitMargin =
          (overview['averageProfitMargin'] as num?)?.toDouble() ?? 0.0;

      // Dữ liệu kỳ trước (Tổng hợp)
      double prevTotalRevenue =
          (previousRevenueData['totalRevenue'] as num?)?.toDouble() ?? 0.0;
      double prevTotalExpense =
          (previousExpenseData['totalExpense'] as num?)?.toDouble() ?? 0.0;
      double prevProfit =
          (previousOverview['profit'] as num?)?.toDouble() ?? 0.0;
      double prevProfitMargin =
          (previousOverview['averageProfitMargin'] as num?)?.toDouble() ?? 0.0;

      // So sánh tổng hợp với kỳ trước
      double revenueChangePercentage = prevTotalRevenue > 0
          ? ((totalRevenue - prevTotalRevenue) / prevTotalRevenue * 100)
          : (totalRevenue > 0 ? 100.0 : 0.0); // Handle prevTotalRevenue = 0
      double expenseChangePercentage = prevTotalExpense > 0
          ? ((totalExpense - prevTotalExpense) / prevTotalExpense * 100)
          : (totalExpense > 0 ? 100.0 : 0.0);
      double profitChangePercentage = prevProfit != 0
          ? ((profit - prevProfit) / prevProfit.abs() * 100)
          : (profit != 0 ? 100.0 : 0.0);
      double profitMarginChangePoints = profitMargin - prevProfitMargin;

      // Xử lý so sánh doanh thu kỳ này vs kỳ trước (Cách số 3 đã làm trước đó)
      double absoluteRevenueChange = totalRevenue - prevTotalRevenue;
      String revenueComparisonReportText;
      if (prevTotalRevenue == 0) {
        if (totalRevenue > 0) {
          revenueComparisonReportText =
          "tăng ${NumberFormat.currency(locale: 'vi_VN', symbol: '').format(absoluteRevenueChange)} VNĐ (từ 0 lên ${NumberFormat.currency(locale: 'vi_VN', symbol: '').format(totalRevenue)} VNĐ). Kỳ trước không có doanh thu.";
        } else if (totalRevenue == 0) {
          revenueComparisonReportText = "vẫn là 0 VNĐ, không có thay đổi.";
        } else {
          revenueComparisonReportText =
          "thay đổi thành ${NumberFormat.currency(locale: 'vi_VN', symbol: '').format(totalRevenue)} VNĐ (từ 0). Kỳ trước không có doanh thu.";
        }
      } else if (prevTotalRevenue > 0) {
        revenueComparisonReportText =
        "${absoluteRevenueChange >= 0 ? 'tăng' : 'giảm'} ${NumberFormat.currency(locale: 'vi_VN', symbol: '').format(absoluteRevenueChange.abs())} VNĐ (tương đương ${revenueChangePercentage >= 0 ? '+' : ''}${revenueChangePercentage.toStringAsFixed(1)}%) so với kỳ trước.";
      } else {
        revenueComparisonReportText = "không thể so sánh do dữ liệu doanh thu kỳ trước không hợp lệ (${NumberFormat.currency(locale: 'vi_VN', symbol: '').format(prevTotalRevenue)} VNĐ).";
      }


      // Chuẩn bị dữ liệu hàng ngày cho phân tích xu hướng hồi quy
      List<double> revenueValues = dailyRevenuesData
          .map((day) => (day['totalRevenue'] as num?)?.toDouble() ?? 0.0)
          .toList();
      List<double> expenseValues = dailyExpensesData
          .map((day) => (day['totalExpense'] as num?)?.toDouble() ?? 0.0)
          .toList();
      List<double> dailyProfitMargins = dailyRevenuesData.asMap().entries.map((entry) {
        int index = entry.key;
        double dailyRev = (entry.value['totalRevenue'] as num?)?.toDouble() ?? 0.0;
        double dailyExp = index < expenseValues.length ? expenseValues[index] : 0.0;
        return dailyRev > 0 ? ((dailyRev - dailyExp) / dailyRev * 100) : 0.0;
      }).toList();

      // 1. Xu hướng doanh thu tổng thể (hồi quy tuyến tính)
      String overallRevenueTrendDescription = "Không đủ dữ liệu";
      if (revenueValues.length >= 2) {
        double slope = _calculateLinearRegressionSlope(revenueValues);
        double sumY = 0;
        for(double val in revenueValues) { sumY += val; }
        double averageRevenue = revenueValues.isEmpty ? 0 : sumY / revenueValues.length;

        if (averageRevenue != 0) {
          double percentageTrend = (slope / averageRevenue) * 100;
          overallRevenueTrendDescription =
          "${percentageTrend >= 0 ? 'Tăng trưởng' : 'Suy giảm'} trung bình ${percentageTrend.abs().toStringAsFixed(1)}% mỗi ngày (so với DT trung bình)";
        } else if (slope != 0) {
          overallRevenueTrendDescription = (slope > 0 ? "Có xu hướng tăng từ 0" : "Có xu hướng giảm (nếu DT có thể âm)");
        } else {
          overallRevenueTrendDescription = "Không có thay đổi (doanh thu 0 VNĐ)";
        }
      }

      // 2. Xu hướng chi phí tổng thể (hồi quy tuyến tính)
      String overallExpenseTrendDescription = "Không đủ dữ liệu";
      if (expenseValues.length >= 2) {
        double slope = _calculateLinearRegressionSlope(expenseValues);
        double sumY = 0;
        for(double val in expenseValues) { sumY += val; }
        double averageExpense = expenseValues.isEmpty ? 0 : sumY / expenseValues.length;

        if (averageExpense != 0) {
          double percentageTrend = (slope / averageExpense) * 100;
          overallExpenseTrendDescription =
          "${percentageTrend >= 0 ? 'Tăng' : 'Giảm'} trung bình ${percentageTrend.abs().toStringAsFixed(1)}% mỗi ngày (so với CP trung bình)";
        } else if (slope != 0) {
          overallExpenseTrendDescription = (slope > 0 ? "Có xu hướng tăng từ 0" : "Có xu hướng giảm (nếu CP có thể âm)");
        } else {
          overallExpenseTrendDescription = "Không có thay đổi (chi phí 0 VNĐ)";
        }
      }

      // 3. Xu hướng biên lợi nhuận tổng thể (hồi quy tuyến tính)
      String overallProfitMarginTrendDescription = "Không đủ dữ liệu";
      if (dailyProfitMargins.length >= 2) {
        double slope = _calculateLinearRegressionSlope(dailyProfitMargins); // Slope này là thay đổi điểm % mỗi ngày
        overallProfitMarginTrendDescription =
        "${slope >= 0 ? 'Cải thiện' : 'Giảm sút'} trung bình ${slope.abs().toStringAsFixed(2)} điểm % mỗi ngày";
      }

      // Các phân tích khác (tỷ trọng, top sản phẩm, điểm bất thường) giữ nguyên
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
        List<MapEntry<String, double>> sortedProducts =
        products.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        topProductsSummary[category] = sortedProducts
            .take(2)
            .map((e) =>
        '${e.key} (${NumberFormat.currency(locale: 'vi_VN', symbol: '').format(e.value)} VNĐ)')
            .join(', ');
      });

      List<String> revenueAnomalies = [];
      List<String> revenueAnomalyDetails = [];
      // (Giữ nguyên logic phát hiện điểm bất thường cho doanh thu)
      if (revenueValues.isNotEmpty) {
        double revenueMean = revenueValues.reduce((a, b) => a + b) / revenueValues.length;
        double revenueStd = _calculateStandardDeviation(revenueValues);
        for (int i = 0; i < revenueValues.length && i < previousDailyRevenuesData.length; i++) {
          if ((revenueValues[i] - revenueMean).abs() > 2 * revenueStd) {
            String date = DateFormat('dd/MM').format(range.start.add(Duration(days: i)));
            double prevRevenue = (previousDailyRevenuesData[i]['totalRevenue'] as num?)?.toDouble() ?? 0.0;
            double change = prevRevenue > 0 ? ((revenueValues[i] - prevRevenue) / prevRevenue * 100) : 0.0;
            revenueAnomalies.add(
                'Ngày $date: ${NumberFormat.currency(locale: 'vi_VN', symbol: '').format(revenueValues[i])} VNĐ (${revenueValues[i] > revenueMean ? "cao" : "thấp"} bất thường, ${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)}% so với kỳ trước)');
            // Thêm chi tiết nếu cần
          }
        }
      }


      List<String> expenseAnomalies = [];
      List<String> expenseAnomalyDetails = [];
      // (Giữ nguyên logic phát hiện điểm bất thường cho chi phí)
      if (expenseValues.isNotEmpty) {
        double expenseMean = expenseValues.reduce((a, b) => a + b) / expenseValues.length;
        double expenseStd = _calculateStandardDeviation(expenseValues);
        for (int i = 0; i < expenseValues.length && i < previousDailyExpensesData.length; i++) {
          if ((expenseValues[i] - expenseMean).abs() > 2 * expenseStd) {
            String date = DateFormat('dd/MM').format(range.start.add(Duration(days: i)));
            double prevExpense = (previousDailyExpensesData[i]['totalExpense'] as num?)?.toDouble() ?? 0.0;
            double change = prevExpense > 0 ? ((expenseValues[i] - prevExpense) / prevExpense * 100) : 0.0;
            expenseAnomalies.add(
                'Ngày $date: ${NumberFormat.currency(locale: 'vi_VN', symbol: '').format(expenseValues[i])} VNĐ (${expenseValues[i] > expenseMean ? "cao" : "thấp"} bất thường, ${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)}% so với kỳ trước)');
            // Thêm chi tiết nếu cần
          }
        }
      }

      List<String> profitMarginAnomalies = [];
      // (Giữ nguyên logic phát hiện điểm bất thường cho biên lợi nhuận)
      if (dailyProfitMargins.isNotEmpty) {
        double profitMarginMean = dailyProfitMargins.reduce((a, b) => a + b) / dailyProfitMargins.length;
        double profitMarginStd = _calculateStandardDeviation(dailyProfitMargins);
        for (int i = 0; i < dailyProfitMargins.length; i++) {
          if ((dailyProfitMargins[i] - profitMarginMean).abs() > 2 * profitMarginStd) {
            String date = DateFormat('dd/MM').format(range.start.add(Duration(days: i)));
            profitMarginAnomalies.add(
                'Ngày $date: ${dailyProfitMargins[i].toStringAsFixed(1)}% (${dailyProfitMargins[i] > profitMarginMean ? "cao" : "thấp"} bất thường)');
          }
        }
      }

      String expenseBreakdownSummary = expenseBreakdown.entries
          .map((e) =>
      '${e.key}: ${NumberFormat.currency(locale: 'vi_VN', symbol: '').format(e.value)} VNĐ')
          .join(', ');
      String productRevenueSummary = productRevenueBreakdown.entries
          .map((e) => '${e.key}: ${e.value.toStringAsFixed(1)}%')
          .join(', ');
      Map<String, double> categoryMargins = {
        'Doanh thu chính': mainRevenue > 0
            ? (mainRevenue - (variableExpense * (mainRevenue / (totalRevenue == 0 ? 1 : totalRevenue)))) / mainRevenue * 100
            : 0.0,
        'Doanh thu phụ': secondaryRevenue > 0
            ? (secondaryRevenue - (variableExpense * (secondaryRevenue / (totalRevenue == 0 ? 1 : totalRevenue)))) / secondaryRevenue * 100
            : 0.0,
        'Doanh thu khác': otherRevenue > 0
            ? (otherRevenue - (variableExpense * (otherRevenue / (totalRevenue == 0 ? 1 : totalRevenue)))) / otherRevenue * 100
            : 0.0,
      };


      String report =
      '''Phân tích ${daysInPeriod} ngày gần nhất (${DateFormat('dd/MM/yyyy').format(range.start)} - ${DateFormat('dd/MM/yyyy').format(range.end)}):
So sánh với kỳ trước (${DateFormat('dd/MM/yyyy').format(previousRange.start)} - ${DateFormat('dd/MM/yyyy').format(previousRange.end)}):
- Doanh thu tổng: $revenueComparisonReportText
- Chi phí tổng: ${expenseChangePercentage >= 0 ? '+' : ''}${expenseChangePercentage.toStringAsFixed(1)}%
- Lợi nhuận tổng: ${profitChangePercentage >= 0 ? '+' : ''}${profitChangePercentage.toStringAsFixed(1)}%
- Thay đổi điểm % Biên LN: ${profitMarginChangePoints >= 0 ? '+' : ''}${profitMarginChangePoints.toStringAsFixed(1)} điểm %

Phân tích chi tiết kỳ này:
1. DOANH THU:
   - Tổng doanh thu: ${NumberFormat.currency(locale: 'vi_VN', symbol: '').format(totalRevenue)} VNĐ.
   - Tỷ trọng: Chính: ${revenueShares['Doanh thu chính']!.toStringAsFixed(1)}%, Phụ: ${revenueShares['Doanh thu phụ']!.toStringAsFixed(1)}%, Khác: ${revenueShares['Doanh thu khác']!.toStringAsFixed(1)}%.
   - Top sản phẩm:
     + Doanh thu chính: ${topProductsSummary['Doanh thu chính'] ?? 'Không có'}
     + Doanh thu phụ: ${topProductsSummary['Doanh thu phụ'] ?? 'Không có'}
     + Doanh thu khác: ${topProductsSummary['Doanh thu khác'] ?? 'Không có'}
   - Xu hướng doanh thu (hồi quy): $overallRevenueTrendDescription
   - Điểm bất thường doanh thu: ${revenueAnomalies.isNotEmpty ? revenueAnomalies.join('; ') : 'Không có'}.
   - Chi tiết bất thường Doanh Thu: ${revenueAnomalyDetails.isNotEmpty ? revenueAnomalyDetails.join('; ') : 'Không có'}.

2. CHI PHÍ:
   - Tổng chi phí: ${NumberFormat.currency(locale: 'vi_VN', symbol: '').format(totalExpense)} VNĐ.
   - Tỷ trọng: Cố định: ${expenseShares['Chi phí cố định']!.toStringAsFixed(1)}%, Biến đổi: ${expenseShares['Chi phí biến đổi']!.toStringAsFixed(1)}%.
   - Phân bổ chi phí: ${expenseBreakdownSummary.isNotEmpty ? expenseBreakdownSummary : 'Không có'}.
   - Xu hướng chi phí (hồi quy): $overallExpenseTrendDescription
   - Điểm bất thường chi phí: ${expenseAnomalies.isNotEmpty ? expenseAnomalies.join('; ') : 'Không có'}.
   - Chi tiết bất thường Chi Phí: ${expenseAnomalyDetails.isNotEmpty ? expenseAnomalyDetails.join('; ') : 'Không có'}.

3. LỢI NHUẬN:
   - Lợi nhuận: ${NumberFormat.currency(locale: 'vi_VN', symbol: '').format(profit)} VNĐ.
   - Biên lợi nhuận: ${profitMargin.toStringAsFixed(1)}%.
   - Biên lợi nhuận theo danh mục DT:
     + Chính: ${categoryMargins['Doanh thu chính']!.toStringAsFixed(1)}%
     + Phụ: ${categoryMargins['Doanh thu phụ']!.toStringAsFixed(1)}%
     + Khác: ${categoryMargins['Doanh thu khác']!.toStringAsFixed(1)}%
   - Xu hướng biên lợi nhuận (hồi quy): $overallProfitMarginTrendDescription
   - Điểm bất thường biên Lợi Nhuận: ${profitMarginAnomalies.isNotEmpty ? profitMarginAnomalies.join('; ') : 'Không có'}.

4. PHÂN BỔ DOANH THU SẢN PHẨM (toàn kỳ): ${productRevenueSummary.isNotEmpty ? productRevenueSummary : 'Không có'}.
Ngành nghề kinh doanh: $industry.''';

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
      String prompt =
      '''Bạn là chuyên gia tài chính trong ngành $industry.
Dưới đây là phân tích dữ liệu kinh doanh:
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
        appState.setLastRecommendation(
            "  ❌   Bạn chưa đăng nhập. Vui lòng đăng nhập để sử dụng A.I.");
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
        final errorMessage =
            errorData["error"] ?? "Bạn đã vượt quá số lượt gọi.";
        appState.setLastRecommendation("  ⚠️   $errorMessage");
        setState(() {
          isLoading = false;
        });
        return;
      }
      if (response.statusCode == 200) {
        var responseData = jsonDecode(utf8.decode(response.bodyBytes));
        String aiResponse = responseData["recommendation"];
        appState
            .setLastRecommendation("  🤖   Phân tích tài chính:\n\n$aiResponse");
      } else {
        print('Lỗi gọi API: Status ${response.statusCode}');
        print('Phản hồi: ${response.body}');
        appState.setLastRecommendation(
            "❌Không thể nhận phân tích. Vui lòng thử lại.");
      }
    } catch (e) {
      appState.setLastRecommendation(
          "⚠️Bạn đã dùng hết số lần gọi hôm nay. Vui lòng thử lại vào ngày mai.");
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
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: _primaryColor,
              onPrimary: Colors.white,
              onSurface: _textColorPrimary,
            ),
            dialogBackgroundColor: _cardBackgroundColor,
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: _primaryColor),
            ),
          ),
          child: child!,
        );
      },
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
    final isWideScreen = MediaQuery.of(context).size.width > 600;
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              color: _primaryColor,
            ),
          ),
          title: Text(
            "AI Phân tích tài chính",
            style: TextStyle(
              fontSize: isWideScreen ? 22 : 20,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              fontFamily: 'Roboto',
            ),
          ),
        ),
        body: Container(
          color: _secondaryColor,
          child: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(isWideScreen ? 24.0 : 16.0),
                  child: ListView(
                    reverse: true,
                    physics: const BouncingScrollPhysics(),
                    children: [
                      if (appState.lastRecommendation.isEmpty && !isLoading)
                        Container(
                          margin: const EdgeInsets.symmetric(
                              vertical: 8, horizontal: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _cardBackgroundColor,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Text(
                            "Chào mừng bạn! Hãy nhập ngành nghề và chọn khoảng thời gian để nhận phân tích tài chính từ AI.",
                            style: TextStyle(
                                fontSize: 16, color: _textColorSecondary),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      if (isLoading)
                        Container(
                          margin: const EdgeInsets.symmetric(
                              vertical: 8, horizontal: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _cardBackgroundColor,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      _primaryColor)),
                              const SizedBox(width: 12),
                              Text(
                                "AI đang phân tích...",
                                style: TextStyle(
                                    fontSize: isWideScreen ? 16 : 14,
                                    color: _primaryColor,
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      if (appState.lastRecommendation.isNotEmpty && !isLoading)
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: Container(
                            margin: const EdgeInsets.symmetric(
                                vertical: 8, horizontal: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: _cardBackgroundColor,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  industry.isEmpty
                                      ? "Phân tích tài chính"
                                      : "Phân tích cho ngành $industry",
                                  style: TextStyle(
                                    fontSize: isWideScreen ? 18 : 16,
                                    fontWeight: FontWeight.bold,
                                    color: _primaryColor,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                SelectableText(
                                  appState.lastRecommendation,
                                  style: TextStyle(
                                    fontSize: isWideScreen ? 16 : 14,
                                    color: _textColorPrimary,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "Phân tích lúc: ${DateFormat('HH:mm, dd/MM/yyyy').format(DateTime.now())}",
                                  style: TextStyle(
                                      fontSize: 12, color: _textColorSecondary),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.all(isWideScreen ? 24.0 : 16.0),
                decoration: BoxDecoration(
                  color: _cardBackgroundColor,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Autocomplete<String>(
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        if (textEditingValue.text.isEmpty) {
                          return industrySuggestions;
                        }
                        return industrySuggestions.where((option) => option
                            .toLowerCase()
                            .contains(textEditingValue.text.toLowerCase()));
                      },
                      onSelected: (String selection) {
                        setState(() {
                          industry = selection;
                        });
                      },
                      fieldViewBuilder:
                          (context, controller, focusNode, onFieldSubmitted) {
                        return TextField(
                          controller: controller,
                          focusNode: focusNode,
                          decoration: InputDecoration(
                            hintText: "Nhập ngành nghề (ví dụ: Bán lẻ, F&B)",
                            filled: true,
                            fillColor: _secondaryColor,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            prefixIcon: const Icon(Icons.business,
                                color: _primaryColor),
                            hintStyle: TextStyle(
                                color: _textColorSecondary,
                                fontSize: isWideScreen ? 16 : 14),
                          ),
                          style: TextStyle(
                              fontSize: isWideScreen ? 16 : 14,
                              color: _textColorPrimary),
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
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _selectDateRange(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 14),
                              decoration: BoxDecoration(
                                color: _secondaryColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_today,
                                      color: _primaryColor,
                                      size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      selectedRange == null
                                          ? "7 ngày gần nhất"
                                          : "Từ ${DateFormat('dd/MM/yyyy').format(selectedRange!.start)} đến ${DateFormat('dd/MM/yyyy').format(selectedRange!.end)}",
                                      style: TextStyle(
                                          fontSize: isWideScreen ? 16 : 14,
                                          color: _textColorPrimary),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.refresh, color: _primaryColor),
                          onPressed: _resetInputs,
                          tooltip: "Xóa dữ liệu",
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ScaleTransition(
                      scale: _buttonScaleAnimation,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          minimumSize: const Size(double.infinity, 50),
                        ),
                        onPressed: industry.isEmpty
                            ? null
                            : () {
                          _controller.forward(from: 0);
                          getAnalysis();
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: _primaryColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          height: 50,
                          child: Text(
                            "Nhận phân tích từ A.I",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isWideScreen ? 16 : 14,
                              fontWeight: FontWeight.w600,
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
    );
  }
}