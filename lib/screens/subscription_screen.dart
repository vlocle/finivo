import 'dart:async';
import 'package:flutter/material.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:provider/provider.dart';
import 'subscription_service.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  late final SubscriptionService _subscriptionService;
  Timer? _fallbackTimer;

  @override
  void initState() {
    super.initState();

    _subscriptionService = context.read<SubscriptionService>();
    _subscriptionService.addListener(_onSubscriptionChange);

    // Fallback: nếu sau 15 giây không có phản hồi thì tự đóng màn hình
    _fallbackTimer = Timer(const Duration(seconds: 15), () {
      if (!_subscriptionService.isSubscribed && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Không thể xác minh giao dịch. Vui lòng thử lại.")),
        );
        Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _subscriptionService.removeListener(_onSubscriptionChange);
    _fallbackTimer?.cancel();
    super.dispose();
  }

  void _onSubscriptionChange() {
    if (_subscriptionService.isSubscribed && mounted) {
      _fallbackTimer?.cancel();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Đăng ký thành công!")),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<SubscriptionService>().isLoading;

    return Scaffold(
      body: Stack(
        children: [
          // Giao diện chính: Paywall
          PaywallView(
            onDismiss: () {
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
            onPurchaseCompleted: (CustomerInfo customerInfo, StoreTransaction storeTransaction) {
              print("Purchase completed successfully!");
            },
            onRestoreCompleted: (CustomerInfo customerInfo) {
              final isSubscribed = customerInfo.entitlements.all.values.any((e) => e.isActive);
              if (context.mounted) {
                final message = isSubscribed
                    ? "Đã khôi phục giao dịch thành công!"
                    : "Không tìm thấy giao dịch nào để khôi phục.";
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

                if (!isSubscribed) {
                  Navigator.pop(context);
                }
              }
            },
          ),

          // ✅ Loading overlay nếu đang xử lý
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