import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:cloud_functions/cloud_functions.dart';

/// Service này sẽ quản lý toàn bộ logic mua hàng.
/// Nó sử dụng ChangeNotifier để thông báo cho UI về các thay đổi trạng thái (loading, error, products loaded).
class SubscriptionService with ChangeNotifier {
  // Singleton pattern để dễ dàng truy cập từ mọi nơi
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();

  final InAppPurchase _iap = InAppPurchase.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: "asia-southeast1");

  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  List<ProductDetails> products = [];
  bool isLoading = false;
  String? error;

  // !!! THAY THẾ BẰNG PRODUCT ID THẬT BẠN ĐÃ TẠO TRÊN APP STORE CONNECT !!!
  final Set<String> _productIds = {
    'com.finivo.weekly',
    'com.finivo.monthly',
    'com.finivo.yearly',
  };

  /// Hàm này nên được gọi một lần khi ứng dụng khởi động.
  Future<void> init() async {
    final bool available = await _iap.isAvailable();
    if (available) {
      // Lắng nghe các cập nhật về giao dịch
      _purchaseSubscription = _iap.purchaseStream.listen(
            (purchaseDetailsList) {
          _listenToPurchaseUpdated(purchaseDetailsList);
        },
        onDone: () => _purchaseSubscription?.cancel(),
        onError: (error) => print("Lỗi lắng nghe giao dịch: $error"),
      );
      // Lấy thông tin sản phẩm từ App Store
      await fetchProducts();
    }
  }

  /// Lấy chi tiết sản phẩm (tên, giá) từ App Store.
  /// Cập nhật trạng thái loading và error, đồng thời thông báo cho listeners.
  Future<void> fetchProducts() async {
    isLoading = true;
    error = null;
    notifyListeners(); // Thông báo bắt đầu loading

    try {
      final ProductDetailsResponse response = await _iap.queryProductDetails(_productIds);
      if (response.error == null) {
        products = response.productDetails;
        print("Đã tải thành công ${products.length} sản phẩm.");
      } else {
        error = "Lỗi khi tải sản phẩm: ${response.error?.message}";
        print("Lỗi khi tải sản phẩm: ${response.error?.message}");
      }
    } catch (e) {
      error = "Lỗi không xác định khi tải sản phẩm: $e";
      print("Lỗi không xác định khi tải sản phẩm: $e");
    }

    isLoading = false;
    notifyListeners(); // Thông báo đã loading xong
  }

  /// Bắt đầu quá trình mua một gói.
  Future<void> buySubscription(ProductDetails product) async {
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);
    await _iap.buyNonConsumable(purchaseParam: purchaseParam);
  }

  /// Khôi phục các giao dịch đã mua.
  Future<void> restorePurchases() async {
    await _iap.restorePurchases();
  }

  /// Hàm lắng nghe và xử lý các trạng thái của giao dịch.
  void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) {
    for (var purchase in purchaseDetailsList) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          print("Giao dịch đang chờ xử lý...");
          break;
        case PurchaseStatus.error:
          print("Lỗi giao dịch: ${purchase.error}");
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          _verifyAndCompletePurchase(purchase);
          break;
        case PurchaseStatus.canceled:
          print("Giao dịch đã bị hủy.");
          break;
      }
    }
  }

  /// GỌI CLOUD FUNCTION VÀ HOÀN TẤT GIAO DỊCH.
  Future<void> _verifyAndCompletePurchase(PurchaseDetails purchase) async {
    // KIỂM TRA HÓA ĐƠN TRƯỚC KHI GỬI
    if (purchase.verificationData.serverVerificationData.isEmpty) {
      print("Lỗi: Hóa đơn xác thực (serverVerificationData) bị trống. Không thể xác thực.");
      // (Tùy chọn) Hiển thị thông báo lỗi cho người dùng
      return;
    }

    try {
      print("Bắt đầu xác thực hóa đơn với Cloud Function...");
      final String receipt = purchase.verificationData.serverVerificationData;

      // In ra để debug
      print("Hóa đơn gửi đi: ${receipt.substring(0, 30)}..."); // In ra 30 ký tự đầu

      final callable = _functions.httpsCallable('verifyApplePurchase');
      final response = await callable.call<Map<String, dynamic>>({
        'receiptData': receipt,
      });

      if (response.data['success'] == true) {
        print("Xác thực thành công! Hoàn tất giao dịch.");
        await _iap.completePurchase(purchase);
      } else {
        print("Xác thực thất bại từ server.");
      }
    } catch (e) {
      print("Lỗi khi gọi Cloud Function: $e");
    }
  }

  /// Dọn dẹp listener khi không cần.
  @override
  void dispose() {
    _purchaseSubscription?.cancel();
    super.dispose();
  }
}