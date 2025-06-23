import 'package:flutter/material.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class SubscriptionScreen extends StatelessWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. Vẫn giữ lại Scaffold để NÚT BACK hoạt động
    return Scaffold(
      body: PaywallView(
        // 2. Thêm callback để ĐÓNG PAYWALL SAU KHI MUA HÀNG THÀNH CÔNG
        onPurchaseCompleted: (CustomerInfo customerInfo, StoreTransaction storeTransaction) {
          print("Purchase completed for user: ${customerInfo.originalAppUserId}");
          Navigator.pop(context);
        },

        // 3. (Tùy chọn) Xử lý khi khôi phục thành công
        onRestoreCompleted: (CustomerInfo customerInfo) {
          print("Restore completed for user: ${customerInfo.originalAppUserId}");

          final isSubscribed = customerInfo.entitlements.all.values.any((e) => e.isActive);

          if (isSubscribed) {
            // Nếu khôi phục thành công, cũng đóng màn hình lại
            Navigator.pop(context);
          } else {
            // Nếu không có gì để khôi phục, hiển thị thông báo
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Không tìm thấy giao dịch nào để khôi phục.")),
            );
          }
        },

        // 4. (Tùy chọn) Xử lý khi có lỗi mua hàng
        onPurchaseError: (PurchasesError error) {
          print("Purchase error: ${error.message}");
        },
      ),
    );
  }
}