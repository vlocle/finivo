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

class _RecommendationScreenState extends State<RecommendationScreen> {
  String recommendation = "Nhấn vào nút để nhận khuyến nghị từ A.I";
  bool isLoading = false;
  String industry = ''; // Ngành nghề
  String selectedGoal = 'Tăng doanh thu'; // Mục tiêu mặc định
  String goalValue = ''; // Giá trị mục tiêu (ví dụ: 20%)
  DateTimeRange? selectedRange; // Khoảng thời gian

  // Danh sách mục tiêu cho dropdown
  final List<String> goals = [
    'Tăng doanh thu',
    'Giảm chi phí',
    'Cải thiện biên lợi nhuận',
  ];

  // Gợi ý ngành nghề
  final List<String> industrySuggestions = [
    'Bán lẻ',
    'F&B',
    'Dịch vụ',
    'Sản xuất',
    'Khác',
  ];

  // Hàm tính độ lệch chuẩn
  double _calculateStandardDeviation(List<double> values) {
    if (values.isEmpty) return 0.0;
    double mean = values.reduce((a, b) => a + b) / values.length;
    double variance = values
        .map((x) => (x - mean) * (x - mean))
        .reduce((a, b) => a + b) /
        values.length;
    return math.sqrt(variance);
  }

  // Hàm phân tích dữ liệu tài chính
  Future<Map<String, dynamic>> _analyzeFinancialData(
      AppState appState, DateTimeRange range) async {
    try {
      // Lấy dữ liệu
      final revenueData = await appState.getRevenueForRange(range);
      final expenseData = await appState.getExpensesForRange(range);
      final overview = await appState.getOverviewForRange(range);
      final topProducts = await appState.getTopProductsByCategory(range);
      final dailyRevenues = await appState.getDailyRevenueForRange(range);
      final dailyExpenses = await appState.getDailyExpensesForRange(range);

      // Doanh thu
      double totalRevenue = revenueData['totalRevenue'] ?? 0.0;
      double mainRevenue = revenueData['mainRevenue'] ?? 0.0;
      double secondaryRevenue = revenueData['secondaryRevenue'] ?? 0.0;
      double otherRevenue = revenueData['otherRevenue'] ?? 0.0;

      // Tỷ trọng doanh thu
      Map<String, double> revenueShares = {
        'Doanh thu chính': totalRevenue > 0 ? (mainRevenue / totalRevenue * 100) : 0.0,
        'Doanh thu phụ': totalRevenue > 0 ? (secondaryRevenue / totalRevenue * 100) : 0.0,
        'Doanh thu khác': totalRevenue > 0 ? (otherRevenue / totalRevenue * 100) : 0.0,
      };

      // Top sản phẩm
      Map<String, String> topProductsSummary = {};
      topProducts.forEach((category, products) {
        List<MapEntry<String, double>> sortedProducts = products.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        topProductsSummary[category] = sortedProducts
            .take(2)
            .map((e) => '${e.key} (${NumberFormat.currency(locale: 'vi_VN', symbol: '').format(e.value)} VNĐ)')
            .join(', ');
      });

      // Xu hướng doanh thu
      List<double> revenueValues = dailyRevenues
          .map((day) => (day['totalRevenue'] ?? 0.0) as double)
          .toList();
      double revenueTrend = revenueValues.isNotEmpty
          ? ((revenueValues.last - revenueValues.first) / (revenueValues.first == 0 ? 1 : revenueValues.first) * 100)
          : 0.0;

      // Điểm bất thường doanh thu
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

      // Chi phí
      double totalExpense = expenseData['totalExpense'] ?? 0.0;
      double fixedExpense = expenseData['fixedExpense'] ?? 0.0;
      double variableExpense = expenseData['variableExpense'] ?? 0.0;

      // Tỷ trọng chi phí
      Map<String, double> expenseShares = {
        'Chi phí cố định': totalExpense > 0 ? (fixedExpense / totalExpense * 100) : 0.0,
        'Chi phí biến đổi': totalExpense > 0 ? (variableExpense / totalExpense * 100) : 0.0,
      };

      // Xu hướng chi phí
      List<double> expenseValues = dailyExpenses
          .map((day) => (day['totalExpense'] ?? 0.0) as double)
          .toList();
      double expenseTrend = expenseValues.isNotEmpty
          ? ((expenseValues.last - expenseValues.first) / (expenseValues.first == 0 ? 1 : expenseValues.first) * 100)
          : 0.0;

      // Điểm bất thường chi phí
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

      // Lợi nhuận
      double profit = overview['profit'] ?? 0.0;
      double profitMargin = overview['averageProfitMargin'] ?? 0.0;

      // Ước tính lợi nhuận theo danh mục (giả định chi phí biến đổi phân bổ theo doanh thu)
      Map<String, double> categoryProfits = {
        'Doanh thu chính': mainRevenue - (variableExpense * (mainRevenue / (totalRevenue == 0 ? 1 : totalRevenue))),
        'Doanh thu phụ': secondaryRevenue - (variableExpense * (secondaryRevenue / (totalRevenue == 0 ? 1 : totalRevenue))),
        'Doanh thu khác': otherRevenue - (variableExpense * (otherRevenue / (totalRevenue == 0 ? 1 : totalRevenue))),
      };

      // Biên lợi nhuận theo danh mục
      Map<String, double> categoryMargins = {
        'Doanh thu chính': mainRevenue > 0 ? (categoryProfits['Doanh thu chính']! / mainRevenue * 100) : 0.0,
        'Doanh thu phụ': secondaryRevenue > 0 ? (categoryProfits['Doanh thu phụ']! / secondaryRevenue * 100) : 0.0,
        'Doanh thu khác': otherRevenue > 0 ? (categoryProfits['Doanh thu khác']! / otherRevenue * 100) : 0.0,
      };

      // Xu hướng biên lợi nhuận
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

      // Điểm bất thường biên lợi nhuận
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

      // Tổng hợp báo cáo
      String report = '''
Phân tích ${range.end.difference(range.start).inDays + 1} ngày gần nhất:
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
${goalValue.isNotEmpty ? '- Mục tiêu: $selectedGoal $goalValue%.' : ''}
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

  // Hàm gọi API AI
  Future<void> getRecommendation() async {
    setState(() {
      isLoading = true;
      recommendation = "Đang phân tích dữ liệu...";
    });

    try {
      final appState = Provider.of<AppState>(context, listen: false);

      // Xác định khoảng thời gian
      final range = selectedRange ??
          DateTimeRange(
            start: DateTime.now().subtract(Duration(days: 30)),
            end: DateTime.now(),
          );

      // Phân tích dữ liệu
      final analysis = await _analyzeFinancialData(appState, range);
      String report = analysis['report'];

      // Tạo prompt
      String prompt = '''
Bạn là chuyên gia tài chính trong ngành $industry. Dưới đây là phân tích dữ liệu kinh doanh:

$report

Hãy phân tích và đề xuất:
1. Hai chiến lược tăng doanh thu dựa trên sản phẩm chủ lực và xu hướng.
2. Một cách giảm chi phí dựa trên điểm bất thường hoặc khoản chi lớn.
3. Một chiến lược cải thiện biên lợi nhuận${goalValue.isNotEmpty ? ', hướng đến mục tiêu: $selectedGoal $goalValue' : ''}.
Mỗi khuyến nghị cần lý do, ví dụ thực tế, và phù hợp với ngành $industry.
''';

      // Gọi API OpenAI
      var response = await http.post(
        Uri.parse("https://api.openai.com/v1/chat/completions"),
        headers: {
          "Authorization": "Bearer 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", // Đảm bảo thay API Key
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
        // Ghi log chi tiết lỗi
        print('Lỗi gọi API OpenAI: Status ${response.statusCode}');
        print('Phản hồi: ${response.body}');
        setState(() {
          recommendation = "❌ Không thể nhận khuyến nghị. Mã lỗi: ${response.statusCode}. Vui lòng thử lại.";
          isLoading = false;
        });
      }
    } catch (e) {
      // Ghi log lỗi ngoại lệ
      print('Ngoại lệ khi gọi API: $e');
      setState(() {
        recommendation = "❌ Đã xảy ra lỗi: $e. Vui lòng thử lại.";
        isLoading = false;
      });
    }
  }

  // Hàm chọn khoảng thời gian
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Khuyến nghị từ A.I")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Nhập thông tin để nhận khuyến nghị tài chính chi tiết:",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              // Ngành nghề
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
                    decoration: const InputDecoration(
                      labelText: "Ngành nghề (ví dụ: Bán lẻ, F&B)",
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setState(() {
                        industry = value;
                      });
                    },
                  );
                },
              ),
              const SizedBox(height: 16),
              // Mục tiêu
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: selectedGoal,
                      decoration: const InputDecoration(
                        labelText: "Mục tiêu",
                        border: OutlineInputBorder(),
                      ),
                      items: goals
                          .map((goal) => DropdownMenuItem(
                        value: goal,
                        child: Text(goal),
                      ))
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedGoal = value!;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 100,
                    child: TextField(
                      decoration: const InputDecoration(
                        labelText: "Giá trị (%)",
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        setState(() {
                          goalValue = value;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Khoảng thời gian
              Row(
                children: [
                  Expanded(
                    child: Text(
                      selectedRange == null
                          ? "Khoảng thời gian: 30 ngày gần nhất"
                          : "Từ ${DateFormat('dd/MM/yyyy').format(selectedRange!.start)} đến ${DateFormat('dd/MM/yyyy').format(selectedRange!.end)}",
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: () => _selectDateRange(context),
                    tooltip: "Chọn khoảng thời gian",
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 20),
              // Kết quả
              isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SelectableText(
                recommendation,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 20),
              // Nút nhận khuyến nghị
              Center(
                child: ElevatedButton(
                  onPressed: industry.isEmpty
                      ? null
                      : getRecommendation,
                  child: const Text("Nhận khuyến nghị từ A.I"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}