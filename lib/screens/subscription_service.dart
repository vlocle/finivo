// subscription_service_latest.docx
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class SubscriptionService with ChangeNotifier {
  // Singleton pattern
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // Trạng thái Premium sẽ là nguồn tin cậy duy nhất
  bool _isSubscribed = false;
  bool get isSubscribed => _isSubscribed;

  // Danh sách các gói sản phẩm để hiển thị trên màn hình mua
  List<Package> _packages = [];
  List<Package> get packages => _packages;

  // Hàm khởi tạo, được gọi từ main.dart hoặc AuthWrapper
  Future<void> init() async {
    // Lắng nghe các thay đổi về thông tin người dùng (bao gồm cả trạng thái premium)
    Purchases.addCustomerInfoUpdateListener((customerInfo) {
      _updateSubscriptionStatus(customerInfo);
    });

    // Lấy thông tin người dùng lần đầu
    await _loadInitialStatus();
  }

  Future<void> _loadInitialStatus() async {
    _setLoading(true);
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      _updateSubscriptionStatus(customerInfo);
      await fetchOfferings();
    } catch (e) {
      print("Lỗi khi lấy thông tin ban đầu: $e");
    }
    _setLoading(false);
  }

  // Hàm cốt lõi: cập nhật trạng thái premium dựa trên thông tin từ RevenueCat
  void _updateSubscriptionStatus(CustomerInfo customerInfo) {
    // 'premium' là tên Entitlement bạn đã tạo trên dashboard của RevenueCat
    final newStatus = customerInfo.entitlements.all["premium"]?.isActive ?? false;

    // --- BẮT ĐẦU LOG DEBUG ---
    print("--- RevenueCat Listener Fired ---");
    print("Current local status (_isSubscribed): $_isSubscribed");
    print("New status from RevenueCat server: $newStatus");
    print("Active entitlements from RevenueCat: ${customerInfo.entitlements.active}");
    // --- KẾT THÚC LOG DEBUG ---

    if (_isSubscribed != newStatus) {
      _isSubscribed = newStatus;
      print(">>> STATUS CHANGED! Calling notifyListeners() to update UI <<<");
      notifyListeners(); // Thông báo cho UI cập nhật
    } else {
      print("--- Status has NOT changed. No need to call notifyListeners(). ---");
    }
  }

  // Lấy danh sách các gói sản phẩm để hiển thị
  Future<void> fetchOfferings() async {
    try {
      final offerings = await Purchases.getOfferings();
      // 'default' là tên Offering bạn đã tạo trên dashboard
      if (offerings.current != null && offerings.current!.availablePackages.isNotEmpty) {
        _packages = offerings.current!.availablePackages;
      }
    } catch (e) {
      print("Lỗi khi lấy các gói sản phẩm: $e");
      _packages = [];
    }
    notifyListeners();
  }

  // Hàm để thực hiện mua một gói
  Future<bool> purchasePackage(Package package) async {
    _setLoading(true);
    try {
      await Purchases.purchasePackage(package);
      // Listener sẽ tự động cập nhật trạng thái premium
      _setLoading(false);
      return true;
    } catch (e) {
      print("Lỗi khi mua hàng: $e");
      _setLoading(false);
      return false;
    }
  }

  // Khôi phục giao dịch
  Future<void> restorePurchases() async {
    _setLoading(true);
    try {
      await Purchases.restorePurchases();
      // Listener sẽ tự động cập nhật trạng thái premium
    } catch (e) {
      print("Lỗi khi khôi phục giao dịch: $e");
    }
    _setLoading(false);
  }

  void _setLoading(bool status) {
    _isLoading = status;
    notifyListeners();
  }

  // Quan trọng: Khi người dùng đăng xuất, cần reset RevenueCat
  Future<void> logout() async {
    await Purchases.logOut();
    _isSubscribed = false;
    _packages = [];
    notifyListeners();
    print("Đã đăng xuất khỏi RevenueCat.");
  }
}