import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import '../state/app_state.dart';

class ExpenseManager {
  // Load fixed expenses
  static Future<List<Map<String, dynamic>>> loadFixedExpenses(AppState appState) async {
    var box = Hive.box('expenseBox');
    String dateKey = DateFormat('yyyy-MM-dd').format(appState.selectedDate);
    String key = appState.getKey('fixedExpenseList_$dateKey');
    List<dynamic> storedData = box.get(key, defaultValue: []);
    try {
      return storedData.map((item) => Map<String, dynamic>.from(jsonDecode(item))).toList();
    } catch (e) {
      print("Error decoding fixed expenses: $e");
      return [];
    }
  }

  // Save fixed expenses
  static Future<void> saveFixedExpenses(AppState appState, List<Map<String, dynamic>> expenses, {String? date}) async {
    var box = Hive.box('expenseBox');
    String dateKey = date ?? DateFormat('yyyy-MM-dd').format(appState.selectedDate);
    String key = appState.getKey('fixedExpenseList_$dateKey');
    List<String> jsonList = expenses.map((item) => jsonEncode(item)).toList();
    await box.put(key, jsonList);
  }

// Update total fixed expense
  static Future<double> updateTotalFixedExpense(AppState appState, List<Map<String, dynamic>> expenses, {String? date}) async {
    var box = Hive.box('expenseBox');
    String dateKey = date ?? DateFormat('yyyy-MM-dd').format(appState.selectedDate);
    double total = expenses.fold(0.0, (sum, item) => sum + (item['amount'] ?? 0.0));
    String totalKey = appState.getKey('total_fixed_expense_$dateKey');
    await box.put(totalKey, total);
    return total;
  }


  // Load variable expenses
  static Future<List<Map<String, dynamic>>> loadVariableExpenses(AppState appState) async {
    var box = Hive.box('expenseBox');
    String dateKey = DateFormat('yyyy-MM-dd').format(appState.selectedDate);
    String key = appState.getKey('variableTransactionHistory_$dateKey');
    List<dynamic> storedData = box.get(key, defaultValue: []);
    try {
      return storedData.map((item) => Map<String, dynamic>.from(jsonDecode(item))).toList();
    } catch (e) {
      print("Error decoding variable expenses: $e");
      return [];
    }
  }

  // Load available variable expenses
  static Future<List<Map<String, dynamic>>> loadAvailableVariableExpenses(AppState appState) async {
    var box = Hive.box('expenseBox');
    String monthKey = DateFormat('yyyy-MM').format(appState.selectedDate);
    String key = appState.getKey('variableExpenseList_$monthKey');
    List<dynamic> storedData = box.get(key, defaultValue: []);
    try {
      return storedData.map((item) => Map<String, dynamic>.from(jsonDecode(item))).toList();
    } catch (e) {
      print("Error decoding available variable expenses: $e");
      return [];
    }
  }

  // Save variable expenses
  static Future<void> saveVariableExpenses(AppState appState, List<Map<String, dynamic>> expenses) async {
    var box = Hive.box('expenseBox');
    String dateKey = DateFormat('yyyy-MM-dd').format(appState.selectedDate);
    String key = appState.getKey('variableTransactionHistory_$dateKey');
    List<String> jsonList = expenses.map((item) => jsonEncode(item)).toList();
    await box.put(key, jsonList);
  }

  // Update total variable expense
  static Future<double> updateTotalVariableExpense(AppState appState, List<Map<String, dynamic>> expenses) async {
    var box = Hive.box('expenseBox');
    String dateKey = DateFormat('yyyy-MM-dd').format(appState.selectedDate);
    double total = expenses.fold(0.0, (sum, item) => sum + (item['amount'] ?? 0.0));
    String totalKey = appState.getKey('total_variable_expense_$dateKey');
    await box.put(totalKey, total);
    return total;
  }

  // Load fixed expense list (for ExpenseScreen)
  static Future<List<Map<String, dynamic>>> loadFixedExpenseList(AppState appState) async {
    var box = Hive.box('expenseBox');
    String key = appState.getKey('fixedExpenseList');
    List<dynamic> storedData = box.get(key, defaultValue: []);
    try {
      return storedData.map((item) => Map<String, dynamic>.from(jsonDecode(item))).toList();
    } catch (e) {
      print("Error decoding fixed expense list: $e");
      return [];
    }
  }

  // Save fixed expense list (for ExpenseScreen)
  static Future<void> saveFixedExpenseList(AppState appState, List<Map<String, dynamic>> expenses) async {
    var box = Hive.box('expenseBox');
    String key = appState.getKey('fixedExpenseList');
    List<String> jsonList = expenses.map((item) => jsonEncode(item)).toList();
    await box.put(key, jsonList);
  }

  // Load monthly fixed amounts
  static Future<Map<String, double>> loadMonthlyFixedAmounts(AppState appState, DateTime month) async {
    var box = Hive.box('expenseBox');
    String key = appState.getKey('monthlyFixedAmounts_${month.year}_${month.month}');
    var rawData = box.get(key, defaultValue: {});
    Map<String, double> result = {};
    if (rawData is Map) {
      rawData.forEach((k, v) => result[k] = (v is int) ? v.toDouble() : v as double);
    }
    return result;
  }

  // Save monthly fixed amounts and distribute daily
  static Future<void> saveMonthlyFixedAmount(AppState appState, String name, double amount, DateTime month) async {
    var box = Hive.box('expenseBox');
    int daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    double dailyAmount = amount / daysInMonth;

    // Lưu ngày ban đầu để khôi phục sau
    DateTime originalDate = appState.selectedDate;

    for (int day = 1; day <= daysInMonth; day++) {
      DateTime currentDate = DateTime(month.year, month.month, day);
      String dateKey = DateFormat('yyyy-MM-dd').format(currentDate);
      String key = appState.getKey('fixedExpenseList_$dateKey');
      List<dynamic> storedData = box.get(key, defaultValue: []);
      List<Map<String, dynamic>> expenseList = storedData
          .map((item) => Map<String, dynamic>.from(jsonDecode(item)))
          .toList();
      var existingItem = expenseList.firstWhere((item) => item['name'] == name, orElse: () => {});
      if (existingItem.isEmpty) {
        expenseList.add({'name': name, 'amount': dailyAmount, 'isFixedMonthly': false});
      } else {
        existingItem['amount'] = dailyAmount;
      }
      // Truyền currentDate thay vì thay đổi appState.selectedDate
      await saveFixedExpenses(appState, expenseList, date: dateKey);
      await updateTotalFixedExpense(appState, expenseList, date: dateKey);
    }

    String monthlyKey = appState.getKey('monthlyFixedAmounts_${month.year}_${month.month}');
    var monthlyData = await loadMonthlyFixedAmounts(appState, month);
    monthlyData[name] = amount;
    await box.put(monthlyKey, monthlyData);

    // Khôi phục selectedDate ban đầu
    appState.setSelectedDate(originalDate);
  }

  // Delete monthly fixed expense
  static Future<void> deleteMonthlyFixedExpense(AppState appState, String name, DateTime month) async {
    var box = Hive.box('expenseBox');
    int daysInMonth = DateTime(month.year, month.month + 1, 0).day;

    // Lưu ngày ban đầu để khôi phục sau
    DateTime originalDate = appState.selectedDate;

    for (int day = 1; day <= daysInMonth; day++) {
      DateTime currentDate = DateTime(month.year, month.month, day);
      String dateKey = DateFormat('yyyy-MM-dd').format(currentDate);
      String key = appState.getKey('fixedExpenseList_$dateKey');
      List<dynamic> storedData = box.get(key, defaultValue: []);
      List<Map<String, dynamic>> expenseList = storedData
          .map((item) => Map<String, dynamic>.from(jsonDecode(item)))
          .toList();
      expenseList.removeWhere((item) => item['name'] == name);
      // Truyền currentDate thay vì thay đổi appState.selectedDate
      await saveFixedExpenses(appState, expenseList, date: dateKey);
      await updateTotalFixedExpense(appState, expenseList, date: dateKey);
    }

    String monthlyKey = appState.getKey('monthlyFixedAmounts_${month.year}_${month.month}');
    var monthlyData = await loadMonthlyFixedAmounts(appState, month);
    monthlyData.remove(name);
    await box.put(monthlyKey, monthlyData);

    // Khôi phục selectedDate ban đầu
    appState.setSelectedDate(originalDate);
  }
}