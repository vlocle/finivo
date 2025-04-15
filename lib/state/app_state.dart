import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart' as model;
import '/screens/expense_manager.dart';
import '/screens/revenue_manager.dart';

class AppState extends ChangeNotifier {
  String? userId; // Thêm userId để tách biệt dữ liệu
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

  bool _notificationsEnabled = true;
  String _currentLanguage = 'vi'; // Mặc định là Tiếng Việt
  bool _isDarkMode = false; // Mặc định là chế độ sáng

  bool get notificationsEnabled => _notificationsEnabled;
  String get currentLanguage => _currentLanguage;
  bool get isDarkMode => _isDarkMode;

  AppState() {
    loadExpenseValues();
    loadRevenueValues();
    _loadSettings();
  }

  // Tải cài đặt từ Hive
  void _loadSettings() {
    var settingsBox = Hive.box('settingsBox');
    _notificationsEnabled = settingsBox.get(getKey('notificationsEnabled'), defaultValue: true);
    _isDarkMode = settingsBox.get(getKey('isDarkMode'), defaultValue: false);
  }

  // Lưu cài đặt vào Hive
  void _saveSettings() {
    var settingsBox = Hive.box('settingsBox');
    settingsBox.put(getKey('notificationsEnabled'), _notificationsEnabled);
    settingsBox.put(getKey('isDarkMode'), _isDarkMode);
  }

  // Các hàm cho cài đặt chung
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

  // Hàm để thiết lập userId sau khi đăng nhập
  void setUserId(String id) {
    if (userId != id) {
      userId = id;
      _loadInitialData(); // Tải dữ liệu ban đầu
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

  // Hàm hỗ trợ thêm tiền tố userId vào key
  String getKey(String baseKey) {
    return userId != null ? '${userId}_$baseKey' : baseKey;
  }

  void setSelectedDate(DateTime date) {
    if (selectedDate != date) {
      selectedDate = date;
      _loadInitialData(); // Tải dữ liệu khi thay đổi ngày
    }
  }

  Future<void> _loadInitialData() async {
    await loadRevenueValues();
    await loadExpenseValues();
    notifyListeners(); // Chỉ gọi 1 lần sau khi tải xong
  }

  // ========== Doanh Thu ==========
  Future<void> loadRevenueValues() async {
    try {
      if (userId == null) throw Exception('User ID không tồn tại');
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      String dateKey = DateFormat('yyyy-MM-dd').format(selectedDate);

      // Tải doanh thu từ Firestore
      DocumentSnapshot mainDoc = await firestore
          .collection('users')
          .doc(userId)
          .collection('revenue')
          .doc(getKey('revenue_Doanh thu chính_$dateKey'))
          .get();
      DocumentSnapshot secondaryDoc = await firestore
          .collection('users')
          .doc(userId)
          .collection('revenue')
          .doc(getKey('revenue_Doanh thu phụ_$dateKey'))
          .get();
      DocumentSnapshot otherDoc = await firestore
          .collection('users')
          .doc(userId)
          .collection('revenue')
          .doc(getKey('revenue_Doanh thu khác_$dateKey'))
          .get();

      mainRevenue = mainDoc.exists ? mainDoc['total']?.toDouble() ?? 0.0 : 0.0;
      secondaryRevenue = secondaryDoc.exists ? secondaryDoc['total']?.toDouble() ?? 0.0 : 0.0;
      otherRevenue = otherDoc.exists ? otherDoc['total']?.toDouble() ?? 0.0 : 0.0;

      // Tải lịch sử giao dịch
      mainRevenueTransactions.value = await RevenueManager.loadTransactionHistory(this, 'Doanh thu chính');
      secondaryRevenueTransactions.value = await RevenueManager.loadTransactionHistory(this, 'Doanh thu phụ');
      otherRevenueTransactions.value = await RevenueManager.loadTransactionHistory(this, 'Doanh thu khác');
    } catch (e) {
      print('Lỗi khi tải doanh thu: $e');
      mainRevenue = 0.0;
      secondaryRevenue = 0.0;
      otherRevenue = 0.0;
      mainRevenueTransactions.value = [];
      secondaryRevenueTransactions.value = [];
      otherRevenueTransactions.value = [];
    }
  }

  Future<void> setRevenue(double main, double secondary, double other) async {
    try {
      if (userId == null) throw Exception('User ID không tồn tại');
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      String dateKey = DateFormat('yyyy-MM-dd').format(selectedDate);

      // Lưu doanh thu
      await firestore
          .collection('users')
          .doc(userId)
          .collection('revenue')
          .doc(getKey('revenue_Doanh thu chính_$dateKey'))
          .set({
        'total': main,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await firestore
          .collection('users')
          .doc(userId)
          .collection('revenue')
          .doc(getKey('revenue_Doanh thu phụ_$dateKey'))
          .set({
        'total': secondary,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await firestore
          .collection('users')
          .doc(userId)
          .collection('revenue')
          .doc(getKey('revenue_Doanh thu khác_$dateKey'))
          .set({
        'total': other,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Cập nhật trạng thái
      mainRevenue = main;
      secondaryRevenue = secondary;
      otherRevenue = other;
      double totalRevenue = main + secondary + other;

      await firestore
          .collection('users')
          .doc(userId)
          .collection('revenue')
          .doc(getKey('total_revenue_$dateKey'))
          .set({
        'total': totalRevenue,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Lấy chi phí từ Firestore
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
      double totalExpense = fixedExpense + variableExpense;

      // Tính lợi nhuận
      double profit = totalRevenue - totalExpense;
      double profitMargin = totalRevenue > 0 ? (profit / totalRevenue) * 100 : 0;

      // Lưu lợi nhuận và tỷ suất lợi nhuận
      await firestore
          .collection('users')
          .doc(userId)
          .collection('revenue')
          .doc(getKey('profit_$dateKey'))
          .set({
        'total': profit,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await firestore
          .collection('users')
          .doc(userId)
          .collection('revenue')
          .doc(getKey('profitMargin_$dateKey'))
          .set({
        'total': profitMargin,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      notifyListeners();
    } catch (e) {
      print('Lỗi khi lưu doanh thu: $e');
      throw Exception('Không thể lưu doanh thu: $e');
    }
  }

  Map<String, List<model.Transaction>> transactions = {
    'Doanh thu chính': [],
    'Doanh thu phụ': [],
    'Doanh thu khác': [],
  };

  // ========== Chi Phí ==========
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

      // Lưu tổng chi phí vào Firestore
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

      // Tính lợi nhuận
      double totalRevenue = getTotalRevenue();
      double totalExpense = fixed + variable;
      double profit = totalRevenue - totalExpense;
      double profitMargin = totalRevenue > 0 ? (profit / totalRevenue) * 100 : 0;

      await firestore
          .collection('users')
          .doc(userId)
          .collection('revenue')
          .doc(getKey('profit_$dateKey'))
          .set({'total': profit, 'updatedAt': FieldValue.serverTimestamp()});
      await firestore
          .collection('users')
          .doc(userId)
          .collection('revenue')
          .doc(getKey('profitMargin_$dateKey'))
          .set({'total': profitMargin, 'updatedAt': FieldValue.serverTimestamp()});

      notifyListeners();
    } catch (e) {
      print('Lỗi khi lưu chi phí: $e');
      throw Exception('Không thể lưu chi phí: $e');
    }
  }

  // Các hàm báo cáo giữ nguyên, chỉ cập nhật key với _getKey
  Future<Map<String, double>> getRevenueForRange(DateTimeRange range) async {
    try {
      if (userId == null) return {'mainRevenue': 0.0, 'secondaryRevenue': 0.0, 'otherRevenue': 0.0, 'totalRevenue': 0.0};
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      double mainRevenueTotal = 0.0;
      double secondaryRevenueTotal = 0.0;
      double otherRevenueTotal = 0.0;
      int days = range.end.difference(range.start).inDays + 1;

      for (int i = 0; i < days; i++) {
        DateTime date = range.start.add(Duration(days: i));
        String dateKey = DateFormat('yyyy-MM-dd').format(date);

        DocumentSnapshot mainDoc = await firestore
            .collection('users')
            .doc(userId)
            .collection('revenue')
            .doc(getKey('revenue_Doanh thu chính_$dateKey'))
            .get();
        DocumentSnapshot secondaryDoc = await firestore
            .collection('users')
            .doc(userId)
            .collection('revenue')
            .doc(getKey('revenue_Doanh thu phụ_$dateKey'))
            .get();
        DocumentSnapshot otherDoc = await firestore
            .collection('users')
            .doc(userId)
            .collection('revenue')
            .doc(getKey('revenue_Doanh thu khác_$dateKey'))
            .get();

        mainRevenueTotal += mainDoc.exists ? mainDoc['total']?.toDouble() ?? 0.0 : 0.0;
        secondaryRevenueTotal += secondaryDoc.exists ? secondaryDoc['total']?.toDouble() ?? 0.0 : 0.0;
        otherRevenueTotal += otherDoc.exists ? otherDoc['total']?.toDouble() ?? 0.0 : 0.0;
      }

      return {
        'mainRevenue': mainRevenueTotal,
        'secondaryRevenue': secondaryRevenueTotal,
        'otherRevenue': otherRevenueTotal,
        'totalRevenue': mainRevenueTotal + secondaryRevenueTotal + otherRevenueTotal
      };
    } catch (e) {
      print('Lỗi khi lấy doanh thu: $e');
      return {
        'mainRevenue': 0.0,
        'secondaryRevenue': 0.0,
        'otherRevenue': 0.0,
        'totalRevenue': 0.0
      };
    }
  }

  Future<List<Map<String, double>>> getDailyRevenueForRange(DateTimeRange range) async {
    try {
      if (userId == null) return [];
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      List<Map<String, double>> dailyData = [];
      int days = range.end.difference(range.start).inDays + 1;

      for (int i = 0; i < days; i++) {
        DateTime date = range.start.add(Duration(days: i));
        String dateKey = DateFormat('yyyy-MM-dd').format(date);

        DocumentSnapshot mainDoc = await firestore
            .collection('users')
            .doc(userId)
            .collection('revenue')
            .doc(getKey('revenue_Doanh thu chính_$dateKey'))
            .get();
        DocumentSnapshot secondaryDoc = await firestore
            .collection('users')
            .doc(userId)
            .collection('revenue')
            .doc(getKey('revenue_Doanh thu phụ_$dateKey'))
            .get();
        DocumentSnapshot otherDoc = await firestore
            .collection('users')
            .doc(userId)
            .collection('revenue')
            .doc(getKey('revenue_Doanh thu khác_$dateKey'))
            .get();

        double mainRevenue = mainDoc.exists ? mainDoc['total']?.toDouble() ?? 0.0 : 0.0;
        double secondaryRevenue = secondaryDoc.exists ? secondaryDoc['total']?.toDouble() ?? 0.0 : 0.0;
        double otherRevenue = otherDoc.exists ? otherDoc['total']?.toDouble() ?? 0.0 : 0.0;

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

      for (int i = 0; i < days; i++) {
        DateTime date = range.start.add(Duration(days: i));
        String dateKey = DateFormat('yyyy-MM-dd').format(date);

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

        fixedExpenseTotal += fixedDoc.exists ? fixedDoc['total']?.toDouble() ?? 0.0 : 0.0;
        variableExpenseTotal += variableDoc.exists ? variableDoc['total']?.toDouble() ?? 0.0 : 0.0;
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
      for (int i = 0; i < days; i++) {
        DateTime date = range.start.add(Duration(days: i));
        String dateKey = DateFormat('yyyy-MM-dd').format(date);
        for (String type in ['fixed', 'variable']) {
          DocumentSnapshot doc = await firestore
              .collection('users')
              .doc(userId)
              .collection('expenses')
              .doc(type)
              .collection('daily')
              .doc(getKey(type == 'fixed' ? 'fixedExpenseList_$dateKey' : 'variableTransactionHistory_$dateKey'))
              .get();
          if (doc.exists && doc['products'] != null) {
            List<dynamic> transactions = doc['products'];
            for (var item in transactions) {
              String name = item['name'] ?? 'Không xác định';
              double amount = item['amount']?.toDouble() ?? 0.0;
              breakdown[name] = (breakdown[name] ?? 0.0) + amount;
            }
          }
        }
      }
      // Nhóm các khoản chi phí dưới 5% vào "Khác"
      Map<String, double> finalBreakdown = {};
      double otherTotal = 0.0;
      double total = breakdown.values.fold(0.0, (sum, value) => sum + value);
      breakdown.forEach((name, amount) {
        if (total > 0 && (amount / total) < 0.05) { // Nhỏ hơn 5% tổng chi phí
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

      for (int i = 0; i < days; i++) {
        DateTime date = range.start.add(Duration(days: i));
        String dateKey = DateFormat('yyyy-MM-dd').format(date);

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

        double fixed = fixedDoc.exists ? fixedDoc['total']?.toDouble() ?? 0.0 : 0.0;
        double variable = variableDoc.exists ? variableDoc['total']?.toDouble() ?? 0.0 : 0.0;

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

      for (int i = 0; i < days; i++) {
        DateTime date = range.start.add(Duration(days: i));
        String dateKey = DateFormat('yyyy-MM-dd').format(date);

        // Doanh thu
        DocumentSnapshot revenueDoc = await firestore
            .collection('users')
            .doc(userId)
            .collection('revenue')
            .doc(getKey('total_revenue_$dateKey'))
            .get();
        totalRevenue += revenueDoc.exists ? revenueDoc['total']?.toDouble() ?? 0.0 : 0.0;

        // Chi phí
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
        for (String category in topProducts.keys) {
          String key = getKey('transactionHistory_${category}_$dateKey');
          DocumentSnapshot doc = await firestore
              .collection('users')
              .doc(userId)
              .collection('transactions')
              .doc(key)
              .get();
          if (doc.exists && doc['transactions'] != null) {
            List<dynamic> transactions = doc['transactions'];
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

      for (int i = 0; i < days; i++) {
        DateTime date = range.start.add(Duration(days: i));
        String dateKey = DateFormat('yyyy-MM-dd').format(date);

        // Doanh thu
        DocumentSnapshot revenueDoc = await firestore
            .collection('users')
            .doc(userId)
            .collection('revenue')
            .doc(getKey('total_revenue_$dateKey'))
            .get();
        double totalRevenue = revenueDoc.exists ? revenueDoc['total']?.toDouble() ?? 0.0 : 0.0;

        // Chi phí
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
        for (String category in ['Doanh thu chính', 'Doanh thu phụ', 'Doanh thu khác']) {
          String key = getKey('transactionHistory_${category}_$dateKey');
          DocumentSnapshot doc = await firestore
              .collection('users')
              .doc(userId)
              .collection('transactions')
              .doc(key)
              .get();
          if (doc.exists && doc['transactions'] != null) {
            List<dynamic> transactions = doc['transactions'];
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
        for (String category in ['Doanh thu chính', 'Doanh thu phụ', 'Doanh thu khác']) {
          String key = getKey('transactionHistory_${category}_$dateKey');
          DocumentSnapshot doc = await firestore
              .collection('users')
              .doc(userId)
              .collection('transactions')
              .doc(key)
              .get();
          if (doc.exists && doc['transactions'] != null) {
            List<dynamic> transactions = doc['transactions'];
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

      for (int i = 0; i < days; i++) {
        DateTime date = range.start.add(Duration(days: i));
        String dateKey = DateFormat('yyyy-MM-dd').format(date);
        for (String category in ['Doanh thu chính', 'Doanh thu phụ', 'Doanh thu khác']) {
          String key = getKey('transactionHistory_${category}_$dateKey');
          DocumentSnapshot doc = await firestore
              .collection('users')
              .doc(userId)
              .collection('transactions')
              .doc(key)
              .get();
          if (doc.exists && doc['transactions'] != null) {
            List<dynamic> transactions = doc['transactions'];
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