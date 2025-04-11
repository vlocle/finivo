import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
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
    var box = Hive.box('revenueBox');
    String dateKey = DateFormat('yyyy-MM-dd').format(selectedDate);
    mainRevenue = box.get(getKey('revenue_Doanh thu chính_$dateKey'), defaultValue: 0.0);
    secondaryRevenue = box.get(getKey('revenue_Doanh thu phụ_$dateKey'), defaultValue: 0.0);
    otherRevenue = box.get(getKey('revenue_Doanh thu khác_$dateKey'), defaultValue: 0.0);
    mainRevenueTransactions.value = await RevenueManager.loadTransactionHistory(this, 'Doanh thu chính');
    secondaryRevenueTransactions.value = await RevenueManager.loadTransactionHistory(this, 'Doanh thu phụ');
    otherRevenueTransactions.value = await RevenueManager.loadOtherRevenueTransactions(this);
    // Không gọi notifyListeners() ở đây
  }

  void setRevenue(double main, double secondary, double other) {
    var revenueBox = Hive.box('revenueBox');
    var expenseBox = Hive.box('expenseBox');
    String dateKey = DateFormat('yyyy-MM-dd').format(selectedDate);
    mainRevenue = main;
    secondaryRevenue = secondary;
    otherRevenue = other;
    revenueBox.put(getKey('revenue_Doanh thu chính_$dateKey'), main);
    revenueBox.put(getKey('revenue_Doanh thu phụ_$dateKey'), secondary);
    revenueBox.put(getKey('revenue_Doanh thu khác_$dateKey'), other);
    double totalRevenue = main + secondary + other;
    revenueBox.put(getKey('total_revenue_$dateKey'), totalRevenue);

    double totalExpense = expenseBox.get(getKey('total_fixed_expense_$dateKey'), defaultValue: 0.0) +
        expenseBox.get(getKey('total_variable_expense_$dateKey'), defaultValue: 0.0);
    double profit = totalRevenue - totalExpense;
    double profitMargin = totalRevenue > 0 ? (profit / totalRevenue) * 100 : 0;
    revenueBox.put(getKey('profit_$dateKey'), profit);
    revenueBox.put(getKey('profitMargin_$dateKey'), profitMargin);

    notifyListeners();
  }

  Map<String, List<Transaction>> transactions = {
    'Doanh thu chính': [],
    'Doanh thu phụ': [],
    'Doanh thu khác': [],
  };

  // ========== Chi Phí ==========
  Future<void> loadExpenseValues() async {
    var box = Hive.box('expenseBox');
    String dateKey = DateFormat('yyyy-MM-dd').format(selectedDate);
    fixedExpense = box.get(getKey('total_fixed_expense_$dateKey'), defaultValue: 0.0);
    variableExpense = box.get(getKey('total_variable_expense_$dateKey'), defaultValue: 0.0);
    fixedExpenseList.value = await ExpenseManager.loadFixedExpenses(this);
    variableExpenseList.value = await ExpenseManager.loadVariableExpenses(this);
    // Không gọi notifyListeners() ở đây
  }

  Future<List<Map<String, dynamic>>> loadVariableExpenseList() async {
    var box = Hive.box('expenseBox');
    String dateKey = DateFormat('yyyy-MM-dd').format(selectedDate);
    String key = getKey('variableExpenseList_$dateKey');
    List<dynamic> storedData = box.get(key, defaultValue: []);
    return storedData
        .map((item) => Map<String, dynamic>.from(item is String ? jsonDecode(item) : item))
        .toList();
  }

  Future<void> setExpenses(double fixed, double variable) async {
    var revenueBox = Hive.box('revenueBox');
    var expenseBox = Hive.box('expenseBox');
    String dateKey = DateFormat('yyyy-MM-dd').format(selectedDate);
    fixedExpense = fixed;
    variableExpense = variable;
    await expenseBox.put(getKey('total_fixed_expense_$dateKey'), fixed);
    await expenseBox.put(getKey('total_variable_expense_$dateKey'), variable);

    double totalRevenue = revenueBox.get(getKey('total_revenue_$dateKey'), defaultValue: 0.0);
    double totalExpense = fixed + variable;
    double profit = totalRevenue - totalExpense;
    double profitMargin = totalRevenue > 0 ? (profit / totalRevenue) * 100 : 0;
    revenueBox.put(getKey('profit_$dateKey'), profit);
    revenueBox.put(getKey('profitMargin_$dateKey'), profitMargin);

    notifyListeners();
  }

  // Các hàm báo cáo giữ nguyên, chỉ cập nhật key với _getKey
  Future<Map<String, double>> getRevenueForRange(DateTimeRange range) async {
    var box = Hive.box('revenueBox');
    double mainRevenueTotal = 0.0;
    double secondaryRevenueTotal = 0.0;
    double otherRevenueTotal = 0.0;

    int days = range.end.difference(range.start).inDays + 1;
    for (int i = 0; i < days; i++) {
      DateTime date = range.start.add(Duration(days: i));
      String dateKey = DateFormat('yyyy-MM-dd').format(date);
      mainRevenueTotal += box.get(getKey('revenue_Doanh thu chính_$dateKey'), defaultValue: 0.0);
      secondaryRevenueTotal += box.get(getKey('revenue_Doanh thu phụ_$dateKey'), defaultValue: 0.0);
      otherRevenueTotal += box.get(getKey('revenue_Doanh thu khác_$dateKey'), defaultValue: 0.0);
    }

    return {
      'mainRevenue': mainRevenueTotal,
      'secondaryRevenue': secondaryRevenueTotal,
      'otherRevenue': otherRevenueTotal,
      'totalRevenue': mainRevenueTotal + secondaryRevenueTotal + otherRevenueTotal
    };
  }

  Future<List<Map<String, double>>> getDailyRevenueForRange(DateTimeRange range) async {
    var box = Hive.box('revenueBox');
    List<Map<String, double>> dailyData = [];

    int days = range.end.difference(range.start).inDays + 1;
    for (int i = 0; i < days; i++) {
      DateTime date = range.start.add(Duration(days: i));
      String dateKey = DateFormat('yyyy-MM-dd').format(date);
      dailyData.add({
        'mainRevenue': box.get(getKey('revenue_Doanh thu chính_$dateKey'), defaultValue: 0.0),
        'secondaryRevenue': box.get(getKey('revenue_Doanh thu phụ_$dateKey'), defaultValue: 0.0),
        'otherRevenue': box.get(getKey('revenue_Doanh thu khác_$dateKey'), defaultValue: 0.0),
        'totalRevenue': box.get(getKey('revenue_Doanh thu chính_$dateKey'), defaultValue: 0.0) +
            box.get(getKey('revenue_Doanh thu phụ_$dateKey'), defaultValue: 0.0) +
            box.get(getKey('revenue_Doanh thu khác_$dateKey'), defaultValue: 0.0),
      });
    }

    return dailyData;
  }

  Future<Map<String, double>> getExpensesForRange(DateTimeRange range) async {
    var box = Hive.box('expenseBox');
    double fixedExpenseTotal = 0.0;
    double variableExpenseTotal = 0.0;

    int days = range.end.difference(range.start).inDays + 1;
    for (int i = 0; i < days; i++) {
      DateTime date = range.start.add(Duration(days: i));
      String dateKey = DateFormat('yyyy-MM-dd').format(date);
      fixedExpenseTotal += box.get(getKey('total_fixed_expense_$dateKey'), defaultValue: 0.0);
      variableExpenseTotal += box.get(getKey('total_variable_expense_$dateKey'), defaultValue: 0.0);
    }

    return {
      'fixedExpense': fixedExpenseTotal,
      'variableExpense': variableExpenseTotal,
      'totalExpense': fixedExpenseTotal + variableExpenseTotal,
    };
  }

  Future<Map<String, double>> getExpenseBreakdown(DateTimeRange range) async {
    var box = Hive.box('expenseBox');
    Map<String, double> breakdown = {};

    int days = range.end.difference(range.start).inDays + 1;
    for (int i = 0; i < days; i++) {
      DateTime date = range.start.add(Duration(days: i));
      String dateKey = DateFormat('yyyy-MM-dd').format(date);
      for (String key in [getKey('fixedExpenseList_$dateKey'), getKey('variableTransactionHistory_$dateKey')]) {
        List<dynamic> transactions = box.get(key, defaultValue: []);
        for (var transaction in transactions) {
          var item = transaction is String ? jsonDecode(transaction) : transaction;
          String name = item['name'] ?? 'Không xác định';
          double amount = item['amount'].toDouble();
          breakdown[name] = (breakdown[name] ?? 0.0) + amount;
        }
      }
    }
    return breakdown;
  }

  Future<List<Map<String, double>>> getDailyExpensesForRange(DateTimeRange range) async {
    var box = Hive.box('expenseBox');
    List<Map<String, double>> dailyData = [];

    int days = range.end.difference(range.start).inDays + 1;
    for (int i = 0; i < days; i++) {
      DateTime date = range.start.add(Duration(days: i));
      String dateKey = DateFormat('yyyy-MM-dd').format(date);
      double fixed = box.get(getKey('total_fixed_expense_$dateKey'), defaultValue: 0.0);
      double variable = box.get(getKey('total_variable_expense_$dateKey'), defaultValue: 0.0);
      dailyData.add({
        'fixedExpense': fixed,
        'variableExpense': variable,
        'totalExpense': fixed + variable,
      });
    }

    return dailyData;
  }

  Future<Map<String, double>> getOverviewForRange(DateTimeRange range) async {
    var revenueBox = Hive.box('revenueBox');
    var expenseBox = Hive.box('expenseBox');
    double totalRevenue = 0.0;
    double totalExpense = 0.0;

    int days = range.end.difference(range.start).inDays + 1;
    for (int i = 0; i < days; i++) {
      DateTime date = range.start.add(Duration(days: i));
      String dateKey = DateFormat('yyyy-MM-dd').format(date);

      // Tính tổng doanh thu
      totalRevenue += revenueBox.get(getKey('total_revenue_$dateKey'), defaultValue: 0.0) as double;

      // Tính tổng chi phí
      double fixedExpense = expenseBox.get(getKey('total_fixed_expense_$dateKey'), defaultValue: 0.0) as double;
      double variableExpense = expenseBox.get(getKey('total_variable_expense_$dateKey'), defaultValue: 0.0) as double;
      totalExpense += fixedExpense + variableExpense;
    }

    // Tính lợi nhuận
    double profit = totalRevenue - totalExpense;

    // Tính các KPI khác
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
  }

  Future<Map<String, Map<String, double>>> getTopProductsByCategory(DateTimeRange range) async {
    var box = Hive.box('transactionBox');
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
        var transactions = box.get(key, defaultValue: []);
        if (transactions is List) {
          for (var transaction in transactions) {
            String name = transaction['name'] ?? 'Không xác định';
            double total = transaction['total'].toDouble();
            topProducts[category]![name] = (topProducts[category]![name] ?? 0.0) + total;
          }
        }
      }
    }
    return topProducts;
  }

  Future<List<Map<String, double>>> getDailyOverviewForRange(DateTimeRange range) async {
    var revenueBox = Hive.box('revenueBox');
    var expenseBox = Hive.box('expenseBox');
    List<Map<String, double>> dailyData = [];

    int days = range.end.difference(range.start).inDays + 1;
    for (int i = 0; i < days; i++) {
      DateTime date = range.start.add(Duration(days: i));
      String dateKey = DateFormat('yyyy-MM-dd').format(date);

      double totalRevenue = revenueBox.get(getKey('total_revenue_$dateKey'), defaultValue: 0.0) as double;
      double fixedExpense = expenseBox.get(getKey('total_fixed_expense_$dateKey'), defaultValue: 0.0) as double;
      double variableExpense = expenseBox.get(getKey('total_variable_expense_$dateKey'), defaultValue: 0.0) as double;
      double totalExpense = fixedExpense + variableExpense;
      double profit = totalRevenue - totalExpense;

      dailyData.add({
        'totalRevenue': totalRevenue,
        'totalExpense': totalExpense,
        'profit': profit,
      });
    }

    return dailyData;
  }

  Future<Map<String, double>> getProductRevenueBreakdown(DateTimeRange range) async {
    var box = Hive.box('transactionBox');
    Map<String, double> productTotals = {};
    double totalRevenue = 0.0;

    int days = range.end.difference(range.start).inDays + 1;
    for (int i = 0; i < days; i++) {
      DateTime date = range.start.add(Duration(days: i));
      String dateKey = DateFormat('yyyy-MM-dd').format(date);
      for (String category in ['Doanh thu chính', 'Doanh thu phụ', 'Doanh thu khác']) {
        String key = getKey('transactionHistory_${category}_$dateKey');
        var transactions = box.get(key, defaultValue: []);
        if (transactions is List) {
          for (var transaction in transactions) {
            String name = transaction['name'];
            double total = transaction['total'];
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
  }

  Future<Map<String, double>> getProductRevenueTotals(DateTimeRange range) async {
    var box = Hive.box('transactionBox');
    Map<String, double> productTotals = {};

    int days = range.end.difference(range.start).inDays + 1;
    for (int i = 0; i < days; i++) {
      DateTime date = range.start.add(Duration(days: i));
      String dateKey = DateFormat('yyyy-MM-dd').format(date);
      for (String category in ['Doanh thu chính', 'Doanh thu phụ', 'Doanh thu khác']) {
        String key = getKey('transactionHistory_${category}_$dateKey');
        var transactions = box.get(key, defaultValue: []);
        if (transactions is List) {
          for (var transaction in transactions) {
            String name = transaction['name'];
            double total = transaction['total'];
            productTotals[name] = (productTotals[name] ?? 0.0) + total;
          }
        }
      }
    }

    return productTotals;
  }

  Future<Map<String, Map<String, double>>> getProductRevenueDetails(DateTimeRange range) async {
    var box = Hive.box('transactionBox');
    Map<String, Map<String, double>> productDetails = {};

    int days = range.end.difference(range.start).inDays + 1;
    for (int i = 0; i < days; i++) {
      DateTime date = range.start.add(Duration(days: i));
      String dateKey = DateFormat('yyyy-MM-dd').format(date);
      for (String category in ['Doanh thu chính', 'Doanh thu phụ', 'Doanh thu khác']) {
        String key = getKey('transactionHistory_${category}_$dateKey');
        var transactions = box.get(key, defaultValue: []);
        if (transactions is List) {
          for (var transaction in transactions) {
            String name = transaction['name'] ?? 'Không xác định';
            double total = transaction['total'].toDouble();
            double quantity = (transaction['quantity'] ?? 1).toDouble();

            // Khởi tạo nếu chưa tồn tại
            productDetails.putIfAbsent(name, () => {'total': 0.0, 'quantity': 0.0});

            // Cập nhật giá trị một cách an toàn
            productDetails[name]!['total'] = (productDetails[name]!['total'] ?? 0.0) + total;
            productDetails[name]!['quantity'] = (productDetails[name]!['quantity'] ?? 0.0) + quantity;
          }
        }
      }
    }
    return productDetails;
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