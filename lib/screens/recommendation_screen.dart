import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fingrowth/screens/report_screen.dart';
import 'package:fingrowth/screens/subscription_screen.dart';
import 'package:fingrowth/screens/subscription_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import '../state/app_state.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class AnalysisScreen extends StatefulWidget {
  @override
  _AnalysisScreenState createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen>
    with SingleTickerProviderStateMixin {

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
      final productProfitability = await appState.getProductProfitability(range);
      final revenueData = await appState.getRevenueForRange(range);
      final expenseData = await appState.getExpensesForRange(range);
      final overview = await appState.getOverviewForRange(range);
      final topProducts = await appState.getTopProductsByCategory(range);
      final dailyRevenuesData = await appState.getDailyRevenueWithDetailsForRange(range);
      final dailyExpensesData = await appState.getDailyExpensesWithDetailsForRange(range);
      // Renamed for clarity
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

      double profitMarginChangePoints = profitMargin - prevProfitMargin;

      // Xử lý so sánh doanh thu kỳ này vs kỳ trước (Cách số 3 đã làm trước đó)
      double absoluteRevenueChange = totalRevenue - prevTotalRevenue;
      String revenueComparisonReportText;
      String expenseComparisonReportText;
      String profitComparisonReportText;
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

      double absoluteExpenseChange = totalExpense - prevTotalExpense;
      if (prevTotalExpense == 0) {
        if (totalExpense > 0) {
          expenseComparisonReportText = "tăng ${NumberFormat.currency(locale: 'vi_VN', symbol: '').format(absoluteExpenseChange)} VNĐ (kỳ trước không có chi phí).";
        } else {
          expenseComparisonReportText = "vẫn là 0 VNĐ, không có thay đổi.";
        }
      } else {
        double expenseChangePercentage = (absoluteExpenseChange / prevTotalExpense.abs()) * 100;
        expenseComparisonReportText = "${absoluteExpenseChange >= 0 ? 'tăng' : 'giảm'} ${NumberFormat.currency(locale: 'vi_VN', symbol: '').format(absoluteExpenseChange.abs())} VNĐ (tương đương ${expenseChangePercentage >= 0 ? '+' : ''}${expenseChangePercentage.toStringAsFixed(1)}%) so với kỳ trước.";
      }

      double absoluteProfitChange = profit - prevProfit;
      if (prevProfit == 0) {
        if (profit > 0) {
          profitComparisonReportText = "tăng ${NumberFormat.currency(locale: 'vi_VN', symbol: '').format(absoluteProfitChange)} VNĐ (kỳ trước lợi nhuận là 0).";
        } else if (profit < 0) {
          profitComparisonReportText = "giảm ${NumberFormat.currency(locale: 'vi_VN', symbol: '').format(absoluteProfitChange.abs())} VNĐ (kỳ trước lợi nhuận là 0).";
        } else {
          profitComparisonReportText = "vẫn là 0 VNĐ, không có thay đổi.";
        }
      } else {
        double profitChangePercentage = (absoluteProfitChange / prevProfit.abs()) * 100;
        profitComparisonReportText = "${absoluteProfitChange >= 0 ? 'tăng' : 'giảm'} ${NumberFormat.currency(locale: 'vi_VN', symbol: '').format(absoluteProfitChange.abs())} VNĐ (tương đương ${profitChangePercentage >= 0 ? '+' : ''}${profitChangePercentage.toStringAsFixed(1)}%) so với kỳ trước.";
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

      // Thay thế logic phát hiện bất thường doanh thu cũ bằng đoạn này
      List<String> revenueAnomalies = [];
      List<String> revenueAnomalyDetails = [];

      if (revenueValues.isNotEmpty) {
        double revenueMean = revenueValues.reduce((a, b) => a + b) / revenueValues.length; //
        double revenueStd = _calculateStandardDeviation(revenueValues); //

        for (int i = 0; i < revenueValues.length; i++) {
          if ((revenueValues[i] - revenueMean).abs() > 2 * revenueStd) { //
            String date = DateFormat('dd/MM').format(range.start.add(Duration(days: i)));
            revenueAnomalies.add(
                'Ngày $date: ${NumberFormat.currency(locale: 'vi_VN', symbol: '').format(revenueValues[i])} VNĐ (${revenueValues[i] > revenueMean ? "cao" : "thấp"} bất thường)');

            // **Phần thêm mới để phân tích chi tiết**
            List<Map<String, dynamic>> dailyTransactions = List<Map<String, dynamic>>.from(dailyRevenuesData[i]['transactions'] ?? []);
            if (dailyTransactions.isNotEmpty) {
              // **BẮT ĐẦU THAY ĐỔI: Gộp các giao dịch cùng tên**
              final Map<String, double> aggregatedAmounts = {};
              for (var transaction in dailyTransactions) {
                final name = transaction['name']?.toString() ?? 'Không xác định';
                final total = (transaction['total'] as num?)?.toDouble() ?? 0.0;
                // Cộng dồn giá trị cho mỗi sản phẩm
                aggregatedAmounts[name] = (aggregatedAmounts[name] ?? 0) + total;
              }

              // Chuyển Map thành List để sắp xếp dựa trên tổng giá trị đã gộp
              final sortedContributors = aggregatedAmounts.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value));

              if (sortedContributors.isNotEmpty) {
                final topContributor = sortedContributors.first;
                revenueAnomalyDetails.add(
                    'Ngày $date ${revenueValues[i] > revenueMean ? "tăng" : "giảm"} đột biến, chủ yếu do sản phẩm "${topContributor.key}" đóng góp tổng cộng ${NumberFormat.currency(locale: 'vi_VN', symbol: '').format(topContributor.value)} VNĐ.'
                );
              }
            }
          }
        }
      }


      // Thay thế logic phát hiện bất thường chi phí cũ bằng đoạn này
      List<String> expenseAnomalies = [];
      List<String> expenseAnomalyDetails = [];

      if (expenseValues.isNotEmpty) {
        double expenseMean = expenseValues.reduce((a, b) => a + b) / expenseValues.length; //
        double expenseStd = _calculateStandardDeviation(expenseValues); //

        for (int i = 0; i < expenseValues.length; i++) {
          if ((expenseValues[i] - expenseMean).abs() > 2 * expenseStd) { //
            String date = DateFormat('dd/MM').format(range.start.add(Duration(days: i)));
            expenseAnomalies.add(
                'Ngày $date: ${NumberFormat.currency(locale: 'vi_VN', symbol: '').format(expenseValues[i])} VNĐ (${expenseValues[i] > expenseMean ? "cao" : "thấp"} bất thường)');

            // **Phần thêm mới để phân tích chi tiết**
            List<Map<String, dynamic>> dailyTransactions = List<Map<String, dynamic>>.from(dailyExpensesData[i]['transactions'] ?? []);
            if (dailyTransactions.isNotEmpty) {
              // **BẮT ĐẦU THAY ĐỔI: Gộp các giao dịch cùng tên**
              final Map<String, double> aggregatedAmounts = {};
              for (var transaction in dailyTransactions) {
                final name = transaction['name']?.toString() ?? 'Không xác định';
                // Chú ý key là 'amount' cho chi phí
                final amount = (transaction['amount'] as num?)?.toDouble() ?? 0.0;
                // Cộng dồn giá trị cho mỗi khoản mục chi phí
                aggregatedAmounts[name] = (aggregatedAmounts[name] ?? 0) + amount;
              }

              // Chuyển Map thành List để sắp xếp dựa trên tổng giá trị đã gộp
              final sortedContributors = aggregatedAmounts.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value));

              if (sortedContributors.isNotEmpty) {
                final topContributor = sortedContributors.first;
                expenseAnomalyDetails.add(
                    'Ngày $date ${expenseValues[i] > expenseMean ? "tăng" : "giảm"} đột biến, chủ yếu do khoản chi "${topContributor.key}" đóng góp tổng cộng ${NumberFormat.currency(locale: 'vi_VN', symbol: '').format(topContributor.value)} VNĐ.'
                );
              }
            }
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


      double contributionMargin = totalRevenue - variableExpense; // Lợi nhuận góp
      double contributionMarginRatio = totalRevenue > 0 ? (contributionMargin / totalRevenue) : 0.0; // Tỷ lệ lợi nhuận góp


      double breakEvenRevenue = contributionMarginRatio > 0 ? (fixedExpense / contributionMarginRatio) : 0.0;

      double safetyMargin = totalRevenue - breakEvenRevenue;
      String breakEvenAnalysisReport = '''
6. PHÂN TÍCH ĐIỂM HÒA VỐN:
   - Doanh thu hòa vốn cần đạt: ${NumberFormat.currency(locale: 'vi_VN', symbol: '').format(breakEvenRevenue)} VNĐ.
   - Tình hình hiện tại: ${totalRevenue >= breakEvenRevenue
          ? 'Chúc mừng! Bạn đã VƯỢT điểm hòa vốn. Vùng an toàn hiện tại là ${NumberFormat.currency(locale: 'vi_VN', symbol: '').format(safetyMargin)} VNĐ.'
          : 'Cần cố gắng! Bạn cần thêm ${NumberFormat.currency(locale: 'vi_VN', symbol: '').format(breakEvenRevenue - totalRevenue)} VNĐ doanh thu để đạt điểm hòa vốn.'}
''';


// Sắp xếp sản phẩm theo lợi nhuận giảm dần
      final sortedProductsByProfit = productProfitability.entries.toList()
        ..sort((a, b) => (b.value['totalProfit'] ?? 0).compareTo(a.value['totalProfit'] ?? 0));

// Format thành chuỗi để đưa vào prompt, lấy top 5 sản phẩm
      String productProfitabilitySummary = sortedProductsByProfit.take(5).map((entry) {
        String name = entry.key;
        double profit = entry.value['totalProfit'] ?? 0.0;
        double margin = entry.value['profitMargin'] ?? 0.0;
        return '$name (Lợi nhuận: ${NumberFormat.currency(locale: 'vi_VN', symbol: '').format(profit)} VNĐ, Biên LN: ${margin.toStringAsFixed(1)}%)';
      }).join('; ');

// Tạo một chuỗi báo cáo riêng cho phần này
      String productProfitabilityReport = '''
5. PHÂN TÍCH HIỆU SUẤT SẢN PHẨM:
   - Top 5 sản phẩm lợi nhuận cao nhất: ${productProfitabilitySummary.isNotEmpty ? productProfitabilitySummary : 'Không có dữ liệu'}.
''';

      String expenseBreakdownSummary = expenseBreakdown.entries
          .map((e) =>
      '${e.key}: ${NumberFormat.currency(locale: 'vi_VN', symbol: '').format(e.value)} VNĐ')
          .join(', ');
      String productRevenueSummary = productRevenueBreakdown.entries
          .map((e) => '${e.key}: ${e.value.toStringAsFixed(1)}%')
          .join(', ');


      String report =
      '''Phân tích ${daysInPeriod} ngày gần nhất (${DateFormat('dd/MM/yyyy').format(range.start)} - ${DateFormat('dd/MM/yyyy').format(range.end)}):
So sánh với kỳ trước (${DateFormat('dd/MM/yyyy').format(previousRange.start)} - ${DateFormat('dd/MM/yyyy').format(previousRange.end)}):
- Doanh thu tổng: $revenueComparisonReportText
- Chi phí tổng: $expenseComparisonReportText
- Lợi nhuận tổng: $profitComparisonReportText
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
   - Xu hướng biên lợi nhuận (hồi quy): $overallProfitMarginTrendDescription
   - Điểm bất thường biên Lợi Nhuận: ${profitMarginAnomalies.isNotEmpty ? profitMarginAnomalies.join('; ') : 'Không có'}.

4. PHÂN BỔ DOANH THU SẢN PHẨM (toàn kỳ): ${productRevenueSummary.isNotEmpty ? productRevenueSummary : 'Không có'}.
Ngành nghề kinh doanh: $industry.
${productProfitabilityReport}
${breakEvenAnalysisReport}
''';

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
      '''Bạn là chuyên gia tài chính trong ngành $industry.Dưới đây là phân tích dữ liệu kinh doanh:

$report

Hãy cung cấp một báo cáo phân tích chuyên sâu, bao gồm các phần sau:

1.  **Tổng quan hiệu suất kinh doanh:** Tóm tắt doanh thu, chi phí, lợi nhuận, và các thay đổi so với kỳ trước. Giải thích ngắn gọn ý nghĩa của các chỉ số này trong ngành $industry.

2.  **Phân tích Xu hướng (Hồi quy tuyến tính):**
    * **Dựa vào 'Xu hướng doanh thu (hồi quy)':** Hãy nhận xét về tốc độ tăng trưởng hoặc suy giảm. Xu hướng này có tốt và bền vững không? Nếu đang tăng trưởng, gợi ý cách để duy trì đà tăng. Nếu đang suy giảm, chỉ ra các nguyên nhân có thể và đề xuất hướng khắc phục.
    * **Dựa vào 'Xu hướng chi phí (hồi quy)':** Hãy đánh giá việc kiểm soát chi phí. Tốc độ tăng của chi phí đang nhanh hơn hay chậm hơn doanh thu? Điều này nói lên điều gì về hiệu quả hoạt động của doanh nghiệp?
    * **Dựa vào 'Xu hướng biên lợi nhuận (hồi quy)':** Bình luận về sự thay đổi trong khả năng sinh lời theo thời gian. Xu hướng này có bền vững không và yếu tố nào có thể đang tác động đến nó (ví dụ: thay đổi cơ cấu sản phẩm bán ra, chính sách giá, việc kiểm soát chi phí biến đổi)?

3.  **Phân tích Cấu trúc Chi phí:**
    * **Dựa vào mục "Phân bổ chi phí" trong báo cáo**, hãy liệt kê và phân tích các khoản mục chi phí lớn nhất.
    * Đánh giá xem cơ cấu chi phí này (tỷ trọng của từng khoản mục) có hợp lý và phù hợp với đặc thù của ngành kinh doanh "$industry" hay không.
    * Chỉ ra những khoản mục chi phí có tỷ trọng cao bất thường hoặc có thể tối ưu.

4.  **Phân tích điểm bất thường:**
    * Doanh thu: Giải thích lý do có những ngày doanh thu tăng/giảm đột biến (nếu có).
    * Chi phí: Xác định nguyên nhân có những ngày chi phí tăng/giảm đột biến (nếu có).

5.  **Phân tích Hiệu suất Sản phẩm:**
    * **Dựa trên báo cáo "PHÂN TÍCH HIỆU SUẤT SẢN PHẨM"**, hãy xác định các sản phẩm "Ngôi sao" (lợi nhuận cao) và sản phẩm "Cần cải thiện" (lợi nhuận thấp hoặc âm).
    * Đưa ra gợi ý chiến lược cụ thể cho các nhóm sản phẩm này (ví dụ: nên tập trung marketing cho sản phẩm nào, nên xem xét lại giá bán hoặc chi phí của sản phẩm nào).

6.  **Phân tích Điểm hòa vốn:**
    * **Dựa trên báo cáo "PHÂN TÍCH ĐIỂM HÒA VỐN"**, hãy giải thích ý nghĩa của con số "Doanh thu hòa vốn" đối với doanh nghiệp.
    * Đánh giá "Tình hình hiện tại" và đưa ra lời khuyên. Nếu chưa đạt điểm hòa vốn, hãy gợi ý những hành động cụ thể để có thể đạt được.

Mỗi phần cần chi tiết, sử dụng dữ liệu từ báo cáo, đưa ra ví dụ thực tế, và phù hợp với ngành $industry.''';
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken == null) {
        appState.setLastRecommendation(
            "  ❌   Bạn chưa đăng nhập. Vui lòng đăng nhập để sử dụng A.I.");
        if (mounted) {
          setState(() {
            isLoading = false;
          });
        }
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
        if (mounted) {
          setState(() {
            isLoading = false;
          });
        }
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
    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
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
          // SỬA Ở ĐÂY: Bắt đầu từ theme hiện tại của context
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppColors.primaryBlue, // Màu chính cho vùng ngày được chọn
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
    final subscriptionService = context.watch<SubscriptionService>();
    final appState = context.read<AppState>();

    // <<< KIỂM TRA TRẠNG THÁI PREMIUM NGAY TỪ ĐẦU >>>
    if (!appState.isSubscribed) {
      // Nếu không phải Premium, hiển thị giao diện "Paywall"
      return _buildPaywallWidget();
    }

    // --- NẾU LÀ PREMIUM USER, HIỂN THỊ NỘI DUNG GỐC CỦA MÀN HÌNH ---
    // Toàn bộ code giao diện gốc của bạn được đặt ở đây
    final isWideScreen = MediaQuery.of(context).size.width > 600;
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              color: AppColors.primaryBlue,
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
          color: AppColors.getBackgroundColor(context),
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
                            color: AppColors.getCardColor(context),
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
                                fontSize: 16, color: AppColors.getTextSecondaryColor(context)),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      if (isLoading)
                        Container(
                          margin: const EdgeInsets.symmetric(
                              vertical: 8, horizontal: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.getCardColor(context),
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
                                      AppColors.primaryBlue)),
                              const SizedBox(width: 12),
                              Text(
                                "AI đang phân tích...",
                                style: TextStyle(
                                    fontSize: isWideScreen ? 16 : 14,
                                    color: AppColors.primaryBlue,
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
                              color: AppColors.getCardColor(context),
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
                                    color: AppColors.primaryBlue,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                MarkdownBody(
                                  data: appState.lastRecommendation,
                                  selectable: true, // Giữ lại tính năng cho phép người dùng chọn/sao chép văn bản
                                  styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                                    p: TextStyle( // 'p' là viết tắt của paragraph, tương đương với style cũ của bạn
                                      fontSize: isWideScreen ? 16 : 14,
                                      color: AppColors.getTextColor(context),
                                      height: 1.4,
                                    ),
                                    // Bạn cũng có thể tùy chỉnh style cho các thẻ khác như h1, h2, strong (in đậm)...
                                    h2: TextStyle(
                                      fontSize: isWideScreen ? 20 : 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primaryBlue, // Sử dụng màu primary cho tiêu đề
                                    ),
                                    strong: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "Phân tích lúc: ${DateFormat('HH:mm, dd/MM/yyyy').format(DateTime.now())}",
                                  style: TextStyle(
                                      fontSize: 12, color: AppColors.getTextSecondaryColor(context)),
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
                  color: AppColors.getCardColor(context),
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
                            fillColor: AppColors.getBackgroundColor(context),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            prefixIcon: const Icon(Icons.business,
                                color: AppColors.primaryBlue),
                            hintStyle: TextStyle(
                                color: AppColors.getTextSecondaryColor(context),
                                fontSize: isWideScreen ? 16 : 14),
                          ),
                          style: TextStyle(
                              fontSize: isWideScreen ? 16 : 14,
                              color: AppColors.getTextColor(context)),
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
                                color: AppColors.getBackgroundColor(context) ,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_today,
                                      color: AppColors.primaryBlue,
                                      size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      selectedRange == null
                                          ? "7 ngày gần nhất"
                                          : "Từ ${DateFormat('dd/MM/yyyy').format(selectedRange!.start)} đến ${DateFormat('dd/MM/yyyy').format(selectedRange!.end)}",
                                      style: TextStyle(
                                          fontSize: isWideScreen ? 16 : 14,
                                          color: AppColors.getTextColor(context)),
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
                          icon: const Icon(Icons.refresh, color: AppColors.primaryBlue),
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
                            color: AppColors.primaryBlue,
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
  Widget _buildPaywallWidget() {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Tính Năng Premium"),
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
      ),
      backgroundColor: AppColors.getBackgroundColor(context),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.workspace_premium_outlined, size: 80, color: Colors.amber[700]),
              const SizedBox(height: 20),
              Text(
                "Mở Khóa Phân Tích Tài Chính Cùng AI",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.getTextColor(context),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "Nâng cấp lên Premium để nhận các phân tích sâu sắc, dự báo xu hướng và những khuyến nghị chiến lược được cá nhân hóa cho doanh nghiệp của bạn.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.getTextSecondaryColor(context),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () {
                  // Điều hướng tới màn hình thanh toán
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionScreen()));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("Nâng Cấp Ngay", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              )
            ],
          ),
        ),
      ),
    );
  }
}