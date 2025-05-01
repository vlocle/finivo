import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart' as model;
import '/screens/expense_manager.dart';
import '/screens/revenue_manager.dart';

class AppState extends ChangeNotifier {
  String? userId;
  DateTime selectedDate = DateTime.now();
  double mainRevenue = 0.0;
  double secondaryRevenue = 0.0;
  double otherRevenue = 0.0;
  double fixedExpense = 0.0;
  double variableExpense = 0.0;
  final ValueNotifier<List<Map<String, dynamic>>> fixedExpenseList = ValueNotifier([]);
  final ValueNotifier<List<Map<String, dynamic>>> variableExpenseList = ValueNotifier([]);
  final ValueNotifier<List<Map<String, dynamic>>> mainRevenueTransactions = ValueNotifier([]);
  final ValueNotifier<List<Map<String, dynamic>>> secondaryRevenueTransactions = ValueNotifier([]);
  final ValueNotifier<List<Map<String, dynamic>>> otherRevenueTransactions = ValueNotifier([]);
  final ValueNotifier<bool> productsUpdated = ValueNotifier(false);
  bool _notificationsEnabled = true;
  String _currentLanguage = 'vi';
  bool _isDarkMode = false;

  bool get notificationsEnabled => _notificationsEnabled;
  String get currentLanguage => _currentLanguage;
  bool get isDarkMode => _isDarkMode;

  AppState() {
    loadExpenseValues();
    _loadSettings();
  }

  void _loadSettings() {
    var settingsBox = Hive.box('settingsBox');
    _notificationsEnabled = settingsBox.get(getKey('notificationsEnabled'), defaultValue: true);
    _isDarkMode = settingsBox.get(getKey('isDarkMode'), defaultValue: false);
  }

  void _saveSettings() {
    var settingsBox = Hive.box('settingsBox');
    settingsBox.put(getKey('notificationsEnabled'), _notificationsEnabled);
    settingsBox.put(getKey('isDarkMode'), _isDarkMode);
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

  void setUserId(String id) {
    if (userId != id) {
      userId = id;
      _loadInitialData();
    }
  }

  void logout() {
    userId = null;
    mainRevenue = 0.0;
    secondaryRevenue = 0.0;
    otherRevenue = 0.0;
    fixedExpense = 0.0;
    variableExpense = 0.0;
    mainRevenueTransactions.value = [];
    secondaryRevenueTransactions.value = [];
    otherRevenueTransactions.value = [];
    fixedExpenseList.value = [];
    variableExpenseList.value = [];
    notifyListeners();
  }

  String getKey(String baseKey) {
    return userId != null ? '${userId}_$baseKey' : baseKey;
  }

  void setSelectedDate(DateTime date) {
    if (selectedDate != date) {
      selectedDate = date;
      _loadInitialData();
    }
  }

  Future<void> _loadInitialData() async {
    if (userId == null) return;
    await loadRevenueValues();
    await loadExpenseValues();
    notifyListeners();
  }

  void notifyProductsUpdated() {
    productsUpdated.value = !productsUpdated.value;
    notifyListeners();
  }

  Future<void> loadRevenueValues() async {
    try {
      if (userId == null) {
        print('User ID không tồn tại');
        mainRevenue = 0.0;
        secondaryRevenue = 0.0;
        otherRevenue = 0.0;
        mainRevenueTransactions.value = [];
        secondaryRevenueTransactions.value = [];
        otherRevenueTransactions.value = [];
        notifyListeners();
        return;
      }

      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      String dateKey = DateFormat('yyyy-MM-dd').format(selectedDate);
      String revenueKey = getKey(dateKey);
      String mainTransKey = getKey('${dateKey}_mainRevenueTransactions');
      String secondaryTransKey = getKey('${dateKey}_secondaryRevenueTransactions');
      String otherTransKey = getKey('${dateKey}_otherRevenueTransactions');

      if (!Hive.isBoxOpen('revenueBox')) await Hive.openBox('revenueBox');
      if (!Hive.isBoxOpen('transactionsBox')) await Hive.openBox('transactionsBox');
      var revenueBox = Hive.box('revenueBox');
      var transactionsBox = Hive.box('transactionsBox');

      print('Hive transactionsBox keys: ${transactionsBox.keys}');

      if (revenueBox.containsKey(revenueKey) &&
          transactionsBox.containsKey(mainTransKey) &&
          transactionsBox.containsKey(secondaryTransKey) &&
          transactionsBox.containsKey(otherTransKey)) {
        var revenueData = revenueBox.get(revenueKey) as Map<dynamic, dynamic>;
        mainRevenue = revenueData['mainRevenue']?.toDouble() ?? 0.0;
        secondaryRevenue = revenueData['secondaryRevenue']?.toDouble() ?? 0.0;
        otherRevenue = revenueData['otherRevenue']?.toDouble() ?? 0.0;

        // Chuyển đổi an toàn cho mainRevenueTransactions
        var mainData = transactionsBox.get(mainTransKey);
        mainRevenueTransactions.value = mainData != null
            ? (mainData as List<dynamic>).map((item) {
          var map = item as Map<dynamic, dynamic>;
          return map.map((key, value) => MapEntry(key.toString(), value));
        }).cast<Map<String, dynamic>>().toList()
            : [];

        // Chuyển đổi an toàn cho secondaryRevenueTransactions
        var secondaryData = transactionsBox.get(secondaryTransKey);
        secondaryRevenueTransactions.value = secondaryData != null
            ? (secondaryData as List<dynamic>).map((item) {
          var map = item as Map<dynamic, dynamic>;
          return map.map((key, value) => MapEntry(key.toString(), value));
        }).cast<Map<String, dynamic>>().toList()
            : [];

        // Chuyển đổi an toàn cho otherRevenueTransactions
        var otherData = transactionsBox.get(otherTransKey);
        otherRevenueTransactions.value = otherData != null
            ? (otherData as List<dynamic>).map((item) {
          var map = item as Map<dynamic, dynamic>;
          return map.map((key, value) => MapEntry(key.toString(), value));
        }).cast<Map<String, dynamic>>().toList()
            : [];

        print('Tải giao dịch từ Hive: main=$mainRevenueTransactions, secondary=$secondaryRevenueTransactions');
      } else {
        DocumentSnapshot doc = await firestore
            .collection('users')
            .doc(userId)
            .collection('daily_data')
            .doc(getKey(dateKey))
            .get();

        if (doc.exists) {
          mainRevenue = doc['mainRevenue']?.toDouble() ?? 0.0;
          secondaryRevenue = doc['secondaryRevenue']?.toDouble() ?? 0.0;
          otherRevenue = doc['otherRevenue']?.toDouble() ?? 0.0;
          mainRevenueTransactions.value = List<Map<String, dynamic>>.from(doc['mainRevenueTransactions'] ?? []);
          secondaryRevenueTransactions.value = List<Map<String, dynamic>>.from(doc['secondaryRevenueTransactions'] ?? []);
          otherRevenueTransactions.value = List<Map<String, dynamic>>.from(doc['otherRevenueTransactions'] ?? []);
          print('Tải giao dịch từ Firestore: main=$mainRevenueTransactions, secondary=$secondaryRevenueTransactions');
        } else {
          mainRevenue = 0.0;
          secondaryRevenue = 0.0;
          otherRevenue = 0.0;
          mainRevenueTransactions.value = [];
          secondaryRevenueTransactions.value = [];
          otherRevenueTransactions.value = [];
        }

        await revenueBox.put(revenueKey, {
          'mainRevenue': mainRevenue,
          'secondaryRevenue': secondaryRevenue,
          'otherRevenue': otherRevenue,
          'lastUpdated': DateTime.now().toIso8601String(),
        });
        await transactionsBox.put(mainTransKey, mainRevenueTransactions.value);
        await transactionsBox.put(secondaryTransKey, secondaryRevenueTransactions.value);
        await transactionsBox.put(otherTransKey, otherRevenueTransactions.value);
      }
    } catch (e) {
      print('Lỗi khi tải doanh thu: $e');
      mainRevenue = 0.0;
      secondaryRevenue = 0.0;
      otherRevenue = 0.0;
      mainRevenueTransactions.value = [];
      secondaryRevenueTransactions.value = [];
      otherRevenueTransactions.value = [];
    }
    notifyListeners();
  }

  Future<void> setRevenue(double main, double secondary, double other) async {
    try {
      if (userId == null) throw Exception('User ID không tồn tại');
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      String dateKey = DateFormat('yyyy-MM-dd').format(selectedDate);
      String revenueKey = getKey(dateKey);
      String mainTransKey = getKey('${dateKey}_mainRevenueTransactions');
      String secondaryTransKey = getKey('${dateKey}_secondaryRevenueTransactions');
      String otherTransKey = getKey('${dateKey}_otherRevenueTransactions');

      mainRevenue = main;
      secondaryRevenue = secondary;
      otherRevenue = other;

      double totalRevenue = main + secondary + other;
      DocumentSnapshot fixedDoc = await firestore
          .collection('users')
          .doc(userId)
          .collection('expenses')
          .doc('fixed')
          .collection('daily')
          .doc(getKey('fixedExpenseList_$dateKey'))
          .get();
      DocumentSnapshot variableDoc = await firestore
          .collection('users')
          .doc(userId)
          .collection('expenses')
          .doc('variable')
          .collection('daily')
          .doc(getKey('variableTransactionHistory_$dateKey'))
          .get();

      double fixedExpense = fixedDoc.exists ? fixedDoc['total']?.toDouble() ?? 0.0 : 0.0;
      double variableExpense = variableDoc.exists ? variableDoc['total']?.toDouble() ?? 0.0 : 0.0;
      this.fixedExpense = fixedExpense;
      this.variableExpense = variableExpense;

      double totalExpense = fixedExpense + variableExpense;
      double profit = totalRevenue - totalExpense;
      double profitMargin = totalRevenue > 0 ? (profit / totalRevenue) * 100 : 0;

      // Chuẩn hóa dữ liệu giao dịch trước khi lưu
      List<Map<String, dynamic>> standardizedMain = mainRevenueTransactions.value.map((t) {
        return {
          'name': t['name'].toString(),
          'total': t['total'] as num? ?? 0.0,
          'quantity': t['quantity'] as num? ?? 1.0,
        };
      }).toList();
      List<Map<String, dynamic>> standardizedSecondary = secondaryRevenueTransactions.value.map((t) {
        return {
          'name': t['name'].toString(),
          'total': t['total'] as num? ?? 0.0,
          'quantity': t['quantity'] as num? ?? 1.0,
        };
      }).toList();
      List<Map<String, dynamic>> standardizedOther = otherRevenueTransactions.value.map((t) {
        return {
          'name': t['name'].toString(),
          'total': t['total'] as num? ?? 0.0,
          'quantity': t['quantity'] as num? ?? 1.0,
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

      notifyListeners();
    } catch (e) {
      print('Lỗi khi lưu doanh thu: $e');
      throw Exception('Không thể lưu doanh thu: $e');
    }
  }

  // Các hàm còn lại giữ nguyên
  Map<String, List<model.Transaction>> transactions = {
    'Doanh thu chính': [],
    'Doanh thu phụ': [],
    'Doanh thu khác': [],
  };

  Future<void> loadExpenseValues() async {
    try {
      if (userId == null) throw Exception('User ID không tồn tại');
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      String dateKey = DateFormat('yyyy-MM-dd').format(selectedDate);
      DocumentSnapshot fixedDoc = await firestore
          .collection('users')
          .doc(userId)
          .collection('expenses')
          .doc('fixed')
          .collection('daily')
          .doc(getKey('fixedExpenseList_$dateKey'))
          .get();
      DocumentSnapshot variableDoc = await firestore
          .collection('users')
          .doc(userId)
          .collection('expenses')
          .doc('variable')
          .collection('daily')
          .doc(getKey('variableTransactionHistory_$dateKey'))
          .get();
      fixedExpense = fixedDoc.exists ? fixedDoc['total']?.toDouble() ?? 0.0 : 0.0;
      variableExpense = variableDoc.exists ? variableDoc['total']?.toDouble() ?? 0.0 : 0.0;
      fixedExpenseList.value = await ExpenseManager.loadFixedExpenses(this);
      variableExpenseList.value = await ExpenseManager.loadVariableExpenses(this);
    } catch (e) {
      print('Lỗi khi tải chi phí: $e');
      fixedExpense = 0.0;
      variableExpense = 0.0;
      fixedExpenseList.value = [];
      variableExpenseList.value = [];
    }
  }

  Future<List<Map<String, dynamic>>> loadVariableExpenseList() async {
    try {
      if (userId == null) return [];
      return await ExpenseManager.loadAvailableVariableExpenses(this);
    } catch (e) {
      print('Lỗi khi tải danh sách chi phí biến đổi: $e');
      return [];
    }
  }

  Future<void> setExpenses(double fixed, double variable) async {
    try {
      if (userId == null) throw Exception('User ID không tồn tại');
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      String dateKey = DateFormat('yyyy-MM-dd').format(selectedDate);
      fixedExpense = fixed;
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
      notifyListeners();
    } catch (e) {
      print('Lỗi khi lưu chi phí: $e');
      throw Exception('Không thể lưu chi phí: $e');
    }
  }

  Future<Map<String, double>> getRevenueForRange(DateTimeRange range) async {
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
      print('Lỗi khi lấy doanh thu: $e');
      return {'mainRevenue': 0.0, 'secondaryRevenue': 0.0, 'otherRevenue': 0.0, 'totalRevenue': 0.0};
    }
  }

  Future<List<Map<String, double>>> getDailyRevenueForRange(DateTimeRange range) async {
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
      print('Lỗi khi lấy doanh thu hàng ngày: $e');
      return [];
    }
  }

  Future<Map<String, double>> getExpensesForRange(DateTimeRange range) async {
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
      print('Lỗi khi lấy chi phí: $e');
      return {'fixedExpense': 0.0, 'variableExpense': 0.0, 'totalExpense': 0.0};
    }
  }

  Future<Map<String, double>> getExpenseBreakdown(DateTimeRange range) async {
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
      print('Lỗi khi lấy phân bổ chi phí: $e');
      return {};
    }
  }

  Future<List<Map<String, double>>> getDailyExpensesForRange(DateTimeRange range) async {
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
      print('Lỗi khi lấy chi phí hàng ngày: $e');
      return [];
    }
  }

  Future<Map<String, double>> getOverviewForRange(DateTimeRange range) async {
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

      // Tạo danh sách các Future để truy vấn đồng thời
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

      // Chờ tất cả các truy vấn hoàn tất đồng thời
      List<DocumentSnapshot> dailyDocs = await Future.wait(dailyFutures);
      List<DocumentSnapshot> fixedDocs = await Future.wait(fixedFutures);
      List<DocumentSnapshot> variableDocs = await Future.wait(variableFutures);

      // Xử lý dữ liệu
      for (int i = 0; i < days; i++) {
        totalRevenue += dailyDocs[i].exists ? dailyDocs[i]['totalRevenue']?.toDouble() ?? 0.0 : 0.0;
        double fixedExpense = fixedDocs[i].exists ? fixedDocs[i]['total']?.toDouble() ?? 0.0 : 0.0;
        double variableExpense = variableDocs[i].exists ? variableDocs[i]['total']?.toDouble() ?? 0.0 : 0.0;
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
      print('Lỗi khi lấy tổng quan: $e');
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
      print('Lỗi khi lấy top sản phẩm: $e');
      return {
        'Doanh thu chính': {},
        'Doanh thu phụ': {},
        'Doanh thu khác': {},
      };
    }
  }

  Future<List<Map<String, double>>> getDailyOverviewForRange(DateTimeRange range) async {
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
      print('Lỗi khi lấy tổng quan hàng ngày: $e');
      return [];
    }
  }

  Future<Map<String, double>> getProductRevenueBreakdown(DateTimeRange range) async {
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
      print('Lỗi khi lấy phân bổ doanh thu: $e');
      return {};
    }
  }

  Future<Map<String, double>> getProductRevenueTotals(DateTimeRange range) async {
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
      print('Lỗi khi lấy tổng doanh thu sản phẩm: $e');
      return {};
    }
  }

  Future<Map<String, Map<String, double>>> getProductRevenueDetails(DateTimeRange range) async {
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
      print('Lỗi khi lấy chi tiết doanh thu sản phẩm: $e');
      return {};
    }
  }

  double getTotalRevenue() {
    return mainRevenue + secondaryRevenue + otherRevenue;
  }

  double getTotalFixedAndVariableExpense() {
    return fixedExpense + variableExpense;
  }

  double getProfit() {
    return getTotalRevenue() - getTotalFixedAndVariableExpense();
  }

  double getProfitMargin() {
    double revenue = getTotalRevenue();
    if (revenue == 0) return 0;
    return (getProfit() / revenue) * 100;
  }
}