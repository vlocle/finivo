import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import '../state/app_state.dart';

class ExpenseManager {
  // Load fixed expenses
  static Future<List<Map<String, dynamic>>> loadFixedExpenses(AppState appState, DateTime date) async {
    final String? userId = appState.userId;
    if (userId == null) return [];

    final String dateKey = DateFormat('yyyy-MM-dd').format(date);
    final String firestoreDocId = appState.getKey('fixedExpenseList_$dateKey');
    final String hiveKey = '$userId-fixedExpenses-$firestoreDocId';
    final fixedExpensesBox = Hive.box('fixedExpensesBox');

    final cachedData = fixedExpensesBox.get(hiveKey);
    if (cachedData != null) {
      try {
        if (cachedData is List) {
          List<Map<String, dynamic>> castedList = [];
          for (var item in cachedData) {
            if (item is Map) {
              castedList.add(
                Map<String, dynamic>.fromEntries(
                    item.entries.map((entry) => MapEntry(entry.key.toString(), entry.value))),
              );
            }
          }
          return castedList;
        }
      } catch (e) {
        print('Error casting Hive data for $dateKey: $e');
      }
    }

    try {
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      DocumentSnapshot doc = await firestore
          .collection('users')
          .doc(userId)
          .collection('expenses')
          .doc('fixed')
          .collection('daily')
          .doc(firestoreDocId)
          .get();

      List<Map<String, dynamic>> expenses = [];
      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['fixedExpenses']?.isNotEmpty == true) {
          expenses = List<Map<String, dynamic>>.from(data['fixedExpenses']);
        }
      }

      await fixedExpensesBox.put(hiveKey, expenses);
      return expenses;
    } catch (e) {
      print("Error loading fixed expenses from Firestore for $dateKey: $e");
      return [];
    }
  }

  static Future<void> _saveDailyFixedExpense(AppState appState, DateTime date, String name, double dailyAmount) async {
    final String dateKey = DateFormat('yyyy-MM-dd').format(date);
    final String firestoreDocId = appState.getKey('fixedExpenseList_$dateKey');
    final String hiveKey = '${appState.userId}-fixedExpenses-$firestoreDocId';
    final fixedExpensesBox = Hive.box('fixedExpensesBox');

    try {
      List<Map<String, dynamic>> dailyExpenses = await loadFixedExpenses(appState, date);
      final existingIndex = dailyExpenses.indexWhere((e) => e['name'] == name);
      if (existingIndex != -1) {
        dailyExpenses[existingIndex] = {'name': name, 'amount': dailyAmount};
      } else {
        dailyExpenses.add({'name': name, 'amount': dailyAmount});
      }

      double total = dailyExpenses.fold(0.0, (sum, item) => sum + (item['amount']?.toDouble() ?? 0.0));
      await FirebaseFirestore.instance
          .collection('users')
          .doc(appState.userId)
          .collection('expenses')
          .doc('fixed')
          .collection('daily')
          .doc(firestoreDocId)
          .set({
        'fixedExpenses': dailyExpenses,
        'total': total,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await fixedExpensesBox.put(hiveKey, dailyExpenses);
    } catch (e) {
      print('Error saving fixed expenses for $dateKey: $e');
      throw e;
    }
  }

  // Save fixed expenses
  static Future<void> saveFixedExpenses(AppState appState, List<Map<String, dynamic>> expenses) async {
    final String? userId = appState.userId;
    if (userId == null) return;

    final String dateKey = DateFormat('yyyy-MM-dd').format(appState.selectedDate);
    final String firestoreDocId = appState.getKey('fixedExpenseList_$dateKey');
    final String hiveKey = '$userId-fixedExpenses-$firestoreDocId';
    final fixedExpensesBox = Hive.box('fixedExpensesBox');

    try {
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      double total = expenses.fold(0.0, (sum, item) => sum + (item['amount']?.toDouble() ?? 0.0));

      // Kiểm tra dữ liệu hiện tại trên Firestore
      final docRef = firestore
          .collection('users')
          .doc(userId)
          .collection('expenses')
          .doc('fixed')
          .collection('daily')
          .doc(firestoreDocId);
      final doc = await docRef.get();

      List<Map<String, dynamic>> mergedExpenses = expenses;
      if (doc.exists && doc.data()?['fixedExpenses'] != null) {
        final existingExpenses = List<Map<String, dynamic>>.from(doc.data()!['fixedExpenses']);
        // Gộp danh sách chi phí, ưu tiên chi phí mới
        final Map<String, Map<String, dynamic>> expenseMap = {};
        for (var exp in existingExpenses) {
          expenseMap[exp['name']] = exp;
        }
        for (var exp in expenses) {
          expenseMap[exp['name']] = exp;
        }
        mergedExpenses = expenseMap.values.toList();
        total = mergedExpenses.fold(0.0, (sum, item) => sum + (item['amount']?.toDouble() ?? 0.0));
      }

      await docRef.set({
        'fixedExpenses': mergedExpenses,
        'total': total,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Lưu vào Hive
      await fixedExpensesBox.put(hiveKey, mergedExpenses);
    } catch (e) {
      print("Error saving fixed expenses: $e");
      // Lưu vào Hive để hỗ trợ offline
      await fixedExpensesBox.put(hiveKey, expenses);
      rethrow;
    }
  }

  // Update total fixed expense
  static Future<double> updateTotalFixedExpense(AppState appState, List<Map<String, dynamic>> expenses) async {
    double total = expenses.fold(0.0, (sum, item) => sum + (item['amount'] ?? 0.0));
    await saveFixedExpenses(appState, expenses); // Loại bỏ tham số date
    return total;
  }

  // Load variable expenses
  static Future<List<Map<String, dynamic>>> loadVariableExpenses(AppState appState) async {
    final String? userId = appState.userId;
    if (userId == null) return [];

    final String dateKey = DateFormat('yyyy-MM-dd').format(appState.selectedDate);
    final String firestoreDocId = appState.getKey('variableTransactionHistory_${DateFormat('yyyy-MM-dd').format(appState.selectedDate)}'); // SỬ DỤNG KEY NHẤT QUÁN
    final String hiveKey = '${appState.userId}-variableExpenses-$firestoreDocId'; // CẬP NHẬT HIVE KEY
    final variableExpensesBox = Hive.box('variableExpensesBox');

    // Kiểm tra dữ liệu trong Hive
    final cachedData = variableExpensesBox.get(hiveKey);
    if (cachedData != null) {
      try {
        if (cachedData is List) {
          List<Map<String, dynamic>> castedList = [];
          for (var item in cachedData) {
            if (item is Map) {
              castedList.add(
                  Map<String, dynamic>.fromEntries(
                      item.entries.map((entry) => MapEntry(entry.key.toString(), entry.value))
                  )
              );
            }
          }
          return castedList;
        }
      } catch (e) {
        print('Error casting Hive data in loadVariableExpenses: $e. Falling back to Firestore.');
      }
    }

    try {
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      DocumentSnapshot doc = await firestore
          .collection('users')
          .doc(userId)
          .collection('expenses')
          .doc('variable')
          .collection('daily')
          .doc(firestoreDocId) // THAY ĐỔI Ở ĐÂY
          .get();

      List<Map<String, dynamic>> expenses = [];
      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['variableExpenses'] != null) {
          expenses = List<Map<String, dynamic>>.from(data['variableExpenses']);
        }
      }

      // Lưu vào Hive
      await variableExpensesBox.put(hiveKey, expenses);
      return expenses;
    } catch (e) {
      print("Error loading variable expenses: $e");
      return cachedData ?? [];
    }
  }

  // Load available variable expenses
  static Future<List<Map<String, dynamic>>> loadAvailableVariableExpenses(AppState appState) async {
    final String? userId = appState.userId; //
    if (userId == null) return []; //
    final String monthKey = DateFormat('yyyy-MM').format(appState.selectedDate); //
    final String hiveKey = '$userId-variableExpenseList-$monthKey'; //
    final variableExpenseListBox = Hive.box('variableExpenseListBox'); //

    final cachedData = variableExpenseListBox.get(hiveKey); //

    if (cachedData != null) { //
      try {
        if (cachedData is List) {
          List<Map<String, dynamic>> castedList = [];
          for (var item in cachedData) {
            if (item is Map) {
              castedList.add(
                  Map<String, dynamic>.fromEntries(
                      item.entries.map((entry) => MapEntry(entry.key.toString(), entry.value))
                  )
              );
            }
          }
          return castedList; // Trả về dữ liệu đã ép kiểu từ Hive
        }
        // Nếu cachedData không phải List, coi như dữ liệu không hợp lệ, sẽ tải từ Firestore
      } catch (e) {
        print('Error casting Hive data in loadAvailableVariableExpenses: $e. Falling back to Firestore.');
        // Nếu lỗi ép kiểu, sẽ tiếp tục thử tải từ Firestore
      }
    }

    // Nếu không có cache hoặc cache không hợp lệ/lỗi ép kiểu, tải từ Firestore
    try {
      final FirebaseFirestore firestore = FirebaseFirestore.instance; //
      final String firestoreDocKey = appState.getKey('variableExpenseList_$monthKey'); //
      DocumentSnapshot doc = await firestore
          .collection('users')
          .doc(userId)
          .collection('expenses')
          .doc('variableList')
          .collection('monthly')
          .doc(firestoreDocKey) // Sử dụng firestoreDocKey đã được tạo với userId (nếu có)
          .get(); //

      List<Map<String, dynamic>> expenses = [];
      if (doc.exists && doc.data() != null) { //
        final data = doc.data() as Map<String, dynamic>; //
        if (data['products'] != null && data['products'] is List) { //
          // Đảm bảo ép kiểu an toàn từ Firestore nếu cần
          List<dynamic> rawExpenses = data['products'];
          expenses = rawExpenses.map((item) {
            if (item is Map) {
              // Giả sử item từ Firestore đã có key là String, nếu không cũng cần toString()
              return Map<String, dynamic>.from(item);
            }
            return <String, dynamic>{}; // Hoặc xử lý lỗi/bỏ qua item không hợp lệ
          }).toList();
        }
      }
      await variableExpenseListBox.put(hiveKey, expenses); //
      return expenses; //
    } catch (e) {
      print("Error loading available variable expenses from Firestore: $e"); //
      return []; // Trả về danh sách rỗng nếu cả Hive và Firestore đều thất bại
    }
  }

  // Save variable expenses
  static Future<void> saveVariableExpenses(AppState appState, List<Map<String, dynamic>> expenses) async {
    final String? userId = appState.userId;
    if (userId == null) return;

    final String dateKey = DateFormat('yyyy-MM-dd').format(appState.selectedDate);
    final String firestoreDocId = appState.getKey('variableTransactionHistory_${DateFormat('yyyy-MM-dd').format(appState.selectedDate)}'); // SỬ DỤNG KEY NHẤT QUÁN
    final String hiveKey = '${appState.userId}-variableExpenses-$firestoreDocId'; // CẬP NHẬT HIVE KEY
    final variableExpensesBox = Hive.box('variableExpensesBox');

    try {
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      double total = expenses.fold(0.0, (sum, item) => sum + (item['amount'] ?? 0.0));
      await firestore
          .collection('users')
          .doc(userId)
          .collection('expenses')
          .doc('variable')
          .collection('daily')
          .doc(firestoreDocId)
          .set({
        'variableExpenses': expenses,
        'total': total, // LƯU CẢ TOTAL
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)); // DÙNG MERGE

      // Lưu vào Hive
      await variableExpensesBox.put(hiveKey, expenses);
    } catch (e) {
      print("Error saving variable expenses: $e");
      // Lưu vào Hive để hỗ trợ offline
      await variableExpensesBox.put(hiveKey, expenses);
      rethrow;
    }
  }

  // Update total variable expense
  static Future<double> updateTotalVariableExpense(AppState appState, List<Map<String, dynamic>> expenses) async {
    double total = expenses.fold(0.0, (sum, item) => sum + (item['amount'] ?? 0.0));
    await saveVariableExpenses(appState, expenses); // Total đã được lưu trong saveVariableExpenses
    return total;
  }

  // Load fixed expense list
  static Future<List<Map<String, dynamic>>> loadFixedExpenseList(AppState appState, DateTime month) async {
    final String? userId = appState.userId;
    if (userId == null) return [];

    final String monthKey = DateFormat('yyyy-MM').format(month);
    final String hiveKey = '$userId-fixedExpenseList-$monthKey';
    final monthlyFixedExpensesBox = Hive.box('monthlyFixedExpensesBox');

    // Kiểm tra dữ liệu trong Hive
    final cachedData = monthlyFixedExpensesBox.get(hiveKey);
    if (cachedData != null) {
      return List<Map<String, dynamic>>.from(cachedData);
    }

    try {
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      DocumentSnapshot doc = await firestore
          .collection('users')
          .doc(userId)
          .collection('expenses')
          .doc('fixedList')
          .collection('monthly')
          .doc(monthKey)
          .get();

      List<Map<String, dynamic>> expenses = [];
      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['products'] != null) {
          expenses = List<Map<String, dynamic>>.from(data['products']);
        }
      }

      // Lưu vào Hive
      await monthlyFixedExpensesBox.put(hiveKey, expenses);
      return expenses;
    } catch (e) {
      print("Error loading fixed expense list: $e");
      return cachedData ?? [];
    }
  }

  // Save fixed expense list
  static Future<void> saveFixedExpenseList(AppState appState, List<Map<String, dynamic>> expenses, DateTime month) async {
    final String? userId = appState.userId;
    if (userId == null) return;

    final String monthKey = DateFormat('yyyy-MM').format(month);
    final String hiveKey = '$userId-fixedExpenseList-$monthKey';
    final monthlyFixedExpensesBox = Hive.box('monthlyFixedExpensesBox');

    try {
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      await firestore
          .collection('users')
          .doc(userId)
          .collection('expenses')
          .doc('fixedList')
          .collection('monthly')
          .doc(monthKey)
          .set({
        'products': expenses,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Lưu vào Hive
      await monthlyFixedExpensesBox.put(hiveKey, expenses);
    } catch (e) {
      print("Error saving fixed expense list: $e");
      // Lưu vào Hive để hỗ trợ offline
      await monthlyFixedExpensesBox.put(hiveKey, expenses);
      rethrow;
    }
  }

  // Load monthly fixed amounts
  static Future<Map<String, double>> loadMonthlyFixedAmounts(AppState appState, DateTime month) async {
    final String? userId = appState.userId;
    if (userId == null) return {};

    final String monthKey = DateFormat('yyyy-MM').format(month);
    final String hiveKey = '$userId-monthlyFixedAmounts-$monthKey';
    final monthlyFixedAmountsBox = Hive.box('monthlyFixedAmountsBox');

    // Kiểm tra dữ liệu trong Hive
    final cachedData = monthlyFixedAmountsBox.get(hiveKey);
    if (cachedData != null) {
      return Map<String, double>.from(cachedData);
    }

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

      Map<String, double> amounts = {};
      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['amounts'] != null) {
          amounts = Map<String, double>.from(data['amounts']);
        }
      }

      // Lưu vào Hive
      await monthlyFixedAmountsBox.put(hiveKey, amounts);
      return amounts;
    } catch (e) {
      print("Error loading monthly fixed amounts: $e");
      return cachedData ?? {};
    }
  }

  // Save monthly fixed amounts and distribute daily
  static Future<void> saveMonthlyFixedAmount(AppState appState, String name, double amount, DateTime month, {DateTimeRange? dateRange}) async {
    final String? userId = appState.userId;
    if (userId == null) return;

    final String monthKey = DateFormat('yyyy-MM').format(month);
    final String hiveKey = '$userId-monthlyFixedAmounts-$monthKey';
    final monthlyFixedAmountsBox = Hive.box('monthlyFixedAmountsBox');

    try {
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      final amounts = await loadMonthlyFixedAmounts(appState, month);
      amounts[name] = amount;

      await firestore
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

      final DateTimeRange range = dateRange ?? DateTimeRange(
        start: DateTime(month.year, month.month, 1),
        end: DateTime(month.year, month.month + 1, 0),
      );
      final int days = range.end.difference(range.start).inDays + 1;
      final double dailyAmount = amount / days;

      List<Future<void>> saveFutures = [];
      for (int i = 0; i < days; i++) {
        final DateTime currentDate = range.start.add(Duration(days: i));
        saveFutures.add(_saveDailyFixedExpense(appState, currentDate, name, dailyAmount));
      }

      await Future.wait(saveFutures);
      await monthlyFixedAmountsBox.put(hiveKey, amounts);
      await appState.loadExpenseValues();
    } catch (e) {
      print("Error saving monthly fixed amount: $e");
      final amounts = await loadMonthlyFixedAmounts(appState, month);
      amounts[name] = amount;
      await monthlyFixedAmountsBox.put(hiveKey, amounts);
      throw e;
    }
  }

  // Delete monthly fixed expense
  static Future<void> deleteMonthlyFixedExpense(AppState appState, String name,
      DateTime month, {DateTimeRange? dateRange}) async {
    final String? userId = appState.userId;
    if (userId == null) {
      print("User ID is null, cannot delete monthly fixed expense.");
      return;
    }

    final String monthKey = DateFormat('yyyy-MM').format(month);
    // *** SỬA Ở ĐÂY: Sử dụng key Hive chi tiết và nhất quán ***
    final String hiveMonthlyAmountsKey = '$userId-monthlyFixedAmounts-$monthKey';
    final monthlyFixedAmountsBox = Hive.box('monthlyFixedAmountsBox');

    final String hiveFixedExpenseListKey = '$userId-fixedExpenseList-$monthKey';
    final monthlyFixedExpensesBox = Hive.box('monthlyFixedExpensesBox');


    try {
      final FirebaseFirestore firestore = FirebaseFirestore.instance;

      // 1. Xóa khoản mục khỏi monthlyFixedAmounts (Firestore and Hive)
      //    Đây là Map lưu trữ {'Tên chi phí': số tiền tháng}
      final amounts = await loadMonthlyFixedAmounts(appState, month);
      if (amounts.containsKey(name)) {
        amounts.remove(name);
        await firestore
            .collection('users')
            .doc(userId)
            .collection('expenses')
            .doc('fixed')
            .collection('monthly')
            .doc(monthKey)
            .set({
          'amounts': amounts,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)); // Dùng merge true để không ghi đè các field khác nếu có

        // Cập nhật Hive cho monthlyFixedAmounts với key ĐÚNG
        await monthlyFixedAmountsBox.put(hiveMonthlyAmountsKey, amounts);
        print("Updated monthlyFixedAmounts in Firestore and Hive for $monthKey after removing $name.");
      } else {
        print("Expense '$name' not found in monthlyFixedAmounts for $monthKey. Skipping update.");
      }


      // 2. Cập nhật danh sách fixedExpenses cho tháng (Firestore and Hive)
      //    Đây là List lưu trữ [{'name': 'Tên chi phí'}, ...] - định nghĩa các khoản chi của tháng
      final fixedExpensesListForMonth = await loadFixedExpenseList(appState, month);
      final originalLength = fixedExpensesListForMonth.length;
      final updatedFixedExpensesListForMonth = fixedExpensesListForMonth.where((e) => e['name'] != name).toList();

      if (updatedFixedExpensesListForMonth.length < originalLength) {
        // saveFixedExpenseList đã xử lý cả Firestore và Hive (monthlyFixedExpensesBox)
        await saveFixedExpenseList(appState, updatedFixedExpensesListForMonth, month);
        print("Updated fixedExpenseList in Firestore and Hive for $monthKey after removing $name.");
      } else {
        print("Expense '$name' not found in fixedExpenseList for $monthKey. Skipping update.");
      }


      // 3. Xóa khoản mục khỏi fixedExpenses hàng ngày (Firestore and Hive)
      final DateTimeRange range = dateRange ??
          DateTimeRange(
            start: DateTime(month.year, month.month, 1),
            end: DateTime(month.year, month.month + 1, 0), // Ngày cuối của tháng
          );

      List<Future<void>> dailyUpdateFutures = [];
      final fixedExpensesBox = Hive.box('fixedExpensesBox'); // Box cho chi phí cố định hàng ngày

      for (int i = 0; i <= range.end.difference(range.start).inDays; i++) {
        final DateTime currentDate = range.start.add(Duration(days: i));
        final String dailyDateKey = DateFormat('yyyy-MM-dd').format(currentDate);
        final String firestoreDailyDocId = appState.getKey('fixedExpenseList_$dailyDateKey');
        final String hiveDailyFixedKey = '$userId-fixedExpenses-$firestoreDailyDocId';

        dailyUpdateFutures.add(
          Future(() async {
            try {
              final List<Map<String, dynamic>> dailyExpenses = await loadFixedExpenses(appState, currentDate);
              final updatedDailyExpenses = dailyExpenses.where((e) => e['name'] != name).toList();

              // Chỉ thực hiện ghi nếu có sự thay đổi
              if (updatedDailyExpenses.length < dailyExpenses.length || (dailyExpenses.isNotEmpty && updatedDailyExpenses.isEmpty)) {
                final docRef = firestore
                    .collection('users')
                    .doc(userId)
                    .collection('expenses')
                    .doc('fixed')
                    .collection('daily')
                    .doc(firestoreDailyDocId);

                if (updatedDailyExpenses.isEmpty) {
                  await docRef.delete();
                  await fixedExpensesBox.delete(hiveDailyFixedKey);
                  print('Deleted daily fixed expense document $firestoreDailyDocId and Hive key $hiveDailyFixedKey for $name.');
                } else {
                  double total = updatedDailyExpenses.fold(0.0,
                          (sum, item) => sum + (item['amount']?.toDouble() ?? 0.0));
                  await docRef.set({
                    'fixedExpenses': updatedDailyExpenses,
                    'total': total,
                    'updatedAt': FieldValue.serverTimestamp(),
                  }, SetOptions(merge: true));
                  await fixedExpensesBox.put(hiveDailyFixedKey, updatedDailyExpenses);
                  print('Updated daily fixed expense document $firestoreDailyDocId and Hive key $hiveDailyFixedKey for $name.');
                }
              } else {
                print('No changes needed for daily fixed expenses on $dailyDateKey for $name.');
              }
            } catch (e) {
              print('Error processing daily fixed expenses for $dailyDateKey when deleting $name: $e, Stacktrace: ${StackTrace.current}');
              // Không ném lỗi ở đây để các ngày khác tiếp tục được xử lý
            }
          }),
        );
      }

      // Chờ tất cả các thao tác cập nhật hàng ngày hoàn tất
      await Future.wait(dailyUpdateFutures.map((future) => future.catchError((e) {
        // Lỗi này không nên xảy ra nếu đã catch bên trong Future
        print('An unexpected error occurred in dailyUpdateFutures during deleteMonthlyFixedExpense: $e');
        return Future.value();
      })));
      print("Finished processing daily fixed expense entries for deletion of $name.");

      // 4. Tải lại dữ liệu chi phí tổng thể trong AppState
      await appState.loadExpenseValues();
      print("Reloaded expense values in AppState after deleting $name.");

    } catch (e) {
      print("Error deleting monthly fixed expense '$name' for month $monthKey: $e, Stacktrace: ${StackTrace.current}");
      // Xử lý lỗi ở đây nếu cần, ví dụ: thông báo cho người dùng
      // Cân nhắc việc có nên cố gắng cập nhật Hive ở đây không nếu Firestore lỗi.
      // Hiện tại, chỉ ném lại lỗi để UI xử lý.
      rethrow;
    }
  }
}