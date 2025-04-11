import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../state/app_state.dart';

class RecommendationScreen extends StatefulWidget {
  @override
  _RecommendationScreenState createState() => _RecommendationScreenState();
}

class _RecommendationScreenState extends State<RecommendationScreen> {
  String recommendation = "Nhấn vào nút để nhận khuyến nghị từ A.I";
  bool isLoading = false;

  Future<void> getRecommendation() async {
    setState(() {
      isLoading = true;
      recommendation = "Đang phân tích dữ liệu...";
    });

    try {
      final appState = Provider.of<AppState>(context, listen: false);
      double revenue = appState.getTotalRevenue();
      double expense = appState.getTotalFixedAndVariableExpense();
      double profit = appState.getProfit();
      double profitMargin = appState.getProfitMargin();

      String prompt = """
      Tôi đang kinh doanh và có dữ liệu tài chính sau:
      - Doanh thu: $revenue
      - Chi phí: $expense
      - Lợi nhuận: $profit
      - Biên lợi nhuận: $profitMargin%

      Hãy phân tích dữ liệu này và đề xuất chiến lược kinh doanh giúp tôi cải thiện lợi nhuận và tối ưu chi phí.
      """;

      var response = await http.post(
        Uri.parse("https://api.openai.com/v1/chat/completions"),
        headers: {
          "Authorization": "Bearer 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", // 🔹 Cập nhật API Key
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "model": "gpt-3.5-turbo",
          "messages": [
            {"role": "system", "content": "Bạn là chuyên gia tài chính."},
            {"role": "user", "content": prompt}
          ],
          "temperature": 0.7,
          "max_tokens": 500,  // 🔹 Tăng max_tokens nếu cần
        }),
      );

      if (response.statusCode == 200) {
        var responseData = jsonDecode(utf8.decode(response.bodyBytes)); // ✅ Đảm bảo UTF-8
        String aiResponse = responseData["choices"][0]["message"]["content"];

        setState(() {
          recommendation = "🤖 AI khuyến nghị:\n\n$aiResponse";
          isLoading = false;
        });
      } else {
        var errorData = jsonDecode(utf8.decode(response.bodyBytes)); // ✅ Đảm bảo UTF-8
        setState(() {
          recommendation = "❌ Lỗi: ${errorData['error']['message']}";
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        recommendation = "❌ Đã xảy ra lỗi: $e";
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Khuyến nghị từ A.I")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              "A.I sẽ phân tích dữ liệu tài chính và đề xuất chiến lược kinh doanh.",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: SingleChildScrollView(
                physics: BouncingScrollPhysics(), // ✅ Giúp cuộn mượt mà
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : SelectableText( // ✅ Cho phép copy nội dung
                  recommendation,
                  textAlign: TextAlign.left,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: getRecommendation,
              child: const Text("Xem khuyến nghị từ A.I"),
            ),
          ],
        ),
      ),
    );
  }
}

