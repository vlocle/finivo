import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/transaction.dart' as model;
import '/screens/expense_manager.dart';
import '/screens/revenue_manager.dart';
import '../screens/chart_data_models.dart';
import 'dart:convert';

class AppState extends ChangeNotifier {
  bool _isSubscribed = false;
  bool get isSubscribed => _isSubscribed;
  DateTime? _subscriptionExpiryDate;
  DateTime? get subscriptionExpiryDate => _subscriptionExpiryDate;
  int _selectedScreenIndex = 0;
  int get selectedScreenIndex => _selectedScreenIndex;
  String? authUserId;
  String? activeUserId;
  Map<String, bool> activeUserPermissions = {};
  final ValueNotifier<int> permissionVersion = ValueNotifier(0);
  DateTime _selectedDate = DateTime.now();
  final ValueNotifier<DateTime> selectedDateListenable = ValueNotifier(DateTime.now());
  final ValueNotifier<bool> isLoadingListenable = ValueNotifier(false);
  final ValueNotifier<bool> dataReadyListenable = ValueNotifier(false);
  double mainRevenue = 0.0;
  double secondaryRevenue = 0.0;
  double otherRevenue = 0.0;
  final ValueNotifier<double> mainRevenueListenable = ValueNotifier(0.0);
  final ValueNotifier<double> secondaryRevenueListenable = ValueNotifier(0.0);
  final ValueNotifier<double> otherRevenueListenable = ValueNotifier(0.0);
  final ValueNotifier<double> totalRevenueListenable = ValueNotifier(0.0);
  final ValueNotifier<double> profitListenable = ValueNotifier(0.0);
  final ValueNotifier<double> profitMarginListenable = ValueNotifier(0.0);
  double _fixedExpense = 0.0;
  double variableExpense = 0.0;
  double otherExpense = 0.0;
  final ValueNotifier<double> fixedExpenseListenable = ValueNotifier(0.0);
  final ValueNotifier<List<Map<String, dynamic>>> fixedExpenseList = ValueNotifier([]);
  final ValueNotifier<List<Map<String, dynamic>>> variableExpenseList = ValueNotifier([]);
  final ValueNotifier<List<Map<String, dynamic>>> mainRevenueTransactions = ValueNotifier([]);
  final ValueNotifier<List<Map<String, dynamic>>> secondaryRevenueTransactions = ValueNotifier([]);
  final ValueNotifier<List<Map<String, dynamic>>> otherRevenueTransactions = ValueNotifier([]);
  final ValueNotifier<List<Map<String, dynamic>>> wallets = ValueNotifier([]);
  final ValueNotifier<List<Map<String, dynamic>>> walletAdjustments = ValueNotifier([]);
  final ValueNotifier<List<Map<String, dynamic>>> otherExpenseTransactions = ValueNotifier([]);
  final Map<String, String> _userDisplayNames = {};
  final ValueNotifier<bool> productsUpdated = ValueNotifier(false);
  bool _notificationsEnabled = true;
  String _currentLanguage = 'vi';
  bool _isDarkMode = false;
  String _lastRecommendation = "Nhấn vào nút để nhận khuyến nghị từ A.I";
  bool _isLoading = false;
  bool _isLoadingRevenue = false;
  String? _cachedDateKey;
  Map<String, dynamic>? _cachedData;
  bool _isFirebaseInitialized = false;
  bool _isLoggingOut = false;
  bool get isLoggingOut => _isLoggingOut;

  StreamSubscription<DocumentSnapshot>? _revenueSubscription;
  StreamSubscription<DocumentSnapshot>? _fixedExpenseSubscription; // Thêm subscription cho chi phí cố định
  StreamSubscription<DocumentSnapshot>? _variableExpenseSubscription;
  StreamSubscription<DocumentSnapshot>? _dailyFixedExpenseSubscription;
  StreamSubscription<DocumentSnapshot>? _dailyDataSubscription;
  StreamSubscription<QuerySnapshot>? _productsSubscription;
  StreamSubscription<DocumentSnapshot>? _permissionSubscription;
  StreamSubscription<DocumentSnapshot>? _variableExpenseListSubscription;
  StreamSubscription<QuerySnapshot>? _walletsSubscription;
  StreamSubscription<DocumentSnapshot>? _otherExpenseSubscription;

  double get fixedExpense => _fixedExpense;
  bool get notificationsEnabled => _notificationsEnabled;
  String get currentLanguage => _currentLanguage;
  bool get isDarkMode => _isDarkMode;
  String get lastRecommendation => _lastRecommendation;
  DateTime get selectedDate => _selectedDate;

  AppState() {
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      _isFirebaseInitialized = Firebase.apps.isNotEmpty;
      if (!_isFirebaseInitialized) {
        return;
      }

      if (!Hive.isBoxOpen('settingsBox')) {
        await Hive.openBox('settingsBox');
      }

      _loadSettings();
      if (_isFirebaseInitialized) {
        await _loadInitialData();
        _subscribeToFixedExpenses(); // Kích hoạt listener cho chi phí cố định
        _subscribeToVariableExpenses();
        _subscribeToDailyFixedExpenses();
      }
    } catch (e) {
      _isFirebaseInitialized = false;
    }
  }

  void setSelectedScreenIndex(int index) {
    _selectedScreenIndex = index;
    notifyListeners();
  }

  void updateSubscriptionStatus(bool newStatus) {
    // Chỉ cập nhật và thông báo nếu có sự thay đổi thực sự
    if (_isSubscribed != newStatus) {
      _isSubscribed = newStatus;
      print("AppState updated by ProxyProvider: User is now premium -> $_isSubscribed");
      notifyListeners(); // Báo cho toàn bộ UI đang nghe AppState cập nhật
    }
  }

  Map<String, dynamic>? get defaultWallet {
    try {
      return wallets.value.firstWhere((wallet) => wallet['isDefault'] == true);
    } catch (e) {
      return null; // Trả về null nếu không tìm thấy
    }
  }

  void _subscribeToWallets() {
    if (activeUserId == null) return;
    _walletsSubscription?.cancel();
    _walletsSubscription = FirebaseFirestore.instance
        .collection('users').doc(activeUserId)
        .collection('wallets')
        .orderBy('createdAt')
        .snapshots()
        .listen((snapshot) {

      // if (snapshot.metadata.hasPendingWrites) return; // <-- XÓA BỎ DÒNG NÀY

      // Sắp xếp lại danh sách để đảm bảo ví mặc định luôn ở trên cùng
      final walletList = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id; // Đảm bảo ID luôn có trong dữ liệu ví
        return data;
      }).toList();

      walletList.sort((a, b) {
        bool aIsDefault = a['isDefault'] ?? false;
        bool bIsDefault = b['isDefault'] ?? false;
        if (aIsDefault && !bIsDefault) {
          return -1; // a đứng trước b
        }
        if (!aIsDefault && bIsDefault) {
          return 1; // b đứng trước a
        }
        // Nếu cả hai đều là hoặc không là mặc định, sắp xếp theo ngày tạo
        final aTime = a['createdAt'] as Timestamp? ?? Timestamp.now();
        final bTime = b['createdAt'] as Timestamp? ?? Timestamp.now();
        return aTime.compareTo(bTime);
      });

      wallets.value = walletList;

    }, onError: (error) {
      print("Lỗi khi lắng nghe ví tiền: $error");
    });
  }

// Thêm phương thức hủy
  void _cancelWalletsSubscription() {
    _walletsSubscription?.cancel();
    _walletsSubscription = null;
  }



  void _updateProfitAndRelatedListenables() {
    mainRevenueListenable.value = mainRevenue;
    secondaryRevenueListenable.value = secondaryRevenue;
    otherRevenueListenable.value = otherRevenue;
    totalRevenueListenable.value = getTotalRevenue();
    fixedExpenseListenable.value = _fixedExpense;
    // Đảm bảo this.variableExpense đã được cập nhật từ listener trước khi gọi các hàm getProfit()
    profitListenable.value = getProfit();
    profitMarginListenable.value = getProfitMargin();
  }

  void _loadSettings() {
    try {
      var settingsBox = Hive.box('settingsBox');
      _notificationsEnabled = settingsBox.get(getKey('notificationsEnabled'), defaultValue: true);
      _isDarkMode = settingsBox.get(getKey('isDarkMode'), defaultValue: false);
      _lastRecommendation = settingsBox.get(getKey('lastRecommendation'), defaultValue: "Nhấn vào nút để nhận khuyến nghị từ A.I");
      notifyListeners();
    } catch (e) {
      print('Lỗi khi tải cài đặt: $e');
    }
  }

  void _saveSettings() {
    try {
      var settingsBox = Hive.box('settingsBox');
      settingsBox.put(getKey('notificationsEnabled'), _notificationsEnabled);
      settingsBox.put(getKey('isDarkMode'), _isDarkMode);
      settingsBox.put(getKey('lastRecommendation'), _lastRecommendation);
    } catch (e) {
      print('Lỗi khi lưu cài đặt: $e');
    }
  }

  void setNotificationsEnabled(bool value) {
    _notificationsEnabled = value;
    _saveSettings();
    notifyListeners();
  }

  void setDarkMode(bool value) {
    _isDarkMode = value;
    _saveSettings();
    notifyListeners();
  }

  void setLastRecommendation(String recommendation) {
    _lastRecommendation = recommendation;
    _saveSettings();
    notifyListeners();
  }

  bool isOwner() {
    if (authUserId == null || activeUserId == null) return true;
    return authUserId == activeUserId;
  }

  bool hasPermission(String permissionKey) {
    if (isOwner()) return true;
    return activeUserPermissions[permissionKey] ?? false;
  }

  Future<void> setUserId(String id) async {
    // Nếu ID người dùng không thay đổi (đã được thiết lập trước đó) thì không cần làm gì cả.
    // Điều này ngăn việc chạy lại logic không cần thiết.
    if (authUserId == id) return;

    // BƯỚC 1: Dọn dẹp dữ liệu của người dùng CŨ (chỉ khi chuyển đổi người dùng)
    // Chỉ dọn dẹp khi đang có một người dùng đăng nhập (authUserId != null) và
    // người dùng mới (id) khác với người dùng cũ.
    if (authUserId != null && authUserId != id) {
      await _clearAllLocalStateAndData();
    }

    authUserId = id;
    activeUserId = id;
    _loadSettings();

    await _loadInitialData(); // Tải dữ liệu chính
    _subscribeToPermissions();
    _subscribeToFixedExpenses();
    _subscribeToVariableExpenses();
    _subscribeToDailyFixedExpenses();
    _subscribeToDailyData();
    _subscribeToProducts();
    _subscribeToAvailableVariableExpenses();
    _subscribeToWallets();
    _subscribeToOtherExpenses();

    // BƯỚC 4: Thông báo cho toàn bộ UI rằng trạng thái đã thay đổi và sẵn sàng
    notifyListeners();
  }

  // Thay thế hàm switchActiveUser cũ bằng phiên bản này
  Future<void> switchActiveUser(String newActiveUserId) async {
    if (activeUserId == newActiveUserId) return; // Không thay đổi thì không làm gì

    if (newActiveUserId != authUserId) {
      try {
        final ownerDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(newActiveUserId)
            .get();

        // Đọc trường isPremium từ Firestore (được cập nhật bởi Cloud Function)
        final bool isOwnerSubscribed = ownerDoc.data()?['isPremium'] ?? false;

        if (!isOwnerSubscribed) {
          print("Access Denied: Owner account is not subscribed.");
          return;
        }
      } catch (e) {
        print("Error checking owner subscription status: $e");
        // Dừng lại nếu có lỗi xảy ra khi kiểm tra
        return;
      }
    }
    // === KẾT THÚC THAY ĐỔI ===

    // Nếu việc kiểm tra vượt qua, tiếp tục logic cũ như bình thường
    activeUserId = newActiveUserId;
    mainRevenue = 0.0;
    secondaryRevenue = 0.0;
    otherRevenue = 0.0;
    _fixedExpense = 0.0;
    variableExpense = 0.0;
    _cachedDateKey = null;
    _cachedData = null;
    _cancelRevenueSubscription();
    _cancelFixedExpenseSubscription();
    _cancelVariableExpenseSubscription();
    _cancelDailyFixedExpenseSubscription();
    _cancelProductsSubscription();
    _cancelVariableExpenseListSubscription();
    _cancelPermissionSubscription();
    _cancelOtherExpenseSubscription();

    _subscribeToPermissions();
    await _loadInitialData();
    _subscribeToFixedExpenses();
    _subscribeToVariableExpenses();
    _subscribeToDailyFixedExpenses();
    _subscribeToDailyData();
    _subscribeToProducts();
    _subscribeToAvailableVariableExpenses();
    _subscribeToWallets();
    _subscribeToOtherExpenses();
    notifyListeners();
  }

  // HÀM MỚI (private): Chịu trách nhiệm dọn dẹp TOÀN BỘ trạng thái và dữ liệu local.
  Future<void> _clearAllLocalStateAndData() async {
    // 1. Hủy tất cả các stream subscriptions đang hoạt động
    _cancelRevenueSubscription();
    _cancelFixedExpenseSubscription();
    _cancelVariableExpenseSubscription();
    _cancelDailyFixedExpenseSubscription();
    _cancelDailyDataSubscription();
    _cancelProductsSubscription();
    _cancelVariableExpenseListSubscription();
    _cancelPermissionSubscription();
    _cancelWalletsSubscription();
    _cancelOtherExpenseSubscription();

    // 2. Reset tất cả các biến trạng thái về giá trị mặc định
    authUserId = null;
    activeUserId = null;
    _isSubscribed = false;
    _subscriptionExpiryDate = null;
    _selectedScreenIndex = 0;
    activeUserPermissions = {};
    permissionVersion.value = 0;
    _selectedDate = DateTime.now();
    selectedDateListenable.value = DateTime.now();
    isLoadingListenable.value = false;
    dataReadyListenable.value = false;
    mainRevenue = 0.0;
    secondaryRevenue = 0.0;
    otherRevenue = 0.0;
    mainRevenueListenable.value = 0.0;
    secondaryRevenueListenable.value = 0.0;
    otherRevenueListenable.value = 0.0;
    totalRevenueListenable.value = 0.0;
    profitListenable.value = 0.0;
    profitMarginListenable.value = 0.0;
    _fixedExpense = 0.0;
    variableExpense = 0.0;
    otherExpense = 0.0;
    fixedExpenseListenable.value = 0.0;
    fixedExpenseList.value = [];
    variableExpenseList.value = [];
    mainRevenueTransactions.value = [];
    secondaryRevenueTransactions.value = [];
    otherRevenueTransactions.value = [];
    wallets.value = [];
    otherExpenseTransactions.value = [];
    _userDisplayNames.clear();
    productsUpdated.value = false;
    _isLoading = false;
    _isLoadingRevenue = false;
    _cachedDateKey = null;
    _cachedData = null;

    // 3. Dọn dẹp tất cả các Hive box
    try {
      final boxesToClear = [
        'productsBox', 'transactionsBox', 'revenueBox',
        'fixedExpensesBox', 'variableExpensesBox', 'variableExpenseListBox',
        'monthlyFixedExpensesBox', 'monthlyFixedAmountsBox', 'settingsBox'
      ];
      for (var boxName in boxesToClear) {
        if (Hive.isBoxOpen(boxName)) {
          await Hive.box(boxName).clear();
        }
      }
    } catch (e) {
      print("Lỗi khi dọn dẹp Hive boxes: $e");
    }

    print("====== Toàn bộ trạng thái và dữ liệu local đã được dọn dẹp. ======");
  }

  // HÀM MỚI (public): Thay thế hàm performFullLogout cũ.
  // Đây là hàm duy nhất mà UI sẽ gọi để đăng xuất.
  Future<void> performFullLogout() async {
    // Ngăn chặn việc gọi lại khi đang xử lý để tránh xung đột
    if (_isLoggingOut) return;

    // Bật cờ, thông báo cho UI (vd: LoginScreen) để khóa nút bấm
    _isLoggingOut = true;
    notifyListeners();
    print("Bắt đầu quy trình đăng xuất, khóa UI.");

    // Giữ lại ID người dùng để thực hiện các tác vụ cuối cùng
    final String? userIdToLogOut = authUserId;

    try {
      // TÁC VỤ 1: Cập nhật Firestore (cần ID người dùng)
      if (userIdToLogOut != null) {
        // Gán thời gian chờ 5 giây cho tác vụ này
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userIdToLogOut)
            .update({'lastLoginDeviceId': null})
            .timeout(const Duration(seconds: 5));
      }

      // TÁC VỤ 2: Đăng xuất khỏi các dịch vụ bên ngoài một cách song song
      // để tiết kiệm thời gian, với tổng thời gian chờ là 8 giây.
      await Future.wait([
        GoogleSignIn().disconnect(),
        Purchases.logOut(),
        FirebaseAuth.instance.signOut(), // Đây là lệnh quan trọng nhất
      ]).timeout(const Duration(seconds: 8));

      print("Đã đăng xuất thành công khỏi các dịch vụ bên ngoài.");

    } catch (e) {
      print("Đã xảy ra lỗi hoặc timeout trong quá trình đăng xuất: $e");
      // TÁC VỤ BẢO VỆ: Dù có lỗi gì, phải đảm bảo người dùng đã đăng xuất khỏi Firebase
      // vì đây là thứ điều khiển AuthWrapper.
      try {
        if (FirebaseAuth.instance.currentUser != null) {
          await FirebaseAuth.instance.signOut();
        }
      } catch (safeguardError) {
        print("Lỗi khi thực hiện đăng xuất bảo vệ: $safeguardError");
      }
    } finally {
      // TÁC VỤ 3 (LUÔN ĐƯỢC THỰC THI): Dọn dẹp cục bộ
      await _clearAllLocalStateAndData();

      // TÁC VỤ 4 (LUÔN ĐƯỢC THỰC THI): Mở khóa UI
      // Đây là bước quan trọng nhất để giải quyết lỗi treo nút
      _isLoggingOut = false;
      notifyListeners();
      print("Kết thúc quy trình đăng xuất, mở khóa UI.");
    }
  }


  String getKey(String baseKey) {
    return activeUserId != null ? '${activeUserId}_$baseKey' : baseKey;
  }

  /// Lấy tên hiển thị từ cache. Nếu không có, trả về một chuỗi tạm thời.
  String getUserDisplayName(String? uid) {
    if (uid == null) return 'Không rõ';
    return _userDisplayNames[uid] ?? 'Đang tải...';
  }

  /// Tải tên của các user nếu chưa có trong cache.
  Future<void> fetchDisplayNames(Set<String> uids) async {
    // Lọc ra những UID chưa có trong cache
    final uidsToFetch = uids.where((uid) => !_userDisplayNames.containsKey(uid)).toSet();

    // Nếu không có UID nào mới cần tải, thì không làm gì cả
    if (uidsToFetch.isEmpty) {
      return;
    }

    print("Đang tải tên cho các UID: $uidsToFetch");

    // Chia nhỏ để tránh giới hạn 10 của mệnh đề 'whereIn' nếu cần
    List<Future<QuerySnapshot>> futures = [];
    List<String> uidsList = uidsToFetch.toList();
    for (var i = 0; i < uidsList.length; i += 10) {
      var sublist = uidsList.sublist(i, i + 10 > uidsList.length ? uidsList.length : i + 10);
      if (sublist.isNotEmpty) {
        futures.add(FirebaseFirestore.instance
            .collection('users')
            .where(FieldPath.documentId, whereIn: sublist)
            .get());
      }
    }

    // Thực hiện tất cả các truy vấn
    final snapshots = await Future.wait(futures);

    bool hasNewNames = false;
    for (var snapshot in snapshots) {
      for (var doc in snapshot.docs) {
        // Lấy dữ liệu một cách an toàn vào một biến tạm
        final data = doc.data() as Map<String, dynamic>?;

        // Sử dụng toán tử ?. để truy cập an toàn và ?? để cung cấp giá trị mặc định
        _userDisplayNames[doc.id] = data?['displayName'] as String? ?? 'Người dùng ẩn danh';

        hasNewNames = true;
      }
    }

    // Nếu có tên mới được tải về, thông báo cho UI để cập nhật
    if (hasNewNames) {
      notifyListeners();
    }
  }

  void setSelectedDate(DateTime date) {
    if (_selectedDate.year != date.year ||
        _selectedDate.month != date.month ||
        _selectedDate.day != date.day) {
      _selectedDate = date;
      selectedDateListenable.value = date; // Cập nhật ValueNotifier để các widget khác biết

      _cancelVariableExpenseSubscription();
      _cancelDailyFixedExpenseSubscription();
      _cancelDailyDataSubscription();
      _cancelFixedExpenseSubscription();
      _cancelVariableExpenseListSubscription();
      _cancelOtherExpenseSubscription();

      _subscribeToFixedExpenses();
      _subscribeToVariableExpenses();
      _subscribeToDailyFixedExpenses();
      _subscribeToDailyData();
      _subscribeToAvailableVariableExpenses();
      _subscribeToOtherExpenses();

      // Chỉ cần notifyListeners() để các widget không dùng ValueNotifier cập nhật nếu có.
      notifyListeners();
    }
  }

  // Trong file appstate.docx, sửa lại hàm _loadInitialData
  Future<void> _loadInitialData() async {
    if (activeUserId == null || _isLoading || !_isFirebaseInitialized) {
      return;
    }
    _isLoading = true;
    isLoadingListenable.value = true;
    dataReadyListenable.value = false;

    try {
      // Bây giờ chỉ cần tải doanh thu và chi phí biến đổi
      // Chi phí cố định sẽ được listener tự động tải
      await Future.wait([

        loadExpenseValues(), // Hàm này giờ chỉ tải chi phí biến đổi
      ]);

    } catch (e) {
      print('Error in _loadInitialData: $e');
    } finally {
      _isLoading = false;
      isLoadingListenable.value = false;
      dataReadyListenable.value = true; // Báo hiệu dữ liệu đã sẵn sàng
      // không cần notifyListeners() ở đây vì các hàm con đã gọi
    }
  }

  Future<void> initializeData() async {
    await _loadInitialData();
  }

  void _applyCachedData(Map<String, dynamic> data) {
    mainRevenue = data['mainRevenue'] as double;
    secondaryRevenue = data['secondaryRevenue'] as double;
    otherRevenue = data['otherRevenue'] as double;
    mainRevenueListenable.value = mainRevenue;
    secondaryRevenueListenable.value = secondaryRevenue;
    otherRevenueListenable.value = otherRevenue;
    mainRevenueTransactions.value = List<Map<String, dynamic>>.from(data['mainRevenueTransactions']);
    secondaryRevenueTransactions.value = List<Map<String, dynamic>>.from(data['secondaryRevenueTransactions']);
    otherRevenueTransactions.value = List<Map<String, dynamic>>.from(data['otherRevenueTransactions']);
    _fixedExpense = data['fixedExpense'] as double;
    variableExpense = data['variableExpense'] as double;
    fixedExpenseListenable.value = _fixedExpense;
    fixedExpenseList.value = List<Map<String, dynamic>>.from(data['fixedExpenseList']);
    variableExpenseList.value = List<Map<String, dynamic>>.from(data['variableExpenseList']);
    totalRevenueListenable.value = getTotalRevenue();
    profitListenable.value = getProfit();
    profitMarginListenable.value = getProfitMargin();
    notifyListeners();
    dataReadyListenable.value = true;
  }

  void _subscribeToPermissions() {
    _cancelPermissionSubscription(); // Luôn hủy listener cũ

    if (isOwner()) {
      activeUserPermissions = {};
      permissionVersion.value++; // Báo hiệu sự thay đổi
      return;
    }

    _permissionSubscription = FirebaseFirestore.instance
        .collection('users').doc(activeUserId)
        .collection('permissions').doc(authUserId)
        .snapshots()
        .listen((snapshot) {
      print("Real-time permission update received!");
      if (snapshot.exists && snapshot.data()?['permissions'] != null) {
        activeUserPermissions = Map<String, bool>.from(snapshot.data()!['permissions']);
      } else {
        activeUserPermissions = {};
      }

      permissionVersion.value++;
    }, onError: (error) {
      print("Lỗi khi lắng nghe quyền: $error");
      activeUserPermissions = {};
      permissionVersion.value++;
    });
  }

  void notifyProductsUpdated() {
    productsUpdated.value = !productsUpdated.value;
    notifyListeners();
  }

  void _cancelRevenueSubscription() {
    _revenueSubscription?.cancel();
    _revenueSubscription = null;
  }

  void _cancelFixedExpenseSubscription() {
    _fixedExpenseSubscription?.cancel();
    _fixedExpenseSubscription = null;
  }

  void _cancelVariableExpenseSubscription() {
    _variableExpenseSubscription?.cancel();
    _variableExpenseSubscription = null;
  }

  void _cancelVariableExpenseListSubscription() {
    _variableExpenseListSubscription?.cancel();
    _variableExpenseListSubscription = null;
  }

  void _cancelPermissionSubscription() {
    _permissionSubscription?.cancel();
    _permissionSubscription = null;
  }

  void _subscribeToAvailableVariableExpenses() {
    if (!_isFirebaseInitialized || activeUserId == null) return;

    _cancelVariableExpenseListSubscription(); // Hủy listener cũ

    final firestore = FirebaseFirestore.instance;
    final String monthKey = DateFormat('yyyy-MM').format(_selectedDate);
    final String firestoreDocKey = getKey('variableExpenseList_$monthKey');
    final String hiveKey = '$activeUserId-variableExpenseList-$monthKey';

    print("Bắt đầu lắng nghe DS chi phí biến đổi cho user: $activeUserId, tháng: $monthKey");

    _variableExpenseListSubscription = firestore
        .collection('users').doc(activeUserId)
        .collection('expenses').doc('variableList')
        .collection('monthly').doc(firestoreDocKey)
        .snapshots()
        .listen((snapshot) async {
      if (snapshot.metadata.hasPendingWrites) {
        return;
      }

      print("Phát hiện thay đổi DS chi phí biến đổi từ Firestore!");
      List<Map<String, dynamic>> expenses = [];
      if (snapshot.exists && snapshot.data()?['products'] != null) {
        expenses = List<Map<String, dynamic>>.from(snapshot.data()!['products']);
      }

      // Cập nhật cache trên Hive
      if (!Hive.isBoxOpen('variableExpenseListBox')) {
        await Hive.openBox('variableExpenseListBox');
      }
      final variableExpenseListBox = Hive.box('variableExpenseListBox');
      await variableExpenseListBox.put(hiveKey, expenses);

      // Thông báo cho UI cập nhật. Ta có thể dùng lại notifier của products.
      notifyProductsUpdated();

    }, onError: (error) {
      print("Lỗi khi lắng nghe DS chi phí biến đổi: $error");
    });
  }

  void _cancelProductsSubscription() {
    _productsSubscription?.cancel();
    _productsSubscription = null;
  }

  void _subscribeToProducts() {
    if (!_isFirebaseInitialized || activeUserId == null) return;

    _cancelProductsSubscription(); // Luôn hủy listener cũ trước khi tạo mới

    print("Bắt đầu lắng nghe thay đổi sản phẩm cho user: $activeUserId");
    final firestore = FirebaseFirestore.instance;

    _productsSubscription = firestore
        .collection('users')
        .doc(activeUserId)
        .collection('products')
        .snapshots() // Lắng nghe toàn bộ collection 'products'
        .listen((snapshot) async {
      // Bỏ qua các thay đổi đang chờ ghi từ chính client này để tránh vòng lặp
      if (snapshot.metadata.hasPendingWrites) {
        return;
      }

      print("Phát hiện thay đổi trong danh sách sản phẩm từ Firestore!");
      if (!Hive.isBoxOpen('productsBox')) {
        await Hive.openBox('productsBox');
      }
      var productsBox = Hive.box('productsBox');

      // Cập nhật cache cho từng loại sản phẩm (chính và phụ)
      for (var doc in snapshot.docs) {
        final productList = List<Map<String, dynamic>>.from(doc.data()['products'] ?? []);
        String hiveStorageKey = '';

        // Xác định đúng key cho Hive cache dựa trên ID của document
        if (doc.id == getKey('mainProductList')) {
          hiveStorageKey = getKey('Doanh thu chính_productList');
        } else if (doc.id == getKey('extraProductList')) {
          hiveStorageKey = getKey('Doanh thu phụ_productList');
        }

        if (hiveStorageKey.isNotEmpty) {
          await productsBox.put(hiveStorageKey, productList);
          print("Đã cập nhật cache cho: $hiveStorageKey");
        }
      }

      // Quan trọng: Thông báo cho UI rằng dữ liệu sản phẩm đã được cập nhật
      notifyProductsUpdated();

    }, onError: (error) {
      print("Lỗi khi lắng nghe danh sách sản phẩm: $error");
    });
  }

  // Dành cho file appstate.docx
  void _subscribeToFixedExpenses() {
    if (!_isFirebaseInitialized || activeUserId == null) return;
    _cancelFixedExpenseSubscription();
    final firestore = FirebaseFirestore.instance;
    String monthKey = DateFormat('yyyy-MM').format(_selectedDate);
    _fixedExpenseSubscription = firestore
        .collection('users').doc(activeUserId)
        .collection('expenses').doc('fixed')
        .collection('monthly').doc(monthKey)
        .snapshots()
        .listen((snapshot) async {

      // <<< THÊM DÒNG KIỂM TRA NÀY VÀO ĐÂY
      if (snapshot.metadata.hasPendingWrites) {
        return;
      }

      if (snapshot.exists) {
        var data = snapshot.data()!;
        var currentFixedExpenses = fixedExpenseList.value;
        var newFixedExpenses = List<Map<String, dynamic>>.from(data['products'] ?? []);
        if (!_areListsEqual(currentFixedExpenses, newFixedExpenses)) {
          await _updateHiveFixedExpenses(data);
          await loadExpenseValues();
          notifyListeners();
        }
      }
    });
  }

  // Dành cho file appstate.docx
  void _subscribeToDailyData() {
    if (!_isFirebaseInitialized || activeUserId == null) return;
    _dailyDataSubscription?.cancel();
    final firestore = FirebaseFirestore.instance;
    String dateKey = DateFormat('yyyy-MM-dd').format(_selectedDate);
    String dailyDocPath = 'users/$activeUserId/daily_data/${getKey(dateKey)}';
    _dailyDataSubscription = firestore.doc(dailyDocPath).snapshots().listen((snapshot) {

      // <<< THÊM DÒNG KIỂM TRA NÀY VÀO ĐÂY
      if (snapshot.metadata.hasPendingWrites) {
        return;
      }

      if (snapshot.exists && snapshot.data() != null) {
        final data = snapshot.data()!;
        mainRevenue = (data['mainRevenue'] as num?)?.toDouble() ?? 0.0;
        secondaryRevenue = (data['secondaryRevenue'] as num?)?.toDouble() ?? 0.0;
        otherRevenue = (data['otherRevenue'] as num?)?.toDouble() ?? 0.0;
        mainRevenueTransactions.value = List<Map<String, dynamic>>.from(data['mainRevenueTransactions'] ?? []);
        secondaryRevenueTransactions.value = List<Map<String, dynamic>>.from(data['secondaryRevenueTransactions'] ?? []);
        otherRevenueTransactions.value = List<Map<String, dynamic>>.from(data['otherRevenueTransactions'] ?? []);
      } else {
        mainRevenue = 0.0;
        secondaryRevenue = 0.0;
        otherRevenue = 0.0;
        mainRevenueTransactions.value = [];
        secondaryRevenueTransactions.value = [];
        otherRevenueTransactions.value = [];
        walletAdjustments.value = [];
      }
      _updateProfitAndRelatedListenables();
      notifyListeners();
    }, onError: (error) {
      print("Lỗi lắng nghe daily_data: $error");
    });
  }

  void _cancelDailyDataSubscription() {
    _dailyDataSubscription?.cancel();
    _dailyDataSubscription = null;
  }

  // Dành cho file appstate.docx
  void _subscribeToVariableExpenses() {
    if (!_isFirebaseInitialized || activeUserId == null) return;
    _cancelVariableExpenseSubscription();
    final firestore = FirebaseFirestore.instance;
    String dateKeyForDoc = DateFormat('yyyy-MM-dd').format(_selectedDate);
    String dailyVariableExpenseDocId = getKey('variableTransactionHistory_$dateKeyForDoc');
    _variableExpenseSubscription = firestore
        .collection('users').doc(activeUserId)
        .collection('expenses').doc('variable')
        .collection('daily').doc(dailyVariableExpenseDocId)
        .snapshots()
        .listen((snapshot) async {

      // <<< THÊM DÒNG KIỂM TRA NÀY VÀO ĐÂY
      if (snapshot.metadata.hasPendingWrites) {
        return;
      }

      if (snapshot.exists && snapshot.data() != null) {
        var data = snapshot.data()!;
        List<Map<String, dynamic>> newExpenses = List<Map<String, dynamic>>.from(data['variableExpenses'] ?? []);
        double newTotal = (data['total'] as num?)?.toDouble() ?? 0.0;
        if (!_areListsEqual(variableExpenseList.value, newExpenses) || variableExpense != newTotal) {
          variableExpenseList.value = newExpenses;
          this.variableExpense = newTotal;
          final String hiveKey = '$activeUserId-variableExpenses-$dailyVariableExpenseDocId';
          final variableExpensesBox = Hive.box('variableExpensesBox');
          await variableExpensesBox.put(hiveKey, newExpenses);
          _updateProfitAndRelatedListenables();
          notifyListeners();
        }
      } else {
        if (variableExpenseList.value.isNotEmpty || variableExpense != 0.0) {
          variableExpenseList.value = [];
          this.variableExpense = 0.0;
          notifyListeners();
          _updateProfitAndRelatedListenables();
        }
      }
    }, onError: (error) {
      print('Error listening to variable expenses: $error');
    });
  }

  // Dành cho file appstate.docx
  void _subscribeToDailyFixedExpenses() {
    if (!_isFirebaseInitialized || activeUserId == null) return;
    _dailyFixedExpenseSubscription?.cancel();
    final firestore = FirebaseFirestore.instance;
    String dateKey = DateFormat('yyyy-MM-dd').format(_selectedDate);
    String dailyFixedExpenseDocId = getKey('fixedExpenseList_$dateKey');
    final String hiveKey = '$activeUserId-fixedExpenses-$dailyFixedExpenseDocId';
    final fixedExpensesBox = Hive.box('fixedExpensesBox');

    _dailyFixedExpenseSubscription = firestore
        .collection('users').doc(activeUserId)
        .collection('expenses').doc('fixed')
        .collection('daily').doc(dailyFixedExpenseDocId)
        .snapshots()
        .listen((snapshot) async {

      // <<< THÊM DÒNG KIỂM TRA NÀY VÀO ĐÂY
      if (snapshot.metadata.hasPendingWrites) {
        return;
      }

      if (snapshot.exists && snapshot.data() != null) {
        var data = snapshot.data()!;
        List<Map<String, dynamic>> newExpenses = List<Map<String, dynamic>>.from(data['fixedExpenses'] ?? []);
        double newTotal = (data['total'] as num?)?.toDouble() ?? 0.0;
        if (!_areListsEqual(fixedExpenseList.value, newExpenses) || _fixedExpense != newTotal) {
          fixedExpenseList.value = newExpenses;
          _fixedExpense = newTotal;
          fixedExpenseListenable.value = newTotal;
          await fixedExpensesBox.put(hiveKey, newExpenses);
          _updateProfitAndRelatedListenables();
          notifyListeners();
        }
      } else {
        if (fixedExpenseList.value.isNotEmpty || _fixedExpense != 0.0) {
          fixedExpenseList.value = [];
          _fixedExpense = 0.0;
          fixedExpenseListenable.value = 0.0;
          await fixedExpensesBox.delete(hiveKey);
          _updateProfitAndRelatedListenables();
          notifyListeners();
        }
      }
    }, onError: (error) {
      print('Error listening to daily fixed expenses: $error');
    });
  }

  void _cancelDailyFixedExpenseSubscription() {
    _dailyFixedExpenseSubscription?.cancel();
    _dailyFixedExpenseSubscription = null;
  }

// Hàm phụ để so sánh hai danh sách
  bool _areListsEqual(List<Map<String, dynamic>> list1, List<Map<String, dynamic>> list2) {
    if (list1.length != list2.length) return false;
    for (int i = 0; i < list1.length; i++) {
      if (list1[i].length != list2[i].length) return false;
      for (var key in list1[i].keys) {
        if (list2[i][key] != list1[i][key]) return false;
      }
    }
    return true;
  }

  Future<void> _updateHiveFixedExpenses(Map<String, dynamic> data) async {
    try {
      var monthlyFixedExpensesBox = Hive.box('monthlyFixedExpensesBox');
      var monthlyFixedAmountsBox = Hive.box('monthlyFixedAmountsBox');
      String monthKey = DateFormat('yyyy-MM').format(_selectedDate);
      await monthlyFixedExpensesBox.put('${activeUserId}-fixedExpenseList-$monthKey', data['products'] ?? []);
      await monthlyFixedAmountsBox.put('${activeUserId}-monthlyFixedAmounts-$monthKey', data['amounts'] ?? {});
      await _updateSyncTimestamp('${activeUserId}-fixedExpenseList-$monthKey');
    } catch (e) {
      print('Lỗi khi cập nhật Hive chi phí cố định: $e');
    }
  }

  Future<bool> _isFirestoreSynced(String hiveKey, String firestorePath) async {
    if (!_isFirebaseInitialized) return false;
    try {
      var revenueBox = Hive.box('revenueBox');
      var hiveData = revenueBox.get(getKey('sync_timestamps')) as Map<dynamic, dynamic>?;
      DateTime? hiveTimestamp = hiveData != null && hiveData[hiveKey] != null
          ? DateTime.parse(hiveData[hiveKey] as String)
          : null;

      final firestore = FirebaseFirestore.instance;
      final doc = await firestore.doc(firestorePath).get();
      Timestamp? firestoreTimestamp = doc.exists ? doc['updatedAt'] as Timestamp? : null;

      if (hiveTimestamp == null || firestoreTimestamp == null) {
        return hiveTimestamp == null && firestoreTimestamp == null;
      }

      return hiveTimestamp.isAtSameMomentAs(firestoreTimestamp.toDate()) ||
          hiveTimestamp.isAfter(firestoreTimestamp.toDate());
    } catch (e) {
      return false;
    }
  }

  Future<void> _updateSyncTimestamp(String hiveKey) async {
    try {
      // === THÊM MỚI: Mở box cần thiết ===
      if (!Hive.isBoxOpen('revenueBox')) {
        await Hive.openBox('revenueBox');
      }
      // ===================================
      var revenueBox = Hive.box('revenueBox'); //
      var syncTimestamps = (revenueBox.get(getKey('sync_timestamps')) as Map<dynamic, dynamic>?) ?? {}; //
      syncTimestamps[hiveKey] = DateTime.now().toIso8601String(); //
      await revenueBox.put(getKey('sync_timestamps'), syncTimestamps); //
    } catch (e) {
      print('Lỗi khi cập nhật timestamp đồng bộ: $e'); //
    }
  }

  Future<bool> _isOnline() async {
    if (!_isFirebaseInitialized) return false;
    try {
      return await FirebaseFirestore.instance
          .collection('users')
          .doc(activeUserId)
          .get()
          .timeout(Duration(seconds: 10), onTimeout: () => throw TimeoutException('Network timeout'))
          .then((_) => true);
    } catch (e) {
      return false;
    }
  }

  Future<void> loadRevenueValues() async {
    if (_isLoadingRevenue || !_isFirebaseInitialized) {
      return;
    }
    _isLoadingRevenue = true;
    final startTime = DateTime.now();
    try {
      if (activeUserId == null) {
        _resetRevenueValues();
        return;
      }

      if (!Hive.isBoxOpen('revenueBox')) await Hive.openLazyBox('revenueBox');
      if (!Hive.isBoxOpen('transactionsBox')) await Hive.openLazyBox('transactionsBox');
      var revenueBox = Hive.box('revenueBox');
      var transactionsBox = Hive.box('transactionsBox');

      String dateKey = DateFormat('yyyy-MM-dd').format(_selectedDate);
      String revenueKey = getKey(dateKey);
      String mainTransKey = getKey('${dateKey}_mainRevenueTransactions');
      String secondaryTransKey = getKey('${dateKey}_secondaryRevenueTransactions');
      String otherTransKey = getKey('${dateKey}_otherTransKey');
      String firestorePath = 'users/$activeUserId/daily_data/$revenueKey';

      // Kiểm tra thời gian đồng bộ từ Hive
      var syncTimestamps = revenueBox.get(getKey('sync_timestamps')) as Map<dynamic, dynamic>?;
      DateTime? lastSync = syncTimestamps != null && syncTimestamps[revenueKey] != null
          ? DateTime.parse(syncTimestamps[revenueKey] as String)
          : null;
      if (lastSync != null && DateTime.now().difference(lastSync).inMinutes < 5) {
        // Nếu dữ liệu mới được đồng bộ trong 5 phút, dùng dữ liệu từ Hive
        var revenueData = await revenueBox.get(revenueKey) as Map<dynamic, dynamic>?;
        if (revenueData != null) {
          mainRevenue = revenueData['mainRevenue']?.toDouble() ?? 0.0;
          secondaryRevenue = revenueData['secondaryRevenue']?.toDouble() ?? 0.0;
          otherRevenue = revenueData['otherRevenue']?.toDouble() ?? 0.0;
          mainRevenueListenable.value = mainRevenue;
          secondaryRevenueListenable.value = secondaryRevenue;
          otherRevenueListenable.value = otherRevenue;

          var mainData = await transactionsBox.get(mainTransKey);
          mainRevenueTransactions.value = mainData != null
              ? (mainData as List<dynamic>)
              .map((item) => (item as Map<dynamic, dynamic>).map((key, value) => MapEntry(key.toString(), value)))
              .cast<Map<String, dynamic>>()
              .toList()
              : [];

          var secondaryData = await transactionsBox.get(secondaryTransKey);
          secondaryRevenueTransactions.value = secondaryData != null
              ? (secondaryData as List<dynamic>)
              .map((item) => (item as Map<dynamic, dynamic>).map((key, value) => MapEntry(key.toString(), value)))
              .cast<Map<String, dynamic>>()
              .toList()
              : [];

          var otherData = await transactionsBox.get(otherTransKey);
          otherRevenueTransactions.value = otherData != null
              ? (otherData as List<dynamic>)
              .map((item) => (item as Map<dynamic, dynamic>).map((key, value) => MapEntry(key.toString(), value)))
              .cast<Map<String, dynamic>>()
              .toList()
              : [];
          _updateProfitAndRelatedListenables();
          return;
        }
      }

      // Tải từ Firestore nếu dữ liệu không mới
      bool useHive = false;
      if (await _isOnline()) {
        int retries = 3;
        DocumentSnapshot? doc;
        for (int i = 0; i < retries; i++) {
          try {
            doc = await FirebaseFirestore.instance
                .doc(firestorePath)
                .get()
                .timeout(Duration(seconds: 15));
            break;
          } catch (e) {
            if (i == retries - 1) {
              useHive = true;
              break;
            }
            await Future.delayed(Duration(seconds: 1));
          }
        }

        if (!useHive && doc != null && doc.exists) {
          mainRevenue = doc['mainRevenue']?.toDouble() ?? 0.0;
          secondaryRevenue = doc['secondaryRevenue']?.toDouble() ?? 0.0;
          otherRevenue = doc['otherRevenue']?.toDouble() ?? 0.0;
          mainRevenueListenable.value = mainRevenue;
          secondaryRevenueListenable.value = secondaryRevenue;
          otherRevenueListenable.value = otherRevenue;
          mainRevenueTransactions.value = List<Map<String, dynamic>>.from(doc['mainRevenueTransactions'] ?? []);
          secondaryRevenueTransactions.value = List<Map<String, dynamic>>.from(doc['secondaryRevenueTransactions'] ?? []);
          otherRevenueTransactions.value = List<Map<String, dynamic>>.from(doc['otherRevenueTransactions'] ?? []);

          await revenueBox.put(revenueKey, {
            'mainRevenue': mainRevenue,
            'secondaryRevenue': secondaryRevenue,
            'otherRevenue': otherRevenue,
            'lastUpdated': DateTime.now().toIso8601String(),
          });
          await transactionsBox.put(mainTransKey, mainRevenueTransactions.value);
          await transactionsBox.put(secondaryTransKey, secondaryRevenueTransactions.value);
          await transactionsBox.put(otherTransKey, otherRevenueTransactions.value);
          await _updateSyncTimestamp(mainTransKey);
          await _updateSyncTimestamp(secondaryTransKey);
          await _updateSyncTimestamp(otherTransKey);
        } else {
          _resetRevenueValues();
        }
      } else {
        useHive = true;
      }

      if (useHive || revenueBox.containsKey(revenueKey)) {
        var revenueData = await revenueBox.get(revenueKey) as Map<dynamic, dynamic>?;
        if (revenueData != null) {
          mainRevenue = revenueData['mainRevenue']?.toDouble() ?? 0.0;
          secondaryRevenue = revenueData['secondaryRevenue']?.toDouble() ?? 0.0;
          otherRevenue = revenueData['otherRevenue']?.toDouble() ?? 0.0;
          mainRevenueListenable.value = mainRevenue;
          secondaryRevenueListenable.value = secondaryRevenue;
          otherRevenueListenable.value = otherRevenue;

          var mainData = await transactionsBox.get(mainTransKey);
          mainRevenueTransactions.value = mainData != null
              ? (mainData as List<dynamic>)
              .map((item) => (item as Map<dynamic, dynamic>).map((key, value) => MapEntry(key.toString(), value)))
              .cast<Map<String, dynamic>>()
              .toList()
              : [];

          var secondaryData = await transactionsBox.get(secondaryTransKey);
          secondaryRevenueTransactions.value = secondaryData != null
              ? (secondaryData as List<dynamic>)
              .map((item) => (item as Map<dynamic, dynamic>).map((key, value) => MapEntry(key.toString(), value)))
              .cast<Map<String, dynamic>>()
              .toList()
              : [];

          var otherData = await transactionsBox.get(otherTransKey);
          otherRevenueTransactions.value = otherData != null
              ? (otherData as List<dynamic>)
              .map((item) => (item as Map<dynamic, dynamic>).map((key, value) => MapEntry(key.toString(), value)))
              .cast<Map<String, dynamic>>()
              .toList()
              : [];
        }
      }

      if (!await _isFirestoreSynced(mainTransKey, firestorePath)) {
        await RevenueManager.saveTransactionHistory(this, 'Doanh thu chính', mainRevenueTransactions.value);
        await _updateSyncTimestamp(mainTransKey);
      }
      if (!await _isFirestoreSynced(secondaryTransKey, firestorePath)) {
        await RevenueManager.saveTransactionHistory(this, 'Doanh thu phụ', secondaryRevenueTransactions.value);
        await _updateSyncTimestamp(secondaryTransKey);
      }
      if (!await _isFirestoreSynced(otherTransKey, firestorePath)) {
        await RevenueManager.saveOtherRevenueTransactions(this, otherRevenueTransactions.value);
        await _updateSyncTimestamp(otherTransKey);
      }
      _updateProfitAndRelatedListenables();
    } catch (e) {
      _resetRevenueValues();
      _updateProfitAndRelatedListenables();
      print('Lỗi khi tải giá trị doanh thu: $e');
    } finally {
      _isLoadingRevenue = false;
      print('loadRevenueValues took ${DateTime.now().difference(startTime).inMilliseconds}ms');
    }
  }

  void _resetRevenueValues() {
    mainRevenue = 0.0;
    secondaryRevenue = 0.0;
    otherRevenue = 0.0;
    mainRevenueListenable.value = 0.0;
    secondaryRevenueListenable.value = 0.0;
    otherRevenueListenable.value = 0.0;
    totalRevenueListenable.value = 0.0;
    profitListenable.value = 0.0;
    profitMarginListenable.value = 0.0;
    mainRevenueTransactions.value = [];
    secondaryRevenueTransactions.value = [];
    otherRevenueTransactions.value = [];
  }

  Future<void> syncWithFirestore() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) return;

    // === THÊM MỚI: Mở tất cả các box cần cho việc đồng bộ ===
    if (!Hive.isBoxOpen('fixedExpensesBox')) await Hive.openBox('fixedExpensesBox');
    if (!Hive.isBoxOpen('variableExpensesBox')) await Hive.openBox('variableExpensesBox');
    if (!Hive.isBoxOpen('variableExpenseListBox')) await Hive.openBox('variableExpenseListBox');
    if (!Hive.isBoxOpen('monthlyFixedExpensesBox')) await Hive.openBox('monthlyFixedExpensesBox');
    if (!Hive.isBoxOpen('monthlyFixedAmountsBox')) await Hive.openBox('monthlyFixedAmountsBox');
    // ========================================================

    final fixedExpensesBox = Hive.box('fixedExpensesBox');
    final variableExpensesBox = Hive.box('variableExpensesBox');
    final variableExpenseListBox = Hive.box('variableExpenseListBox');
    final monthlyFixedExpensesBox = Hive.box('monthlyFixedExpensesBox');
    final monthlyFixedAmountsBox = Hive.box('monthlyFixedAmountsBox');
    // ...
  }

  Future<void> _syncFixedExpensesFromFirestore() async {
    if (!_isFirebaseInitialized || activeUserId == null) return;
    try {
      String monthKey = DateFormat('yyyy-MM').format(_selectedDate);
      var doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(activeUserId)
          .collection('expenses')
          .doc('fixed')
          .collection('monthly')
          .doc(monthKey)
          .get();
      if (doc.exists) {
        await _updateHiveFixedExpenses(doc.data()!);
      }
    } catch (e) {
      print('Lỗi khi đồng bộ chi phí cố định từ Firestore: $e');
    }
  }


  Future<void> loadExpenseValues() async {
    // Hàm này giờ chỉ tập trung vào Chi phí biến đổi (Variable Expenses)
    // vì Chi phí cố định đã được xử lý bởi listener _subscribeToDailyFixedExpenses
    final String dateKey = DateFormat('yyyy-MM-dd').format(selectedDate);
    final String firestoreDailyVariableDocId = getKey('variableTransactionHistory_$dateKey');
    final String hiveVariableKey = '$activeUserId-variableExpenses-$firestoreDailyVariableDocId';
    if (!Hive.isBoxOpen('variableExpensesBox')) {
      await Hive.openBox('variableExpensesBox');
    }
    final variableExpensesBox = Hive.box('variableExpensesBox');

    List<Map<String, dynamic>> safeCast(List<dynamic>? data) {
      if (data == null) return [];
      try {
        return data.map((item) {
          final map = item as Map;
          return map.map((key, value) => MapEntry(key.toString(), value));
        }).toList().cast<Map<String, dynamic>>();
      } catch (e) {
        print('Error safely casting variable expenses from Hive: $e');
        return [];
      }
    }

    try {
      // Luôn ưu tiên tải từ Firestore nếu online để đảm bảo dữ liệu mới nhất
      if (await _isOnline()) {
        final variableExpenses = await ExpenseManager.loadVariableExpenses(this);
        variableExpenseList.value = variableExpenses;
        await variableExpensesBox.put(hiveVariableKey, variableExpenses);
      } else {
        // Nếu offline, tải từ cache Hive
        final cachedData = variableExpensesBox.get(hiveVariableKey) as List?;
        variableExpenseList.value = safeCast(cachedData);
      }
    } catch (e) {
      print("Error loading variable expense values: $e");
      // Fallback về cache nếu có lỗi
      final cachedDataOnError = variableExpensesBox.get(hiveVariableKey) as List?;
      variableExpenseList.value = safeCast(cachedDataOnError);
    }

    final variableTotal = variableExpenseList.value.fold<double>(0.0, (sum, e) => sum + (e['amount']?.toDouble() ?? 0.0));

    // Cập nhật giá trị tổng chi phí biến đổi
    this.variableExpense = variableTotal;

    _updateProfitAndRelatedListenables();
    notifyListeners();
  }

  Future<void> setRevenue(double main, double secondary, double other) async {
    if (!_isFirebaseInitialized) throw Exception('Firebase not initialized');
    try {
      if (activeUserId == null) throw Exception('User ID không tồn tại');
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      String dateKey = DateFormat('yyyy-MM-dd').format(_selectedDate);
      String revenueKey = getKey(dateKey);
      String mainTransKey = getKey('${dateKey}_mainRevenueTransactions');
      String secondaryTransKey = getKey('${dateKey}_secondaryRevenueTransactions');
      String otherTransKey = getKey('${dateKey}_otherRevenueTransactions');

      mainRevenue = main;
      secondaryRevenue = secondary;
      otherRevenue = other;
      mainRevenueListenable.value = main;
      secondaryRevenueListenable.value = secondary;
      otherRevenueListenable.value = other;

      double totalRevenue = main + secondary + other;
      final fixedDocFuture = firestore
          .collection('users')
          .doc(activeUserId)
          .collection('expenses')
          .doc('fixed')
          .collection('daily')
          .doc(getKey('fixedExpenseList_$dateKey'))
          .get();
      final variableDocFuture = firestore
          .collection('users')
          .doc(activeUserId)
          .collection('expenses')
          .doc('variable')
          .collection('daily')
          .doc(getKey('variableTransactionHistory_$dateKey'))
          .get();

      final results = await Future.wait([fixedDocFuture, variableDocFuture]);
      double fixedExpense = results[0].exists ? results[0]['total']?.toDouble() ?? 0.0 : 0.0;
      double variableExpense = results[1].exists ? results[1]['total']?.toDouble() ?? 0.0 : 0.0;
      _fixedExpense = fixedExpense;
      fixedExpenseListenable.value = fixedExpense;
      this.variableExpense = variableExpense;

      double totalExpense = fixedExpense + variableExpense;
      double profit = totalRevenue - totalExpense;
      double profitMargin = totalRevenue > 0 ? (profit / totalRevenue) * 100 : 0;

      List<Map<String, dynamic>> standardizedMain = mainRevenueTransactions.value.map((t) {
        return {
          "id": t['id'],
          'name': t['name'].toString(),
          'price': t['price'] as num? ?? 0.0,
          'total': t['total'] as num? ?? 0.0,
          'quantity': t['quantity'] as num? ?? 1.0,
          'date': t['date']?.toString() ?? DateTime.now().toIso8601String(),
          'unitVariableCost': (t['unitVariableCost'] as num?)?.toDouble() ?? 0.0,
          'totalVariableCost': (t['totalVariableCost'] as num?)?.toDouble() ?? 0.0,
          if (t.containsKey('cogsSourceType')) 'cogsSourceType': t['cogsSourceType'], // Không có _Secondary
          if (t.containsKey('cogsWasFlexible')) 'cogsWasFlexible': t['cogsWasFlexible'],
          if (t.containsKey('cogsDefaultCostAtTimeOfSale')) 'cogsDefaultCostAtTimeOfSale': t['cogsDefaultCostAtTimeOfSale'],
          if (t.containsKey('cogsComponentsUsed')) 'cogsComponentsUsed': t['cogsComponentsUsed'],
          if (t.containsKey('createdBy')) 'createdBy': t['createdBy'],
        };
      }).toList();
      List<Map<String, dynamic>> standardizedSecondary = secondaryRevenueTransactions.value.map((t) {
        return {
          "id": t['id'],
          'name': t['name'].toString(),
          'price': t['price'] as num? ?? 0.0,
          'total': t['total'] as num? ?? 0.0,
          'quantity': t['quantity'] as num? ?? 1.0,
          'date': t['date']?.toString() ?? DateTime.now().toIso8601String(),
          'unitVariableCost': (t['unitVariableCost'] as num?)?.toDouble() ?? 0.0,
          'totalVariableCost': (t['totalVariableCost'] as num?)?.toDouble() ?? 0.0,
          if (t.containsKey('cogsSourceType_Secondary')) 'cogsSourceType_Secondary': t['cogsSourceType_Secondary'],
          if (t.containsKey('cogsWasFlexible_Secondary')) 'cogsWasFlexible_Secondary': t['cogsWasFlexible_Secondary'],
          if (t.containsKey('cogsDefaultCostAtTimeOfSale_Secondary')) 'cogsDefaultCostAtTimeOfSale_Secondary': t['cogsDefaultCostAtTimeOfSale_Secondary'],
          if (t.containsKey('cogsComponentsUsed_Secondary')) 'cogsComponentsUsed_Secondary': t['cogsComponentsUsed_Secondary'],
          if (t.containsKey('createdBy')) 'createdBy': t['createdBy'],
        };
      }).toList();
      List<Map<String, dynamic>> standardizedOther = otherRevenueTransactions.value.map((t) {
        return {
          'name': t['name'].toString(),
          'price': t['price'] as num? ?? 0.0,
          'total': t['total'] as num? ?? 0.0,
          'quantity': t['quantity'] as num? ?? 1.0,
          'date': t['date']?.toString() ?? DateTime.now().toIso8601String(),
          if (t.containsKey('createdBy')) 'createdBy': t['createdBy'],
        };
      }).toList();

      await firestore
          .collection('users')
          .doc(activeUserId)
          .collection('daily_data')
          .doc(getKey(dateKey))
          .set({
        'mainRevenue': main,
        'secondaryRevenue': secondary,
        'otherRevenue': other,
        'totalRevenue': totalRevenue,
        'mainRevenueTransactions': standardizedMain,
        'secondaryRevenueTransactions': standardizedSecondary,
        'otherRevenueTransactions': standardizedOther,
        'profit': profit,
        'profitMargin': profitMargin,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      var revenueBox = Hive.box('revenueBox');
      var transactionsBox = Hive.box('transactionsBox');
      await revenueBox.put(revenueKey, {
        'mainRevenue': main,
        'secondaryRevenue': secondary,
        'otherRevenue': other,
        'lastUpdated': DateTime.now().toIso8601String(),
      });
      await transactionsBox.put(mainTransKey, standardizedMain);
      await transactionsBox.put(secondaryTransKey, standardizedSecondary);
      await transactionsBox.put(otherTransKey, standardizedOther);
      await _updateSyncTimestamp(mainTransKey);
      await _updateSyncTimestamp(secondaryTransKey);
      await _updateSyncTimestamp(otherTransKey);

      totalRevenueListenable.value = totalRevenue;
      profitListenable.value = profit;
      profitMarginListenable.value = profitMargin;
      _cachedDateKey = dateKey;
      _cachedData = {
        'mainRevenue': main,
        'secondaryRevenue': secondary,
        'otherRevenue': other,
        'mainRevenueTransactions': standardizedMain,
        'secondaryRevenueTransactions': standardizedSecondary,
        'otherRevenueTransactions': standardizedOther,
        'fixedExpense': fixedExpense,
        'variableExpense': variableExpense,
        'fixedExpenseList': fixedExpenseList.value,
        'variableExpenseList': variableExpenseList.value,
      };
      notifyListeners();
    } catch (e) {
      throw Exception('Không thể lưu doanh thu: $e');
    }
  }

  Map<String, List<model.Transaction>> transactions = {
    'Doanh thu chính': [],
    'Doanh thu phụ': [],
    'Doanh thu khác': [],
  };

  Future<List<Map<String, dynamic>>> loadVariableExpenseList() async {
    try {
      if (activeUserId == null || !_isFirebaseInitialized) return [];
      return await ExpenseManager.loadAvailableVariableExpenses(this);
    } catch (e) {
      return [];
    }
  }

  // Dán hàm mới này vào trong class AppState (appstate.docx)

  Future<void> addTransactionAndUpdateState({
    required String category,
    required Map<String, dynamic> newSalesTransaction,
    required List<Map<String, dynamic>> autoGeneratedCogs,
    // --- Tham số MỚI ---
    required bool isCashReceived,
    String? walletId,
  }) async {
    // 1. CẬP NHẬT TRẠNG THÁI LOCAL (OPTIMISTIC UPDATE)
    if (isCashReceived && walletId != null) {
      newSalesTransaction['walletId'] = walletId;
      newSalesTransaction['paymentStatus'] = 'paid'; // Trạng thái: Đã thanh toán
    } else {
      newSalesTransaction['paymentStatus'] = 'unpaid'; // Trạng thái: Chưa thanh toán
    }
    if (category == 'Doanh thu chính') {
      mainRevenueTransactions.value.add(newSalesTransaction);
      mainRevenueTransactions.value = List.from(mainRevenueTransactions.value);
    } else if (category == 'Doanh thu phụ') {
      secondaryRevenueTransactions.value.add(newSalesTransaction);
      secondaryRevenueTransactions.value = List.from(secondaryRevenueTransactions.value);
    }
    if (autoGeneratedCogs.isNotEmpty) {
      variableExpenseList.value.addAll(autoGeneratedCogs);
      variableExpenseList.value = List.from(variableExpenseList.value);
    }

    // 2. TÍNH TOÁN LẠI TẤT CẢ CÁC TỔNG
    mainRevenue = mainRevenueTransactions.value.fold(0.0, (sum, e) => sum + (e['total']?.toDouble() ?? 0.0));
    secondaryRevenue = secondaryRevenueTransactions.value.fold(0.0, (sum, e) => sum + (e['total']?.toDouble() ?? 0.0));
    otherRevenue = otherRevenueTransactions.value.fold(0.0, (sum, e) => sum + (e['total']?.toDouble() ?? 0.0));
    variableExpense = variableExpenseList.value.fold(0.0, (sum, e) => sum + (e['amount']?.toDouble() ?? 0.0));

    if (isCashReceived && walletId != null) {
      final index = wallets.value.indexWhere((w) => w['id'] == walletId);
      if (index != -1) {
        final wallet = wallets.value[index];
        final currentBalance = (wallet['balance'] as num?)?.toDouble() ?? 0.0;
        final transactionAmount = (newSalesTransaction['total'] as num?)?.toDouble() ?? 0.0;

        // Tạo một bản sao của ví với số dư mới
        final updatedWallet = Map<String, dynamic>.from(wallet);
        updatedWallet['balance'] = currentBalance + transactionAmount;

        // Cập nhật lại danh sách ví
        wallets.value[index] = updatedWallet;
        // Gán một List mới để ValueNotifier nhận biết sự thay đổi
        wallets.value = List.from(wallets.value);
      }
    }

    // 3. CẬP NHẬT TẤT CẢ VALUE NOTIFIER VÀ GỌI NOTIFYLISTENERS() MỘT LẦN
    _updateProfitAndRelatedListenables();
    notifyListeners();

    // 4. LƯU DỮ LIỆU LÊN FIRESTORE DÙNG WRITEBATCH
    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();

    // Tác vụ 1: Lưu dữ liệu dồn tích (daily_data)
    await _saveAllDailyDataToFirestore(batch: batch); // Sửa hàm này để nhận batch

    // Tác vụ 2: Lưu chi phí biến đổi
    if (autoGeneratedCogs.isNotEmpty) {
      await ExpenseManager.saveVariableExpenses(this, variableExpenseList.value, batch: batch); // Sửa hàm này để nhận batch
    }

    // Tác vụ 3: Cập nhật số dư ví nếu "Thực thu"
    if (isCashReceived && walletId != null) {
      final walletRef = firestore.collection('users').doc(activeUserId).collection('wallets').doc(walletId);
      double transactionAmount = newSalesTransaction['total'] as double;
      batch.update(walletRef, {'balance': FieldValue.increment(transactionAmount)});
    }

    // Thực thi toàn bộ các tác vụ
    await batch.commit();
  }

  // Dán hàm mới này vào trong class AppState (appstate.docx)



  // Dán hàm mới này vào trong class AppState (appstate.docx)

  Future<void> editTransactionAndUpdateState({
    required String category,
    required Map<String, dynamic> originalTransaction,
    required Map<String, dynamic> updatedTransaction,
    required List<Map<String, dynamic>> newCogsTransactions,
  }) async {
    final String? transactionId = updatedTransaction['id'] as String?;
    if (transactionId == null) {
      throw Exception("Không thể sửa giao dịch không có ID.");
    }

    // 1. Tính toán chênh lệch doanh thu
    final double oldTotal = (originalTransaction['total'] as num?)?.toDouble() ?? 0.0;
    final double newTotal = (updatedTransaction['total'] as num?)?.toDouble() ?? 0.0;
    final double delta = newTotal - oldTotal;
    final String? walletId = originalTransaction['walletId'] as String?;
    final bool wasPaid = originalTransaction['paymentStatus'] == 'paid';

    // 2. Chuẩn bị cập nhật cho Firestore
    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();

    // 3. Cập nhật số dư ví trên Firestore nếu cần
    if (wasPaid && walletId != null && delta != 0) {
      final walletRef = firestore.collection('users').doc(activeUserId).collection('wallets').doc(walletId);
      batch.update(walletRef, {'balance': FieldValue.increment(delta)});
    }

    // --- BẮT ĐẦU BỔ SUNG: CẬP NHẬT SỐ DƯ VÍ Ở LOCAL STATE ---
    if (wasPaid && walletId != null && delta != 0) {
      final walletIndex = wallets.value.indexWhere((w) => w['id'] == walletId);
      if (walletIndex != -1) {
        final wallet = wallets.value[walletIndex];
        final currentBalance = (wallet['balance'] as num?)?.toDouble() ?? 0.0;
        final updatedWallet = Map<String, dynamic>.from(wallet);
        updatedWallet['balance'] = currentBalance + delta;

        final updatedList = List<Map<String, dynamic>>.from(wallets.value);
        updatedList[walletIndex] = updatedWallet;
        wallets.value = updatedList;
      }
    }
    // --- KẾT THÚC BỔ SUNG ---

    // Các logic còn lại giữ nguyên...
    ValueNotifier<List<Map<String, dynamic>>>? targetRevenueList;
    if (category == 'Doanh thu chính') {
      targetRevenueList = mainRevenueTransactions;
    } else if (category == 'Doanh thu phụ') {
      targetRevenueList = secondaryRevenueTransactions;
    } else if (category == 'Doanh thu khác') {
      targetRevenueList = otherRevenueTransactions;
    }

    final index = targetRevenueList!.value.indexWhere((t) => t['id'] == transactionId);
    if (index != -1) {
      targetRevenueList.value[index] = updatedTransaction;
      targetRevenueList.value = List.from(targetRevenueList.value);
    }

    variableExpenseList.value.removeWhere((expense) => expense['sourceSalesTransactionId'] == transactionId);
    variableExpenseList.value.addAll(newCogsTransactions);
    variableExpenseList.value = List.from(variableExpenseList.value);

    mainRevenue = mainRevenueTransactions.value.fold(0.0, (sum, e) => sum + (e['total']?.toDouble() ?? 0.0));
    secondaryRevenue = secondaryRevenueTransactions.value.fold(0.0, (sum, e) => sum + (e['total']?.toDouble() ?? 0.0));
    otherRevenue = otherRevenueTransactions.value.fold(0.0, (sum, e) => sum + (e['total']?.toDouble() ?? 0.0));
    variableExpense = variableExpenseList.value.fold(0.0, (sum, e) => sum + (e['amount']?.toDouble() ?? 0.0));

    _updateProfitAndRelatedListenables();
    notifyListeners();

    await _saveAllDailyDataToFirestore(batch: batch);
    await ExpenseManager.saveVariableExpenses(this, variableExpenseList.value, batch: batch);
    await batch.commit();
  }

  // Dán 3 hàm mới này vào trong class AppState (appstate.docx)

// Hàm thêm giao dịch "Doanh thu khác"
  Future<void> addOtherRevenueAndUpdateState(
      Map<String, dynamic> newTransaction, {
        // --- THAM SỐ MỚI ---
        required bool isCashReceived,
        String? walletId,
      }) async {
    if (activeUserId == null) return;

    if (isCashReceived && walletId != null) {
      newTransaction['walletId'] = walletId;
      newTransaction['paymentStatus'] = 'paid';
    } else {
      newTransaction['paymentStatus'] = 'unpaid';
    }

    // 1. Cập nhật danh sách local
    otherRevenueTransactions.value.add(newTransaction);
    otherRevenueTransactions.value = List.from(otherRevenueTransactions.value);

    // 2. Tính toán lại TOÀN BỘ các giá trị tổng
    mainRevenue = mainRevenueTransactions.value.fold(0.0, (sum, e) => sum + (e['total']?.toDouble() ?? 0.0));
    secondaryRevenue = secondaryRevenueTransactions.value.fold(0.0, (sum, e) => sum + (e['total']?.toDouble() ?? 0.0));
    otherRevenue = otherRevenueTransactions.value.fold(0.0, (sum, e) => sum + (e['total']?.toDouble() ?? 0.0));
    _fixedExpense = fixedExpenseList.value.fold(0.0, (sum, e) => sum + (e['amount']?.toDouble() ?? 0.0));
    variableExpense = variableExpenseList.value.fold(0.0, (sum, e) => sum + (e['amount']?.toDouble() ?? 0.0));

    if (isCashReceived && walletId != null) {
      final index = wallets.value.indexWhere((w) => w['id'] == walletId);
      if (index != -1) {
        final wallet = wallets.value[index];
        final currentBalance = (wallet['balance'] as num?)?.toDouble() ?? 0.0;
        final transactionAmount = (newTransaction['total'] as num?)?.toDouble() ?? 0.0;

        final updatedWallet = Map<String, dynamic>.from(wallet);
        updatedWallet['balance'] = currentBalance + transactionAmount;

        wallets.value[index] = updatedWallet;
        wallets.value = List.from(wallets.value);
      }
    }

    // 3. Cập nhật Notifier và giao diện một lần
    _updateProfitAndRelatedListenables();
    notifyListeners();

    // 4. Lưu lên server dùng BATCH để đảm bảo đồng bộ
    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();

    try {
      // Tác vụ 1: Lưu dữ liệu dồn tích (daily_data)
      await _saveAllDailyDataToFirestore(batch: batch);

      // Tác vụ 2: Cập nhật số dư ví nếu "Thực thu"
      if (isCashReceived && walletId != null) {
        final walletRef = firestore
            .collection('users')
            .doc(activeUserId)
            .collection('wallets')
            .doc(walletId);
        double transactionAmount = newTransaction['total'] as double;
        batch.update(walletRef, {'balance': FieldValue.increment(transactionAmount)});
      }

      // Thực thi toàn bộ tác vụ
      await batch.commit();
    } catch (e) {
      print("Lỗi khi thêm giao dịch doanh thu khác và cập nhật ví: $e");
    }
  }

  Future<void> collectPaymentForTransaction({
    required String category,
    required Map<String, dynamic> transactionToUpdate,
    required DateTime paymentDate,
    required String walletId,
    required DateTime transactionRecordDate, // THAM SỐ MỚI: Ngày ghi nhận giao dịch
  }) async {
    if (activeUserId == null) throw Exception("User not logged in");

    final String transactionId = transactionToUpdate['id'];
    final double transactionAmount = (transactionToUpdate['total'] as num).toDouble();
    // SỬA ĐỔI Ở ĐÂY: Sử dụng ngày được truyền vào thay vì ngày trong giao dịch
    final DateTime recordDate = transactionRecordDate;
    final firestore = FirebaseFirestore.instance;

    final recordDateKey = DateFormat('yyyy-MM-dd').format(recordDate);
    final docId = getKey(recordDateKey);
    final dailyDataRef = firestore.collection('users').doc(activeUserId).collection('daily_data').doc(docId);
    final walletRef = firestore.collection('users').doc(activeUserId).collection('wallets').doc(walletId);

    print("--- BẮT ĐẦU TRANSACTION ĐỂ THU TIỀN ---");
    print("Sẽ cập nhật tài liệu tại đường dẫn: ${dailyDataRef.path}");
    print("ID giao dịch cần tìm: $transactionId");

    try {
      await firestore.runTransaction((transaction) async {
        final dailySnapshot = await transaction.get(dailyDataRef);
        if (!dailySnapshot.exists) {
          throw Exception("Tài liệu không tồn tại tại đường dẫn: ${dailyDataRef.path}");
        }

        final String field;
        if (category == 'Doanh thu chính') {
          field = 'mainRevenueTransactions';
        } else if (category == 'Doanh thu phụ') {
          field = 'secondaryRevenueTransactions';
        } else {
          field = 'otherRevenueTransactions';
        }

        final List<Map<String, dynamic>> transactionsList = List<Map<String, dynamic>>.from(dailySnapshot.data()?[field] ?? []);
        final int txIndex = transactionsList.indexWhere((t) => t['id'] == transactionId);

        if (txIndex == -1) {
          throw Exception("Không tìm thấy giao dịch với ID '$transactionId' trong tài liệu trên server.");
        }

        transactionsList[txIndex]['paymentStatus'] = 'paid';
        transactionsList[txIndex]['walletId'] = walletId;
        transactionsList[txIndex]['paymentDate'] = paymentDate.toIso8601String();

        transaction.update(dailyDataRef, {field: transactionsList});
        transaction.update(walletRef, {'balance': FieldValue.increment(transactionAmount)});
      });

      print("✅ Firestore Transaction THÀNH CÔNG! Dữ liệu đã được cập nhật trên server.");

      // Đoạn code cập nhật local state giữ nguyên...
      final fullyUpdatedTransaction = Map<String, dynamic>.from(transactionToUpdate);
      fullyUpdatedTransaction['paymentStatus'] = 'paid';
      fullyUpdatedTransaction['walletId'] = walletId;
      fullyUpdatedTransaction['paymentDate'] = paymentDate.toIso8601String();

      final walletIndex = wallets.value.indexWhere((w) => w['id'] == walletId);
      if (walletIndex != -1) {
        final wallet = wallets.value[walletIndex];
        final currentBalance = (wallet['balance'] as num?)?.toDouble() ?? 0.0;
        final updatedWallet = Map<String, dynamic>.from(wallet);
        updatedWallet['balance'] = currentBalance + transactionAmount;
        wallets.value[walletIndex] = updatedWallet;
        wallets.value = List.from(wallets.value);
      }

      ValueNotifier<List<Map<String, dynamic>>>? targetListNotifier;
      if (category == 'Doanh thu chính') {
        targetListNotifier = mainRevenueTransactions;
      } else if (category == 'Doanh thu phụ') {
        targetListNotifier = secondaryRevenueTransactions;
      } else {
        targetListNotifier = otherRevenueTransactions;
      }

      if (targetListNotifier != null) {
        final list = targetListNotifier.value;
        final txIndex = list.indexWhere((t) => t['id'] == transactionId);
        if (txIndex != -1) {
          final newList = List<Map<String, dynamic>>.from(list);
          newList[txIndex] = fullyUpdatedTransaction;
          targetListNotifier.value = newList;
        }
      }
      notifyListeners();

    } catch (e) {
      print("❌ LỖI KHI THỰC THI TRANSACTION: $e");
      throw e;
    }
  }

  Future<List<Map<String, dynamic>>> getTransactionsForWallet(String walletId, DateTime selectedMonth) async {
    if (activeUserId == null) return [];
    final firestore = FirebaseFirestore.instance;
    List<Map<String, dynamic>> walletTransactions = [];

    try {
      // 1. Xác định ngày bắt đầu và kết thúc của tháng được chọn
      final DateTime startDate = DateTime(selectedMonth.year, selectedMonth.month, 1);
      final DateTime endDate = DateTime(selectedMonth.year, selectedMonth.month + 1, 0); // Ngày cuối cùng của tháng

      // 2. Tạo key để truy vấn trong Firestore
      final String startKey = getKey(DateFormat('yyyy-MM-dd').format(startDate));
      final String endKey = getKey(DateFormat('yyyy-MM-dd').format(endDate));

      // 3. Truy vấn tất cả các document daily_data trong khoảng thời gian của tháng
      final querySnapshot = await firestore
          .collection('users')
          .doc(activeUserId)
          .collection('daily_data')
          .where(FieldPath.documentId, isGreaterThanOrEqualTo: startKey)
          .where(FieldPath.documentId, isLessThanOrEqualTo: endKey)
          .get();

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final allTransactions = [
          ...(data['mainRevenueTransactions'] as List? ?? []),
          ...(data['secondaryRevenueTransactions'] as List? ?? []),
          ...(data['otherRevenueTransactions'] as List? ?? []),
          ...(data['walletAdjustments'] as List? ?? []),
          // TODO: Gộp các giao dịch chi phí nếu chúng được liên kết với ví
        ];

        for (var tx in allTransactions) {
          if (tx is Map<String, dynamic> && tx['walletId'] == walletId) {
            // Xác định đây là khoản thu hay chi
            if (tx['category'] == 'Điều chỉnh Ví') {
              tx['isIncome'] = (tx['total'] as num? ?? 0.0) >= 0;
            } else {
              tx['isIncome'] = true; // Mặc định các giao dịch doanh thu là khoản thu
            }
            walletTransactions.add(tx);
          }
        }
      }

      walletTransactions.sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));
      return walletTransactions;
    } catch (e) {
      print("Lỗi khi tải giao dịch của ví theo tháng: $e");
      return [];
    }
  }

  Future<void> createWalletBalanceAdjustment({
    required String walletId,
    required String walletName,
    required double delta, // Khoản chênh lệch
  }) async {
    if (activeUserId == null || delta == 0) return;

    // 1. Tạo đối tượng giao dịch điều chỉnh
    final adjustmentTransaction = {
      'id': Uuid().v4(),
      'name': 'Cập nhật số dư',
      'category': 'Điều chỉnh Ví', // Category mới để nhận biết
      'walletId': walletId,
      'total': delta, // Có thể là số âm hoặc dương
      'date': DateTime.now().toIso8601String(), // Luôn là ngày giờ hiện tại
      'createdBy': authUserId,
    };

    // 2. Cập nhật trạng thái local
    walletAdjustments.value.add(adjustmentTransaction);
    walletAdjustments.value = List.from(walletAdjustments.value);
    notifyListeners(); // Thông báo cho các listener khác nếu cần

    // 3. Lưu lên Firestore
    final firestore = FirebaseFirestore.instance;
    final dateKey = DateFormat('yyyy-MM-dd').format(DateTime.now()); // Luôn lưu vào ngày hiện tại
    final docId = getKey(dateKey);
    final dailyDataRef = firestore.collection('users').doc(activeUserId).collection('daily_data').doc(docId);

    try {
      await dailyDataRef.set({
        'walletAdjustments': FieldValue.arrayUnion([adjustmentTransaction]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print("Lỗi khi tạo giao dịch điều chỉnh ví: $e");
    }
  }

  // THÊM hàm MỚI này vào class AppState
  Future<void> deleteTransactionAndUpdateAll({
    required Map<String, dynamic> transactionToRemove,
  }) async {
    final String? transactionId = transactionToRemove['id'] as String?;
    final String? category = transactionToRemove['category'] as String?;
    if (transactionId == null || category == null) {
      throw Exception("Giao dịch thiếu ID hoặc Category để xóa.");
    }

    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();

    final String? walletId = transactionToRemove['walletId'] as String?;
    final double amountToRevert = (transactionToRemove['total'] as num?)?.toDouble() ?? 0.0;
    final bool wasPaid = transactionToRemove['paymentStatus'] == 'paid';

    // Hoàn tiền vào ví trên Firestore nếu cần
    if (wasPaid && walletId != null) {
      final walletRef = firestore.collection('users').doc(activeUserId).collection('wallets').doc(walletId);
      batch.update(walletRef, {'balance': FieldValue.increment(-amountToRevert)});
    }

    // --- BẮT ĐẦU BỔ SUNG: CẬP NHẬT SỐ DƯ VÍ Ở LOCAL STATE ---
    if (wasPaid && walletId != null) {
      final walletIndex = wallets.value.indexWhere((w) => w['id'] == walletId);
      if (walletIndex != -1) {
        final wallet = wallets.value[walletIndex];
        final currentBalance = (wallet['balance'] as num?)?.toDouble() ?? 0.0;
        final updatedWallet = Map<String, dynamic>.from(wallet);
        updatedWallet['balance'] = currentBalance - amountToRevert;

        final updatedList = List<Map<String, dynamic>>.from(wallets.value);
        updatedList[walletIndex] = updatedWallet;
        wallets.value = updatedList;
      }
    }
    // --- KẾT THÚC BỔ SUNG ---

    // Các logic còn lại giữ nguyên...
    ValueNotifier<List<Map<String, dynamic>>>? targetRevenueList;
    if (category == 'Doanh thu chính') {
      targetRevenueList = mainRevenueTransactions;
    } else if (category == 'Doanh thu phụ') {
      targetRevenueList = secondaryRevenueTransactions;
    } else if (category == 'Doanh thu khác') {
      targetRevenueList = otherRevenueTransactions;
    }

    targetRevenueList?.value.removeWhere((t) => t['id'] == transactionId);
    targetRevenueList?.value = List.from(targetRevenueList.value);

    variableExpenseList.value.removeWhere((expense) => expense['sourceSalesTransactionId'] == transactionId);
    variableExpenseList.value = List.from(variableExpenseList.value);

    mainRevenue = mainRevenueTransactions.value.fold(0.0, (sum, e) => sum + (e['total']?.toDouble() ?? 0.0));
    secondaryRevenue = secondaryRevenueTransactions.value.fold(0.0, (sum, e) => sum + (e['total']?.toDouble() ?? 0.0));
    otherRevenue = otherRevenueTransactions.value.fold(0.0, (sum, e) => sum + (e['total']?.toDouble() ?? 0.0));
    variableExpense = variableExpenseList.value.fold(0.0, (sum, e) => sum + (e['amount']?.toDouble() ?? 0.0));

    _updateProfitAndRelatedListenables();
    notifyListeners();

    await _saveAllDailyDataToFirestore(batch: batch);
    await ExpenseManager.saveVariableExpenses(this, variableExpenseList.value, batch: batch);
    await batch.commit();
  }

  Future<void> saveOrUpdateWallet(Map<String, dynamic> walletData) async {
    if (activeUserId == null) return;

    final isEditing = walletData['createdAt'] is Timestamp;

    // --- BƯỚC 1: CẬP NHẬT GIAO DIỆN LẠC QUAN ---
    // Tạo một bản sao của danh sách ví hiện tại để thao tác
    List<Map<String, dynamic>> updatedList = List.from(wallets.value);

    // Xử lý logic isDefault ngay trên danh sách cục bộ
    if (walletData['isDefault'] == true) {
      for (int i = 0; i < updatedList.length; i++) {
        if (updatedList[i]['isDefault'] == true) {
          // Tạo bản sao và cập nhật
          final tempWallet = Map<String, dynamic>.from(updatedList[i]);
          tempWallet['isDefault'] = false;
          updatedList[i] = tempWallet;
        }
      }
    }

    // Tìm và cập nhật hoặc thêm mới ví
    final index = updatedList.indexWhere((w) => w['id'] == walletData['id']);
    if (index != -1) { // Nếu là sửa
      updatedList[index] = walletData;
    } else { // Nếu là thêm mới
      updatedList.add(walletData);
    }

    // Sắp xếp lại danh sách theo ngày tạo
    updatedList.sort((a, b) => (a['createdAt'] as Timestamp).compareTo(b['createdAt'] as Timestamp));
    print("--- DEBUG APPSTATE: Chuẩn bị gán wallets.value với ${updatedList.length} phần tử."); // <-- THÊM DÒNG NÀY

    // Gán danh sách mới để ValueNotifier nhận biết sự thay đổi và cập nhật UI
    wallets.value = updatedList;
    notifyListeners();

    print("--- DEBUG APPSTATE: Đã gán xong wallets.value.");


    // --- BƯỚC 2: LƯU DỮ LIỆU LÊN FIRESTORE (bất đồng bộ) ---
    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();

    try {
      // Nếu đặt ví này làm mặc định, hãy bỏ mặc định tất cả các ví khác trên server
      if (walletData['isDefault'] == true) {
        final querySnapshot = await firestore
            .collection('users')
            .doc(activeUserId)
            .collection('wallets')
            .where('isDefault', isEqualTo: true)
            .get();

        for (var doc in querySnapshot.docs) {
          if (doc.id != walletData['id']) {
            batch.update(doc.reference, {'isDefault': false});
          }
        }
      }

      // Thêm hoặc cập nhật ví hiện tại vào batch
      final walletRef = firestore
          .collection('users')
          .doc(activeUserId)
          .collection('wallets')
          .doc(walletData['id']);
      batch.set(walletRef, walletData, SetOptions(merge: true));

      // Thực thi batch
      await batch.commit();
    } catch (e) {
      print("Lỗi khi cập nhật ví trên Firestore: $e");
      // Cân nhắc việc hoàn tác lại state nếu có lỗi nghiêm trọng
    }
  }

// Hàm sửa giao dịch "Doanh thu khác"
  Future<void> editOtherRevenueAndUpdateState(int originalIndex, Map<String, dynamic> updatedTransaction) async {
    if (originalIndex < 0 || originalIndex >= otherRevenueTransactions.value.length) return;

    // 1. Cập nhật danh sách local
    otherRevenueTransactions.value[originalIndex] = updatedTransaction;
    otherRevenueTransactions.value = List.from(otherRevenueTransactions.value);

    // 2. Tính toán lại TOÀN BỘ các giá trị tổng
    mainRevenue = mainRevenueTransactions.value.fold(0.0, (sum, e) => sum + (e['total']?.toDouble() ?? 0.0));
    secondaryRevenue = secondaryRevenueTransactions.value.fold(0.0, (sum, e) => sum + (e['total']?.toDouble() ?? 0.0));
    otherRevenue = otherRevenueTransactions.value.fold(0.0, (sum, e) => sum + (e['total']?.toDouble() ?? 0.0));
    _fixedExpense = fixedExpenseList.value.fold(0.0, (sum, e) => sum + (e['amount']?.toDouble() ?? 0.0));
    variableExpense = variableExpenseList.value.fold(0.0, (sum, e) => sum + (e['amount']?.toDouble() ?? 0.0));

    // 3. Cập nhật Notifier và giao diện một lần
    _updateProfitAndRelatedListenables();
    notifyListeners();

    // 4. Lưu lên server
    await _saveAllDailyDataToFirestore();
  }

// Hàm xóa giao dịch "Doanh thu khác"
  Future<void> deleteOtherRevenueAndUpdateState(int originalIndex) async {
    if (originalIndex < 0 || originalIndex >= otherRevenueTransactions.value.length) return;

    // 1. Cập nhật danh sách local
    otherRevenueTransactions.value.removeAt(originalIndex);
    otherRevenueTransactions.value = List.from(otherRevenueTransactions.value);

    // 2. Tính toán lại TOÀN BỘ các giá trị tổng
    mainRevenue = mainRevenueTransactions.value.fold(0.0, (sum, e) => sum + (e['total']?.toDouble() ?? 0.0));
    secondaryRevenue = secondaryRevenueTransactions.value.fold(0.0, (sum, e) => sum + (e['total']?.toDouble() ?? 0.0));
    otherRevenue = otherRevenueTransactions.value.fold(0.0, (sum, e) => sum + (e['total']?.toDouble() ?? 0.0));
    _fixedExpense = fixedExpenseList.value.fold(0.0, (sum, e) => sum + (e['amount']?.toDouble() ?? 0.0));
    variableExpense = variableExpenseList.value.fold(0.0, (sum, e) => sum + (e['amount']?.toDouble() ?? 0.0));

    // 3. Cập nhật Notifier và giao diện một lần
    _updateProfitAndRelatedListenables();
    notifyListeners();

    // 4. Lưu lên server
    await _saveAllDailyDataToFirestore();
  }

  // Dán hàm mới này vào trong class AppState (appstate.docx)

  Future<void> _saveAllDailyDataToFirestore({WriteBatch? batch}) async { // THAY ĐỔI 1: Thêm tham số tùy chọn
    if (activeUserId == null) return;

    bool isExternalBatch = batch != null; // Kiểm tra xem có dùng batch từ bên ngoài không
    final firestore = FirebaseFirestore.instance;
    // Nếu không có batch từ bên ngoài, tự tạo một batch mới
    final localBatch = isExternalBatch ? batch : firestore.batch();

    // --- BẮT ĐẦU SỬA LỖI ---
    // Hàm nội bộ để chuẩn hóa một danh sách giao dịch, đảm bảo các kiểu số là double
    List<Map<String, dynamic>> _standardizeTransactions(List<Map<String, dynamic>> transactions) {
      return transactions.map((t) {
        // Tạo một bản sao của giao dịch gốc để giữ lại tất cả các trường
        final standardizedMap = Map<String, dynamic>.from(t);

        // Ghi đè các trường số để đảm bảo chúng là double
        standardizedMap['price'] = (t['price'] as num?)?.toDouble() ?? 0.0;
        standardizedMap['total'] = (t['total'] as num?)?.toDouble() ?? 0.0;
        standardizedMap['quantity'] = (t['quantity'] as num?)?.toDouble() ?? 1.0;
        standardizedMap['unitVariableCost'] = (t['unitVariableCost'] as num?)?.toDouble() ?? 0.0;
        standardizedMap['totalVariableCost'] = (t['totalVariableCost'] as num?)?.toDouble() ?? 0.0;

        return standardizedMap;
      }).toList();
    }
    // --- KẾT THÚC SỬA LỖI ---

    try {
      String dateKey = DateFormat('yyyy-MM-dd').format(_selectedDate);
      String docPath = 'users/$activeUserId/daily_data/${getKey(dateKey)}';
      final dailyDataRef = firestore.doc(docPath);

      // Chuẩn bị MỘT LẦN DUY NHẤT tất cả dữ liệu cần lưu
      final Map<String, dynamic> dataToSave = {
        // Doanh thu
        'mainRevenue': mainRevenue,
        'secondaryRevenue': secondaryRevenue,
        'otherRevenue': otherRevenue,
        'totalRevenue': getTotalRevenue(),
        // Lợi nhuận
        'profit': getProfit(),
        'profitMargin': getProfitMargin(),
        // Danh sách giao dịch chi tiết (SỬ DỤNG HÀM CHUẨN HÓA)
        'mainRevenueTransactions': _standardizeTransactions(mainRevenueTransactions.value),
        'secondaryRevenueTransactions': _standardizeTransactions(secondaryRevenueTransactions.value),
        'otherRevenueTransactions': _standardizeTransactions(otherRevenueTransactions.value),
        'walletAdjustments': walletAdjustments.value,
        // Dấu thời gian
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // THAY ĐỔI 2: Dùng batch để ghi dữ liệu thay vì .set() trực tiếp
      localBatch.set(dailyDataRef, dataToSave, SetOptions(merge: true));

      // THAY ĐỔI 3: Chỉ commit nếu đây là batch được tạo nội bộ
      if (!isExternalBatch) {
        await localBatch.commit();
      }
    } catch (e) {
      print("Lỗi nghiêm trọng khi lưu daily_data lên Firestore: $e");
      // Bạn có thể thêm xử lý lỗi ở đây nếu cần
    }
  }

  Future<void> deleteWalletAndAssociatedData({
    required Map<String, dynamic> walletToDelete,
  }) async {
    if (activeUserId == null) throw Exception("User not logged in.");

    final String walletIdToDelete = walletToDelete['id'];
    final bool wasDefault = walletToDelete['isDefault'] ?? false;

    // --- BƯỚC 1: CẬP NHẬT TRẠNG THÁI LOCAL ---
    // Lấy danh sách ví hiện tại TRƯỚC khi xóa
    List<Map<String, dynamic>> currentWallets = List.from(wallets.value);
    // Xóa ví khỏi danh sách local
    currentWallets.removeWhere((w) => w['id'] == walletIdToDelete);

    // XỬ LÝ LOGIC VÍ MẶC ĐỊNH MỚI
    if (wasDefault && currentWallets.isNotEmpty) {
      // Tìm ví lâu đời nhất để đặt làm mặc định mới
      currentWallets.sort((a, b) {
        final aTime = a['createdAt'] as Timestamp? ?? Timestamp.now();
        final bTime = b['createdAt'] as Timestamp? ?? Timestamp.now();
        return aTime.compareTo(bTime);
      });
      // Cập nhật ví đầu tiên trong danh sách đã sắp xếp
      final newDefaultWallet = Map<String, dynamic>.from(currentWallets[0]);
      newDefaultWallet['isDefault'] = true;
      currentWallets[0] = newDefaultWallet;
    }

    // Cập nhật giao diện với danh sách ví mới
    wallets.value = currentWallets;
    notifyListeners();

    // --- BƯỚC 2: XÓA DỮ LIỆU NỀN TRÊN FIRESTORE ---
    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();

    // Xử lý gán ví mặc định mới trên server
    if (wasDefault && currentWallets.isNotEmpty) {
      final String newDefaultWalletId = currentWallets[0]['id'];
      final newDefaultWalletRef = firestore.collection('users').doc(activeUserId).collection('wallets').doc(newDefaultWalletId);
      batch.update(newDefaultWalletRef, {'isDefault': true});
    }

    // Lấy và lọc các giao dịch liên quan (logic này giữ nguyên)
    final dailyDataSnapshot = await firestore
        .collection('users')
        .doc(activeUserId)
        .collection('daily_data')
        .get();

    final List<String> transactionFields = [
      'mainRevenueTransactions',
      'secondaryRevenueTransactions',
      'otherRevenueTransactions',
      'walletAdjustments'
    ];

    for (final doc in dailyDataSnapshot.docs) {
      bool needsUpdate = false;
      final Map<String, dynamic> updateData = {};
      for (final field in transactionFields) {
        final List<Map<String, dynamic>> originalList = List<Map<String, dynamic>>.from(doc.data()[field] ?? []);
        if (originalList.isNotEmpty) {
          final List<Map<String, dynamic>> filteredList = originalList
              .where((tx) => tx['walletId'] != walletIdToDelete)
              .toList();
          if (originalList.length != filteredList.length) {
            needsUpdate = true;
            updateData[field] = filteredList;
          }
        }
      }
      if (needsUpdate) {
        batch.update(doc.reference, updateData);
      }
    }

    // Xóa tài liệu của chính ví đó
    final walletRef = firestore.collection('users').doc(activeUserId).collection('wallets').doc(walletIdToDelete);
    batch.delete(walletRef);

    // Thực thi tất cả các thao tác
    await batch.commit();

    // Tải lại dữ liệu của ngày hiện tại để đảm bảo UI nhất quán
    setSelectedDate(DateTime.now());
  }

  Future<void> deleteWalletAdjustment({
    required Map<String, dynamic> adjustmentToRemove,
  }) async {
    if (activeUserId == null) throw Exception("User not logged in.");

    final String transactionId = adjustmentToRemove['id'] as String? ?? '';
    final String walletId = adjustmentToRemove['walletId'] as String? ?? '';
    if (transactionId.isEmpty || walletId.isEmpty) {
      throw Exception("Giao dịch điều chỉnh thiếu ID hoặc Wallet ID.");
    }

    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();

    // --- BƯỚC 1: CẬP NHẬT TRẠNG THÁI LOCAL TRƯỚC TIÊN ---

    // Xóa giao dịch gốc trong danh sách "Chi phí khác" nếu có liên kết
    final String? sourceExpenseId = adjustmentToRemove['sourceExpenseId'] as String?;
    if (sourceExpenseId != null) {
      otherExpenseTransactions.value.removeWhere((e) => e['id'] == sourceExpenseId);
      otherExpenseTransactions.value = List.from(otherExpenseTransactions.value);
      // Tính toán lại tổng chi phí khác
      this.otherExpense = otherExpenseTransactions.value.fold(0.0, (sum, e) => sum + ((e['amount'] as num?)?.toDouble() ?? 0.0));
    }

    // Xóa giao dịch điều chỉnh khỏi danh sách local
    walletAdjustments.value.removeWhere((t) => t['id'] == transactionId);
    walletAdjustments.value = List.from(walletAdjustments.value);

    // Hoàn tiền vào ví local
    final double amountToRevert = -((adjustmentToRemove['total'] as num?)?.toDouble() ?? 0.0);
    final walletIndex = wallets.value.indexWhere((w) => w['id'] == walletId);
    if (walletIndex != -1) {
      final wallet = wallets.value[walletIndex];
      final currentBalance = (wallet['balance'] as num?)?.toDouble() ?? 0.0;
      final updatedWallet = Map<String, dynamic>.from(wallet);
      updatedWallet['balance'] = currentBalance + amountToRevert;

      final updatedList = List<Map<String, dynamic>>.from(wallets.value);
      updatedList[walletIndex] = updatedWallet;
      wallets.value = updatedList;
    }

    // Thông báo cho toàn bộ giao diện cập nhật
    _updateProfitAndRelatedListenables();
    notifyListeners();

    // --- BƯỚC 2: CẬP NHẬT DỮ LIỆU TRÊN FIRESTORE ---

    // Hoàn tiền vào ví trên server
    final walletRef = firestore.collection('users').doc(activeUserId).collection('wallets').doc(walletId);
    batch.update(walletRef, {'balance': FieldValue.increment(amountToRevert)});

    // Xóa giao dịch điều chỉnh khỏi daily_data
    final recordDate = DateTime.parse(adjustmentToRemove['date']);
    final dateKey = DateFormat('yyyy-MM-dd').format(recordDate);
    final docId = getKey(dateKey);
    final dailyDataRef = firestore.collection('users').doc(activeUserId).collection('daily_data').doc(docId);

    // SỬA LỖI Ở ĐÂY: Ghi đè lại toàn bộ danh sách đã được cập nhật ở local
    // thay vì dùng arrayRemove
    batch.update(dailyDataRef, {
      'walletAdjustments': walletAdjustments.value
    });

    // Nếu có giao dịch gốc, lưu lại danh sách chi phí khác đã được cập nhật
    if (sourceExpenseId != null) {
      await ExpenseManager.saveOtherExpenses(this, otherExpenseTransactions.value);
    }

    try {
      await batch.commit();
      print("Đã xóa giao dịch và các dữ liệu liên quan thành công.");
    } catch (e) {
      print("Lỗi khi thực thi xóa trên Firestore: $e");
      // Cân nhắc tải lại dữ liệu từ server nếu có lỗi
    }
  }

  void _subscribeToOtherExpenses() {
    if (!_isFirebaseInitialized || activeUserId == null) return;
    _cancelOtherExpenseSubscription(); // Hủy listener cũ

    String dateKey = DateFormat('yyyy-MM-dd').format(_selectedDate);
    String docId = getKey('otherExpenseList_$dateKey');

    _otherExpenseSubscription = FirebaseFirestore.instance
        .collection('users').doc(activeUserId)
        .collection('expenses').doc('other')
        .collection('daily').doc(docId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.metadata.hasPendingWrites) return;

      if (snapshot.exists && snapshot.data() != null) {
        var data = snapshot.data()!;
        otherExpenseTransactions.value = List<Map<String, dynamic>>.from(data['otherExpenses'] ?? []);
        this.otherExpense = (data['total'] as num?)?.toDouble() ?? 0.0;
      } else {
        otherExpenseTransactions.value = [];
        this.otherExpense = 0.0;
      }
      _updateProfitAndRelatedListenables();
      notifyListeners();
    }, onError: (error) {
      print('Error listening to other expenses: $error');
    });
  }

  void _cancelOtherExpenseSubscription() {
    _otherExpenseSubscription?.cancel();
    _otherExpenseSubscription = null;
  }

  // Dán hàm mới này vào trong class AppState của file appstate.docx
  Future<List<Map<String, dynamic>>> getDailyExpensesWithDetailsForRange(DateTimeRange range) async {
    if (!_isFirebaseInitialized) return [];
    try {
      if (activeUserId == null) return [];
      final FirebaseFirestore firestore = FirebaseFirestore.instance; //
      List<Map<String, dynamic>> dailyData = [];
      int days = range.end.difference(range.start).inDays + 1; //
      List<Future<DocumentSnapshot>> fixedFutures = []; //
      List<Future<DocumentSnapshot>> variableFutures = []; //

      for (int i = 0; i < days; i++) {
        DateTime date = range.start.add(Duration(days: i));
        String dateKey = DateFormat('yyyy-MM-dd').format(date);
        String fixedKey = getKey('fixedExpenseList_$dateKey'); //
        String variableKey = getKey('variableTransactionHistory_$dateKey'); //

        fixedFutures.add(
          firestore
              .collection('users')
              .doc(activeUserId)
              .collection('expenses')
              .doc('fixed')
              .collection('daily')
              .doc(fixedKey)
              .get(), //
        );
        variableFutures.add(
          firestore
              .collection('users')
              .doc(activeUserId)
              .collection('expenses')
              .doc('variable')
              .collection('daily')
              .doc(variableKey)
              .get(), //
        );
      }

      List<DocumentSnapshot> fixedDocs = await Future.wait(fixedFutures); //
      List<DocumentSnapshot> variableDocs = await Future.wait(variableFutures); //

      for (int i = 0; i < days; i++) {
        double fixed = fixedDocs[i].exists ? fixedDocs[i]['total']?.toDouble() ?? 0.0 : 0.0; //
        double variable = variableDocs[i].exists ? variableDocs[i]['total']?.toDouble() ?? 0.0 : 0.0; //

        // Lấy danh sách giao dịch chi tiết từ snapshot
        List<Map<String, dynamic>> fixedTransactions = [];
        if (fixedDocs[i].exists && (fixedDocs[i].data() as Map<String, dynamic>).containsKey('fixedExpenses')) {
          fixedTransactions = List<Map<String, dynamic>>.from(fixedDocs[i]['fixedExpenses'] ?? []); //
        }

        List<Map<String, dynamic>> variableTransactions = [];
        if (variableDocs[i].exists && (variableDocs[i].data() as Map<String, dynamic>).containsKey('variableExpenses')) {
          variableTransactions = List<Map<String, dynamic>>.from(variableDocs[i]['variableExpenses'] ?? []); //
        }

        dailyData.add({
          'fixedExpense': fixed,
          'variableExpense': variable,
          'totalExpense': fixed + variable,
          'transactions': [...fixedTransactions, ...variableTransactions], // Dữ liệu chi tiết được tổng hợp ở đây
        });
      }
      return dailyData;
    } catch (e) {
      print('Error in getDailyExpensesWithDetailsForRange: $e');
      return [];
    }
  }

  // Dán hàm mới này vào trong class AppState của file appstate.docx
  Future<List<Map<String, dynamic>>> getDailyRevenueWithDetailsForRange(DateTimeRange range) async {
    if (!_isFirebaseInitialized) return [];
    try {
      if (activeUserId == null) return [];
      final FirebaseFirestore firestore = FirebaseFirestore.instance; //
      List<Map<String, dynamic>> dailyData = [];
      int days = range.end.difference(range.start).inDays + 1; //
      List<Future<DocumentSnapshot>> futures = []; //

      for (int i = 0; i < days; i++) {
        DateTime date = range.start.add(Duration(days: i));
        String dateKey = DateFormat('yyyy-MM-dd').format(date);
        futures.add(
          firestore
              .collection('users')
              .doc(activeUserId)
              .collection('daily_data')
              .doc(getKey(dateKey))
              .get(), //
        );
      }

      List<DocumentSnapshot> docs = await Future.wait(futures); //
      for (var doc in docs) {
        if (doc.exists) {
          double mainRevenue = doc['mainRevenue']?.toDouble() ?? 0.0; //
          double secondaryRevenue = doc['secondaryRevenue']?.toDouble() ?? 0.0; //
          double otherRevenue = doc['otherRevenue']?.toDouble() ?? 0.0; //

          List<Map<String, dynamic>> mainTransactions = List<Map<String, dynamic>>.from(doc['mainRevenueTransactions'] ?? []); //
          List<Map<String, dynamic>> secondaryTransactions = List<Map<String, dynamic>>.from(doc['secondaryRevenueTransactions'] ?? []); //
          List<Map<String, dynamic>> otherTransactions = List<Map<String, dynamic>>.from(doc['otherRevenueTransactions'] ?? []);

          dailyData.add({
            'mainRevenue': mainRevenue,
            'secondaryRevenue': secondaryRevenue,
            'otherRevenue': otherRevenue,
            'totalRevenue': mainRevenue + secondaryRevenue + otherRevenue,
            'transactions': [...mainTransactions, ...secondaryTransactions, ...otherTransactions], // Dữ liệu chi tiết được tổng hợp ở đây
          });
        } else {
          dailyData.add({
            'mainRevenue': 0.0,
            'secondaryRevenue': 0.0,
            'otherRevenue': 0.0,
            'totalRevenue': 0.0,
            'transactions': [],
          });
        }
      }
      return dailyData;
    } catch (e) {
      print('Error in getDailyRevenueWithDetailsForRange: $e');
      return [];
    }
  }

  Future<void> setExpenses(double fixed, double variable) async {
    if (!_isFirebaseInitialized) throw Exception('Firebase not initialized');
    try {
      if (activeUserId == null) throw Exception('User ID không tồn tại');
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      String dateKey = DateFormat('yyyy-MM-dd').format(_selectedDate);
      _fixedExpense = fixed;
      fixedExpenseListenable.value = fixed;
      variableExpense = variable;
      await firestore
          .collection('users')
          .doc(activeUserId)
          .collection('expenses')
          .doc('fixed')
          .collection('daily')
          .doc(getKey('fixedExpenseList_$dateKey'))
          .update({'total': fixed, 'updatedAt': FieldValue.serverTimestamp()});
      await firestore
          .collection('users')
          .doc(activeUserId)
          .collection('expenses')
          .doc('variable')
          .collection('daily')
          .doc(getKey('variableTransactionHistory_$dateKey'))
          .update({'total': variable, 'updatedAt': FieldValue.serverTimestamp()});
      double totalRevenue = getTotalRevenue();
      double totalExpense = fixed + variable;
      double profit = totalRevenue - totalExpense;
      double profitMargin = totalRevenue > 0 ? (profit / totalRevenue) * 100 : 0;
      await firestore
          .collection('users')
          .doc(activeUserId)
          .collection('daily_data')
          .doc(getKey(dateKey))
          .set({
        'profit': profit,
        'profitMargin': profitMargin,
        'totalRevenue': totalRevenue,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      totalRevenueListenable.value = totalRevenue;
      profitListenable.value = profit;
      profitMarginListenable.value = profitMargin;
      _cachedDateKey = dateKey;
      _cachedData = {
        'mainRevenue': mainRevenue,
        'secondaryRevenue': secondaryRevenue,
        'otherRevenue': otherRevenue,
        'mainRevenueTransactions': mainRevenueTransactions.value,
        'secondaryRevenueTransactions': secondaryRevenueTransactions.value,
        'otherRevenueTransactions': otherRevenueTransactions.value,
        'fixedExpense': fixed,
        'variableExpense': variable,
        'fixedExpenseList': fixedExpenseList.value,
        'variableExpenseList': variableExpenseList.value,
      };
      notifyListeners();
    } catch (e) {
      throw Exception('Không thể lưu chi phí: $e');
    }
  }

  Future<Map<String, double>> getRevenueForRange(DateTimeRange range) async {
    if (!_isFirebaseInitialized) return {'mainRevenue': 0.0, 'secondaryRevenue': 0.0, 'otherRevenue': 0.0, 'totalRevenue': 0.0};
    try {
      if (activeUserId == null) return {'mainRevenue': 0.0, 'secondaryRevenue': 0.0, 'otherRevenue': 0.0, 'totalRevenue': 0.0};
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      double mainRevenueTotal = 0.0;
      double secondaryRevenueTotal = 0.0;
      double otherRevenueTotal = 0.0;
      int days = range.end.difference(range.start).inDays + 1;

      List<Future<DocumentSnapshot>> futures = [];

      for (int i = 0; i < days; i++) {
        DateTime date = range.start.add(Duration(days: i));
        String dateKey = DateFormat('yyyy-MM-dd').format(date);
        futures.add(
          firestore
              .collection('users')
              .doc(activeUserId)
              .collection('daily_data')
              .doc(getKey(dateKey))
              .get(),
        );
      }

      List<DocumentSnapshot> docs = await Future.wait(futures);

      for (var doc in docs) {
        if (doc.exists) {
          mainRevenueTotal += doc['mainRevenue']?.toDouble() ?? 0.0;
          secondaryRevenueTotal += doc['secondaryRevenue']?.toDouble() ?? 0.0;
          otherRevenueTotal += doc['otherRevenue']?.toDouble() ?? 0.0;
        }
      }

      return {
        'mainRevenue': mainRevenueTotal,
        'secondaryRevenue': secondaryRevenueTotal,
        'otherRevenue': otherRevenueTotal,
        'totalRevenue': mainRevenueTotal + secondaryRevenueTotal + otherRevenueTotal,
      };
    } catch (e) {
      return {'mainRevenue': 0.0, 'secondaryRevenue': 0.0, 'otherRevenue': 0.0, 'totalRevenue': 0.0};
    }
  }

  Future<Map<String, List<TimeSeriesChartData>>> getDailyRevenueForRange(DateTimeRange range) async {
    if (!_isFirebaseInitialized || activeUserId == null) return {}; //

    try {
      final FirebaseFirestore firestore = FirebaseFirestore.instance; //
      int days = range.end.difference(range.start).inDays + 1; //
      List<Future<DocumentSnapshot>> futures = []; //

      for (int i = 0; i < days; i++) {
        DateTime date = range.start.add(Duration(days: i)); //
        String dateKey = DateFormat('yyyy-MM-dd').format(date); //
        futures.add(
          firestore.collection('users').doc(activeUserId).collection('daily_data').doc(getKey(dateKey)).get(), //
        );
      }

      List<DocumentSnapshot> docs = await Future.wait(futures); //

      // *** THAY ĐỔI QUAN TRỌNG: Chuẩn bị các list cho từng series dữ liệu ***
      List<TimeSeriesChartData> mainSeries = [];
      List<TimeSeriesChartData> secondarySeries = [];
      List<TimeSeriesChartData> otherSeries = [];
      List<TimeSeriesChartData> totalSeries = [];

      for (int i = 0; i < docs.length; i++) {
        DateTime currentDate = range.start.add(Duration(days: i));
        final doc = docs[i];

        double mainRevenue = doc.exists ? doc['mainRevenue']?.toDouble() ?? 0.0 : 0.0; //
        double secondaryRevenue = doc.exists ? doc['secondaryRevenue']?.toDouble() ?? 0.0 : 0.0; //
        double otherRevenue = doc.exists ? doc['otherRevenue']?.toDouble() ?? 0.0 : 0.0; //
        double totalRevenue = mainRevenue + secondaryRevenue + otherRevenue; //

        mainSeries.add(TimeSeriesChartData(currentDate, mainRevenue));
        secondarySeries.add(TimeSeriesChartData(currentDate, secondaryRevenue));
        otherSeries.add(TimeSeriesChartData(currentDate, otherRevenue));
        totalSeries.add(TimeSeriesChartData(currentDate, totalRevenue));
      }

      return {
        'main': mainSeries,
        'secondary': secondarySeries,
        'other': otherSeries,
        'total': totalSeries,
      };

    } catch (e) {
      print('Error in getDailyRevenueForRange: $e');
      return {}; //
    }
  }

  Future<Map<String, double>> getExpensesForRange(DateTimeRange range) async {
    if (!_isFirebaseInitialized) return {'fixedExpense': 0.0, 'variableExpense': 0.0, 'otherExpense': 0.0, 'totalExpense': 0.0};
    try {
      if (activeUserId == null) return {'fixedExpense': 0.0, 'variableExpense': 0.0, 'otherExpense': 0.0, 'totalExpense': 0.0};
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      double fixedExpenseTotal = 0.0;
      double variableExpenseTotal = 0.0;
      double otherExpenseTotal = 0.0; // <<< THÊM MỚI
      int days = range.end.difference(range.start).inDays + 1;
      List<Future<DocumentSnapshot>> fixedFutures = [];
      List<Future<DocumentSnapshot>> variableFutures = [];
      List<Future<DocumentSnapshot>> otherFutures = []; // <<< THÊM MỚI

      for (int i = 0; i < days; i++) {
        DateTime date = range.start.add(Duration(days: i));
        String dateKey = DateFormat('yyyy-MM-dd').format(date);
        String fixedKey = getKey('fixedExpenseList_$dateKey');
        String variableKey = getKey('variableTransactionHistory_$dateKey');
        String otherKey = getKey('otherExpenseList_$dateKey'); // <<< THÊM MỚI

        fixedFutures.add(firestore.collection('users').doc(activeUserId).collection('expenses').doc('fixed').collection('daily').doc(fixedKey).get());
        variableFutures.add(firestore.collection('users').doc(activeUserId).collection('expenses').doc('variable').collection('daily').doc(variableKey).get());
        otherFutures.add(firestore.collection('users').doc(activeUserId).collection('expenses').doc('other').collection('daily').doc(otherKey).get()); // <<< THÊM MỚI
      }

      List<DocumentSnapshot> fixedDocs = await Future.wait(fixedFutures);
      List<DocumentSnapshot> variableDocs = await Future.wait(variableFutures);
      List<DocumentSnapshot> otherDocs = await Future.wait(otherFutures); // <<< THÊM MỚI

      for (int i = 0; i < days; i++) {
        fixedExpenseTotal += fixedDocs[i].exists ? fixedDocs[i]['total']?.toDouble() ?? 0.0 : 0.0;
        variableExpenseTotal += variableDocs[i].exists ? variableDocs[i]['total']?.toDouble() ?? 0.0 : 0.0;
        otherExpenseTotal += otherDocs[i].exists ? otherDocs[i]['total']?.toDouble() ?? 0.0 : 0.0; // <<< THÊM MỚI
      }

      return {
        'fixedExpense': fixedExpenseTotal,
        'variableExpense': variableExpenseTotal,
        'otherExpense': otherExpenseTotal, // <<< THÊM MỚI
        'totalExpense': fixedExpenseTotal + variableExpenseTotal + otherExpenseTotal, // <<< CẬP NHẬT TỔNG
      };
    } catch (e) {
      return {'fixedExpense': 0.0, 'variableExpense': 0.0, 'otherExpense': 0.0, 'totalExpense': 0.0};
    }
  }

  Future<List<Map<String, dynamic>>> getExpenseBreakdown(DateTimeRange range) async {
    if (!_isFirebaseInitialized || activeUserId == null) return [];
    try {
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      List<Map<String, dynamic>> detailedBreakdown = []; // Danh sách kết quả mới
      int days = range.end.difference(range.start).inDays + 1;

      // Tạo danh sách các future để lấy dữ liệu đồng thời
      List<Future<DocumentSnapshot>> fixedFutures = [];
      List<Future<DocumentSnapshot>> variableFutures = [];
      List<Future<DocumentSnapshot>> otherFutures = [];

      for (int i = 0; i < days; i++) {
        DateTime date = range.start.add(Duration(days: i));
        String dateKey = DateFormat('yyyy-MM-dd').format(date);
        String fixedKey = getKey('fixedExpenseList_$dateKey');
        String variableKey = getKey('variableTransactionHistory_$dateKey');
        String otherKey = getKey('otherExpenseList_$dateKey');

        fixedFutures.add(firestore.collection('users').doc(activeUserId).collection('expenses').doc('fixed').collection('daily').doc(fixedKey).get());
        variableFutures.add(firestore.collection('users').doc(activeUserId).collection('expenses').doc('variable').collection('daily').doc(variableKey).get());
        otherFutures.add(firestore.collection('users').doc(activeUserId).collection('expenses').doc('other').collection('daily').doc(otherKey).get());
      }

      // Chờ tất cả các future hoàn thành
      List<DocumentSnapshot> fixedDocs = await Future.wait(fixedFutures);
      List<DocumentSnapshot> variableDocs = await Future.wait(variableFutures);
      List<DocumentSnapshot> otherDocs = await Future.wait(otherFutures);

      // Hàm helper để xử lý từng loại transaction
      void processTransactions(List<DocumentSnapshot> docs, String transactionKey, String type) {
        for (var doc in docs) {
          if (doc.exists && doc.data() != null) {
            final data = doc.data() as Map<String, dynamic>;
            if (data.containsKey(transactionKey) && data[transactionKey] != null) {
              for (var item in (data[transactionKey] as List<dynamic>)) {
                if (item is Map<String, dynamic>) {
                  detailedBreakdown.add({
                    'name': item['name']?.toString() ?? 'Không xác định',
                    'amount': (item['amount'] as num?)?.toDouble() ?? 0.0,
                    'type': type, // Thêm loại chi phí để UI xử lý
                  });
                }
              }
            }
          }
        }
      }

      // Xử lý và thêm dữ liệu vào danh sách kết quả
      processTransactions(fixedDocs, 'fixedExpenses', 'fixed');
      processTransactions(variableDocs, 'variableExpenses', 'variable');
      processTransactions(otherDocs, 'otherExpenses', 'other');

      return detailedBreakdown;

    } catch (e) {
      print('Error in getExpenseBreakdown: $e');
      return [];
    }
  }

  Future<Map<String, List<TimeSeriesChartData>>> getDailyExpensesForRange(DateTimeRange range) async {
    if (!_isFirebaseInitialized || activeUserId == null) return {};
    try {
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      int days = range.end.difference(range.start).inDays + 1;
      List<Future<DocumentSnapshot>> fixedFutures = [];
      List<Future<DocumentSnapshot>> variableFutures = [];
      List<Future<DocumentSnapshot>> otherFutures = [];

      for (int i = 0; i < days; i++) {
        DateTime date = range.start.add(Duration(days: i));
        String dateKey = DateFormat('yyyy-MM-dd').format(date);
        String fixedKey = getKey('fixedExpenseList_$dateKey');
        String variableKey = getKey('variableTransactionHistory_$dateKey');
        String otherKey = getKey('otherExpenseList_$dateKey');

        fixedFutures.add(
          firestore.collection('users').doc(activeUserId).collection('expenses').doc('fixed').collection('daily').doc(fixedKey).get(),
        );
        variableFutures.add(
          firestore.collection('users').doc(activeUserId).collection('expenses').doc('variable').collection('daily').doc(variableKey).get(),
        );
        otherFutures.add(
          firestore.collection('users').doc(activeUserId).collection('expenses').doc('other').collection('daily').doc(otherKey).get(),
        );
      }

      List<DocumentSnapshot> fixedDocs = await Future.wait(fixedFutures);
      List<DocumentSnapshot> variableDocs = await Future.wait(variableFutures);
      List<DocumentSnapshot> otherDocs = await Future.wait(otherFutures);

      List<TimeSeriesChartData> fixedSeries = [];
      List<TimeSeriesChartData> variableSeries = [];
      List<TimeSeriesChartData> otherSeries = [];
      List<TimeSeriesChartData> totalSeries = [];

      // <<< HÀM HELPER AN TOÀN ĐỂ LẤY DỮ LIỆU >>>
      double _getSafeTotal(DocumentSnapshot doc) {
        if (!doc.exists) return 0.0;
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) return 0.0;

        final totalValue = data['total'];
        // Kiểm tra xem giá trị có phải là một con số không
        if (totalValue is num) {
          return totalValue.toDouble();
        }
        return 0.0; // Trả về 0 nếu không phải là số
      }

      for (int i = 0; i < days; i++) {
        DateTime currentDate = range.start.add(Duration(days: i));

        // <<< SỬ DỤNG HÀM HELPER ĐỂ LẤY DỮ LIỆU AN TOÀN >>>
        double fixed = _getSafeTotal(fixedDocs[i]);
        double variable = _getSafeTotal(variableDocs[i]);
        double other = _getSafeTotal(otherDocs[i]);

        double total = fixed + variable + other;

        fixedSeries.add(TimeSeriesChartData(currentDate, fixed));
        variableSeries.add(TimeSeriesChartData(currentDate, variable));
        otherSeries.add(TimeSeriesChartData(currentDate, other));
        totalSeries.add(TimeSeriesChartData(currentDate, total));
      }

      return {
        'fixed': fixedSeries,
        'variable': variableSeries,
        'other': otherSeries,
        'total': totalSeries,
      };
    } catch (e) {
      print('Error in getDailyExpensesForRange: $e');
      return {};
    }
  }

  // THAY THẾ TOÀN BỘ HÀM getOverviewForRange CỦA BẠN BẰNG HÀM NÀY

  Future<Map<String, double>> getOverviewForRange(DateTimeRange range) async {
    if (!_isFirebaseInitialized) return {'totalRevenue': 0.0, 'totalExpense': 0.0, 'profit': 0.0, 'averageProfitMargin': 0.0, 'avgRevenuePerDay': 0.0, 'avgExpensePerDay': 0.0, 'avgProfitPerDay': 0.0, 'expenseToRevenueRatio': 0.0};
    try {
      if (activeUserId == null) {
        print("[BÁO CÁO DEBUG] Lỗi: activeUserId là null.");
        return {'totalRevenue': 0.0, 'totalExpense': 0.0, 'profit': 0.0, 'averageProfitMargin': 0.0, 'avgRevenuePerDay': 0.0, 'avgExpensePerDay': 0.0, 'avgProfitPerDay': 0.0, 'expenseToRevenueRatio': 0.0};
      }
      print("[BÁO CÁO DEBUG] Bắt đầu getOverviewForRange cho user: $activeUserId trong khoảng ${range.start} - ${range.end}");
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      double totalRevenue = 0.0;
      double totalExpense = 0.0;
      int days = range.end.difference(range.start).inDays + 1;
      List<Future<DocumentSnapshot>> dailyFutures = [];
      List<Future<DocumentSnapshot>> fixedFutures = [];
      List<Future<DocumentSnapshot>> variableFutures = [];
      List<Future<DocumentSnapshot>> otherFutures = []; // <<< THÊM MỚI

      for (int i = 0; i < days; i++) {
        DateTime date = range.start.add(Duration(days: i));
        String dateKey = DateFormat('yyyy-MM-dd').format(date);
        // SỬA LẠI CÁCH TẠO DOCUMENT ID ĐỂ TRÁNH DÙNG getKey()
        String dailyDataDocId = '${activeUserId}_$dateKey';
        String fixedExpenseDocId = '${activeUserId}_fixedExpenseList_$dateKey';
        String variableExpenseDocId = '${activeUserId}_variableTransactionHistory_$dateKey';
        String otherExpenseDocId = '${activeUserId}_otherExpenseList_$dateKey'; // <<< THÊM MỚI

        dailyFutures.add(
          firestore.collection('users').doc(activeUserId).collection('daily_data').doc(dailyDataDocId).get(),
        );
        fixedFutures.add(
          firestore.collection('users').doc(activeUserId).collection('expenses').doc('fixed').collection('daily').doc(fixedExpenseDocId).get(),
        );
        variableFutures.add(
          firestore.collection('users').doc(activeUserId).collection('expenses').doc('variable').collection('daily').doc(variableExpenseDocId).get(),
        );
        // <<< THÊM MỚI: Lấy dữ liệu chi phí khác >>>
        otherFutures.add(
          firestore.collection('users').doc(activeUserId).collection('expenses').doc('other').collection('daily').doc(otherExpenseDocId).get(),
        );
      }

      List<DocumentSnapshot> dailyDocs = await Future.wait(dailyFutures);
      List<DocumentSnapshot> fixedDocs = await Future.wait(fixedFutures);
      List<DocumentSnapshot> variableDocs = await Future.wait(variableFutures);
      List<DocumentSnapshot> otherDocs = await Future.wait(otherFutures); // <<< THÊM MỚI

      print("[BÁO CÁO DEBUG] Đã tải về: ${dailyDocs.where((d) => d.exists).length} daily docs, ${fixedDocs.where((d) => d.exists).length} fixed docs, ${variableDocs.where((d) => d.exists).length} variable docs, ${otherDocs.where((d) => d.exists).length} other docs.");

      for (int i = 0; i < days; i++) {
        if (dailyDocs[i].exists) {
          final data = dailyDocs[i].data() as Map<String, dynamic>? ?? {};
          double revenue = (data['totalRevenue'] as num?)?.toDouble() ?? 0.0;
          totalRevenue += revenue;
          print("[BÁO CÁO DEBUG] Ngày ${i+1}: Doanh thu = $revenue. Tổng doanh thu = $totalRevenue");
        }
        double currentDayFixedExpense = 0;
        if (fixedDocs[i].exists) {
          final data = fixedDocs[i].data() as Map<String, dynamic>? ?? {};
          currentDayFixedExpense = (data['total'] as num?)?.toDouble() ?? 0.0;
        }
        double currentDayVariableExpense = 0;
        if (variableDocs[i].exists) {
          final data = variableDocs[i].data() as Map<String, dynamic>? ?? {};
          currentDayVariableExpense = (data['total'] as num?)?.toDouble() ?? 0.0;
        }
        // <<< THÊM MỚI: Lấy tổng chi phí khác trong ngày >>>
        double currentDayOtherExpense = 0;
        if (otherDocs[i].exists) {
          final data = otherDocs[i].data() as Map<String, dynamic>? ?? {};
          currentDayOtherExpense = (data['total'] as num?)?.toDouble() ?? 0.0;
        }

        // <<< CẬP NHẬT: Cộng cả 3 loại chi phí >>>
        totalExpense += currentDayFixedExpense + currentDayVariableExpense + currentDayOtherExpense;
        print("[BÁO CÁO DEBUG] Ngày ${i+1}: Chi phí CĐ = $currentDayFixedExpense, CP BĐ = $currentDayVariableExpense, CP Khác = $currentDayOtherExpense. Tổng chi phí = $totalExpense");
      }

      print("[BÁO CÁO DEBUG] Tính toán cuối cùng: TotalRevenue=$totalRevenue, TotalExpense=$totalExpense");

      double profit = totalRevenue - totalExpense;
      double avgRevenuePerDay = days > 0 ? totalRevenue / days : 0.0;
      double avgExpensePerDay = days > 0 ? totalExpense / days : 0.0;
      double avgProfitPerDay = days > 0 ? profit / days : 0.0;
      double averageProfitMargin = totalRevenue > 0 ? (profit / totalRevenue) * 100 : 0.0;
      double expenseToRevenueRatio = totalRevenue > 0 ? (totalExpense / totalRevenue) * 100 : 0.0;

      return {'totalRevenue': totalRevenue, 'totalExpense': totalExpense, 'profit': profit, 'averageProfitMargin': averageProfitMargin, 'avgRevenuePerDay': avgRevenuePerDay, 'avgExpensePerDay': avgExpensePerDay, 'avgProfitPerDay': avgProfitPerDay, 'expenseToRevenueRatio': expenseToRevenueRatio};
    } catch (e) {
      print("[BÁO CÁO DEBUG] Lỗi nghiêm trọng trong getOverviewForRange: $e");
      return {'totalRevenue': 0.0, 'totalExpense': 0.0, 'profit': 0.0, 'averageProfitMargin': 0.0, 'avgRevenuePerDay': 0.0, 'avgExpensePerDay': 0.0, 'avgProfitPerDay': 0.0, 'expenseToRevenueRatio': 0.0};
    }
  }

  // Dán đoạn code này vào trong class AppState trong file appstate.docx

  Future<Map<String, Map<String, double>>> getProductProfitability(DateTimeRange range) async {
    if (activeUserId == null || !_isFirebaseInitialized) return {};

    Map<String, Map<String, double>> productProfitability = {};
    int days = range.end.difference(range.start).inDays + 1;
    List<Future<DocumentSnapshot>> futures = [];

    for (int i = 0; i < days; i++) {
      DateTime date = range.start.add(Duration(days: i));
      String dateKey = DateFormat('yyyy-MM-dd').format(date);
      futures.add(
        FirebaseFirestore.instance
            .collection('users')
            .doc(activeUserId)
            .collection('daily_data')
            .doc(getKey(dateKey))
            .get(),
      );
    }

    List<DocumentSnapshot> docs = await Future.wait(futures);

    for (var doc in docs) {
      if (doc.exists) {
        // Phân tích cho Doanh thu chính và Phụ, vì chúng có giá vốn (COGS)
        for (String field in ['mainRevenueTransactions', 'secondaryRevenueTransactions']) {
          List<dynamic> transactions = doc[field] ?? [];
          for (var t in transactions) {
            if (t is Map<String, dynamic>) {
              String name = t['name'] ?? 'Không xác định';
              double revenue = (t['total'] as num?)?.toDouble() ?? 0.0;
              double cost = (t['totalVariableCost'] as num?)?.toDouble() ?? 0.0;
              double quantity = (t['quantity'] as num?)?.toDouble() ?? 1.0;

              productProfitability.putIfAbsent(name, () => {
                'totalRevenue': 0.0,
                'totalCost': 0.0,
                'totalQuantity': 0.0,
              });

              productProfitability[name]!['totalRevenue'] = (productProfitability[name]!['totalRevenue'] ?? 0) + revenue;
              productProfitability[name]!['totalCost'] = (productProfitability[name]!['totalCost'] ?? 0) + cost;
              productProfitability[name]!['totalQuantity'] = (productProfitability[name]!['totalQuantity'] ?? 0) + quantity;
            }
          }
        }
      }
    }

    // Tính toán lợi nhuận và biên lợi nhuận cho mỗi sản phẩm
    productProfitability.forEach((name, data) {
      double totalRevenue = data['totalRevenue']!;
      double totalCost = data['totalCost']!;
      double totalProfit = totalRevenue - totalCost;
      data['totalProfit'] = totalProfit;
      data['profitMargin'] = totalRevenue > 0 ? (totalProfit / totalRevenue) * 100 : 0.0;
    });

    return productProfitability;
  }

  // THÊM 3 HÀM MỚI NÀY VÀO TRONG CLASS APPSTATE

  Future<void> addOtherExpenseAndUpdateState({
    required Map<String, dynamic> newExpense,
  }) async {
    if (activeUserId == null) return;

    final isCashSpent = newExpense['walletId'] != null;
    final walletId = newExpense['walletId'] as String?;
    final amount = (newExpense['amount'] as num?)?.toDouble() ?? 0.0;

    // 1. Cập nhật trạng thái local
    otherExpenseTransactions.value.insert(0, newExpense);
    otherExpenseTransactions.value = List.from(otherExpenseTransactions.value);

    Map<String, dynamic>? adjustmentTransaction; // Khai báo ở đây

    if (isCashSpent && walletId != null) {
      // TẠO GIAO DỊCH ĐIỀU CHỈNH VÍ VỚI LIÊN KẾT
      adjustmentTransaction = {
        'id': Uuid().v4(),
        'name': 'Thanh toán: ${newExpense['name']}',
        'category': 'Điều chỉnh Ví',
        'walletId': walletId,
        'total': -amount,
        'date': DateTime.now().toIso8601String(),
        'createdBy': authUserId,
        'sourceExpenseId': newExpense['id'], // <-- LIÊN KẾT QUAN TRỌNG
      };
      walletAdjustments.value.add(adjustmentTransaction);
      walletAdjustments.value = List.from(walletAdjustments.value);

      // Cập nhật số dư ví local
      final walletIndex = wallets.value.indexWhere((w) => w['id'] == walletId);
      if (walletIndex != -1) {
        final wallet = wallets.value[walletIndex];
        final currentBalance = (wallet['balance'] as num?)?.toDouble() ?? 0.0;
        final updatedWallet = Map<String, dynamic>.from(wallet);
        updatedWallet['balance'] = currentBalance - amount;

        final updatedList = List<Map<String, dynamic>>.from(wallets.value);
        updatedList[walletIndex] = updatedWallet;
        wallets.value = updatedList;
      }
    }

    // 2. Tính toán lại tổng và thông báo cho UI
    this.otherExpense = otherExpenseTransactions.value.fold(0.0, (sum, e) => sum + ((e['amount'] as num?)?.toDouble() ?? 0.0));
    _updateProfitAndRelatedListenables();
    notifyListeners();

    // 3. Lưu lên Firestore
    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();

    // Lưu danh sách chi phí khác
    await ExpenseManager.saveOtherExpenses(this, otherExpenseTransactions.value);

    // Nếu có thực chi, cập nhật ví và thêm giao dịch điều chỉnh
    if (isCashSpent && walletId != null && adjustmentTransaction != null) {
      final walletRef = firestore.collection('users').doc(activeUserId).collection('wallets').doc(walletId);
      batch.update(walletRef, {'balance': FieldValue.increment(-amount)});

      final dateKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final docId = getKey(dateKey);
      final dailyDataRef = firestore.collection('users').doc(activeUserId).collection('daily_data').doc(docId);
      batch.set(dailyDataRef,
          {'walletAdjustments': FieldValue.arrayUnion([adjustmentTransaction])},
          SetOptions(merge: true)
      );
    }

    await batch.commit();
  }

  Future<void> editOtherExpenseAndUpdateState({
    required Map<String, dynamic> updatedExpense,
    required Map<String, dynamic> originalExpense,
  }) async {
    if (activeUserId == null) return;

    final expenseId = originalExpense['id'] as String?;
    if (expenseId == null) return;

    final originalAmount = (originalExpense['amount'] as num?)?.toDouble() ?? 0.0;
    final newAmount = (updatedExpense['amount'] as num?)?.toDouble() ?? 0.0;
    final delta = newAmount - originalAmount; // Chênh lệch số tiền
    final walletId = originalExpense['walletId'] as String?;

    // --- BƯỚC 1: CẬP NHẬT TRẠNG THÁI LOCAL ---

    // 1a. Cập nhật danh sách chi phí gốc
    final expenseIndex = otherExpenseTransactions.value.indexWhere((e) => e['id'] == expenseId);
    if (expenseIndex != -1) {
      otherExpenseTransactions.value[expenseIndex] = updatedExpense;
      otherExpenseTransactions.value = List.from(otherExpenseTransactions.value);
    }

    // 1b. Cập nhật giao dịch trong lịch sử ví và số dư ví (nếu có)
    if (walletId != null) {
      final adjIndex = walletAdjustments.value.indexWhere((adj) => adj['sourceExpenseId'] == expenseId);
      if (adjIndex != -1) {
        // Cập nhật tên và số tiền của giao dịch trong lịch sử ví
        final updatedAdjustment = Map<String, dynamic>.from(walletAdjustments.value[adjIndex]);
        updatedAdjustment['name'] = 'Thanh toán: ${updatedExpense['name']}';
        updatedAdjustment['total'] = -newAmount; // Cập nhật số tiền mới (luôn là số âm)

        final updatedAdjList = List<Map<String, dynamic>>.from(walletAdjustments.value);
        updatedAdjList[adjIndex] = updatedAdjustment;
        walletAdjustments.value = updatedAdjList;
      }

      // Điều chỉnh lại số dư ví local
      final walletIndex = wallets.value.indexWhere((w) => w['id'] == walletId);
      if (walletIndex != -1) {
        final wallet = wallets.value[walletIndex];
        final currentBalance = (wallet['balance'] as num?)?.toDouble() ?? 0.0;
        final updatedWallet = Map<String, dynamic>.from(wallet);
        // Hoàn lại tiền cũ và trừ đi tiền mới => tương đương trừ đi khoản chênh lệch
        updatedWallet['balance'] = currentBalance - delta;

        final updatedList = List<Map<String, dynamic>>.from(wallets.value);
        updatedList[walletIndex] = updatedWallet;
        wallets.value = updatedList;
      }
    }

    // 1c. Tính toán lại tổng và thông báo UI
    this.otherExpense = otherExpenseTransactions.value.fold(0.0, (sum, e) => sum + ((e['amount'] as num?)?.toDouble() ?? 0.0));
    _updateProfitAndRelatedListenables();
    notifyListeners();

    // --- BƯỚC 2: CẬP NHẬT DỮ LIỆU TRÊN FIRESTORE ---
    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();

    // 2a. Lưu lại toàn bộ danh sách chi phí khác đã được cập nhật
    await ExpenseManager.saveOtherExpenses(this, otherExpenseTransactions.value);

    // 2b. Cập nhật ví và lịch sử ví trên server
    if (walletId != null) {
      // Điều chỉnh số dư ví trên server
      if (delta != 0) {
        final walletRef = firestore.collection('users').doc(activeUserId).collection('wallets').doc(walletId);
        batch.update(walletRef, {'balance': FieldValue.increment(-delta)});
      }

      // Cập nhật lại danh sách điều chỉnh trên server
      final recordDate = DateTime.parse(updatedExpense['date']);
      final dateKey = DateFormat('yyyy-MM-dd').format(recordDate);
      final docId = getKey(dateKey);
      final dailyDataRef = firestore.collection('users').doc(activeUserId).collection('daily_data').doc(docId);
      batch.update(dailyDataRef, {'walletAdjustments': walletAdjustments.value});
    }

    await batch.commit();
  }

  Future<Map<String, dynamic>> getCashFlowDetailsForRange(DateTimeRange range) async {
    if (activeUserId == null) return {'totalCashIn': 0.0, 'totalCashOut': 0.0, 'netCashFlow': 0.0};

    final firestore = FirebaseFirestore.instance;
    double totalCashIn = 0.0;
    double totalCashOut = 0.0;

    try {
      final String startKey = getKey(DateFormat('yyyy-MM-dd').format(range.start));
      final String endKey = getKey(DateFormat('yyyy-MM-dd').format(range.end));

      final querySnapshot = await firestore
          .collection('users')
          .doc(activeUserId)
          .collection('daily_data')
          .where(FieldPath.documentId, isGreaterThanOrEqualTo: startKey)
          .where(FieldPath.documentId, isLessThanOrEqualTo: endKey)
          .get();

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        if (data == null) continue;

        final allTransactions = [
          ...(data['mainRevenueTransactions'] as List? ?? []),
          ...(data['secondaryRevenueTransactions'] as List? ?? []),
          ...(data['otherRevenueTransactions'] as List? ?? []),
          ...(data['walletAdjustments'] as List? ?? []),
        ];

        for (var tx in allTransactions) {
          if (tx is Map<String, dynamic>) {
            final bool isRevenue = tx['category'] != 'Điều chỉnh Ví';
            // Lấy giá trị 'total' một cách an toàn
            final double totalAmount = (tx['total'] as num?)?.toDouble() ?? 0.0;

            // A. XỬ LÝ DÒNG TIỀN VÀO (CASH IN)
            if (isRevenue && tx['paymentStatus'] == 'paid') {
              totalCashIn += totalAmount;
            }
            // SỬA LỖI Ở ĐÂY: Sử dụng biến trung gian `totalAmount`
            else if (!isRevenue && totalAmount > 0) {
              totalCashIn += totalAmount;
            }

            // B. XỬ LÝ DÒNG TIỀN RA (CASH OUT)
            // SỬA LỖI Ở ĐÂY: Sử dụng biến trung gian `totalAmount`
            else if (!isRevenue && totalAmount < 0) {
              totalCashOut += totalAmount.abs();
            }
          }
        }
      }
      return {
        'totalCashIn': totalCashIn,
        'totalCashOut': totalCashOut,
        'netCashFlow': totalCashIn - totalCashOut,
      };
    } catch (e) {
      print("Lỗi khi tính toán dòng tiền: $e");
      return {'totalCashIn': 0.0, 'totalCashOut': 0.0, 'netCashFlow': 0.0};
    }
  }

  Future<List<Map<String, dynamic>>> getScheduledFuturePayments(DateTimeRange forecastRange) async {
    if (activeUserId == null) return [];
    final firestore = FirebaseFirestore.instance;
    List<Map<String, dynamic>> futurePayments = [];

    try {
      final querySnapshot = await firestore
          .collection('scheduledFixedPayments') // Giả định bạn có collection này dựa trên logic của manage_fixed_expense_rules_screen
          .where('userId', isEqualTo: activeUserId)
          .where('status', isEqualTo: 'scheduled')
          .where('paymentDate', isGreaterThanOrEqualTo: Timestamp.fromDate(forecastRange.start))
          .where('paymentDate', isLessThanOrEqualTo: Timestamp.fromDate(forecastRange.end))
          .get();

      for (var doc in querySnapshot.docs) {
        futurePayments.add(doc.data());
      }
      return futurePayments;
    } catch (e) {
      print("Lỗi khi tải các khoản thanh toán tương lai: $e");
      return [];
    }
  }


  Future<void> removeOtherExpenseAndUpdateState({
    required Map<String, dynamic> expenseToRemove,
  }) async {
    if (activeUserId == null) return;

    final expenseId = expenseToRemove['id'] as String?;
    final walletId = expenseToRemove['walletId'] as String?;
    final amountToRevert = (expenseToRemove['amount'] as num?)?.toDouble() ?? 0.0;

    // 1. Cập nhật trạng thái local
    // Xóa chi phí gốc
    otherExpenseTransactions.value.removeWhere((e) => e['id'] == expenseId);
    otherExpenseTransactions.value = List.from(otherExpenseTransactions.value);

    // Nếu có, xóa cả giao dịch thanh toán trong lịch sử ví
    if (walletId != null) {
      walletAdjustments.value.removeWhere((adj) => adj['sourceExpenseId'] == expenseId);
      walletAdjustments.value = List.from(walletAdjustments.value);

      // Hoàn tiền vào ví local
      final walletIndex = wallets.value.indexWhere((w) => w['id'] == walletId);
      if (walletIndex != -1) {
        final wallet = wallets.value[walletIndex];
        final currentBalance = (wallet['balance'] as num?)?.toDouble() ?? 0.0;
        final updatedWallet = Map<String, dynamic>.from(wallet);
        updatedWallet['balance'] = currentBalance + amountToRevert;

        final updatedList = List<Map<String, dynamic>>.from(wallets.value);
        updatedList[walletIndex] = updatedWallet;
        wallets.value = updatedList;
      }
    }

    // 2. Tính toán lại tổng và thông báo UI
    this.otherExpense = otherExpenseTransactions.value.fold(0.0, (sum, e) => sum + ((e['amount'] as num?)?.toDouble() ?? 0.0));
    _updateProfitAndRelatedListenables();
    notifyListeners();

    // 3. Lưu lên Firestore
    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();

    // Lưu lại danh sách chi phí khác đã được cập nhật
    await ExpenseManager.saveOtherExpenses(this, otherExpenseTransactions.value);

    if (walletId != null) {
      // Hoàn tiền vào ví trên server
      final walletRef = firestore.collection('users').doc(activeUserId).collection('wallets').doc(walletId);
      batch.update(walletRef, {'balance': FieldValue.increment(amountToRevert)});

      // Cập nhật lại danh sách điều chỉnh ví trên server
      final recordDate = DateTime.parse(expenseToRemove['date']); // Giả định ngày của chi phí và thanh toán là gần nhau
      final dateKey = DateFormat('yyyy-MM-dd').format(recordDate);
      final docId = getKey(dateKey);
      final dailyDataRef = firestore.collection('users').doc(activeUserId).collection('daily_data').doc(docId);
      batch.update(dailyDataRef, {'walletAdjustments': walletAdjustments.value});
    }
    await batch.commit();
  }

  Future<void> payForOtherExpense({
    required Map<String, dynamic> expenseToPay,
    required String walletId,
  }) async {
    if (activeUserId == null) return;

    final expenseId = expenseToPay['id'] as String?;
    final amount = (expenseToPay['amount'] as num?)?.toDouble() ?? 0.0;

    // 1. Cập nhật trạng thái local
    // Cập nhật chi phí gốc
    final expenseIndex = otherExpenseTransactions.value.indexWhere((e) => e['id'] == expenseId);
    if (expenseIndex != -1) {
      otherExpenseTransactions.value[expenseIndex]['walletId'] = walletId;
      otherExpenseTransactions.value = List.from(otherExpenseTransactions.value);
    }

    // Tạo giao dịch thanh toán mới
    final adjustmentTransaction = {
      'id': Uuid().v4(),
      'name': 'Thanh toán: ${expenseToPay['name']}',
      'category': 'Điều chỉnh Ví',
      'walletId': walletId,
      'total': -amount,
      'date': DateTime.now().toIso8601String(),
      'createdBy': authUserId,
      'sourceExpenseId': expenseId,
    };
    walletAdjustments.value.add(adjustmentTransaction);
    walletAdjustments.value = List.from(walletAdjustments.value);

    // Trừ tiền trong ví local
    final walletIndex = wallets.value.indexWhere((w) => w['id'] == walletId);
    if (walletIndex != -1) {
      final wallet = wallets.value[walletIndex];
      final currentBalance = (wallet['balance'] as num?)?.toDouble() ?? 0.0;
      final updatedWallet = Map<String, dynamic>.from(wallet);
      updatedWallet['balance'] = currentBalance - amount;

      final updatedList = List<Map<String, dynamic>>.from(wallets.value);
      updatedList[walletIndex] = updatedWallet;
      wallets.value = updatedList;
    }
    notifyListeners();

    // 2. Lưu lên Firestore
    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();

    await ExpenseManager.saveOtherExpenses(this, otherExpenseTransactions.value);

    final walletRef = firestore.collection('users').doc(activeUserId).collection('wallets').doc(walletId);
    batch.update(walletRef, {'balance': FieldValue.increment(-amount)});

    final dateKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final docId = getKey(dateKey);
    final dailyDataRef = firestore.collection('users').doc(activeUserId).collection('daily_data').doc(docId);
    batch.set(dailyDataRef,
        {'walletAdjustments': FieldValue.arrayUnion([adjustmentTransaction])},
        SetOptions(merge: true)
    );

    await batch.commit();
  }

  Future<Map<String, Map<String, double>>> getTopProductsByCategory(DateTimeRange range) async {
    if (!_isFirebaseInitialized) {
      return {
        'Doanh thu chính': {},
        'Doanh thu phụ': {},
        'Doanh thu khác': {},
      };
    }
    try {
      if (activeUserId == null) {
        return {
          'Doanh thu chính': {},
          'Doanh thu phụ': {},
          'Doanh thu khác': {},
        };
      }
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      Map<String, Map<String, double>> topProducts = {
        'Doanh thu chính': {},
        'Doanh thu phụ': {},
        'Doanh thu khác': {},
      };
      int days = range.end.difference(range.start).inDays + 1;
      for (int i = 0; i < days; i++) {
        DateTime date = range.start.add(Duration(days: i));
        String dateKey = DateFormat('yyyy-MM-dd').format(date);
        DocumentSnapshot doc = await firestore
            .collection('users')
            .doc(activeUserId)
            .collection('daily_data')
            .doc(getKey(dateKey))
            .get();
        if (doc.exists) {
          for (String category in topProducts.keys) {
            String field = category == 'Doanh thu chính'
                ? 'mainRevenueTransactions'
                : category == 'Doanh thu phụ'
                ? 'secondaryRevenueTransactions'
                : 'otherRevenueTransactions';
            List<dynamic> transactions = doc[field] ?? [];
            for (var transaction in transactions) {
              String name = transaction['name'] ?? 'Không xác định';
              double total = (transaction['total'] as num?)?.toDouble() ?? 0.0;
              topProducts[category]![name] = (topProducts[category]![name] ?? 0.0) + total;
            }
          }
        }
      }
      return topProducts;
    } catch (e) {
      return {
        'Doanh thu chính': {},
        'Doanh thu phụ': {},
        'Doanh thu khác': {},
      };
    }
  }

  Future<Map<String, List<TimeSeriesChartData>>> getDailyOverviewForRange(DateTimeRange range) async {
    if (!_isFirebaseInitialized || activeUserId == null) return {};

    List<TimeSeriesChartData> revenueSeries = [];
    List<TimeSeriesChartData> expenseSeries = [];
    List<TimeSeriesChartData> profitSeries = [];

    try {
      int days = range.end.difference(range.start).inDays + 1;
      List<Future<DocumentSnapshot>> dailyFutures = [];
      List<Future<DocumentSnapshot>> fixedFutures = [];
      List<Future<DocumentSnapshot>> variableFutures = [];
      List<Future<DocumentSnapshot>> otherFutures = [];

      for (int i = 0; i < days; i++) {
        DateTime date = range.start.add(Duration(days: i));
        String dateKey = DateFormat('yyyy-MM-dd').format(date);
        String key = getKey(dateKey);
        String fixedKey = getKey('fixedExpenseList_$dateKey');
        String variableKey = getKey('variableTransactionHistory_$dateKey');
        String otherKey = getKey('otherExpenseList_$dateKey');

        dailyFutures.add(FirebaseFirestore.instance.collection('users').doc(activeUserId).collection('daily_data').doc(key).get());
        fixedFutures.add(FirebaseFirestore.instance.collection('users').doc(activeUserId).collection('expenses').doc('fixed').collection('daily').doc(fixedKey).get());
        variableFutures.add(FirebaseFirestore.instance.collection('users').doc(activeUserId).collection('expenses').doc('variable').collection('daily').doc(variableKey).get());
        otherFutures.add(FirebaseFirestore.instance.collection('users').doc(activeUserId).collection('expenses').doc('other').collection('daily').doc(otherKey).get());
      }

      List<DocumentSnapshot> dailyDocs = await Future.wait(dailyFutures);
      List<DocumentSnapshot> fixedDocs = await Future.wait(fixedFutures);
      List<DocumentSnapshot> variableDocs = await Future.wait(variableFutures);
      List<DocumentSnapshot> otherDocs = await Future.wait(otherFutures);

      // Hàm helper an toàn để lấy giá trị từ một document
      double _getSafeValue(DocumentSnapshot doc, String fieldName) {
        if (!doc.exists) return 0.0;
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) return 0.0;

        final value = data[fieldName];
        // Kiểm tra xem giá trị có phải là một con số không
        if (value is num) {
          return value.toDouble();
        }
        // Trả về 0 nếu không phải là số (ví dụ: là List, String hoặc null)
        return 0.0;
      }

      for (int i = 0; i < days; i++) {
        DateTime currentDate = range.start.add(Duration(days: i));

        // <<< SỬ DỤNG HÀM HELPER ĐỂ LẤY DỮ LIỆU AN TOÀN >>>
        double totalRevenue = _getSafeValue(dailyDocs[i], 'totalRevenue');
        double fixedExpense = _getSafeValue(fixedDocs[i], 'total');
        double variableExpense = _getSafeValue(variableDocs[i], 'total');
        double otherExpense = _getSafeValue(otherDocs[i], 'total');

        double totalExpense = fixedExpense + variableExpense + otherExpense;
        double profit = totalRevenue - totalExpense;

        revenueSeries.add(TimeSeriesChartData(currentDate, totalRevenue));
        expenseSeries.add(TimeSeriesChartData(currentDate, totalExpense));
        profitSeries.add(TimeSeriesChartData(currentDate, profit));
      }

      return {
        'revenueData': revenueSeries,
        'expenseData': expenseSeries,
        'profitData': profitSeries,
      };
    } catch (e) {
      print('Error in getDailyOverviewForRange: $e');
      return {};
    }
  }

  Future<Map<String, double>> getProductRevenueBreakdown(DateTimeRange range) async {
    if (!_isFirebaseInitialized) return {};
    try {
      if (activeUserId == null) return {};
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      Map<String, double> productTotals = {};
      double totalRevenue = 0.0;
      int days = range.end.difference(range.start).inDays + 1;
      for (int i = 0; i < days; i++) {
        DateTime date = range.start.add(Duration(days: i));
        String dateKey = DateFormat('yyyy-MM-dd').format(date);
        DocumentSnapshot doc = await firestore
            .collection('users')
            .doc(activeUserId)
            .collection('daily_data')
            .doc(getKey(dateKey))
            .get();
        if (doc.exists) {
          for (String field in ['mainRevenueTransactions', 'secondaryRevenueTransactions', 'otherRevenueTransactions']) {
            List<dynamic> transactions = doc[field] ?? [];
            for (var transaction in transactions) {
              String name = transaction['name'] ?? 'Không xác định';
              double total = (transaction['total'] as num?)?.toDouble() ?? 0.0;
              productTotals[name] = (productTotals[name] ?? 0.0) + total;
              totalRevenue += total;
            }
          }
        }
      }
      Map<String, double> breakdown = {};
      if (totalRevenue > 0) {
        productTotals.forEach((name, total) {
          breakdown[name] = (total / totalRevenue) * 100;
        });
      }
      return breakdown;
    } catch (e) {
      return {};
    }
  }

  Future<Map<String, double>> getProductRevenueTotals(DateTimeRange range) async {
    if (!_isFirebaseInitialized) return {};
    try {
      if (activeUserId == null) return {};
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      Map<String, double> productTotals = {};
      int days = range.end.difference(range.start).inDays + 1;
      for (int i = 0; i < days; i++) {
        DateTime date = range.start.add(Duration(days: i));
        String dateKey = DateFormat('yyyy-MM-dd').format(date);
        DocumentSnapshot doc = await firestore
            .collection('users')
            .doc(activeUserId)
            .collection('daily_data')
            .doc(getKey(dateKey))
            .get();
        if (doc.exists) {
          for (String field in ['mainRevenueTransactions', 'secondaryRevenueTransactions', 'otherRevenueTransactions']) {
            List<dynamic> transactions = doc[field] ?? [];
            for (var transaction in transactions) {
              String name = transaction['name'] ?? 'Không xác định';
              double total = (transaction['total'] as num?)?.toDouble() ?? 0.0;
              productTotals[name] = (productTotals[name] ?? 0.0) + total;
            }
          }
        }
      }
      return productTotals;
    } catch (e) {
      return {};
    }
  }

  Future<Map<String, Map<String, double>>> getProductRevenueDetails(DateTimeRange range) async {
    if (!_isFirebaseInitialized) return {};
    try {
      if (activeUserId == null) return {};
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      Map<String, Map<String, double>> productDetails = {};
      int days = range.end.difference(range.start).inDays + 1;

      List<Future<DocumentSnapshot>> futures = [];

      for (int i = 0; i < days; i++) {
        DateTime date = range.start.add(Duration(days: i));
        String dateKey = DateFormat('yyyy-MM-dd').format(date);
        futures.add(
          firestore
              .collection('users')
              .doc(activeUserId)
              .collection('daily_data')
              .doc(getKey(dateKey))
              .get(),
        );
      }

      List<DocumentSnapshot> docs = await Future.wait(futures);

      for (var doc in docs) {
        if (doc.exists) {
          for (String field in ['mainRevenueTransactions', 'secondaryRevenueTransactions', 'otherRevenueTransactions']) {
            List<dynamic> transactions = doc[field] ?? [];
            for (var transaction in transactions) {
              String name = transaction['name'] ?? 'Không xác định';
              double total = (transaction['total'] as num?)?.toDouble() ?? 0.0;
              double quantity = (transaction['quantity'] as num?)?.toDouble() ?? 1.0;
              productDetails.putIfAbsent(name, () => {'total': 0.0, 'quantity': 0.0});
              productDetails[name]!['total'] = (productDetails[name]!['total'] ?? 0.0) + total;
              productDetails[name]!['quantity'] = (productDetails[name]!['quantity'] ?? 0.0) + quantity;
            }
          }
        }
      }

      return productDetails;
    } catch (e) {
      return {};
    }
  }

  double getTotalRevenue() {
    return mainRevenue + secondaryRevenue + otherRevenue;
  }

  double getTotalExpense() {
    return _fixedExpense + variableExpense + otherExpense;
  }

  double getProfit() {
    return getTotalRevenue() - getTotalExpense();
  }

  double getProfitMargin() {
    double revenue = getTotalRevenue();
    if (revenue == 0) return 0;
    return (getProfit() / revenue) * 100;
  }

  @override
  void dispose() {
    selectedDateListenable.dispose();
    isLoadingListenable.dispose();
    dataReadyListenable.dispose();
    mainRevenueListenable.dispose();
    secondaryRevenueListenable.dispose();
    otherRevenueListenable.dispose();
    totalRevenueListenable.dispose();
    profitListenable.dispose();
    profitMarginListenable.dispose();
    fixedExpenseListenable.dispose();
    fixedExpenseList.dispose();
    variableExpenseList.dispose();
    mainRevenueTransactions.dispose();
    secondaryRevenueTransactions.dispose();
    otherRevenueTransactions.dispose();
    productsUpdated.dispose();
    wallets.dispose();
    _cancelRevenueSubscription();
    _cancelFixedExpenseSubscription();
    _cancelVariableExpenseSubscription();
    _cancelDailyFixedExpenseSubscription();
    _cancelProductsSubscription();
    _cancelVariableExpenseListSubscription();
    _cancelPermissionSubscription();
    _cancelWalletsSubscription();
    permissionVersion.dispose();
    super.dispose();
  }

  Future<void> resetAllUserData() async {

    // Giữ lại toàn bộ phần reset state và dọn dẹp Hive
    mainRevenue = 0.0;
    secondaryRevenue = 0.0;
    otherRevenue = 0.0;
    mainRevenueListenable.value = 0.0;
    secondaryRevenueListenable.value = 0.0;
    otherRevenueListenable.value = 0.0;
    totalRevenueListenable.value = 0.0;
    profitListenable.value = 0.0;
    profitMarginListenable.value = 0.0;
    _fixedExpense = 0.0;
    fixedExpenseListenable.value = 0.0;
    variableExpense = 0.0;
    mainRevenueTransactions.value = [];
    secondaryRevenueTransactions.value = [];
    otherRevenueTransactions.value = [];
    fixedExpenseList.value = [];
    variableExpenseList.value = [];

    _cancelRevenueSubscription();
    _cancelFixedExpenseSubscription();
    _cancelVariableExpenseSubscription();
    _cancelDailyFixedExpenseSubscription();
    _cancelDailyDataSubscription();
    _cancelProductsSubscription();
    _cancelVariableExpenseListSubscription();
    _cancelPermissionSubscription();

    _saveSettings(); // Có thể giữ lại để lưu các cài đặt chung
    _cachedDateKey = null;
    _cachedData = null;

    if (!Hive.isBoxOpen('productsBox')) await Hive.openBox('productsBox');
    if (!Hive.isBoxOpen('transactionsBox')) await Hive.openBox('transactionsBox');
    if (!Hive.isBoxOpen('revenueBox')) await Hive.openBox('revenueBox'); // Sửa lỗi gõ: transactionsBox -> revenueBox
    if (!Hive.isBoxOpen('fixedExpensesBox')) await Hive.openBox('fixedExpensesBox'); // Sửa lỗi gõ: transactionsBox -> fixedExpensesBox
    if (!Hive.isBoxOpen('variableExpensesBox')) await Hive.openBox('variableExpensesBox'); // Sửa lỗi gõ: transactionsBox -> variableExpensesBox
    if (!Hive.isBoxOpen('variableExpenseListBox')) await Hive.openBox('variableExpenseListBox'); // Sửa lỗi gõ: transactionsBox -> variableExpenseListBox
    if (!Hive.isBoxOpen('monthlyFixedExpensesBox')) await Hive.openBox('monthlyFixedExpensesBox'); // Sửa lỗi gõ: transactionsBox -> monthlyFixedExpensesBox
    if (!Hive.isBoxOpen('monthlyFixedAmountsBox')) await Hive.openBox('monthlyFixedAmountsBox'); // Sửa lỗi gõ: transactionsBox -> monthlyFixedAmountsBox

    Hive.box('productsBox').clear();
    Hive.box('transactionsBox').clear();
    Hive.box('revenueBox').clear();
    Hive.box('fixedExpensesBox').clear();
    Hive.box('variableExpensesBox').clear();
    Hive.box('variableExpenseListBox').clear();
    Hive.box('monthlyFixedExpensesBox').clear();
    Hive.box('monthlyFixedAmountsBox').clear();

    notifyListeners();
  }
}