import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import 'subscription_service.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  @override
  Widget build(BuildContext context) {
    // Theo dõi trạng thái isLoading từ service
    final isLoading = context.watch<SubscriptionService>().isLoading;

    return Scaffold(
      body: Stack(
        children: [
          // Lớp dưới cùng là Paywall của RevenueCat
          PaywallView(
            onDismiss: () {
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
            onPurchaseCompleted: (CustomerInfo customerInfo, StoreTransaction storeTransaction) {
              // ✅ ĐÂY LÀ THAY ĐỔI QUAN TRỌNG NHẤT
              // Bật lớp phủ loading ngay sau khi cửa sổ của Apple/Google đóng lại.
              if (context.mounted) {
                context.read<SubscriptionService>().setLoading(true);
              }

              // Logic kiểm tra và điều hướng vẫn giữ nguyên
              // Service sẽ tự động tắt loading và pop màn hình khi có kết quả.
              final isSubscribed = customerInfo.entitlements.all["premium"]?.isActive ?? false;
              if (isSubscribed && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Đăng ký thành công!")),
                );
                Navigator.of(context).pop();
              }
            },
            onRestoreCompleted: (CustomerInfo customerInfo) {
              // Bật loading khi bắt đầu khôi phục
              if(context.mounted) {
                context.read<SubscriptionService>().setLoading(true);
              }
              final isSubscribed = customerInfo.entitlements.all.values.any((e) => e.isActive);
              if (context.mounted) {
                final message = isSubscribed
                    ? "Đã khôi phục giao dịch thành công!"
                    : "Không tìm thấy giao dịch nào để khôi phục.";
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

                if (isSubscribed) {
                  Navigator.pop(context);
                }
              }
            },
          ),

          // Lớp trên cùng: Lớp phủ loading
          // Chỉ hiển thị khi isLoading là true
          if (isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}