import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import '../state/app_state.dart';

class RevenueManager {
  static Future<List<Map<String, dynamic>>> loadProducts(AppState appState, String category) async {
    var box = await Hive.openBox('productBox');
    String baseKey = category == "Doanh thu chính" ? 'mainProductList' : 'extraProductList';
    String key = appState.getKey(baseKey);
    var storedData = box.get(key);
    return storedData != null && storedData is String
        ? List<Map<String, dynamic>>.from(jsonDecode(storedData))
        : [];
  }

  static Future<List<Map<String, dynamic>>> loadTransactionHistory(AppState appState, String category) async {
    var box = Hive.box('transactionBox');
    String dateKey = DateFormat('yyyy-MM-dd').format(appState.selectedDate);
    String key = appState.getKey('transactionHistory_${category}_$dateKey');
    var storedData = box.get(key, defaultValue: []);
    return storedData is List
        ? storedData.map((item) => Map<String, dynamic>.from(item as Map)).toList()
        : [];
  }

  static Future<void> saveTransactionHistory(AppState appState, String category, List<Map<String, dynamic>> transactions) async {
    var box = Hive.box('transactionBox');
    String dateKey = DateFormat('yyyy-MM-dd').format(appState.selectedDate);
    String key = appState.getKey('transactionHistory_${category}_$dateKey');
    await box.put(key, transactions);
    await updateTotalRevenue(appState, category, transactions);
  }

  static Future<void> updateTotalRevenue(AppState appState, String category, List<Map<String, dynamic>> transactions) async {
    var box = Hive.box('revenueBox');
    String dateKey = DateFormat('yyyy-MM-dd').format(appState.selectedDate);
    String key = appState.getKey('revenue_${category}_$dateKey');
    double total = transactions.fold(0.0, (sum, item) => sum + (item['total'] as num? ?? item['amount'] as num? ?? 0.0).toDouble());
    await box.put(key, total);

    double main = box.get(appState.getKey('revenue_Doanh thu chính_$dateKey'), defaultValue: 0.0);
    double secondary = box.get(appState.getKey('revenue_Doanh thu phụ_$dateKey'), defaultValue: 0.0);
    double other = box.get(appState.getKey('revenue_Doanh thu khác_$dateKey'), defaultValue: 0.0);
    appState.setRevenue(main, secondary, other);
  }

  static Future<List<Map<String, dynamic>>> loadOtherRevenueTransactions(AppState appState) async {
    var box = Hive.box('transactionBox');
    String dateKey = DateFormat('yyyy-MM-dd').format(appState.selectedDate);
    String key = appState.getKey('other_revenue_transactions_$dateKey');
    var storedData = box.get(key, defaultValue: []);
    return storedData is List
        ? storedData.map((item) => Map<String, dynamic>.from(item as Map)).toList()
        : [];
  }

  static Future<void> saveOtherRevenueTransactions(AppState appState, List<Map<String, dynamic>> transactions) async {
    var box = Hive.box('transactionBox');
    String dateKey = DateFormat('yyyy-MM-dd').format(appState.selectedDate);
    String key = appState.getKey('other_revenue_transactions_$dateKey');
    await box.put(key, transactions);
    await updateTotalRevenue(appState, 'Doanh thu khác', transactions);
    appState.notifyListeners(); // Đảm bảo thông báo thay đổi
  }
}