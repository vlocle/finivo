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

  static Future<void> saveFixedExpenses(AppState appState, List<Map<String, dynamic>> expenses) async {
    final String? userId = appState.activeUserId;
    if (userId == null) return;

    final String dateKey = DateFormat('yyyy-MM-dd').format(appState.selectedDate);
    final String firestoreDocId = appState.getKey('fixedExpenseList_$dateKey');
    final String hiveKey = '$userId-fixedExpenses-$firestoreDocId';

    if (!Hive.isBoxOpen('fixedExpensesBox')) {
      await Hive.openBox('fixedExpensesBox');
    }
    final fixedExpensesBox = Hive.box('fixedExpensesBox');

    try {
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      final docRef = firestore
          .collection('users')
          .doc(userId)
          .collection('expenses')
          .doc('fixed')
          .collection('daily')
          .doc(firestoreDocId);

      double total = expenses.fold(0.0, (sum, item) => sum + (item['amount']?.toDouble() ?? 0.0));

      await docRef.set({
        'fixedExpenses': expenses,
        'total': total,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Cập nhật lại cache trên Hive
      await fixedExpensesBox.put(hiveKey, expenses);

    } catch (e) {
      print("Error saving fixed expenses: $e");
      await fixedExpensesBox.put(hiveKey, expenses);
      rethrow;
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

  static Future<List<Map<String, dynamic>>> loadAvailableVariableExpenses(
      AppState appState) async {
    final String? userId = appState.activeUserId;
    if (userId == null) return [];

    final String monthKey = DateFormat('yyyy-MM').format(appState.selectedDate);
    final String hiveKey = '$userId-variableExpenseList-$monthKey';

    if (!Hive.isBoxOpen('variableExpenseListBox')) {
      await Hive.openBox('variableExpenseListBox');
    }
    final variableExpenseListBox = Hive.box('variableExpenseListBox');

    // Luồng 1: Tải từ Hive cache
    final cachedData = variableExpenseListBox.get(hiveKey);
    if (cachedData != null) {
      try {
        if (cachedData is List) {
          List<Map<String, dynamic>> castedList = [];
          for (var item in cachedData) {
            if (item is Map) {
              // =============================================================
              // <<< SỬA LỖI CỐT LÕI NẰM Ở ĐÂY (LOGIC ĐỌC TỪ HIVE) >>>
              //
              // Đọc theo cấu trúc dữ liệu mới
              castedList.add({
                'name': item['name']?.toString() ?? 'Không xác định',
                'costType': item['costType']?.toString() ?? 'fixed',
                'costValue': (item['costValue'] as num? ?? 0.0).toDouble(),
                'linkedProductId': item['linkedProductId'] as String?,
              });
              //
              // <<< KẾT THÚC SỬA LỖI >>>
              // =============================================================
            }
          }
          return castedList;
        }
      } catch (e) {
        print('Error casting Hive data in loadAvailableVariableExpenses: $e. Falling back to Firestore.');
      }
    }

    // Luồng 2: Tải từ Firestore (Logic này đã đúng, giữ nguyên)
    try {
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      final String firestoreDocKey = appState.getKey('variableExpenseList_$monthKey');
      DocumentSnapshot doc = await firestore
          .collection('users')
          .doc(userId)
          .collection('expenses')
          .doc('variableList')
          .collection('monthly')
          .doc(firestoreDocKey)
          .get();

      List<Map<String, dynamic>> expenses = [];
      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['products'] != null && data['products'] is List) {
          List<dynamic> rawExpenses = data['products'];
          expenses = rawExpenses.map((item) {
            if (item is Map) {
              return {
                'name': item['name']?.toString() ?? 'Không xác định',
                'costType': item['costType']?.toString() ?? 'fixed',
                'costValue': (item['costValue'] as num? ?? 0.0).toDouble(),
                'linkedProductId': item['linkedProductId'] as String?,
              };
            }
            return <String, dynamic>{'name': 'Lỗi dữ liệu', 'costType': 'fixed', 'costValue': 0.0, 'linkedProductId': null};
          }).toList();
        }
      }

      // Lưu kết quả đúng vào cache cho lần sau
      await variableExpenseListBox.put(hiveKey, expenses);
      return expenses;
    } catch (e) {
      print("Error loading available variable expenses from Firestore: $e");
      return []; // Trả về rỗng nếu có lỗi
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
    final String? userId = appState.activeUserId;
    if (userId == null) return [];
    final String monthKey = DateFormat('yyyy-MM').format(month);
    final String hiveKey = '$userId-fixedExpenseList-$monthKey';
    if (!Hive.isBoxOpen('monthlyFixedExpensesBox')) {
      await Hive.openBox('monthlyFixedExpensesBox');
    }
    final monthlyFixedExpensesBox = Hive.box('monthlyFixedExpensesBox');

    // Đọc dữ liệu từ cache trên điện thoại trước
    final cachedData = monthlyFixedExpensesBox.get(hiveKey);

    if (cachedData != null) {
      if (cachedData is Map) {
        final List<Map<String, dynamic>> resultList = [];
        // Lặp qua dữ liệu từ cache một cách an toàn
        for (final entry in cachedData.entries) {
          final key = entry.key?.toString();
          final value = entry.value;

          // Đảm bảo key là chuỗi và value là một Map
          if (key != null && value is Map) {
            // Xây dựng lại Map của từng khoản chi với kiểu dữ liệu chính xác
            resultList.add({
              'name': key,
              // Chuyển đổi Map con bên trong sang đúng kiểu Map<String, dynamic>
              ...Map<String, dynamic>.from(value),
            });
          }
        }
        return resultList;
      }
    }

    // Nếu không có cache, đọc từ máy chủ Firestore
    try {
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      DocumentSnapshot doc = await firestore
          .collection('users')
          .doc(userId)
          .collection('expenses')
          .doc('fixed')
          .collection('monthly')
          .doc(monthKey)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        final expensesMap = data['expenses'] as Map<String, dynamic>? ?? {};

        // Lưu cấu trúc Map này vào cache để dùng cho lần sau
        await monthlyFixedExpensesBox.put(hiveKey, expensesMap);

        // Chuyển đổi Map thành List để giao diện hiển thị
        return expensesMap.entries.map((e) => {'name': e.key, ...e.value as Map<String, dynamic>}).toList();
      }
      return [];
    } catch (e) {
      print("Error loading fixed expense list: $e");
      return [];
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

  static Future<void> saveOrUpdateMonthlyFixedAmount(
      AppState appState,
      String newName,
      double newAmount,
      {
        required DateTimeRange newDateRange,
        String? oldName,
        DateTimeRange? oldDateRange,
        double? oldAmount,
      }) async {
    final String? userId = appState.activeUserId;
    if (userId == null) return;
    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();

    // --- BƯỚC 1: DỌN DẸP DỮ LIỆU CŨ (CHỈ THỰC HIỆN KHI CẬP NHẬT) ---
    // Chỉ chạy logic dọn dẹp nếu đây là thao tác "sửa" (có đầy đủ dữ liệu cũ).
    if (oldName != null && oldAmount != null && oldDateRange != null) {
      final nameToRemove = oldName;
      final dateRangeToRemoveFrom = oldDateRange;

      // 1a. Xóa metadata ở các tháng không còn được áp dụng
      final oldMonthKeys = _getMonthsInRange(dateRangeToRemoveFrom);
      final newMonthKeysSet = _getMonthsInRange(newDateRange).toSet();
      final monthsToDeleteFrom = oldMonthKeys.where((key) => !newMonthKeysSet.contains(key));
      for (final monthKey in monthsToDeleteFrom) {
        final monthlyDocRef = firestore.collection('users').doc(userId).collection('expenses').doc('fixed').collection('monthly').doc(monthKey);
        batch.update(monthlyDocRef, {'expenses.${nameToRemove}': FieldValue.delete()});
      }

      // 1b. Xóa phân bổ hàng ngày cũ
      final daysInOldRange = dateRangeToRemoveFrom.end.difference(dateRangeToRemoveFrom.start).inDays + 1;
      if (daysInOldRange > 0) {
        final oldDailyAmount = oldAmount / daysInOldRange;
        final expenseToRemove = {'name': nameToRemove, 'amount': oldDailyAmount};
        for (int i = 0; i < daysInOldRange; i++) {
          final date = dateRangeToRemoveFrom.start.add(Duration(days: i));
          final dateKey = DateFormat('yyyy-MM-dd').format(date);
          final firestoreDocId = appState.getKey('fixedExpenseList_$dateKey');
          final dailyDocRef = firestore.collection('users').doc(userId).collection('expenses').doc('fixed').collection('daily').doc(firestoreDocId);
          batch.update(dailyDocRef, {'fixedExpenses': FieldValue.arrayRemove([expenseToRemove])});
        }
      }
    }

    // --- BƯỚC 2: LƯU/CẬP NHẬT DỮ LIỆU MỚI (LUÔN THỰC HIỆN) ---
    // 2a. Lưu metadata mới vào các tháng liên quan
    final newMonthKeys = _getMonthsInRange(newDateRange);
    final expenseData = {
      'totalAmount': newAmount,
      'startDate': newDateRange.start.toIso8601String(),
      'endDate': newDateRange.end.toIso8601String(),
    };

    for (final monthKey in newMonthKeys) {
      final monthlyDocRef = firestore.collection('users').doc(userId).collection('expenses').doc('fixed').collection('monthly').doc(monthKey);
      // Nếu đổi tên khoản chi, cần đảm bảo key cũ đã bị xóa
      if (oldName != null && oldName != newName) {
        batch.update(monthlyDocRef, {'expenses.${oldName}': FieldValue.delete()});
      }
      batch.set(
          monthlyDocRef,
          {'expenses': {newName: expenseData}, 'updatedAt': FieldValue.serverTimestamp()},
          SetOptions(merge: true)
      );
    }

    // 2b. Thêm phân bổ hàng ngày mới
    final daysInNewRange = newDateRange.end.difference(newDateRange.start).inDays + 1;
    if (daysInNewRange > 0) {
      final newDailyAmount = newAmount / daysInNewRange;
      final expenseToAdd = {'name': newName, 'amount': newDailyAmount};
      for (int i = 0; i < daysInNewRange; i++) {
        final date = newDateRange.start.add(Duration(days: i));
        final dateKey = DateFormat('yyyy-MM-dd').format(date);
        final firestoreDocId = appState.getKey('fixedExpenseList_$dateKey');
        final dailyDocRef = firestore.collection('users').doc(userId).collection('expenses').doc('fixed').collection('daily').doc(firestoreDocId);
        batch.set(
            dailyDocRef,
            {'fixedExpenses': FieldValue.arrayUnion([expenseToAdd])},
            SetOptions(merge: true)
        );
      }
    }

    // --- BƯỚC 3: GỬI TẤT CẢ LỆNH LÊN SERVER ---
    await batch.commit();
  }

// <<< THÊM HÀM HELPER MỚI NÀY VÀO CLASS ExpenseManager >>>
  /// Lấy danh sách các tháng (dưới dạng key 'yyyy-MM') trong một khoảng thời gian.
  static List<String> _getMonthsInRange(DateTimeRange range) {
    final Set<String> months = {};
    DateTime currentDate = range.start;
    while (currentDate.isBefore(range.end) || currentDate.isAtSameMomentAs(range.end)) {
      months.add(DateFormat('yyyy-MM').format(currentDate));
      currentDate = DateTime(currentDate.year, currentDate.month + 1, 1);
    }
    return months.toList();
  }

  static Future<void> deleteMonthlyFixedExpense(
      AppState appState,
      String name,
      double amount,
      {required DateTimeRange dateRange}
      ) async {
    final String? userId = appState.activeUserId;
    if (userId == null) return;

    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();

    // Mở sẵn hộp cache
    if (!Hive.isBoxOpen('monthlyFixedExpensesBox')) {
      await Hive.openBox('monthlyFixedExpensesBox');
    }
    final monthlyFixedExpensesBox = Hive.box('monthlyFixedExpensesBox');

    // --- BƯỚC 1: XÓA DỮ LIỆU Ở CẢ MÁY CHỦ VÀ CACHE ---
    final monthKeys = _getMonthsInRange(dateRange);
    for (final monthKey in monthKeys) {
      // Lên lịch xóa trên máy chủ
      final monthlyDocRef = firestore.collection('users').doc(userId).collection('expenses').doc('fixed').collection('monthly').doc(monthKey);
      batch.update(monthlyDocRef, {
        'expenses.$name': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp()
      });

      // <<< SỬA LỖI: Xóa trực tiếp trong bộ nhớ đệm trên điện thoại >>>
      final hiveKey = '$userId-fixedExpenseList-$monthKey';
      if (monthlyFixedExpensesBox.containsKey(hiveKey)) {
        final cachedMap = Map<String, dynamic>.from(monthlyFixedExpensesBox.get(hiveKey));
        cachedMap.remove(name); // Xóa khoản chi ra khỏi map trong cache
        await monthlyFixedExpensesBox.put(hiveKey, cachedMap); // Lưu lại map đã được cập nhật
      }
    }

    // --- BƯỚC 2: XÓA PHÂN BỔ HÀNG NGÀY (trên máy chủ) ---
    final daysInRange = dateRange.end.difference(dateRange.start).inDays + 1;
    if (daysInRange > 0) {
      final dailyAmount = amount / daysInRange;
      final expenseToRemove = {'name': name, 'amount': dailyAmount};
      for (int i = 0; i < daysInRange; i++) {
        final currentDate = dateRange.start.add(Duration(days: i));
        final dateKey = DateFormat('yyyy-MM-dd').format(currentDate);
        final firestoreDocId = appState.getKey('fixedExpenseList_$dateKey');
        final dailyDocRef = firestore.collection('users').doc(userId).collection('expenses').doc('fixed').collection('daily').doc(firestoreDocId);
        batch.update(dailyDocRef, {'fixedExpenses': FieldValue.arrayRemove([expenseToRemove])});
      }
    }

    // --- BƯỚC 3: GỬI TẤT CẢ LỆNH XÓA LÊN MÁY CHỦ ---
    await batch.commit();
  }
}