import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart' as model;
import '/screens/expense_manager.dart';
import '/screens/revenue_manager.dart';
import '../screens/chart_data_models.dart';

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
  final ValueNotifier<double> fixedExpenseListenable = ValueNotifier(0.0);
  final ValueNotifier<List<Map<String, dynamic>>> fixedExpenseList = ValueNotifier([]);
  final ValueNotifier<List<Map<String, dynamic>>> variableExpenseList = ValueNotifier([]);
  final ValueNotifier<List<Map<String, dynamic>>> mainRevenueTransactions = ValueNotifier([]);
  final ValueNotifier<List<Map<String, dynamic>>> secondaryRevenueTransactions = ValueNotifier([]);
  final ValueNotifier<List<Map<String, dynamic>>> otherRevenueTransactions = ValueNotifier([]);
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

  StreamSubscription<DocumentSnapshot>? _revenueSubscription;
  StreamSubscription<DocumentSnapshot>? _fixedExpenseSubscription; // Thêm subscription cho chi phí cố định
  StreamSubscription<DocumentSnapshot>? _variableExpenseSubscription;
  StreamSubscription<DocumentSnapshot>? _dailyFixedExpenseSubscription;
  StreamSubscription<DocumentSnapshot>? _dailyDataSubscription;
  StreamSubscription<QuerySnapshot>? _productsSubscription;
  StreamSubscription<DocumentSnapshot>? _permissionSubscription;
  StreamSubscription<DocumentSnapshot>? _variableExpenseListSubscription;

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

  void setUserId(String id) {
    if (authUserId != id) {
      authUserId = id;
      activeUserId = id; // Mặc định, người dùng xem dữ liệu của chính mình

      _cachedDateKey = null;
      _cachedData = null;

      // Hủy các subscription cũ
      _cancelRevenueSubscription();
      _cancelFixedExpenseSubscription();
      _cancelVariableExpenseSubscription();
      _cancelDailyFixedExpenseSubscription();
      _cancelProductsSubscription();
      _cancelVariableExpenseListSubscription();
      _cancelPermissionSubscription();

      _loadSettings();
      _loadInitialData().then((_) async {
        _subscribeToPermissions();

        _subscribeToFixedExpenses();
        _subscribeToVariableExpenses();
        _subscribeToDailyFixedExpenses();
        _subscribeToDailyData();
        _subscribeToProducts();
        _subscribeToAvailableVariableExpenses();
        notifyListeners();
      });
    }
  }

  // Thay thế hàm switchActiveUser cũ bằng phiên bản này
  Future<void> switchActiveUser(String newActiveUserId) async {
    if (activeUserId != newActiveUserId) {
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

      print("Switching to user $newActiveUserId and reloading data...");

      // Tải quyền của người dùng mới TRƯỚC khi tải dữ liệu chính
      _subscribeToPermissions();// <-- GỌI HÀM TẢI QUYỀN

      await _loadInitialData();

      _subscribeToFixedExpenses();
      _subscribeToVariableExpenses();
      _subscribeToDailyFixedExpenses();
      _subscribeToDailyData();
      _subscribeToProducts();
      _subscribeToAvailableVariableExpenses();

      notifyListeners();
    }
  }

  Future<void> logout() async {
    if (authUserId != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(authUserId!).update({
          'lastLoginDeviceId': null, // <-- Đặt trường này về null
        });
      } catch (e) {
        // Ghi lại lỗi nếu có, nhưng không ngăn cản quá trình đăng xuất
        print('Lỗi khi xóa device ID lúc đăng xuất: $e');
      }
    }
    authUserId = null;
    activeUserId = null;
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
    _saveSettings();
    _cachedDateKey = null;
    _cachedData = null;
    if (!Hive.isBoxOpen('productsBox')) await Hive.openBox('productsBox');
    if (!Hive.isBoxOpen('transactionsBox')) await Hive.openBox('transactionsBox');
    if (!Hive.isBoxOpen('revenueBox')) await Hive.openBox('transactionsBox');
    if (!Hive.isBoxOpen('fixedExpensesBox')) await Hive.openBox('transactionsBox');
    if (!Hive.isBoxOpen('variableExpensesBox')) await Hive.openBox('transactionsBox');
    if (!Hive.isBoxOpen('variableExpenseListBox')) await Hive.openBox('transactionsBox');
    if (!Hive.isBoxOpen('monthlyFixedExpensesBox')) await Hive.openBox('transactionsBox');
    if (!Hive.isBoxOpen('monthlyFixedAmountsBox')) await Hive.openBox('transactionsBox');
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

      _subscribeToFixedExpenses();
      _subscribeToVariableExpenses();
      _subscribeToDailyFixedExpenses();
      _subscribeToDailyData();
      _subscribeToAvailableVariableExpenses();

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
    required String category, // 'Doanh thu chính' hoặc 'Doanh thu phụ'
    required Map<String, dynamic> newSalesTransaction,
    required List<Map<String, dynamic>> autoGeneratedCogs,
  }) async {
    // 1. CẬP NHẬT TRẠNG THÁI LOCAL (OPTIMISTIC UPDATE)
    // Thêm giao dịch vào đúng danh sách
    if (category == 'Doanh thu chính') {
      mainRevenueTransactions.value.add(newSalesTransaction);
      // Phải gán lại list mới để ValueNotifier nhận biết sự thay đổi
      mainRevenueTransactions.value = List.from(mainRevenueTransactions.value);
    } else if (category == 'Doanh thu phụ') {
      secondaryRevenueTransactions.value.add(newSalesTransaction);
      secondaryRevenueTransactions.value = List.from(secondaryRevenueTransactions.value);
    }

    // Thêm giá vốn vào danh sách chi phí biến đổi
    if (autoGeneratedCogs.isNotEmpty) {
      variableExpenseList.value.addAll(autoGeneratedCogs);
      variableExpenseList.value = List.from(variableExpenseList.value);
    }

// 2. TÍNH TOÁN LẠI TẤT CẢ CÁC TỔNG
    mainRevenue = mainRevenueTransactions.value.fold(0.0, (sum, e) => sum + (e['total']?.toDouble() ?? 0.0));
    secondaryRevenue = secondaryRevenueTransactions.value.fold(0.0, (sum, e) => sum + (e['total']?.toDouble() ?? 0.0));
    otherRevenue = otherRevenueTransactions.value.fold(0.0, (sum, e) => sum + (e['total']?.toDouble() ?? 0.0));

    _fixedExpense = fixedExpenseList.value.fold(0.0, (sum, e) => sum + (e['amount']?.toDouble() ?? 0.0));
    variableExpense = variableExpenseList.value.fold(0.0, (sum, e) => sum + (e['amount']?.toDouble() ?? 0.0));

    // 3. CẬP NHẬT TẤT CẢ VALUE NOTIFIER VÀ GỌI NOTIFYLISTENERS() MỘT LẦN
    _updateProfitAndRelatedListenables(); // Hàm này sẽ cập nhật các ValueNotifier về doanh thu, lợi nhuận...
    notifyListeners(); // <-- CHỈ GỌI 1 LẦN DUY NHẤT Ở ĐÂY

    // 4. LƯU DỮ LIỆU LÊN FIRESTORE (KHÔNG CẦN AWAIT VÀ KHÔNG GỌI NOTIFIER NỮA)
    // Các hàm save này bây giờ chỉ có nhiệm vụ lưu, không cập nhật state nữa
    await _saveAllDailyDataToFirestore();
    if (autoGeneratedCogs.isNotEmpty) {
      ExpenseManager.saveVariableExpenses(this, variableExpenseList.value);
    }
  }

  // Dán hàm mới này vào trong class AppState (appstate.docx)

  Future<void> removeTransactionAndUpdateState({
    required String category,
    required Map<String, dynamic> transactionToRemove,
  }) async {
    final String? transactionId = transactionToRemove['id'] as String?;

    // 1. CẬP NHẬT TRẠNG THÁI LOCAL (OPTIMISTIC UPDATE)

    // Xác định danh sách doanh thu cần cập nhật
    ValueNotifier<List<Map<String, dynamic>>>? targetRevenueList;
    if (category == 'Doanh thu chính') {
      targetRevenueList = mainRevenueTransactions;
    } else if (category == 'Doanh thu phụ') {
      targetRevenueList = secondaryRevenueTransactions;
    } else if (category == 'Doanh thu khác') {
      targetRevenueList = otherRevenueTransactions;
    }

    // Xóa giao dịch doanh thu
    targetRevenueList?.value.removeWhere((t) => t['id'] == transactionId);
    targetRevenueList?.value = List.from(targetRevenueList.value);

    // Xóa giá vốn (COGS) liên quan nếu có
    if (transactionId != null) {
      variableExpenseList.value.removeWhere((expense) => expense['sourceSalesTransactionId'] == transactionId);
      variableExpenseList.value = List.from(variableExpenseList.value);
    }

    // 2. TÍNH TOÁN LẠI TẤT CẢ CÁC TỔNG
    mainRevenue = mainRevenueTransactions.value.fold(0.0, (sum, e) => sum + (e['total']?.toDouble() ?? 0.0));
    secondaryRevenue = secondaryRevenueTransactions.value.fold(0.0, (sum, e) => sum + (e['total']?.toDouble() ?? 0.0));
    otherRevenue = otherRevenueTransactions.value.fold(0.0, (sum, e) => sum + (e['total']?.toDouble() ?? 0.0));

    _fixedExpense = fixedExpenseList.value.fold(0.0, (sum, e) => sum + (e['amount']?.toDouble() ?? 0.0));
    variableExpense = variableExpenseList.value.fold(0.0, (sum, e) => sum + (e['amount']?.toDouble() ?? 0.0));

    // 3. CẬP NHẬT VALUE NOTIFIER VÀ GỌI NOTIFYLISTENERS() MỘT LẦN
    _updateProfitAndRelatedListenables();
    notifyListeners();

    // 4. LƯU TRỮ DỮ LIỆU LÊN FIRESTORE
    // Các hàm save này chỉ lưu, không cập nhật state nữa
    await _saveAllDailyDataToFirestore();
    if (transactionId != null) {
      ExpenseManager.saveVariableExpenses(this, variableExpenseList.value);
    }
  }

  // Dán hàm mới này vào trong class AppState (appstate.docx)

  Future<void> editTransactionAndUpdateState({
    required String category,
    required Map<String, dynamic> updatedTransaction,
    required List<Map<String, dynamic>> newCogsTransactions,
  }) async {
    final String? transactionId = updatedTransaction['id'] as String?;
    if (transactionId == null) {
      throw Exception("Không thể sửa giao dịch không có ID.");
    }

    // 1. CẬP NHẬT TRẠNG THÁI LOCAL (OPTIMISTIC UPDATE)

    // Xác định và cập nhật danh sách doanh thu
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

    // Xóa COGS cũ và thêm COGS mới
    variableExpenseList.value.removeWhere((expense) => expense['sourceSalesTransactionId'] == transactionId);
    variableExpenseList.value.addAll(newCogsTransactions);
    variableExpenseList.value = List.from(variableExpenseList.value);

    // 2. TÍNH TOÁN LẠI TẤT CẢ CÁC TỔNG
    mainRevenue = mainRevenueTransactions.value.fold(0.0, (sum, e) => sum + (e['total']?.toDouble() ?? 0.0));
    secondaryRevenue = secondaryRevenueTransactions.value.fold(0.0, (sum, e) => sum + (e['total']?.toDouble() ?? 0.0));
    otherRevenue = otherRevenueTransactions.value.fold(0.0, (sum, e) => sum + (e['total']?.toDouble() ?? 0.0));

    _fixedExpense = fixedExpenseList.value.fold(0.0, (sum, e) => sum + (e['amount']?.toDouble() ?? 0.0));
    variableExpense = variableExpenseList.value.fold(0.0, (sum, e) => sum + (e['amount']?.toDouble() ?? 0.0));

    // 3. CẬP NHẬT VALUE NOTIFIER VÀ GỌI NOTIFYLISTENERS() MỘT LẦN
    _updateProfitAndRelatedListenables();
    notifyListeners();

    // 4. LƯU TRỮ DỮ LIỆU LÊN FIRESTORE
    await _saveAllDailyDataToFirestore();
    ExpenseManager.saveVariableExpenses(this, variableExpenseList.value);
  }

  // Dán 3 hàm mới này vào trong class AppState (appstate.docx)

// Hàm thêm giao dịch "Doanh thu khác"
  Future<void> addOtherRevenueAndUpdateState(Map<String, dynamic> newTransaction) async {
    // 1. Cập nhật danh sách local
    otherRevenueTransactions.value.add(newTransaction);
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

  Future<void> _saveAllDailyDataToFirestore() async {
    if (activeUserId == null) return;

    try {
      final firestore = FirebaseFirestore.instance;
      String dateKey = DateFormat('yyyy-MM-dd').format(_selectedDate);
      String docPath = 'users/$activeUserId/daily_data/${getKey(dateKey)}';

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

        // Danh sách giao dịch chi tiết
        'mainRevenueTransactions': mainRevenueTransactions.value,
        'secondaryRevenueTransactions': secondaryRevenueTransactions.value,
        'otherRevenueTransactions': otherRevenueTransactions.value,

        // Dấu thời gian
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Ghi toàn bộ dữ liệu lên Firestore
      await firestore.doc(docPath).set(dataToSave);

    } catch (e) {
      print("Lỗi nghiêm trọng khi lưu daily_data lên Firestore: $e");
      // Bạn có thể thêm xử lý lỗi ở đây nếu cần
    }
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
    if (!_isFirebaseInitialized) return {'fixedExpense': 0.0, 'variableExpense': 0.0, 'totalExpense': 0.0};
    try {
      if (activeUserId == null) return {'fixedExpense': 0.0, 'variableExpense': 0.0, 'totalExpense': 0.0};
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      double fixedExpenseTotal = 0.0;
      double variableExpenseTotal = 0.0;
      int days = range.end.difference(range.start).inDays + 1;

      List<Future<DocumentSnapshot>> fixedFutures = [];
      List<Future<DocumentSnapshot>> variableFutures = [];

      for (int i = 0; i < days; i++) {
        DateTime date = range.start.add(Duration(days: i));
        String dateKey = DateFormat('yyyy-MM-dd').format(date);
        String fixedKey = getKey('fixedExpenseList_$dateKey');
        String variableKey = getKey('variableTransactionHistory_$dateKey');

        fixedFutures.add(
          firestore
              .collection('users')
              .doc(activeUserId)
              .collection('expenses')
              .doc('fixed')
              .collection('daily')
              .doc(fixedKey)
              .get(),
        );
        variableFutures.add(
          firestore
              .collection('users')
              .doc(activeUserId)
              .collection('expenses')
              .doc('variable')
              .collection('daily')
              .doc(variableKey)
              .get(),
        );
      }

      List<DocumentSnapshot> fixedDocs = await Future.wait(fixedFutures);
      List<DocumentSnapshot> variableDocs = await Future.wait(variableFutures);

      for (int i = 0; i < days; i++) {
        fixedExpenseTotal += fixedDocs[i].exists ? fixedDocs[i]['total']?.toDouble() ?? 0.0 : 0.0;
        variableExpenseTotal += variableDocs[i].exists ? variableDocs[i]['total']?.toDouble() ?? 0.0 : 0.0;
      }

      return {
        'fixedExpense': fixedExpenseTotal,
        'variableExpense': variableExpenseTotal,
        'totalExpense': fixedExpenseTotal + variableExpenseTotal,
      };
    } catch (e) {
      return {'fixedExpense': 0.0, 'variableExpense': 0.0, 'totalExpense': 0.0};
    }
  }

  Future<List<CategoryChartData>> getExpenseBreakdown(DateTimeRange range) async {
    if (!_isFirebaseInitialized || activeUserId == null) return []; //

    try {
      final FirebaseFirestore firestore = FirebaseFirestore.instance; //
      Map<String, double> breakdown = {}; //
      int days = range.end.difference(range.start).inDays + 1; //
      List<Future<DocumentSnapshot>> fixedFutures = []; //
      List<Future<DocumentSnapshot>> variableFutures = []; //

      for (int i = 0; i < days; i++) {
        DateTime date = range.start.add(Duration(days: i)); //
        String dateKey = DateFormat('yyyy-MM-dd').format(date); //
        String fixedKey = getKey('fixedExpenseList_$dateKey'); //
        String variableKey = getKey('variableTransactionHistory_$dateKey'); //
        fixedFutures.add(
          firestore.collection('users').doc(activeUserId).collection('expenses').doc('fixed').collection('daily').doc(fixedKey).get(), //
        );
        variableFutures.add(
          firestore.collection('users').doc(activeUserId).collection('expenses').doc('variable').collection('daily').doc(variableKey).get(), //
        );
      }

      List<DocumentSnapshot> fixedDocs = await Future.wait(fixedFutures); //
      List<DocumentSnapshot> variableDocs = await Future.wait(variableFutures); //

      for (var doc in fixedDocs) {
        if (doc.exists && doc.data() != null) {
          final data = doc.data() as Map<String, dynamic>; //
          if (data.containsKey('fixedExpenses') && data['fixedExpenses'] != null) { //
            List<dynamic> transactions = data['fixedExpenses'] as List<dynamic>; //
            for (var item in transactions) {
              if (item is Map<String, dynamic>) { //
                String name = item['name']?.toString() ?? 'Không xác định'; //
                double amount = (item['amount'] as num?)?.toDouble() ?? 0.0; //
                breakdown[name] = (breakdown[name] ?? 0.0) + amount; //
              }
            }
          }
        }
      }

      for (var doc in variableDocs) {
        if (doc.exists && doc.data() != null) {
          final data = doc.data() as Map<String, dynamic>; //
          if (data.containsKey('variableExpenses') && data['variableExpenses'] != null) { //
            List<dynamic> transactions = data['variableExpenses'] as List<dynamic>; //
            for (var item in transactions) {
              if (item is Map<String, dynamic>) { //
                String name = item['name']?.toString() ?? 'Không xác định'; //
                double amount = (item['amount'] as num?)?.toDouble() ?? 0.0; //
                breakdown[name] = (breakdown[name] ?? 0.0) + amount; //
              }
            }
          }
        }
      }

      // Phần logic nhóm "Khác" vẫn giữ nguyên
      Map<String, double> finalBreakdown = {}; //
      double otherTotal = 0.0; //
      double total = breakdown.values.fold(0.0, (sum, value) => sum + value); //
      breakdown.forEach((name, amount) {
        if (total > 0 && (amount / total) < 0.05) { //
          otherTotal += amount; //
        } else {
          finalBreakdown[name] = amount; //
        }
      });
      if (otherTotal > 0) { //
        finalBreakdown['Khác'] = otherTotal; //
      }

      // *** THAY ĐỔI QUAN TRỌNG: Chuyển đổi Map thành List<CategoryChartData> ***
      final List<CategoryChartData> chartData = finalBreakdown.entries.map((entry) {
        return CategoryChartData(entry.key, entry.value);
      }).toList();

      return chartData;

    } catch (e) {
      print('Error in getExpenseBreakdown: $e'); // In ra lỗi để debug
      return []; //
    }
  }

  Future<Map<String, List<TimeSeriesChartData>>> getDailyExpensesForRange(DateTimeRange range) async {
    if (!_isFirebaseInitialized || activeUserId == null) return {}; //

    try {
      final FirebaseFirestore firestore = FirebaseFirestore.instance; //
      int days = range.end.difference(range.start).inDays + 1; //
      List<Future<DocumentSnapshot>> fixedFutures = []; //
      List<Future<DocumentSnapshot>> variableFutures = []; //

      for (int i = 0; i < days; i++) {
        DateTime date = range.start.add(Duration(days: i)); //
        String dateKey = DateFormat('yyyy-MM-dd').format(date); //
        String fixedKey = getKey('fixedExpenseList_$dateKey'); //
        String variableKey = getKey('variableTransactionHistory_$dateKey'); //
        fixedFutures.add(
          firestore.collection('users').doc(activeUserId).collection('expenses').doc('fixed').collection('daily').doc(fixedKey).get(), //
        );
        variableFutures.add(
          firestore.collection('users').doc(activeUserId).collection('expenses').doc('variable').collection('daily').doc(variableKey).get(), //
        );
      }

      List<DocumentSnapshot> fixedDocs = await Future.wait(fixedFutures); //
      List<DocumentSnapshot> variableDocs = await Future.wait(variableFutures); //

      // *** THAY ĐỔI QUAN TRỌNG: Chuẩn bị các list cho từng series dữ liệu ***
      List<TimeSeriesChartData> fixedSeries = [];
      List<TimeSeriesChartData> variableSeries = [];
      List<TimeSeriesChartData> totalSeries = [];

      for (int i = 0; i < days; i++) {
        DateTime currentDate = range.start.add(Duration(days: i));
        double fixed = fixedDocs[i].exists ? fixedDocs[i]['total']?.toDouble() ?? 0.0 : 0.0; //
        double variable = variableDocs[i].exists ? variableDocs[i]['total']?.toDouble() ?? 0.0 : 0.0; //
        double total = fixed + variable;

        fixedSeries.add(TimeSeriesChartData(currentDate, fixed));
        variableSeries.add(TimeSeriesChartData(currentDate, variable));
        totalSeries.add(TimeSeriesChartData(currentDate, total));
      }

      return {
        'fixed': fixedSeries,
        'variable': variableSeries,
        'total': totalSeries,
      };

    } catch (e) {
      print('Error in getDailyExpensesForRange: $e');
      return {}; //
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

      for (int i = 0; i < days; i++) {
        DateTime date = range.start.add(Duration(days: i));
        String dateKey = DateFormat('yyyy-MM-dd').format(date);

        // SỬA LẠI CÁCH TẠO DOCUMENT ID ĐỂ TRÁNH DÙNG getKey()
        String dailyDataDocId = '${activeUserId}_$dateKey';
        String fixedExpenseDocId = '${activeUserId}_fixedExpenseList_$dateKey';
        String variableExpenseDocId = '${activeUserId}_variableTransactionHistory_$dateKey';

        dailyFutures.add(
          firestore.collection('users').doc(activeUserId).collection('daily_data').doc(dailyDataDocId).get(),
        );
        fixedFutures.add(
          firestore.collection('users').doc(activeUserId).collection('expenses').doc('fixed').collection('daily').doc(fixedExpenseDocId).get(),
        );
        variableFutures.add(
          firestore.collection('users').doc(activeUserId).collection('expenses').doc('variable').collection('daily').doc(variableExpenseDocId).get(),
        );
      }

      List<DocumentSnapshot> dailyDocs = await Future.wait(dailyFutures);
      List<DocumentSnapshot> fixedDocs = await Future.wait(fixedFutures);
      List<DocumentSnapshot> variableDocs = await Future.wait(variableFutures);

      print("[BÁO CÁO DEBUG] Đã tải về: ${dailyDocs.where((d) => d.exists).length} daily docs, ${fixedDocs.where((d) => d.exists).length} fixed docs, ${variableDocs.where((d) => d.exists).length} variable docs.");

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

        totalExpense += currentDayFixedExpense + currentDayVariableExpense;
        print("[BÁO CÁO DEBUG] Ngày ${i+1}: Chi phí CĐ = $currentDayFixedExpense, CP BĐ = $currentDayVariableExpense. Tổng chi phí = $totalExpense");
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
    if (!_isFirebaseInitialized || activeUserId == null) return {}; //

    List<TimeSeriesChartData> revenueSeries = [];
    List<TimeSeriesChartData> expenseSeries = [];
    List<TimeSeriesChartData> profitSeries = [];

    try {
      int days = range.end.difference(range.start).inDays + 1; //
      List<Future<DocumentSnapshot>> dailyFutures = []; //
      List<Future<DocumentSnapshot>> fixedFutures = []; //
      List<Future<DocumentSnapshot>> variableFutures = []; //

      for (int i = 0; i < days; i++) {
        DateTime date = range.start.add(Duration(days: i)); //
        String dateKey = DateFormat('yyyy-MM-dd').format(date); //
        String key = getKey(dateKey); //
        String fixedKey = getKey('fixedExpenseList_$dateKey'); //
        String variableKey = getKey('variableTransactionHistory_$dateKey'); //

        dailyFutures.add(FirebaseFirestore.instance.collection('users').doc(activeUserId).collection('daily_data').doc(key).get()); //
        fixedFutures.add(FirebaseFirestore.instance.collection('users').doc(activeUserId).collection('expenses').doc('fixed').collection('daily').doc(fixedKey).get()); //
        variableFutures.add(FirebaseFirestore.instance.collection('users').doc(activeUserId).collection('expenses').doc('variable').collection('daily').doc(variableKey).get()); //
      }

      List<DocumentSnapshot> dailyDocs = await Future.wait(dailyFutures); //
      List<DocumentSnapshot> fixedDocs = await Future.wait(fixedFutures); //
      List<DocumentSnapshot> variableDocs = await Future.wait(variableFutures); //

      for (int i = 0; i < days; i++) {
        DateTime currentDate = range.start.add(Duration(days: i));
        double totalRevenue = dailyDocs[i].exists ? dailyDocs[i]['totalRevenue']?.toDouble() ?? 0.0 : 0.0; //
        double fixedExpense = fixedDocs[i].exists ? fixedDocs[i]['total']?.toDouble() ?? 0.0 : 0.0; //
        double variableExpense = variableDocs[i].exists ? variableDocs[i]['total']?.toDouble() ?? 0.0 : 0.0; //
        double totalExpense = fixedExpense + variableExpense; //
        double profit = totalRevenue - totalExpense; //

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
      return {}; //
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

  double getTotalFixedAndVariableExpense() {
    return _fixedExpense + variableExpense;
  }

  double getProfit() {
    return getTotalRevenue() - getTotalFixedAndVariableExpense();
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
    _cancelRevenueSubscription();
    _cancelFixedExpenseSubscription();
    _cancelVariableExpenseSubscription();
    _cancelDailyFixedExpenseSubscription();
    _cancelProductsSubscription();
    _cancelVariableExpenseListSubscription();
    _cancelPermissionSubscription();
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