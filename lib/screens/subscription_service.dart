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

  bool _isSubscribed = false;
  bool get isSubscribed => _isSubscribed;

  List<Package> _packages = [];
  List<Package> get packages => _packages;

  Future<void> init() async {
    Purchases.addCustomerInfoUpdateListener((customerInfo) {
      _updateSubscriptionStatus(customerInfo);
    });
    await _loadInitialStatus();
  }

  Future<void> _loadInitialStatus() async {
    setLoading(true); // ✅ Thay đổi: Sử dụng hàm public mới
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      _updateSubscriptionStatus(customerInfo);
      await fetchOfferings();
    } catch (e) {
      print("Lỗi khi lấy thông tin ban đầu: $e");
    }
    setLoading(false); // ✅ Thay đổi: Sử dụng hàm public mới
  }

  void _updateSubscriptionStatus(CustomerInfo customerInfo) {
    final newStatus = customerInfo.entitlements.all["premium"]?.isActive ?? false;
    print("--- RevenueCat Listener Fired: New status is $newStatus ---");

    if (_isSubscribed != newStatus) {
      _isSubscribed = newStatus;
      notifyListeners();
    }

    // ✅ THAY ĐỔI QUAN TRỌNG: Tự động tắt loading khi có kết quả cuối cùng
    if (_isLoading) {
      setLoading(false);
    }
  }

  Future<void> fetchOfferings() async {
    try {
      final offerings = await Purchases.getOfferings();
      if (offerings.current != null && offerings.current!.availablePackages.isNotEmpty) {
        _packages = offerings.current!.availablePackages;
      }
    } catch (e) {
      print("Lỗi khi lấy các gói sản phẩm: $e");
      _packages = [];
    }
    notifyListeners();
  }

  Future<bool> purchasePackage(Package package) async {
    setLoading(true); // ✅ Thay đổi: Sử dụng hàm public mới
    try {
      await Purchases.purchasePackage(package);
      // ✅ THAY ĐỔI: Xóa dòng setLoading(false) ở đây. Listener sẽ xử lý việc này.
      return true;
    } catch (e) {
      print("Lỗi khi mua hàng: $e");
      setLoading(false); // Giữ lại để xử lý lỗi tức thời
      return false;
    }
  }

  Future<void> restorePurchases() async {
    setLoading(true); // ✅ Thay đổi: Sử dụng hàm public mới
    try {
      await Purchases.restorePurchases();
      // ✅ THAY ĐỔI: Xóa dòng setLoading(false) ở đây. Listener sẽ xử lý việc này.
    } catch (e) {
      print("Lỗi khi khôi phục giao dịch: $e");
      setLoading(false); // Giữ lại để xử lý lỗi tức thời
    }
  }

  // ✅ THAY ĐỔI: Bỏ gạch dưới để hàm này trở thành public
  void setLoading(bool status) {
    // Thêm check để tránh gọi notifyListeners không cần thiết
    if (_isLoading != status) {
      _isLoading = status;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await Purchases.logOut();
    _isSubscribed = false;
    _packages = [];
    _isLoading = false; // Đảm bảo reset loading khi logout
    notifyListeners();
    print("Đã đăng xuất khỏi RevenueCat.");
  }
}