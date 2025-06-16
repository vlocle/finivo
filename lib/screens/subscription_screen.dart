import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../screens/subscription_service.dart'; // Import service của bạn
import 'package:fingrowth/screens/report_screen.dart'; // Import AppColors

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final SubscriptionService _subscriptionService = SubscriptionService();

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getBackgroundColor(context),
      appBar: AppBar(
        title: const Text("Nâng Cấp Premium", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.getCardColor(context),
        foregroundColor: AppColors.getTextColor(context),
        elevation: 1,
      ),
      body: _subscriptionService.products.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_subscriptionService.products.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Text(
            "Không thể tải các gói đăng ký vào lúc này. Vui lòng kiểm tra kết nối và thử lại.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
          ..._subscriptionService.products.map((product) {
            // Sắp xếp để gói năm hiển thị trước (nếu có)
            _subscriptionService.products.sort((a, b) => b.price.compareTo(a.price));
            return _buildProductCard(product);
          }).toList(),
          const SizedBox(height: 24),
          _buildRestoreButton(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Icon(Icons.workspace_premium_outlined, size: 64, color: Colors.amber[700]),
        const SizedBox(height: 16),
        const Text(
          "Mở Khóa Toàn Bộ Tiềm Năng",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _buildFeatureItem("Quản lý quyền hạn, thêm cộng tác viên."),
        _buildFeatureItem("Báo cáo không giới hạn thời gian."),
        _buildFeatureItem("Sử dụng A.I phân tích tài chính chuyên sâu."),
      ],
    );
  }

  Widget _buildFeatureItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle, color: AppColors.chartGreen, size: 20),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildProductCard(ProductDetails product) {
    bool isYearly = product.id.contains('yearly'); // Giả định ID gói năm chứa 'yearly'

    return Card(
      elevation: isYearly ? 4 : 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isYearly ? Colors.amber[700]! : AppColors.getBorderColor(context),
          width: isYearly ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            if (isYearly)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber[700],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text("TIẾT KIỆM NHẤT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            const SizedBox(height: 12),
            Text(product.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              product.price,
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.primaryBlue),
            ),
            Text(product.description, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                _subscriptionService.buySubscription(product);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isYearly ? Colors.amber[800] : AppColors.primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
              ),
              child: const Text("Chọn Gói Này", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRestoreButton() {
    return TextButton(
      onPressed: () {
        _subscriptionService.restorePurchases();
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Đang thử khôi phục các giao dịch đã mua..."))
        );
      },
      child: const Text(
        "Khôi phục giao dịch đã mua",
        style: TextStyle(decoration: TextDecoration.underline),
      ),
    );
  }
}