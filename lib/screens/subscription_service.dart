import 'dart:async';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:cloud_functions/cloud_functions.dart';

// Service này sẽ quản lý toàn bộ logic mua hàng
class SubscriptionService {
  // Singleton pattern để dễ dàng truy cập từ mọi nơi
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();

  final InAppPurchase _iap = InAppPurchase.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: "asia-southeast1");

  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  List<ProductDetails> products = [];

  // !!! THAY THẾ BẰNG PRODUCT ID THẬT BẠN ĐÃ TẠO TRÊN APP STORE CONNECT !!!
  final Set<String> _productIds = {
    'com.finivo.weekly',
    'com.finivo.monthly',
    'com.finivo.yearly',
  };

  // Hàm này nên được gọi một lần khi ứng dụng khởi động
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

  // Lấy chi tiết sản phẩm (tên, giá) từ App Store
  Future<void> fetchProducts() async {
    try {
      final ProductDetailsResponse response = await _iap.queryProductDetails(_productIds);
      if (response.error == null) {
        products = response.productDetails;
        print("Đã tải thành công ${products.length} sản phẩm.");
      } else {
        print("Lỗi khi tải sản phẩm: ${response.error?.message}");
      }
    } catch (e) {
      print("Lỗi không xác định khi tải sản phẩm: $e");
    }
  }

  // Bắt đầu quá trình mua một gói
  Future<void> buySubscription(ProductDetails product) async {
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);
    await _iap.buyNonConsumable(purchaseParam: purchaseParam);
  }

  // Khôi phục các giao dịch đã mua
  Future<void> restorePurchases() async {
    await _iap.restorePurchases();
  }

  // Hàm lắng nghe và xử lý các trạng thái của giao dịch
  void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) {
    for (var purchase in purchaseDetailsList) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
        // Hiển thị loading... (sẽ làm ở UI)
          print("Giao dịch đang chờ xử lý...");
          break;
        case PurchaseStatus.error:
          print("Lỗi giao dịch: ${purchase.error}");
          // Ẩn loading, hiển thị lỗi (sẽ làm ở UI)
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
        // Giao dịch thành công, xác thực với backend
          _verifyAndCompletePurchase(purchase);
          break;
        case PurchaseStatus.canceled:
        // Giao dịch bị người dùng hủy
          print("Giao dịch đã bị hủy.");
          break;
      }
    }
  }

  // GỌI CLOUD FUNCTION VÀ HOÀN TẤT GIAO DỊCH
  Future<void> _verifyAndCompletePurchase(PurchaseDetails purchase) async {
    try {
      print("Bắt đầu xác thực hóa đơn với Cloud Function...");
      // Lấy hóa đơn từ giao dịch
      final String receipt = purchase.verificationData.serverVerificationData;

      // Gọi Cloud Function 'verifyApplePurchase'
      final callable = _functions.httpsCallable('verifyApplePurchase');
      final response = await callable.call<Map<String, dynamic>>({
        'receiptData': receipt,
      });

      if (response.data['success'] == true) {
        print("Xác thực thành công! Hoàn tất giao dịch.");
        // RẤT QUAN TRỌNG: Báo cho App Store rằng giao dịch đã được xử lý xong
        await _iap.completePurchase(purchase);
        // Sau bước này, listener của Firestore sẽ tự động cập nhật AppState
      } else {
        print("Xác thực thất bại từ server.");
        // Xử lý lỗi (hiển thị thông báo cho người dùng)
      }
    } catch (e) {
      print("Lỗi khi gọi Cloud Function: $e");
      // Xử lý lỗi (hiển thị thông báo cho người dùng)
    }
  }

  // Dọn dẹp listener khi không cần
  void dispose() {
    _purchaseSubscription?.cancel();
  }
}