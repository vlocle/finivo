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

  @override
  void initState() {
    super.initState();
    // Lấy đối tượng service từ Provider
    _subscriptionService = context.read<SubscriptionService>();
    // Thêm một listener để lắng nghe thay đổi từ service
    _subscriptionService.addListener(_onSubscriptionChange);
  }

  @override
  void dispose() {
    // Luôn gỡ bỏ listener khi widget bị hủy để tránh rò rỉ bộ nhớ
    _subscriptionService.removeListener(_onSubscriptionChange);
    super.dispose();
  }

  // Hàm này sẽ được gọi mỗi khi SubscriptionService có thay đổi
  void _onSubscriptionChange() {
    // Nếu trạng thái đã là premium VÀ widget vẫn còn trên cây giao diện
    if (_subscriptionService.isSubscribed && mounted) {
      // Tự động đóng màn hình paywall
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PaywallView(
        onDismiss: () {
          if (context.mounted) {
            Navigator.of(context).pop();
          }
        },
        // Callback này giờ chỉ dùng để ghi log hoặc các tác vụ phụ, không dùng để pop màn hình
        onPurchaseCompleted: (CustomerInfo customerInfo, StoreTransaction storeTransaction) {
          print("Purchase completed successfully!");
          // Listener ở trên sẽ tự động xử lý việc đóng màn hình
        },
        onRestoreCompleted: (CustomerInfo customerInfo) {
          final isSubscribed = customerInfo.entitlements.all.values.any((e) => e.isActive);
          if (context.mounted) {
            final message = isSubscribed
                ? "Đã khôi phục giao dịch thành công!"
                : "Không tìm thấy giao dịch nào để khôi phục.";
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

            // Nếu khôi phục thành công, listener cũng sẽ tự động đóng màn hình
            // Nhưng nếu khôi phục thất bại, chúng ta có thể đóng màn hình ở đây
            if (!isSubscribed) {
              Navigator.pop(context);
            }
          }
        },
      ),
    );
  }
}