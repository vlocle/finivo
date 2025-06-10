import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart'; // Giữ lại nếu có sử dụng context hoặc các lớp UI khác (hiện tại không thấy)
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import '../state/app_state.dart';

class ExpenseManager {
  // Load fixed expenses
  static Future<List<Map<String, dynamic>>> loadFixedExpenses(AppState appState, DateTime date) async {
    final String? userId = appState.activeUserId; // [cite: 862]
    if (userId == null) return []; // [cite: 863]
    final String dateKey = DateFormat('yyyy-MM-dd').format(date);
    final String firestoreDocId = appState.getKey('fixedExpenseList_$dateKey');
    final String hiveKey = '$userId-fixedExpenses-$firestoreDocId';
    if (!Hive.isBoxOpen('fixedExpensesBox')) {
      await Hive.openBox('fixedExpensesBox');
    }
    if (!Hive.isBoxOpen('revenueBox')) {
      await Hive.openBox('revenueBox');
    }
    final fixedExpensesBox = Hive.box('fixedExpensesBox'); // [cite: 864]

    var syncTimestamps = Hive.box('revenueBox').get(appState.getKey('sync_timestamps')) as Map<dynamic, dynamic>?; // [cite: 864]
    DateTime? lastSync = syncTimestamps != null && syncTimestamps[hiveKey] != null
        ? DateTime.parse(syncTimestamps[hiveKey] as String) // [cite: 865, 866]
        : null; // [cite: 866]

    if (lastSync != null && DateTime.now().difference(lastSync).inMinutes < 5) { // [cite: 867]
      final cachedData = fixedExpensesBox.get(hiveKey); // [cite: 867]
      if (cachedData != null) { // [cite: 868]
        try {
          if (cachedData is List) { // [cite: 868]
            List<Map<String, dynamic>> castedList = []; // [cite: 868]
            for (var item in cachedData) { // [cite: 869]
              if (item is Map) { // [cite: 869]
                castedList.add( // [cite: 869]
                  Map<String, dynamic>.fromEntries( // [cite: 869]
                      item.entries.map((entry) => MapEntry(entry.key.toString(), entry.value))), // [cite: 869]
                );
              }
            }
            return castedList; // [cite: 870]
          }
        } catch (e) {
          print('Error casting Hive data for $dateKey: $e'); // [cite: 871]
        }
      }
    }

    try {
      final FirebaseFirestore firestore = FirebaseFirestore.instance; // [cite: 872]
      DocumentSnapshot doc = await firestore // [cite: 873]
          .collection('users') // [cite: 873]
          .doc(userId) // [cite: 873]
          .collection('expenses') // [cite: 873]
          .doc('fixed') // [cite: 873]
          .collection('daily') // [cite: 873]
          .doc(firestoreDocId) // [cite: 873]
          .get();
      List<Map<String, dynamic>> expenses = []; // [cite: 874]
      if (doc.exists && doc.data() != null) { // [cite: 874]
        final data = doc.data() as Map<String, dynamic>; // [cite: 874]
        if (data['fixedExpenses']?.isNotEmpty == true) { // [cite: 875]
          expenses = List<Map<String, dynamic>>.from(data['fixedExpenses']); // [cite: 875]
        }
      }
      await fixedExpensesBox.put(hiveKey, expenses); // [cite: 876]
      await Hive.box('revenueBox').put( // [cite: 877]
          appState.getKey('sync_timestamps'), // [cite: 877]
          {...(syncTimestamps ?? {}), hiveKey: DateTime.now().toIso8601String()}); // [cite: 877]
      return expenses; // [cite: 878]
    } catch (e) {
      print("Error loading fixed expenses from Firestore for $dateKey: $e"); // [cite: 878]
      final cachedData = fixedExpensesBox.get(hiveKey); // Attempt to return cached data on error
      if (cachedData != null && cachedData is List) {
        try {
          List<Map<String, dynamic>> castedList = [];
          for (var item in cachedData) {
            if (item is Map) {
              castedList.add( Map<String, dynamic>.fromEntries(
                  item.entries.map((entry) => MapEntry(entry.key.toString(), entry.value))));
            }
          }
          return castedList;
        } catch (castError) {
          print("Error casting Hive data on fallback for fixed expenses: $castError");
          return [];
        }
      }
      return []; // [cite: 879]
    }
  }

  static Future<void> _saveDailyFixedExpense(AppState appState, DateTime date, String name, double dailyAmount) async {
    final String dateKey = DateFormat('yyyy-MM-dd').format(date); // [cite: 879]
    final String firestoreDocId = appState.getKey('fixedExpenseList_$dateKey'); // [cite: 880]
    final String hiveKey = '${appState.activeUserId}-fixedExpenses-$firestoreDocId';
    if (!Hive.isBoxOpen('fixedExpensesBox')) {
      await Hive.openBox('fixedExpensesBox');
    }
    final fixedExpensesBox = Hive.box('fixedExpensesBox'); // [cite: 880]
    try {
      List<Map<String, dynamic>> dailyExpenses = await loadFixedExpenses(appState, date); // [cite: 881]
      final existingIndex = dailyExpenses.indexWhere((e) => e['name'] == name); // [cite: 882]
      if (existingIndex != -1) { // [cite: 882]
        dailyExpenses[existingIndex] = {'name': name, 'amount': dailyAmount}; // [cite: 882]
      } else {
        dailyExpenses.add({'name': name, 'amount': dailyAmount}); // [cite: 883]
      }
      double total = dailyExpenses.fold(0.0, (sum, item) => sum + (item['amount']?.toDouble() ?? 0.0)); // [cite: 884]
      await FirebaseFirestore.instance // [cite: 884]
          .collection('users') // [cite: 885]
          .doc(appState.activeUserId) // [cite: 885]
          .collection('expenses') // [cite: 885]
          .doc('fixed') // [cite: 885]
          .collection('daily') // [cite: 885]
          .doc(firestoreDocId) // [cite: 885]
          .set({ // [cite: 885]
        'fixedExpenses': dailyExpenses, // [cite: 885]
        'total': total, // [cite: 885]
        'updatedAt': FieldValue.serverTimestamp(), // [cite: 885]
      }, SetOptions(merge: true)); // [cite: 886]
      await fixedExpensesBox.put(hiveKey, dailyExpenses); // [cite: 886]
    } catch (e) {
      print('Error saving fixed expenses for $dateKey: $e'); // [cite: 887]
      throw e; // [cite: 887]
    }
  }

  // Save fixed expenses
  static Future<void> saveFixedExpenses(AppState appState, List<Map<String, dynamic>> expenses) async {
    final String? userId = appState.activeUserId; // [cite: 888]
    if (userId == null) return; // [cite: 889]
    final String dateKey = DateFormat('yyyy-MM-dd').format(appState.selectedDate); // [cite: 889]
    final String firestoreDocId = appState.getKey('fixedExpenseList_$dateKey'); // [cite: 889]
    final String hiveKey = '$userId-fixedExpenses-$firestoreDocId';
    if (!Hive.isBoxOpen('fixedExpensesBox')) {
      await Hive.openBox('fixedExpensesBox');
    }
    final fixedExpensesBox = Hive.box('fixedExpensesBox'); // [cite: 890]
    try {
      final FirebaseFirestore firestore = FirebaseFirestore.instance; // [cite: 890]
      double total = expenses.fold(0.0, (sum, item) => sum + (item['amount']?.toDouble() ?? 0.0)); // [cite: 891]
      final docRef = firestore // [cite: 892]
          .collection('users') // [cite: 892]
          .doc(userId) // [cite: 892]
          .collection('expenses') // [cite: 892]
          .doc('fixed') // [cite: 892]
          .collection('daily') // [cite: 892]
          .doc(firestoreDocId); // [cite: 892]
      final doc = await docRef.get(); // [cite: 893]
      List<Map<String, dynamic>> mergedExpenses = expenses; // [cite: 893]
      if (doc.exists && doc.data()?['fixedExpenses'] != null) { // [cite: 894]
        final existingExpenses = List<Map<String, dynamic>>.from(doc.data()!['fixedExpenses']); // [cite: 894]
        final Map<String, Map<String, dynamic>> expenseMap = {}; // [cite: 895]
        for (var exp in existingExpenses) { // [cite: 896]
          expenseMap[exp['name']] = exp; // [cite: 896]
        }
        for (var exp in expenses) { // [cite: 897]
          expenseMap[exp['name']] = exp; // [cite: 897]
        }
        mergedExpenses = expenseMap.values.toList(); // [cite: 898]
        total = mergedExpenses.fold(0.0, (sum, item) => sum + (item['amount']?.toDouble() ?? 0.0)); // [cite: 899]
      }
      await docRef.set({ // [cite: 900]
        'fixedExpenses': mergedExpenses, // [cite: 900]
        'total': total, // [cite: 900]
        'updatedAt': FieldValue.serverTimestamp(), // [cite: 900]
      }, SetOptions(merge: true)); // [cite: 900]
      await fixedExpensesBox.put(hiveKey, mergedExpenses); // [cite: 901]
    } catch (e) {
      print("Error saving fixed expenses: $e"); // [cite: 902]
      await fixedExpensesBox.put(hiveKey, expenses); // [cite: 903]
      rethrow; // [cite: 903]
    }
  }

  static Future<double> updateTotalFixedExpense(AppState appState, List<Map<String, dynamic>> expenses) async {
    double total = expenses.fold(0.0, (sum, item) => sum + (item['amount'] ?? 0.0)); // [cite: 904]
    await saveFixedExpenses(appState, expenses); // [cite: 905]
    return total; // [cite: 905]
  }

  static Future<List<Map<String, dynamic>>> loadVariableExpenses(AppState appState) async {
    final String? userId = appState.activeUserId; // [cite: 906]
    if (userId == null) return []; // [cite: 907]
    final String dateKey = DateFormat('yyyy-MM-dd').format(appState.selectedDate); // [cite: 907]
    final String firestoreDocId = appState.getKey('variableTransactionHistory_${DateFormat('yyyy-MM-dd').format(appState.selectedDate)}'); // [cite: 907]
    final String hiveKey = '${appState.activeUserId}-variableExpenses-$firestoreDocId'; // [cite: 908]
    if (!Hive.isBoxOpen('variableExpensesBox')) {
      await Hive.openBox('variableExpensesBox');
    }
    final variableExpensesBox = Hive.box('variableExpensesBox'); // [cite: 909]
    final cachedData = variableExpensesBox.get(hiveKey); // [cite: 910]

    if (cachedData != null) { // [cite: 911]
      try {
        if (cachedData is List) { // [cite: 911]
          List<Map<String, dynamic>> castedList = []; // [cite: 911]
          for (var item in cachedData) { // [cite: 912]
            if (item is Map) { // [cite: 912]
              castedList.add( // [cite: 912]
                  Map<String, dynamic>.fromEntries( // [cite: 912]
                      item.entries.map((entry) => MapEntry(entry.key.toString(), entry.value)) // [cite: 912]
                  )
              );
            }
          }
          return castedList; // [cite: 914]
        }
      } catch (e) {
        print('Error casting Hive data in loadVariableExpenses: $e. Falling back to Firestore.'); // [cite: 915]
      }
    }

    try {
      final FirebaseFirestore firestore = FirebaseFirestore.instance; // [cite: 916]
      DocumentSnapshot doc = await firestore // [cite: 917]
          .collection('users') // [cite: 917]
          .doc(userId) // [cite: 917]
          .collection('expenses') // [cite: 917]
          .doc('variable') // [cite: 917]
          .collection('daily') // [cite: 917]
          .doc(firestoreDocId) // [cite: 917]
          .get();
      List<Map<String, dynamic>> expenses = []; // [cite: 918]
      if (doc.exists && doc.data() != null) { // [cite: 918]
        final data = doc.data() as Map<String, dynamic>; // [cite: 918]
        if (data['variableExpenses'] != null) { // [cite: 919]
          expenses = List<Map<String, dynamic>>.from(data['variableExpenses']); // [cite: 919]
        }
      }
      await variableExpensesBox.put(hiveKey, expenses); // [cite: 920]
      return expenses; // [cite: 921]
    } catch (e) {
      print("Error loading variable expenses: $e"); // [cite: 921]
      // Attempt to return cached data on error if not already returned
      if (cachedData != null && cachedData is List) {
        try {
          List<Map<String, dynamic>> castedList = [];
          for (var item in cachedData) {
            if (item is Map) {
              castedList.add( Map<String, dynamic>.fromEntries(
                  item.entries.map((entry) => MapEntry(entry.key.toString(), entry.value))));
            }
          }
          return castedList;
        } catch (castError) {
          print("Error casting Hive data on fallback for variable expenses: $castError");
          return [];
        }
      }
      return []; // [cite: 921] // Return empty if no cache and error
    }
  }

  // Load available variable expenses (Danh sách các loại chi phí biến đổi có thể chọn)
  static Future<List<Map<String, dynamic>>> loadAvailableVariableExpenses(
      AppState appState) async {
    final String? userId = appState.activeUserId; // [cite: 922]
    if (userId == null) return []; // [cite: 923]
    final String monthKey = DateFormat('yyyy-MM').format(appState.selectedDate); // [cite: 923]
    final String hiveKey = '$userId-variableExpenseList-$monthKey'; // [cite: 923]
    if (!Hive.isBoxOpen('variableExpenseListBox')) {
      await Hive.openBox('variableExpenseListBox');
    }
    final variableExpenseListBox = Hive.box('variableExpenseListBox'); // [cite: 924]

    final cachedData = variableExpenseListBox.get(hiveKey); // [cite: 924]
    if (cachedData != null) { // [cite: 925]
      try {
        if (cachedData is List) { // [cite: 925]
          List<Map<String, dynamic>> castedList = []; // [cite: 925]
          for (var item in cachedData) { // [cite: 926]
            if (item is Map) { // [cite: 926]
              // Đảm bảo 'name' là String và 'price' là double, và thêm 'linkedProductName'
              castedList.add({ //
                'name': item['name']?.toString() ?? 'Không xác định', // [cite: 926]
                'price': (item['price'] as num? ?? 0.0).toDouble(), // [cite: 926, 927]
                'linkedProductId': item['linkedProductId'] as String?, // THÊM MỚI: Đọc trường liên kết sản phẩm
              });
            }
          }
          return castedList; // [cite: 928]
        }
      } catch (e) {
        print(
            'Error casting Hive data in loadAvailableVariableExpenses: $e. Falling back to Firestore.'); // [cite: 929]
      }
    }

    try {
      final FirebaseFirestore firestore = FirebaseFirestore.instance; // [cite: 930]
      final String firestoreDocKey =
      appState.getKey('variableExpenseList_$monthKey'); // [cite: 931]
      DocumentSnapshot doc = await firestore // [cite: 932]
          .collection('users') // [cite: 932]
          .doc(userId) // [cite: 932]
          .collection('expenses') // [cite: 932]
          .doc('variableList') // [cite: 932]
          .collection('monthly') // [cite: 932]
          .doc(firestoreDocKey) // [cite: 932]
          .get();
      List<Map<String, dynamic>> expenses = []; // [cite: 933]
      if (doc.exists && doc.data() != null) { // [cite: 933]
        final data = doc.data() as Map<String, dynamic>; // [cite: 933]
        if (data['products'] != null && data['products'] is List) { // [cite: 934]
          List<dynamic> rawExpenses = data['products']; // [cite: 934]
          expenses = rawExpenses.map((item) { // [cite: 935]
            if (item is Map) { // [cite: 935]
              return { //
                'name': item['name']?.toString() ?? 'Không xác định', // [cite: 935]
                'price': (item['price'] as num? ?? 0.0).toDouble(), // [cite: 935]
                'linkedProductId': item['linkedProductId'] as String?, // THÊM MỚI: Đọc trường liên kết sản phẩm
              };
            }
            return <String, dynamic>{'name': 'Lỗi dữ liệu', 'price': 0.0, 'linkedProductId': null}; // [cite: 936]
          }).toList();
        }
      }
      await variableExpenseListBox.put(hiveKey, expenses); // [cite: 937]
      return expenses; // [cite: 938]
    } catch (e) {
      print("Error loading available variable expenses from Firestore: $e"); // [cite: 938]
      // Attempt to return cached data on error if not already returned (though logic above might catch it)
      if (cachedData != null && cachedData is List) {
        try {
          List<Map<String, dynamic>> castedList = [];
          for (var item in cachedData) {
            if (item is Map) {
              castedList.add({
                'name': item['name']?.toString() ?? 'Không xác định',
                'price': (item['price'] as num? ?? 0.0).toDouble(),
                'linkedProductId': item['linkedProductId'] as String?,
              });
            }
          }
          return castedList;
        } catch (castError) {
          print("Error casting Hive data on fallback for available variable expenses: $castError");
          return [];
        }
      }
      return []; // [cite: 939]
    }
  }

  static Future<void> saveVariableExpenses(AppState appState, List<Map<String, dynamic>> expenses) async {
    final String? userId = appState.activeUserId; // [cite: 939]
    if (userId == null) return; // [cite: 940]
    final String dateKey = DateFormat('yyyy-MM-dd').format(appState.selectedDate); // [cite: 940]
    final String firestoreDocId = appState.getKey('variableTransactionHistory_${DateFormat('yyyy-MM-dd').format(appState.selectedDate)}'); // [cite: 940]
    final String hiveKey = '${appState.activeUserId}-variableExpenses-$firestoreDocId'; // [cite: 941]
    if (!Hive.isBoxOpen('variableExpensesBox')) {
      await Hive.openBox('variableExpensesBox');
    }
    final variableExpensesBox = Hive.box('variableExpensesBox'); // [cite: 942]
    try {
      final FirebaseFirestore firestore = FirebaseFirestore.instance; // [cite: 943]
      double total = expenses.fold(0.0, (sum, item) => sum + (item['amount'] ?? 0.0)); // [cite: 944]
      await firestore // [cite: 945]
          .collection('users') // [cite: 945]
          .doc(userId) // [cite: 945]
          .collection('expenses') // [cite: 945]
          .doc('variable') // [cite: 945]
          .collection('daily') // [cite: 945]
          .doc(firestoreDocId) // [cite: 945]
          .set({ // [cite: 945]
        'variableExpenses': expenses, // [cite: 945]
        'total': total, // [cite: 945]
        'updatedAt': FieldValue.serverTimestamp(), // [cite: 946]
      }, SetOptions(merge: true)); // [cite: 946]
      await variableExpensesBox.put(hiveKey, expenses); // [cite: 947]
    } catch (e) {
      print("Error saving variable expenses: $e"); // [cite: 948]
      await variableExpensesBox.put(hiveKey, expenses); // [cite: 949]
      rethrow; // [cite: 949]
    }
  }

  static Future<double> updateTotalVariableExpense(AppState appState, List<Map<String, dynamic>> expenses) async {
    double total = expenses.fold(0.0, (sum, item) => sum + (item['amount'] ?? 0.0)); // [cite: 950]
    await saveVariableExpenses(appState, expenses); // [cite: 951]
    return total; // [cite: 951]
  }

  static Future<List<Map<String, dynamic>>> loadFixedExpenseList(AppState appState, DateTime month) async {
    final String? userId = appState.activeUserId; // [cite: 952]
    if (userId == null) return []; // [cite: 953]
    final String monthKey = DateFormat('yyyy-MM').format(month); // [cite: 953]
    final String hiveKey = '$userId-fixedExpenseList-$monthKey'; // [cite: 953]
    if (!Hive.isBoxOpen('monthlyFixedExpensesBox')) {
      await Hive.openBox('monthlyFixedExpensesBox');
    }
    final monthlyFixedExpensesBox = Hive.box('monthlyFixedExpensesBox'); // [cite: 954]
    final cachedData = monthlyFixedExpensesBox.get(hiveKey); // [cite: 954]
    if (cachedData != null) { // [cite: 955]
      return List<Map<String, dynamic>>.from(cachedData); // [cite: 955]
    }
    try {
      final FirebaseFirestore firestore = FirebaseFirestore.instance; // [cite: 956]
      DocumentSnapshot doc = await firestore // [cite: 957]
          .collection('users') // [cite: 957]
          .doc(userId) // [cite: 957]
          .collection('expenses') // [cite: 957]
          .doc('fixed') // [cite: 957]
          .collection('monthly') // [cite: 957]
          .doc(monthKey) // [cite: 957]
          .get();
      List<Map<String, dynamic>> expenses = []; // [cite: 958]
      if (doc.exists && doc.data() != null) { // [cite: 958]
        final data = doc.data() as Map<String, dynamic>; // [cite: 958]
        if (data['products'] != null) { // [cite: 959]
          expenses = List<Map<String, dynamic>>.from(data['products']); // [cite: 959]
        }
      }
      await monthlyFixedExpensesBox.put(hiveKey, expenses); // [cite: 960]
      return expenses; // [cite: 961]
    } catch (e) {
      print("Error loading fixed expense list: $e"); // [cite: 961]
      return cachedData != null ? List<Map<String, dynamic>>.from(cachedData) : []; // [cite: 961, 962]
    }
  }

  static Future<void> saveFixedExpenseList(AppState appState, List<Map<String, dynamic>> expenses, DateTime month) async {
    final String? userId = appState.activeUserId; // [cite: 962]
    if (userId == null) return; // [cite: 963]
    final String monthKey = DateFormat('yyyy-MM').format(month); // [cite: 963]
    final String hiveKey = '$userId-fixedExpenseList-$monthKey'; // [cite: 963]
    if (!Hive.isBoxOpen('monthlyFixedExpensesBox')) {
      await Hive.openBox('monthlyFixedExpensesBox');
    }
    final monthlyFixedExpensesBox = Hive.box('monthlyFixedExpensesBox'); // [cite: 964]
    try {
      final FirebaseFirestore firestore = FirebaseFirestore.instance; // [cite: 964]
      await firestore // [cite: 965]
          .collection('users') // [cite: 965]
          .doc(userId) // [cite: 965]
          .collection('expenses') // [cite: 965]
          .doc('fixed') // [cite: 965]
          .collection('monthly') // [cite: 965]
          .doc(monthKey) // [cite: 965]
          .set({ // [cite: 965]
        'products': expenses, // [cite: 965]
        'updatedAt': FieldValue.serverTimestamp(), // [cite: 965]
      }, SetOptions(merge: true)); // [cite: 965]
      await monthlyFixedExpensesBox.put(hiveKey, expenses); // [cite: 966]
    } catch (e) {
      print("Error saving fixed expense list: $e"); // [cite: 967]
      await monthlyFixedExpensesBox.put(hiveKey, expenses); // [cite: 968]
      rethrow; // [cite: 968]
    }
  }

  static Future<Map<String, double>> loadMonthlyFixedAmounts(AppState appState, DateTime month) async {
    final String? userId = appState.activeUserId; // [cite: 969]
    if (userId == null) return {}; // [cite: 970]
    final String monthKey = DateFormat('yyyy-MM').format(month); // [cite: 970]
    final String hiveKey = '$userId-monthlyFixedAmounts-$monthKey'; // [cite: 970]
    if (!Hive.isBoxOpen('monthlyFixedAmountsBox')) {
      await Hive.openBox('monthlyFixedAmountsBox');
    }
    final monthlyFixedAmountsBox = Hive.box('monthlyFixedAmountsBox'); // [cite: 971]
    final cachedData = monthlyFixedAmountsBox.get(hiveKey); // [cite: 971]
    if (cachedData != null) { // [cite: 972]
      return Map<String, double>.from(cachedData); // [cite: 972]
    }
    try {
      final FirebaseFirestore firestore = FirebaseFirestore.instance; // [cite: 973]
      DocumentSnapshot doc = await firestore // [cite: 974]
          .collection('users') // [cite: 974]
          .doc(userId) // [cite: 974]
          .collection('expenses') // [cite: 974]
          .doc('fixed') // [cite: 974]
          .collection('monthly') // [cite: 974]
          .doc(monthKey) // [cite: 974]
          .get();
      Map<String, double> amounts = {}; // [cite: 975]
      if (doc.exists && doc.data() != null) { // [cite: 975]
        final data = doc.data() as Map<String, dynamic>; // [cite: 975]
        if (data['amounts'] != null) { // [cite: 976]
          amounts = Map<String, double>.from(data['amounts']); // [cite: 976]
        }
      }
      await monthlyFixedAmountsBox.put(hiveKey, amounts); // [cite: 977]
      return amounts; // [cite: 978]
    } catch (e) {
      print("Error loading monthly fixed amounts: $e"); // [cite: 978]
      return cachedData != null ? Map<String, double>.from(cachedData) : {}; // [cite: 978, 979]
    }
  }

  static Future<void> saveMonthlyFixedAmount(AppState appState, String name, double amount, DateTime month, {DateTimeRange? dateRange}) async {
    final String? userId = appState.activeUserId; // [cite: 979]
    if (userId == null) return; // [cite: 980]
    final String monthKey = DateFormat('yyyy-MM').format(month); // [cite: 980]
    final String hiveKey = '$userId-monthlyFixedAmounts-$monthKey'; // [cite: 980]
    if (!Hive.isBoxOpen('monthlyFixedAmountsBox')) {
      await Hive.openBox('monthlyFixedAmountsBox');
    }
    final monthlyFixedAmountsBox = Hive.box('monthlyFixedAmountsBox'); // [cite: 981]
    try {
      final FirebaseFirestore firestore = FirebaseFirestore.instance; // [cite: 981]
      final amounts = await loadMonthlyFixedAmounts(appState, month); // [cite: 982]
      amounts[name] = amount; // [cite: 982]
      await firestore // [cite: 983]
          .collection('users') // [cite: 983]
          .doc(userId) // [cite: 983]
          .collection('expenses') // [cite: 983]
          .doc('fixed') // [cite: 983]
          .collection('monthly') // [cite: 983]
          .doc(monthKey) // [cite: 983]
          .set({ // [cite: 983]
        'amounts': amounts, // [cite: 983]
        'updatedAt': FieldValue.serverTimestamp(), // [cite: 983]
      }, SetOptions(merge: true)); // [cite: 983]
      final DateTimeRange range = dateRange ?? DateTimeRange( // [cite: 984]
        start: DateTime(month.year, month.month, 1), // [cite: 984]
        end: DateTime(month.year, month.month + 1, 0), // [cite: 984]
      );
      final int days = range.end.difference(range.start).inDays + 1; // [cite: 985]
      final double dailyAmount = amount / days; // [cite: 985]
      List<Future<void>> saveFutures = []; // [cite: 985]
      for (int i = 0; i < days; i++) { // [cite: 986]
        final DateTime currentDate = range.start.add(Duration(days: i)); // [cite: 986]
        saveFutures.add(_saveDailyFixedExpense(appState, currentDate, name, dailyAmount)); // [cite: 987]
      }
      await Future.wait(saveFutures); // [cite: 987]
      await monthlyFixedAmountsBox.put(hiveKey, amounts); // [cite: 987]
      await appState.loadExpenseValues(); // [cite: 987]
    } catch (e) {
      print("Error saving monthly fixed amount: $e"); // [cite: 988]
      final amounts = await loadMonthlyFixedAmounts(appState, month); // [cite: 989]
      amounts[name] = amount; // [cite: 989]
      await monthlyFixedAmountsBox.put(hiveKey, amounts); // [cite: 989]
      throw e; // [cite: 989]
    }
  }

  static Future<void> deleteMonthlyFixedExpense(AppState appState, String name,
      DateTime month, {DateTimeRange? dateRange}) async {
    final String? userId = appState.activeUserId; // [cite: 990]
    if (userId == null) { // [cite: 991]
      print("User ID is null, cannot delete monthly fixed expense."); // [cite: 991]
      return; // [cite: 992]
    }
    final String monthKey = DateFormat('yyyy-MM').format(month); // [cite: 992]
    final String hiveMonthlyAmountsKey = '$userId-monthlyFixedAmounts-$monthKey'; // [cite: 993]
    if (!Hive.isBoxOpen('monthlyFixedAmountsBox')) {
      await Hive.openBox('monthlyFixedAmountsBox');
    }
    if (!Hive.isBoxOpen('monthlyFixedExpensesBox')) {
      await Hive.openBox('monthlyFixedExpensesBox');
    }
    if (!Hive.isBoxOpen('fixedExpensesBox')) {
      await Hive.openBox('fixedExpensesBox');
    }
    final monthlyFixedAmountsBox = Hive.box('monthlyFixedAmountsBox'); // [cite: 994]
    final String hiveFixedExpenseListKey = '$userId-fixedExpenseList-$monthKey'; // [cite: 994]
    final monthlyFixedExpensesBox = Hive.box('monthlyFixedExpensesBox'); // [cite: 994]

    try {
      final FirebaseFirestore firestore = FirebaseFirestore.instance; // [cite: 995]
      final amounts = await loadMonthlyFixedAmounts(appState, month); // [cite: 996]
      if (amounts.containsKey(name)) { // [cite: 997]
        amounts.remove(name); // [cite: 997]
        await firestore // [cite: 998]
            .collection('users') // [cite: 998]
            .doc(userId) // [cite: 998]
            .collection('expenses') // [cite: 998]
            .doc('fixed') // [cite: 998]
            .collection('monthly') // [cite: 998]
            .doc(monthKey) // [cite: 998]
            .set({ // [cite: 998]
          'amounts': amounts, // [cite: 998]
          'updatedAt': FieldValue.serverTimestamp(), // [cite: 999]
        }, SetOptions(merge: true)); // [cite: 999]
        await monthlyFixedAmountsBox.put(hiveMonthlyAmountsKey, amounts); // [cite: 1000]
        print("Updated monthlyFixedAmounts in Firestore and Hive for $monthKey after removing $name."); // [cite: 1001]
      } else {
        print("Expense '$name' not found in monthlyFixedAmounts for $monthKey. Skipping update."); // [cite: 1002]
      }

      final fixedExpensesListForMonth = await loadFixedExpenseList(appState, month); // [cite: 1003]
      final originalLength = fixedExpensesListForMonth.length; // [cite: 1004]
      final updatedFixedExpensesListForMonth = fixedExpensesListForMonth.where((e) => e['name'] != name).toList(); // [cite: 1004]
      if (updatedFixedExpensesListForMonth.length < originalLength) { // [cite: 1005]
        await saveFixedExpenseList(appState, updatedFixedExpensesListForMonth, month); // [cite: 1005]
        print("Updated fixedExpenseList in Firestore and Hive for $monthKey after removing $name."); // [cite: 1006]
      } else {
        print("Expense '$name' not found in fixedExpenseList for $monthKey. Skipping update."); // [cite: 1007]
      }

      final DateTimeRange range = dateRange ?? // [cite: 1008]
          DateTimeRange( // [cite: 1009]
            start: DateTime(month.year, month.month, 1), // [cite: 1009]
            end: DateTime(month.year, month.month + 1, 0), // [cite: 1009]
          );
      List<Future<void>> dailyUpdateFutures = []; // [cite: 1010]
      final fixedExpensesBox = Hive.box('fixedExpensesBox'); // [cite: 1010]
      for (int i = 0; i <= range.end.difference(range.start).inDays; i++) { // [cite: 1010]
        final DateTime currentDate = range.start.add(Duration(days: i)); // [cite: 1010]
        final String dailyDateKey = DateFormat('yyyy-MM-dd').format(currentDate); // [cite: 1011]
        final String firestoreDailyDocId = appState.getKey('fixedExpenseList_$dailyDateKey'); // [cite: 1011]
        final String hiveDailyFixedKey = '$userId-fixedExpenses-$firestoreDailyDocId'; // [cite: 1011]

        dailyUpdateFutures.add( // [cite: 1012]
          Future(() async { // [cite: 1012]
            try {
              final List<Map<String, dynamic>> dailyExpenses = await loadFixedExpenses(appState, currentDate); // [cite: 1012]
              final updatedDailyExpenses = dailyExpenses.where((e) => e['name'] != name).toList(); // [cite: 1012]
              if (updatedDailyExpenses.length < dailyExpenses.length || (dailyExpenses.isNotEmpty && updatedDailyExpenses.isEmpty)) { // [cite: 1013]
                final docRef = firestore // [cite: 1013]
                    .collection('users') // [cite: 1013]
                    .doc(userId) // [cite: 1013]
                    .collection('expenses') // [cite: 1013]
                    .doc('fixed') // [cite: 1014]
                    .collection('daily') // [cite: 1014]
                    .doc(firestoreDailyDocId); // [cite: 1014]
                if (updatedDailyExpenses.isEmpty) { // [cite: 1014]
                  await docRef.delete(); // [cite: 1014]
                  await fixedExpensesBox.delete(hiveDailyFixedKey); // [cite: 1015]
                  print('Deleted daily fixed expense document $firestoreDailyDocId and Hive key $hiveDailyFixedKey for $name.'); // [cite: 1015]
                } else {
                  double total = updatedDailyExpenses.fold(0.0, // [cite: 1016]
                          (sum, item) => sum + (item['amount']?.toDouble() ?? 0.0)); // [cite: 1016]
                  await docRef.set({ // [cite: 1017]
                    'fixedExpenses': updatedDailyExpenses, // [cite: 1017]
                    'total': total, // [cite: 1017]
                    'updatedAt': FieldValue.serverTimestamp(), // [cite: 1017]
                  }, SetOptions(merge: true)); // [cite: 1017]
                  await fixedExpensesBox.put(hiveDailyFixedKey, updatedDailyExpenses); // [cite: 1018]
                  print('Updated daily fixed expense document $firestoreDailyDocId and Hive key $hiveDailyFixedKey for $name.'); // [cite: 1018]
                }
              } else {
                print('No changes needed for daily fixed expenses on $dailyDateKey for $name.'); // [cite: 1019]
              }
            } catch (e) {
              print('Error processing daily fixed expenses for $dailyDateKey when deleting $name: $e, Stacktrace: ${StackTrace.current}'); // [cite: 1020]
            }
          }),
        );
      }
      await Future.wait(dailyUpdateFutures.map((future) => future.catchError((e) { // [cite: 1022]
        print('An unexpected error occurred in dailyUpdateFutures during deleteMonthlyFixedExpense: $e'); // [cite: 1022]
        return Future.value(); // [cite: 1022]
      })));
      print("Finished processing daily fixed expense entries for deletion of $name."); // [cite: 1023]
      await appState.loadExpenseValues(); // [cite: 1024]
      print("Reloaded expense values in AppState after deleting $name."); // [cite: 1025]
    } catch (e) {
      print("Error deleting monthly fixed expense '$name' for month $monthKey: $e, Stacktrace: ${StackTrace.current}"); // [cite: 1025]
      rethrow; // [cite: 1027]
    }
  }
}