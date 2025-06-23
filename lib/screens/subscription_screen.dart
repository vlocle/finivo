import 'package:flutter/material.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class SubscriptionScreen extends StatelessWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PaywallView(
        onDismiss: () {
          if (context.mounted) {
            Navigator.of(context).pop();
          }
        },
        onPurchaseCompleted: (CustomerInfo customerInfo, StoreTransaction storeTransaction) {
          if (context.mounted) Navigator.pop(context);
        },
        onRestoreCompleted: (CustomerInfo customerInfo) {
          final isSubscribed = customerInfo.entitlements.all.values.any((e) => e.isActive);
          if (context.mounted) {
            final message = isSubscribed
                ? "Đã khôi phục giao dịch thành công!"
                : "Không tìm thấy giao dịch nào để khôi phục.";
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
            Navigator.pop(context);
          }
        },
      ),
    );
  }
}