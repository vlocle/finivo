import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart'; // THAY ĐỔI: Import RevenueCat SDK
import '../screens/subscription_service.dart';
import 'package:fingrowth/screens/report_screen.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  @override
  void initState() {
    super.initState();
    // Gọi fetchOfferings nếu cần, hoặc có thể đã được gọi trong init của service
    context.read<SubscriptionService>().fetchOfferings();
  }

  @override
  Widget build(BuildContext context) {
    // Sử dụng Consumer để lắng nghe thay đổi từ SubscriptionService
    return Consumer<SubscriptionService>(
      builder: (context, subscriptionService, child) {
        return Scaffold(
          backgroundColor: AppColors.getBackgroundColor(context),
          appBar: AppBar(
            title: const Text("Nâng Cấp Premium", style: TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: AppColors.getCardColor(context),
            foregroundColor: AppColors.getTextColor(context),
            elevation: 1,
          ),
          body: subscriptionService.isLoading
              ? const Center(child: CircularProgressIndicator())
          // THAY ĐỔI: Kiểm tra subscriptionService.packages
              : subscriptionService.packages.isEmpty
              ? const Center(child: Text("Không có gói nào được tìm thấy."))
              : _buildContent(context, subscriptionService),
        );
      },
    );
  }

  Widget _buildContent(BuildContext context, SubscriptionService subscriptionService) {
    // THAY ĐỔI: Sắp xếp danh sách các "Package"
    final sortedPackages = List<Package>.from(subscriptionService.packages);
    sortedPackages.sort((a, b) {
      // Sắp xếp theo thứ tự: Năm > Tháng > Tuần
      final aOrder = a.packageType == PackageType.annual ? 0 : (a.packageType == PackageType.monthly ? 1 : 2);
      final bOrder = b.packageType == PackageType.annual ? 0 : (b.packageType == PackageType.monthly ? 1 : 2);
      return aOrder.compareTo(bOrder);
    });

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
          // Sử dụng danh sách đã sắp xếp để build UI
          ...sortedPackages.map((package) {
            return _buildProductCard(context, package, subscriptionService);
          }).toList(),
          const SizedBox(height: 24),
          _buildRestoreButton(context, subscriptionService),
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
        _buildFeatureItem("Phân quyền cho nhân viên/cộng sự."),
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

  // THAY ĐỔI: Hàm này giờ nhận vào một đối tượng "Package"
  Widget _buildProductCard(BuildContext context, Package package, SubscriptionService subscriptionService) {
    final storeProduct = package.storeProduct;
    final isYearly = package.packageType == PackageType.annual;

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
            // THAY ĐỔI: Truy cập thông tin từ storeProduct
            Text(storeProduct.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              storeProduct.priceString, // Sử dụng priceString đã được định dạng sẵn
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.primaryBlue),
            ),
            Text(storeProduct.description, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // THAY ĐỔI: Gọi hàm mua gói mới
                subscriptionService.purchasePackage(package);
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

  Widget _buildRestoreButton(BuildContext context, SubscriptionService subscriptionService) {
    return TextButton(
      onPressed: () {
        subscriptionService.restorePurchases();
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