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

class AppState extends ChangeNotifier {
  int _selectedScreenIndex = 0;
  int get selectedScreenIndex => _selectedScreenIndex;

  String? userId;
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

      if (!Hive.isBoxOpen('revenueBox')) {
        await Hive.openLazyBox('revenueBox');
      }
      if (!Hive.isBoxOpen('transactionsBox')) {
        await Hive.openLazyBox('transactionsBox');
      }
      if (!Hive.isBoxOpen('settingsBox')) {
        await Hive.openBox('settingsBox');
      }
      if (!Hive.isBoxOpen('fixedExpensesBox')) {
        await Hive.openBox('fixedExpensesBox');
      }
      if (!Hive.isBoxOpen('monthlyFixedExpensesBox')) {
        await Hive.openBox('monthlyFixedExpensesBox');
      }
      if (!Hive.isBoxOpen('monthlyFixedAmountsBox')) {
        await Hive.openBox('monthlyFixedAmountsBox');
      }

      _loadSettings();
      if (_isFirebaseInitialized) {
        await _loadInitialData();
        _subscribeToFixedExpenses(); // Kích hoạt listener cho chi phí cố định
      }
    } catch (e) {
      _isFirebaseInitialized = false;
    }
  }

  void setSelectedScreenIndex(int index) {
    _selectedScreenIndex = index;
    notifyListeners();
  }

  void _updateProfitAndRelatedListenables() {
    mainRevenueListenable.value = mainRevenue;
    secondaryRevenueListenable.value = secondaryRevenue;
    otherRevenueListenable.value = otherRevenue;
    totalRevenueListenable.value = getTotalRevenue();
    fixedExpenseListenable.value = _fixedExpense;
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

  void setUserId(String id) {
    if (userId != id) {
      userId = id;
      _cachedDateKey = null;
      _cachedData = null;
      _loadSettings();
      _loadInitialData().then((_) {
        _subscribeToFixedExpenses();
        notifyListeners();
      });
    }
  }

  void logout() {
    userId = null;
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
    _saveSettings();
    _cachedDateKey = null;
    _cachedData = null;
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
    return userId != null ? '${userId}_$baseKey' : baseKey;
  }

  void setSelectedDate(DateTime date) {
    if (_selectedDate.year != date.year || _selectedDate.month != date.month || _selectedDate.day != date.day) {
      _selectedDate = date;
      selectedDateListenable.value = date;
      _loadInitialData();
      _subscribeToFixedExpenses();
    }
  }

  Future<void> _loadInitialData() async {
    if (userId == null || _isLoading || !_isFirebaseInitialized) {
      return;
    }
    _isLoading = true;
    isLoadingListenable.value = true;
    dataReadyListenable.value = false;
    try {
      String dateKey = DateFormat('yyyy-MM-dd').format(_selectedDate);
      if (_cachedDateKey == dateKey && _cachedData != null && _cachedData!['userId'] == userId) {
        _applyCachedData(_cachedData!);
        return;
      }
      await Future.wait([
        loadRevenueValues(),
        loadExpenseValues(),
      ]);
      totalRevenueListenable.value = getTotalRevenue();
      profitListenable.value = getProfit();
      profitMarginListenable.value = getProfitMargin();
      _cachedDateKey = dateKey;
      _cachedData = {
        'userId': userId,
        'mainRevenue': mainRevenue,
        'secondaryRevenue': secondaryRevenue,
        'otherRevenue': otherRevenue,
        'mainRevenueTransactions': mainRevenueTransactions.value,
        'secondaryRevenueTransactions': secondaryRevenueTransactions.value,
        'otherRevenueTransactions': otherRevenueTransactions.value,
        'fixedExpense': _fixedExpense,
        'variableExpense': variableExpense,
        'fixedExpenseList': fixedExpenseList.value,
        'variableExpenseList': variableExpenseList.value,
      };
      notifyListeners();
      dataReadyListenable.value = true;
    } catch (e) {
      print('Error in _loadInitialData: $e');
    } finally {
      _isLoading = false;
      isLoadingListenable.value = false;
    }
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

  void _subscribeToFixedExpenses() {
    if (!_isFirebaseInitialized || userId == null) return;
    _cancelFixedExpenseSubscription();
    final firestore = FirebaseFirestore.instance;
    String monthKey = DateFormat('yyyy-MM').format(_selectedDate);
    _fixedExpenseSubscription = firestore
        .collection('users')
        .doc(userId)
        .collection('expenses')
        .doc('fixed')
        .collection('monthly')
        .doc(monthKey)
        .snapshots()
        .listen((snapshot) async {
      if (snapshot.exists) {
        var data = snapshot.data()!;
        await _updateHiveFixedExpenses(data);
        await loadExpenseValues();
        notifyListeners();
      }
    });
  }

  Future<void> _updateHiveFixedExpenses(Map<String, dynamic> data) async {
    try {
      var monthlyFixedExpensesBox = Hive.box('monthlyFixedExpensesBox');
      var monthlyFixedAmountsBox = Hive.box('monthlyFixedAmountsBox');
      String monthKey = DateFormat('yyyy-MM').format(_selectedDate);
      await monthlyFixedExpensesBox.put('${userId}-fixedExpenseList-$monthKey', data['products'] ?? []);
      await monthlyFixedAmountsBox.put('${userId}-monthlyFixedAmounts-$monthKey', data['amounts'] ?? {});
      await _updateSyncTimestamp('${userId}-fixedExpenseList-$monthKey');
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
      var revenueBox = Hive.box('revenueBox');
      var syncTimestamps = (revenueBox.get(getKey('sync_timestamps')) as Map<dynamic, dynamic>?) ?? {};
      syncTimestamps[hiveKey] = DateTime.now().toIso8601String();
      await revenueBox.put(getKey('sync_timestamps'), syncTimestamps);
    } catch (e) {
      print('Lỗi khi cập nhật timestamp đồng bộ: $e');
    }
  }

  Future<bool> _isOnline() async {
    if (!_isFirebaseInitialized) return false;
    try {
      return await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
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
      if (userId == null) {
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
      String firestorePath = 'users/$userId/daily_data/$revenueKey';

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
        }

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

    final fixedExpensesBox = Hive.box('fixedExpensesBox');
    final variableExpensesBox = Hive.box('variableExpensesBox');
    final variableExpenseListBox = Hive.box('variableExpenseListBox');
    final monthlyFixedExpensesBox = Hive.box('monthlyFixedExpensesBox');
    final monthlyFixedAmountsBox = Hive.box('monthlyFixedAmountsBox');

    // Đồng bộ fixedExpenses
    for (var key in fixedExpensesBox.keys) {
      if (key.startsWith('$userId-fixedExpenses-')) {
        final expenses = fixedExpensesBox.get(key);
        await ExpenseManager.saveFixedExpenses(this, List<Map<String, dynamic>>.from(expenses));
      }
    }

    // Đồng bộ variableExpenses
    for (var key in variableExpensesBox.keys) {
      if (key.startsWith('$userId-variableExpenses-')) {
        final expenses = variableExpensesBox.get(key);
        await ExpenseManager.saveVariableExpenses(this, List<Map<String, dynamic>>.from(expenses));
      }
    }

    // Đồng bộ variableExpenseList
    for (var key in variableExpenseListBox.keys) {
      if (key.startsWith('$userId-variableExpenseList-')) {
        final expenses = variableExpenseListBox.get(key);
        final monthKey = key.split('-').last;
        final firestoreDocKey = getKey('variableExpenseList_$monthKey');
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('expenses')
            .doc('variableList')
            .collection('monthly')
            .doc(firestoreDocKey)
            .set({
          'products': expenses,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }

    // Đồng bộ monthlyFixedExpenses
    for (var key in monthlyFixedExpensesBox.keys) {
      if (key.startsWith('$userId-fixedExpenseList-')) {
        final expenses = monthlyFixedExpensesBox.get(key);
        final monthKey = key.split('-').last;
        await ExpenseManager.saveFixedExpenseList(this, List<Map<String, dynamic>>.from(expenses), DateFormat('yyyy-MM').parse(monthKey));
      }
    }

    // Đồng bộ monthlyFixedAmounts
    for (var key in monthlyFixedAmountsBox.keys) {
      if (key.startsWith('$userId-monthlyFixedAmounts-')) {
        final amounts = monthlyFixedAmountsBox.get(key);
        final monthKey = key.split('-').last;
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('expenses')
            .doc('fixed')
            .collection('monthly')
            .doc(monthKey)
            .set({
          'amounts': amounts,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    }

    // Đồng bộ từ Firestore về Hive
    await _syncFixedExpensesFromFirestore();
  }

  Future<void> _syncFixedExpensesFromFirestore() async {
    if (!_isFirebaseInitialized || userId == null) return;
    try {
      String monthKey = DateFormat('yyyy-MM').format(_selectedDate);
      var doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
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
    final String dateKey = DateFormat('yyyy-MM-dd').format(selectedDate);
    final String hiveFixedKey = '$userId-fixedExpenses-$dateKey';
    final String hiveVariableKey = '$userId-variableExpenses-$dateKey';
    final String monthKey = DateFormat('yyyy-MM').format(selectedDate);
    final fixedExpensesBox = Hive.box('fixedExpensesBox');
    final variableExpensesBox = Hive.box('variableExpensesBox');

    try {
      bool isSynced = await _isFirestoreSynced(hiveFixedKey, 'users/$userId/expenses/fixed/daily/$dateKey');
      if (!isSynced && await _isOnline()) {
        final fixedExpenses = await ExpenseManager.loadFixedExpenses(this, selectedDate);
        final variableExpenses = await ExpenseManager.loadVariableExpenses(this);
        fixedExpenseList.value = fixedExpenses;
        variableExpenseList.value = variableExpenses;
        await fixedExpensesBox.put(hiveFixedKey, fixedExpenses);
        await variableExpensesBox.put(hiveVariableKey, variableExpenses);
        await _updateSyncTimestamp(hiveFixedKey);
      } else {
        fixedExpenseList.value = List<Map<String, dynamic>>.from(fixedExpensesBox.get(hiveFixedKey) ?? []);
        variableExpenseList.value = List<Map<String, dynamic>>.from(variableExpensesBox.get(hiveVariableKey) ?? []);
      }

      final fixedTotal = fixedExpenseList.value.fold<double>(0.0, (sum, e) => sum + (e['amount']?.toDouble() ?? 0.0));
      final variableTotal = variableExpenseList.value.fold<double>(0.0, (sum, e) => sum + (e['amount']?.toDouble() ?? 0.0));

      final firestore = FirebaseFirestore.instance;
      final fixedDocRef = firestore
          .collection('users')
          .doc(userId)
          .collection('expenses')
          .doc('fixed')
          .collection('daily')
          .doc(getKey('fixedExpenseList_$dateKey'));
      final fixedDoc = await fixedDocRef.get();
      if (fixedDoc.exists && (fixedDoc['total']?.toDouble() ?? 0.0) != fixedTotal) {
        await fixedDocRef.set({
          'fixedExpenses': fixedExpenseList.value,
          'total': fixedTotal,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      setExpenses(fixedTotal, variableTotal);
    } catch (e) {
      print("Error loading expense values: $e");
      fixedExpenseList.value = List<Map<String, dynamic>>.from(fixedExpensesBox.get(hiveFixedKey) ?? []);
      variableExpenseList.value = List<Map<String, dynamic>>.from(variableExpensesBox.get(hiveVariableKey) ?? []);
      final fixedTotal = fixedExpenseList.value.fold<double>(0.0, (sum, e) => sum + (e['amount']?.toDouble() ?? 0.0));
      final variableTotal = variableExpenseList.value.fold<double>(0.0, (sum, e) => sum + (e['amount']?.toDouble() ?? 0.0));
      setExpenses(fixedTotal, variableTotal);
    }
  }

  Future<void> setRevenue(double main, double secondary, double other) async {
    if (!_isFirebaseInitialized) throw Exception('Firebase not initialized');
    try {
      if (userId == null) throw Exception('User ID không tồn tại');
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
          .doc(userId)
          .collection('expenses')
          .doc('fixed')
          .collection('daily')
          .doc(getKey('fixedExpenseList_$dateKey'))
          .get();
      final variableDocFuture = firestore
          .collection('users')
          .doc(userId)
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
          'name': t['name'].toString(),
          'price': t['price'] as num? ?? 0.0,
          'total': t['total'] as num? ?? 0.0,
          'quantity': t['quantity'] as num? ?? 1.0,
          'date': t['date']?.toString() ?? DateTime.now().toIso8601String(),
        };
      }).toList();
      List<Map<String, dynamic>> standardizedSecondary = secondaryRevenueTransactions.value.map((t) {
        return {
          'name': t['name'].toString(),
          'price': t['price'] as num? ?? 0.0,
          'total': t['total'] as num? ?? 0.0,
          'quantity': t['quantity'] as num? ?? 1.0,
          'date': t['date']?.toString() ?? DateTime.now().toIso8601String(),
        };
      }).toList();
      List<Map<String, dynamic>> standardizedOther = otherRevenueTransactions.value.map((t) {
        return {
          'name': t['name'].toString(),
          'price': t['price'] as num? ?? 0.0,
          'total': t['total'] as num? ?? 0.0,
          'quantity': t['quantity'] as num? ?? 1.0,
          'date': t['date']?.toString() ?? DateTime.now().toIso8601String(),
        };
      }).toList();

      await firestore
          .collection('users')
          .doc(userId)
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
      if (userId == null || !_isFirebaseInitialized) return [];
      return await ExpenseManager.loadAvailableVariableExpenses(this);
    } catch (e) {
      return [];
    }
  }

  Future<void> setExpenses(double fixed, double variable) async {
    if (!_isFirebaseInitialized) throw Exception('Firebase not initialized');
    try {
      if (userId == null) throw Exception('User ID không tồn tại');
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      String dateKey = DateFormat('yyyy-MM-dd').format(_selectedDate);
      _fixedExpense = fixed;
      fixedExpenseListenable.value = fixed;
      variableExpense = variable;
      await firestore
          .collection('users')
          .doc(userId)
          .collection('expenses')
          .doc('fixed')
          .collection('daily')
          .doc(getKey('fixedExpenseList_$dateKey'))
          .update({'total': fixed, 'updatedAt': FieldValue.serverTimestamp()});
      await firestore
          .collection('users')
          .doc(userId)
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
          .doc(userId)
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
      if (userId == null) return {'mainRevenue': 0.0, 'secondaryRevenue': 0.0, 'otherRevenue': 0.0, 'totalRevenue': 0.0};
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
              .doc(userId)
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

  Future<List<Map<String, double>>> getDailyRevenueForRange(DateTimeRange range) async {
    if (!_isFirebaseInitialized) return [];
    try {
      if (userId == null) return [];
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      List<Map<String, double>> dailyData = [];
      int days = range.end.difference(range.start).inDays + 1;

      List<Future<DocumentSnapshot>> futures = [];

      for (int i = 0; i < days; i++) {
        DateTime date = range.start.add(Duration(days: i));
        String dateKey = DateFormat('yyyy-MM-dd').format(date);
        futures.add(
          firestore
              .collection('users')
              .doc(userId)
              .collection('daily_data')
              .doc(getKey(dateKey))
              .get(),
        );
      }

      List<DocumentSnapshot> docs = await Future.wait(futures);

      for (var doc in docs) {
        double mainRevenue = doc.exists ? doc['mainRevenue']?.toDouble() ?? 0.0 : 0.0;
        double secondaryRevenue = doc.exists ? doc['secondaryRevenue']?.toDouble() ?? 0.0 : 0.0;
        double otherRevenue = doc.exists ? doc['otherRevenue']?.toDouble() ?? 0.0 : 0.0;
        dailyData.add({
          'mainRevenue': mainRevenue,
          'secondaryRevenue': secondaryRevenue,
          'otherRevenue': otherRevenue,
          'totalRevenue': mainRevenue + secondaryRevenue + otherRevenue,
        });
      }

      return dailyData;
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, double>> getExpensesForRange(DateTimeRange range) async {
    if (!_isFirebaseInitialized) return {'fixedExpense': 0.0, 'variableExpense': 0.0, 'totalExpense': 0.0};
    try {
      if (userId == null) return {'fixedExpense': 0.0, 'variableExpense': 0.0, 'totalExpense': 0.0};
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
              .doc(userId)
              .collection('expenses')
              .doc('fixed')
              .collection('daily')
              .doc(fixedKey)
              .get(),
        );
        variableFutures.add(
          firestore
              .collection('users')
              .doc(userId)
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

  Future<Map<String, double>> getExpenseBreakdown(DateTimeRange range) async {
    if (!_isFirebaseInitialized) return {};
    try {
      if (userId == null) return {};
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      Map<String, double> breakdown = {};
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
              .doc(userId)
              .collection('expenses')
              .doc('fixed')
              .collection('daily')
              .doc(fixedKey)
              .get(),
        );
        variableFutures.add(
          firestore
              .collection('users')
              .doc(userId)
              .collection('expenses')
              .doc('variable')
              .collection('daily')
              .doc(variableKey)
              .get(),
        );
      }

      List<DocumentSnapshot> fixedDocs = await Future.wait(fixedFutures);
      List<DocumentSnapshot> variableDocs = await Future.wait(variableFutures);

      for (var doc in [...fixedDocs, ...variableDocs]) {
        if (doc.exists && doc['products'] != null) {
          List<dynamic> transactions = doc['products'];
          for (var item in transactions) {
            String name = item['name'] ?? 'Không xác định';
            double amount = item['amount']?.toDouble() ?? 0.0;
            breakdown[name] = (breakdown[name] ?? 0.0) + amount;
          }
        }
      }

      Map<String, double> finalBreakdown = {};
      double otherTotal = 0.0;
      double total = breakdown.values.fold(0.0, (sum, value) => sum + value);
      breakdown.forEach((name, amount) {
        if (total > 0 && (amount / total) < 0.05) {
          otherTotal += amount;
        } else {
          finalBreakdown[name] = amount;
        }
      });
      if (otherTotal > 0) {
        finalBreakdown['Khác'] = otherTotal;
      }

      return finalBreakdown;
    } catch (e) {
      return {};
    }
  }

  Future<List<Map<String, double>>> getDailyExpensesForRange(DateTimeRange range) async {
    if (!_isFirebaseInitialized) return [];
    try {
      if (userId == null) return [];
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      List<Map<String, double>> dailyData = [];
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
              .doc(userId)
              .collection('expenses')
              .doc('fixed')
              .collection('daily')
              .doc(fixedKey)
              .get(),
        );
        variableFutures.add(
          firestore
              .collection('users')
              .doc(userId)
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
        double fixed = fixedDocs[i].exists ? fixedDocs[i]['total']?.toDouble() ?? 0.0 : 0.0;
        double variable = variableDocs[i].exists ? variableDocs[i]['total']?.toDouble() ?? 0.0 : 0.0;
        dailyData.add({
          'fixedExpense': fixed,
          'variableExpense': variable,
          'totalExpense': fixed + variable,
        });
      }

      return dailyData;
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, double>> getOverviewForRange(DateTimeRange range) async {
    if (!_isFirebaseInitialized) {
      return {
        'totalRevenue': 0.0,
        'totalExpense': 0.0,
        'profit': 0.0,
        'averageProfitMargin': 0.0,
        'avgRevenuePerDay': 0.0,
        'avgExpensePerDay': 0.0,
        'avgProfitPerDay': 0.0,
        'expenseToRevenueRatio': 0.0,
      };
    }
    try {
      if (userId == null) {
        return {
          'totalRevenue': 0.0,
          'totalExpense': 0.0,
          'profit': 0.0,
          'averageProfitMargin': 0.0,
          'avgRevenuePerDay': 0.0,
          'avgExpensePerDay': 0.0,
          'avgProfitPerDay': 0.0,
          'expenseToRevenueRatio': 0.0,
        };
      }
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
        String key = getKey(dateKey);
        String fixedKey = getKey('fixedExpenseList_$dateKey');
        String variableKey = getKey('variableTransactionHistory_$dateKey');

        dailyFutures.add(
          firestore
              .collection('users')
              .doc(userId)
              .collection('daily_data')
              .doc(key)
              .get(),
        );
        fixedFutures.add(
          firestore
              .collection('users')
              .doc(userId)
              .collection('expenses')
              .doc('fixed')
              .collection('daily')
              .doc(fixedKey)
              .get(),
        );
        variableFutures.add(
          firestore
              .collection('users')
              .doc(userId)
              .collection('expenses')
              .doc('variable')
              .collection('daily')
              .doc(variableKey)
              .get(),
        );
      }

      List<DocumentSnapshot> dailyDocs = await Future.wait(dailyFutures);
      List<DocumentSnapshot> fixedDocs = await Future.wait(fixedFutures);
      List<DocumentSnapshot> variableDocs = await Future.wait(variableFutures);

      for (int i = 0; i < days; i++) {
        double revenue = 0.0;
        if (dailyDocs[i].exists && dailyDocs[i].data() != null) {
          final data = dailyDocs[i].data() as Map<String, dynamic>?;
          revenue = data != null && data.containsKey('totalRevenue')
              ? (data['totalRevenue'] as num?)?.toDouble() ?? 0.0
              : 0.0;
        }
        totalRevenue += revenue;

        double fixedExpense = 0.0;
        if (fixedDocs[i].exists && fixedDocs[i].data() != null) {
          final data = fixedDocs[i].data() as Map<String, dynamic>?;
          fixedExpense = data != null && data.containsKey('total')
              ? (data['total'] as num?)?.toDouble() ?? 0.0
              : 0.0;
        }

        double variableExpense = 0.0;
        if (variableDocs[i].exists && variableDocs[i].data() != null) {
          final data = variableDocs[i].data() as Map<String, dynamic>?;
          variableExpense = data != null && data.containsKey('total')
              ? (data['total'] as num?)?.toDouble() ?? 0.0
              : 0.0;
        }

        totalExpense += fixedExpense + variableExpense;
      }

      double profit = totalRevenue - totalExpense;
      double avgRevenuePerDay = days > 0 ? totalRevenue / days : 0.0;
      double avgExpensePerDay = days > 0 ? totalExpense / days : 0.0;
      double avgProfitPerDay = days > 0 ? profit / days : 0.0;
      double averageProfitMargin = totalRevenue > 0 ? (profit / totalRevenue) * 100 : 0.0;
      double expenseToRevenueRatio = totalRevenue > 0 ? (totalExpense / totalRevenue) * 100 : 0.0;

      return {
        'totalRevenue': totalRevenue,
        'totalExpense': totalExpense,
        'profit': profit,
        'averageProfitMargin': averageProfitMargin,
        'avgRevenuePerDay': avgRevenuePerDay,
        'avgExpensePerDay': avgExpensePerDay,
        'avgProfitPerDay': avgProfitPerDay,
        'expenseToRevenueRatio': expenseToRevenueRatio,
      };
    } catch (e) {
      return {
        'totalRevenue': 0.0,
        'totalExpense': 0.0,
        'profit': 0.0,
        'averageProfitMargin': 0.0,
        'avgRevenuePerDay': 0.0,
        'avgExpensePerDay': 0.0,
        'avgProfitPerDay': 0.0,
        'expenseToRevenueRatio': 0.0,
      };
    }
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
      if (userId == null) {
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
            .doc(userId)
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

  Future<List<Map<String, double>>> getDailyOverviewForRange(DateTimeRange range) async {
    if (!_isFirebaseInitialized) return [];
    try {
      if (userId == null) return [];
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      List<Map<String, double>> dailyData = [];
      int days = range.end.difference(range.start).inDays + 1;

      List<Future<DocumentSnapshot>> dailyFutures = [];
      List<Future<DocumentSnapshot>> fixedFutures = [];
      List<Future<DocumentSnapshot>> variableFutures = [];

      for (int i = 0; i < days; i++) {
        DateTime date = range.start.add(Duration(days: i));
        String dateKey = DateFormat('yyyy-MM-dd').format(date);
        String key = getKey(dateKey);
        String fixedKey = getKey('fixedExpenseList_$dateKey');
        String variableKey = getKey('variableTransactionHistory_$dateKey');

        dailyFutures.add(
          firestore
              .collection('users')
              .doc(userId)
              .collection('daily_data')
              .doc(key)
              .get(),
        );
        fixedFutures.add(
          firestore
              .collection('users')
              .doc(userId)
              .collection('expenses')
              .doc('fixed')
              .collection('daily')
              .doc(fixedKey)
              .get(),
        );
        variableFutures.add(
          firestore
              .collection('users')
              .doc(userId)
              .collection('expenses')
              .doc('variable')
              .collection('daily')
              .doc(variableKey)
              .get(),
        );
      }

      List<DocumentSnapshot> dailyDocs = await Future.wait(dailyFutures);
      List<DocumentSnapshot> fixedDocs = await Future.wait(fixedFutures);
      List<DocumentSnapshot> variableDocs = await Future.wait(variableFutures);

      for (int i = 0; i < days; i++) {
        double totalRevenue = dailyDocs[i].exists ? dailyDocs[i]['totalRevenue']?.toDouble() ?? 0.0 : 0.0;
        double fixedExpense = fixedDocs[i].exists ? fixedDocs[i]['total']?.toDouble() ?? 0.0 : 0.0;
        double variableExpense = variableDocs[i].exists ? variableDocs[i]['total']?.toDouble() ?? 0.0 : 0.0;
        double totalExpense = fixedExpense + variableExpense;
        double profit = totalRevenue - totalExpense;
        dailyData.add({
          'totalRevenue': totalRevenue,
          'totalExpense': totalExpense,
          'profit': profit,
        });
      }

      return dailyData;
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, double>> getProductRevenueBreakdown(DateTimeRange range) async {
    if (!_isFirebaseInitialized) return {};
    try {
      if (userId == null) return {};
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      Map<String, double> productTotals = {};
      double totalRevenue = 0.0;
      int days = range.end.difference(range.start).inDays + 1;
      for (int i = 0; i < days; i++) {
        DateTime date = range.start.add(Duration(days: i));
        String dateKey = DateFormat('yyyy-MM-dd').format(date);
        DocumentSnapshot doc = await firestore
            .collection('users')
            .doc(userId)
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
      if (userId == null) return {};
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      Map<String, double> productTotals = {};
      int days = range.end.difference(range.start).inDays + 1;
      for (int i = 0; i < days; i++) {
        DateTime date = range.start.add(Duration(days: i));
        String dateKey = DateFormat('yyyy-MM-dd').format(date);
        DocumentSnapshot doc = await firestore
            .collection('users')
            .doc(userId)
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
      if (userId == null) return {};
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
              .doc(userId)
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
    super.dispose();
  }
}