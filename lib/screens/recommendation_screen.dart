import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import '../state/app_state.dart';

class RecommendationScreen extends StatefulWidget {
  @override
  _RecommendationScreenState createState() => _RecommendationScreenState();
}

class _RecommendationScreenState extends State<RecommendationScreen> with SingleTickerProviderStateMixin {
  String recommendation = "Nhấn vào nút để nhận khuyến nghị từ A.I";
  bool isLoading = false;
  String industry = '';
  String selectedGoal = 'Tăng doanh thu';
  String goalValue = '';
  DateTimeRange? selectedRange;
  final List<String> goals = [
    'Tăng doanh thu',
    'Giảm chi phí',
    'Cải thiện biên lợi nhuận',
  ];
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
      final revenueData = await appState.getRevenueForRange(range);
      final expenseData = await appState.getExpensesForRange(range);
      final overview = await appState.getOverviewForRange(range);
      final topProducts = await appState.getTopProductsByCategory(range);
      final dailyRevenues = await appState.getDailyRevenueForRange(range);
      final dailyExpenses = await appState.getDailyExpensesForRange(range);

      double totalRevenue = revenueData['totalRevenue'] ?? 0.0;
      double mainRevenue = revenueData['mainRevenue'] ?? 0.0;
      double secondaryRevenue = revenueData['secondaryRevenue'] ?? 0.0;
      double otherRevenue = revenueData['otherRevenue'] ?? 0.0;

      Map<String, double> revenueShares = {
        'Doanh thu chính': totalRevenue > 0 ? (mainRevenue / totalRevenue * 100) : 0.0,
        'Doanh thu phụ': totalRevenue > 0 ? (secondaryRevenue / totalRevenue * 100) : 0.0,
        'Doanh thu khác': totalRevenue > 0 ? (otherRevenue / totalRevenue * 100) : 0.0,
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
          .map((day) => (day['totalRevenue'] ?? 0.0) as double)
          .toList();
      double revenueTrend = revenueValues.isNotEmpty
          ? ((revenueValues.last - revenueValues.first) / (revenueValues.first == 0 ? 1 : revenueValues.first) * 100)
          : 0.0;

      List<String> revenueAnomalies = [];
      if (revenueValues.isNotEmpty) {
        double revenueMean = revenueValues.reduce((a, b) => a + b) / revenueValues.length;
        double revenueStd = _calculateStandardDeviation(revenueValues);
        for (int i = 0; i < revenueValues.length; i++) {
          if ((revenueValues[i] - revenueMean).abs() > 2 * revenueStd) {
            String date = DateFormat('dd/MM').format(range.start.add(Duration(days: i)));
            revenueAnomalies.add(
                'Ngày $date: ${NumberFormat.currency(locale: 'vi_VN', symbol: '').format(revenueValues[i])} VNĐ (${revenueValues[i] > revenueMean ? "cao" : "thấp"} bất thường)');
          }
        }
      }

      double totalExpense = expenseData['totalExpense'] ?? 0.0;
      double fixedExpense = expenseData['fixedExpense'] ?? 0.0;
      double variableExpense = expenseData['variableExpense'] ?? 0.0;

      Map<String, double> expenseShares = {
        'Chi phí cố định': totalExpense > 0 ? (fixedExpense / totalExpense * 100) : 0.0,
        'Chi phí biến đổi': totalExpense > 0 ? (variableExpense / totalExpense * 100) : 0.0,
      };

      List<double> expenseValues = dailyExpenses
          .map((day) => (day['totalExpense'] ?? 0.0) as double)
          .toList();
      double expenseTrend = expenseValues.isNotEmpty
          ? ((expenseValues.last - expenseValues.first) / (expenseValues.first == 0 ? 1 : expenseValues.first) * 100)
          : 0.0;

      List<String> expenseAnomalies = [];
      if (expenseValues.isNotEmpty) {
        double expenseMean = expenseValues.reduce((a, b) => a + b) / expenseValues.length;
        double expenseStd = _calculateStandardDeviation(expenseValues);
        for (int i = 0; i < expenseValues.length; i++) {
          if ((expenseValues[i] - expenseMean).abs() > 2 * expenseStd) {
            String date = DateFormat('dd/MM').format(range.start.add(Duration(days: i)));
            expenseAnomalies.add(
                'Ngày $date: ${NumberFormat.currency(locale: 'vi_VN', symbol: '').format(expenseValues[i])} VNĐ (${expenseValues[i] > expenseMean ? "cao" : "thấp"} bất thường)');
          }
        }
      }

      double profit = overview['profit'] ?? 0.0;
      double profitMargin = overview['averageProfitMargin'] ?? 0.0;

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
        double revenue = entry.value['totalRevenue'] ?? 0.0;
        double expense = dailyExpenses[index]['totalExpense'] ?? 0.0;
        return revenue > 0 ? ((revenue - expense) / revenue * 100) : 0.0;
      })
          .toList();

      double profitMarginTrend = dailyProfits.isNotEmpty
          ? (dailyProfits.last - dailyProfits.first)
          : 0.0;

      List<String> profitMarginAnomalies = [];
      if (dailyProfits.isNotEmpty) {
        double profitMarginMean = dailyProfits.reduce((a, b) => a + b) / dailyProfits.length;
        double profitMarginStd = _calculateStandardDeviation(dailyProfits);
        for (int i = 0; i < dailyProfits.length; i++) {
          if ((dailyProfits[i] - profitMarginMean).abs() > 2 * profitMarginStd) {
            String date = DateFormat('dd/MM').format(range.start.add(Duration(days: i)));
            profitMarginAnomalies.add(
                'Ngày $date: ${dailyProfits[i].toStringAsFixed(1)}% (${dailyProfits[i] > profitMarginMean ? "cao" : "thấp"} bất thường)');
          }
        }
      }

      String report = '''Phân tích ${range.end.difference(range.start).inDays + 1} ngày gần nhất:
- Doanh thu: ${NumberFormat.currency(locale: 'vi_VN', symbol: '').format(totalRevenue)} VNĐ (chính: ${revenueShares['Doanh thu chính']!.toStringAsFixed(1)}%, phụ: ${revenueShares['Doanh thu phụ']!.toStringAsFixed(1)}%, khác: ${revenueShares['Doanh thu khác']!.toStringAsFixed(1)}%).
  Top sản phẩm:
  + Doanh thu chính: ${topProductsSummary['Doanh thu chính'] ?? 'Không có'}
  + Doanh thu phụ: ${topProductsSummary['Doanh thu phụ'] ?? 'Không có'}
  + Doanh thu khác: ${topProductsSummary['Doanh thu khác'] ?? 'Không có'}
  Xu hướng: ${revenueTrend >= 0 ? '+' : ''}${revenueTrend.toStringAsFixed(1)}% so với kỳ trước.
  Điểm bất thường: ${revenueAnomalies.isNotEmpty ? revenueAnomalies.join('; ') : 'Không có'}.
- Chi phí: ${NumberFormat.currency(locale: 'vi_VN', symbol: '').format(totalExpense)} VNĐ (cố định: ${expenseShares['Chi phí cố định']!.toStringAsFixed(1)}%, biến đổi: ${expenseShares['Chi phí biến đổi']!.toStringAsFixed(1)}%).
  Xu hướng: ${expenseTrend >= 0 ? '+' : ''}${expenseTrend.toStringAsFixed(1)}% so với kỳ trước.
  Điểm bất thường: ${expenseAnomalies.isNotEmpty ? expenseAnomalies.join('; ') : 'Không có'}.
- Lợi nhuận: ${NumberFormat.currency(locale: 'vi_VN', symbol: '').format(profit)} VNĐ, biên lợi nhuận: ${profitMargin.toStringAsFixed(1)}%.
  Biên lợi nhuận theo danh mục:
  + Doanh thu chính: ${categoryMargins['Doanh thu chính']!.toStringAsFixed(1)}%
  + Doanh thu phụ: ${categoryMargins['Doanh thu phụ']!.toStringAsFixed(1)}%
  + Doanh thu khác: ${categoryMargins['Doanh thu khác']!.toStringAsFixed(1)}%
  Xu hướng biên lợi nhuận: ${profitMarginTrend >= 0 ? '+' : ''}${profitMarginTrend.toStringAsFixed(1)}%.
  Điểm bất thường: ${profitMarginAnomalies.isNotEmpty ? profitMarginAnomalies.join('; ') : 'Không có'}.
- Ngành nghề: $industry.
${goalValue.isNotEmpty ? '- Mục tiêu: $selectedGoal $goalValue%.' : ''}''';

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

  Future<void> getRecommendation() async {
    setState(() {
      isLoading = true;
      recommendation = "Đang phân tích dữ liệu...";
    });
    try {
      final appState = Provider.of<AppState>(context, listen: false);
      final range = selectedRange ??
          DateTimeRange(
            start: DateTime.now().subtract(Duration(days: 30)),
            end: DateTime.now(),
          );
      final analysis = await _analyzeFinancialData(appState, range);
      String report = analysis['report'];

      String prompt = '''Bạn là chuyên gia tài chính trong ngành $industry. Dưới đây là phân tích dữ liệu kinh doanh:
$report
Hãy phân tích và đề xuất:
1. Hai chiến lược tăng doanh thu dựa trên sản phẩm chủ lực và xu hướng.
2. Một cách giảm chi phí dựa trên điểm bất thường hoặc khoản chi lớn.
3. Một chiến lược cải thiện biên lợi nhuận${goalValue.isNotEmpty ? ', hướng đến mục tiêu: $selectedGoal $goalValue%' : ''}.
Mỗi khuyến nghị cần lý do, ví dụ thực tế, và phù hợp với ngành $industry.''';

      var response = await http.post(
        Uri.parse("https://api.openai.com/v1/chat/completions"),
        headers: {
          "Authorization": "Bearer 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",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "model": "gpt-4.1",
          "messages": [
            {"role": "system", "content": "Bạn là chuyên gia tài chính."},
            {"role": "user", "content": prompt}
          ],
          "temperature": 0.7,
          "max_tokens": 2000,
        }),
      );

      if (response.statusCode == 200) {
        var responseData = jsonDecode(utf8.decode(response.bodyBytes));
        String aiResponse = responseData["choices"][0]["message"]["content"];
        setState(() {
          recommendation = "🤖 AI khuyến nghị:\n\n$aiResponse";
          isLoading = false;
        });
      } else {
        print('Lỗi gọi API OpenAI: Status ${response.statusCode}');
        print('Phản hồi: ${response.body}');
        setState(() {
          recommendation = "❌ Không thể nhận khuyến nghị. Mã lỗi: ${response.statusCode}. Vui lòng thử lại.";
          isLoading = false;
        });
      }
    } catch (e) {
      print('Ngoại lệ khi gọi API: $e');
      setState(() {
        recommendation = "❌ Đã xảy ra lỗi: $e. Vui lòng thử lại.";
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
            start: DateTime.now().subtract(Duration(days: 30)),
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
      selectedGoal = 'Tăng doanh thu';
      goalValue = '';
      selectedRange = null;
      recommendation = "Nhấn vào nút để nhận khuyến nghị từ A.I";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1976D2),
        title: Text(
          "Khuyến nghị từ A.I",
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
                  ? "30 ngày gần nhất"
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
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  DropdownButtonFormField<String>(
                                    value: selectedGoal,
                                    decoration: InputDecoration(
                                      labelText: "Mục tiêu",
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                      isDense: true,
                                    ),
                                    items: goals
                                        .map((goal) => DropdownMenuItem(
                                      value: goal,
                                      child: Text(goal, overflow: TextOverflow.ellipsis),
                                    ))
                                        .toList(),
                                    onChanged: (value) {
                                      setState(() {
                                        selectedGoal = value!;
                                      });
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: 120, // Slightly wider for better visibility
                                    child: TextField(
                                      decoration: InputDecoration(
                                        labelText: "Mục tiêu (%)",
                                        hintText: "Nhập số % (ví dụ: 10)",
                                        suffixText: '%',
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                        isDense: true,
                                      ),
                                      keyboardType: TextInputType.number,
                                      onChanged: (value) {
                                        setState(() {
                                          goalValue = value;
                                        });
                                      },
                                      maxLines: 1,
                                      maxLength: 5,
                                    ),
                                  ),
                                ],
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
                                            ? "Khoảng thời gian: 30 ngày gần nhất"
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
                                          getRecommendation();
                                        },
                                        child: Text(
                                          "Nhận khuyến nghị từ A.I",
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
                                industry.isEmpty ? "Kết quả khuyến nghị" : "Khuyến nghị cho ngành $industry",
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
                                      recommendation,
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
    );
  }
}