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
    // Lớp phủ loading này vẫn hữu ích để ngăn người dùng tương tác
    // trong lúc giao dịch đang được xử lý.
    final isLoading = context.watch<SubscriptionService>().isLoading;

    return Scaffold(
      body: Stack(
        children: [
          PaywallView(
            onDismiss: () {
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
            // ✅ Xử lý chính khi mua hàng thành công
            onPurchaseCompleted: (CustomerInfo customerInfo, StoreTransaction storeTransaction) {
              print("Purchase completed successfully on store!");

              // Kiểm tra xem entitlement 'premium' đã active chưa.
              final isSubscribed = customerInfo.entitlements.all["premium"]?.isActive ?? false;

              if (isSubscribed && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Đăng ký thành công!")),
                );
                // Đóng màn hình paywall và quay về.
                Navigator.of(context).pop();
              }
            },
            // ✅ Xử lý chính khi khôi phục giao dịch
            onRestoreCompleted: (CustomerInfo customerInfo) {
              final isSubscribed = customerInfo.entitlements.all.values.any((e) => e.isActive);
              if (context.mounted) {
                final message = isSubscribed
                    ? "Đã khôi phục giao dịch thành công!"
                    : "Không tìm thấy giao dịch nào để khôi phục.";
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

                // Chỉ đóng màn hình nếu khôi phục thành công.
                if (isSubscribed) {
                  Navigator.pop(context);
                }
              }
            },
          ),

          // Lớp phủ Loading (tùy chọn nhưng khuyến khích)
          if (isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}