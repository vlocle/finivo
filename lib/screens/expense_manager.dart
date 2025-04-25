import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../state/app_state.dart';

class ExpenseManager {
  // Load fixed expenses
  static Future<List<Map<String, dynamic>>> loadFixedExpenses(AppState appState) async {
    try {
      if (appState.userId == null) return [];
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      String dateKey = DateFormat('yyyy-MM-dd').format(appState.selectedDate);
      String key = appState.getKey('fixedExpenseList_$dateKey');

      DocumentSnapshot doc = await firestore
          .collection('users')
          .doc(appState.userId)
          .collection('expenses')
          .doc('fixed')
          .collection('daily')
          .doc(key)
          .get();

      if (doc.exists && doc['products'] != null) {
        return List<Map<String, dynamic>>.from(doc['products']);
      }
      return [];
    } catch (e) {
      print("Error loading fixed expenses: $e");
      return [];
    }
  }

  // Save fixed expenses
  static Future<void> saveFixedExpenses(AppState appState, List<Map<String, dynamic>> expenses, {String? date}) async {
    try {
      if (appState.userId == null) throw Exception('User ID không tồn tại');
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      String dateKey = date ?? DateFormat('yyyy-MM-dd').format(appState.selectedDate);
      String key = appState.getKey('fixedExpenseList_$dateKey');

      await firestore
          .collection('users')
          .doc(appState.userId)
          .collection('expenses')
          .doc('fixed')
          .collection('daily')
          .doc(key)
          .set({
        'products': expenses,
        'total': expenses.fold(0.0, (sum, item) => sum + (item['amount'] ?? 0.0)),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print("Error saving fixed expenses: $e");
      throw Exception("Không thể lưu chi phí cố định: $e");
    }
  }

  // Update total fixed expense
  static Future<double> updateTotalFixedExpense(AppState appState, List<Map<String, dynamic>> expenses, {String? date}) async {
    double total = expenses.fold(0.0, (sum, item) => sum + (item['amount'] ?? 0.0));
    await saveFixedExpenses(appState, expenses, date: date); // Total đã được lưu trong saveFixedExpenses
    return total;
  }

  // Load variable expenses
  static Future<List<Map<String, dynamic>>> loadVariableExpenses(AppState appState) async {
    try {
      if (appState.userId == null) return [];
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      String dateKey = DateFormat('yyyy-MM-dd').format(appState.selectedDate);
      String key = appState.getKey('variableTransactionHistory_$dateKey');

      DocumentSnapshot doc = await firestore
          .collection('users')
          .doc(appState.userId)
          .collection('expenses')
          .doc('variable')
          .collection('daily')
          .doc(key)
          .get();

      if (doc.exists && doc['products'] != null) {
        return List<Map<String, dynamic>>.from(doc['products']);
      }
      return [];
    } catch (e) {
      print("Error loading variable expenses: $e");
      return [];
    }
  }

  // Load available variable expenses
  static Future<List<Map<String, dynamic>>> loadAvailableVariableExpenses(AppState appState) async {
    try {
      if (appState.userId == null) return [];
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      String monthKey = DateFormat('yyyy-MM').format(appState.selectedDate);
      String key = appState.getKey('variableExpenseList_$monthKey');

      DocumentSnapshot doc = await firestore
          .collection('users')
          .doc(appState.userId)
          .collection('expenses')
          .doc('variableList')
          .collection('monthly')
          .doc(key)
          .get();

      if (doc.exists && doc['products'] != null) {
        return List<Map<String, dynamic>>.from(doc['products']);
      }
      return [];
    } catch (e) {
      print("Error loading available variable expenses: $e");
      return [];
    }
  }

  // Save variable expenses
  static Future<void> saveVariableExpenses(AppState appState, List<Map<String, dynamic>> expenses) async {
    try {
      if (appState.userId == null) throw Exception('User ID không tồn tại');
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      String dateKey = DateFormat('yyyy-MM-dd').format(appState.selectedDate);
      String key = appState.getKey('variableTransactionHistory_$dateKey');

      await firestore
          .collection('users')
          .doc(appState.userId)
          .collection('expenses')
          .doc('variable')
          .collection('daily')
          .doc(key)
          .set({
        'products': expenses,
        'total': expenses.fold(0.0, (sum, item) => sum + (item['amount'] ?? 0.0)),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print("Error saving variable expenses: $e");
      throw Exception("Không thể lưu chi phí biến đổi: $e");
    }
  }

  // Update total variable expense
  static Future<double> updateTotalVariableExpense(AppState appState, List<Map<String, dynamic>> expenses) async {
    double total = expenses.fold(0.0, (sum, item) => sum + (item['amount'] ?? 0.0));
    await saveVariableExpenses(appState, expenses); // Total đã được lưu trong saveVariableExpenses
    return total;
  }

  // Load fixed expense list
  static Future<List<Map<String, dynamic>>> loadFixedExpenseList(AppState appState) async {
    try {
      if (appState.userId == null) return [];
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      String key = appState.getKey('fixedExpenseList');

      DocumentSnapshot doc = await firestore
          .collection('users')
          .doc(appState.userId)
          .collection('expenses')
          .doc('fixedList')
          .get();

      if (doc.exists && doc['products'] != null) {
        return List<Map<String, dynamic>>.from(doc['products']);
      }
      return [];
    } catch (e) {
      print("Error loading fixed expense list: $e");
      return [];
    }
  }

  // Save fixed expense list
  static Future<void> saveFixedExpenseList(AppState appState, List<Map<String, dynamic>> expenses) async {
    try {
      if (appState.userId == null) throw Exception('User ID không tồn tại');
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      String key = appState.getKey('fixedExpenseList');

      await firestore
          .collection('users')
          .doc(appState.userId)
          .collection('expenses')
          .doc('fixedList')
          .set({
        'products': expenses,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print("Error saving fixed expense list: $e");
      throw Exception("Không thể lưu danh sách chi phí cố định: $e");
    }
  }

  // Load monthly fixed amounts
  static Future<Map<String, double>> loadMonthlyFixedAmounts(AppState appState, DateTime month) async {
    try {
      if (appState.userId == null) return {};
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      String key = appState.getKey('monthlyFixedAmounts_${month.year}_${month.month}');

      DocumentSnapshot doc = await firestore
          .collection('users')
          .doc(appState.userId)
          .collection('expenses')
          .doc('monthlyFixed')
          .collection('monthly')
          .doc(key)
          .get();

      if (doc.exists && doc['amounts'] != null) {
        return Map<String, double>.from(doc['amounts']);
      }
      return {};
    } catch (e) {
      print("Error loading monthly fixed amounts: $e");
      return {};
    }
  }

  // Save monthly fixed amounts and distribute daily
  static Future<void> saveMonthlyFixedAmount(AppState appState, String name, double amount, DateTime month) async {
    try {
      if (appState.userId == null) throw Exception('User ID không tồn tại');
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();
      int daysInMonth = DateTime(month.year, month.month + 1, 0).day;
      double dailyAmount = amount / daysInMonth;
      DateTime originalDate = appState.selectedDate;

      // Tải tất cả dữ liệu chi phí cố định của tháng
      List<Future<DocumentSnapshot>> futures = [];
      for (int day = 1; day <= daysInMonth; day++) {
        DateTime currentDate = DateTime(month.year, month.month, day);
        String dateKey = DateFormat('yyyy-MM-dd').format(currentDate);
        String key = appState.getKey('fixedExpenseList_$dateKey');
        futures.add(
          firestore
              .collection('users')
              .doc(appState.userId)
              .collection('expenses')
              .doc('fixed')
              .collection('daily')
              .doc(key)
              .get(),
        );
      }
      List<DocumentSnapshot> docs = await Future.wait(futures);

      // Cập nhật dữ liệu và thêm vào batch
      for (int day = 0; day < daysInMonth; day++) {
        DateTime currentDate = DateTime(month.year, month.month, day + 1);
        String dateKey = DateFormat('yyyy-MM-dd').format(currentDate);
        String key = appState.getKey('fixedExpenseList_$dateKey');
        DocumentReference docRef = firestore
            .collection('users')
            .doc(appState.userId)
            .collection('expenses')
            .doc('fixed')
            .collection('daily')
            .doc(key);

        List<Map<String, dynamic>> expenseList = [];
        if (docs[day].exists && docs[day]['products'] != null) {
          expenseList = List<Map<String, dynamic>>.from(docs[day]['products']);
        }

        var existingItem = expenseList.firstWhere((item) => item['name'] == name, orElse: () => {});
        if (existingItem.isEmpty) {
          expenseList.add({'name': name, 'amount': dailyAmount, 'isFixedMonthly': false});
        } else {
          existingItem['amount'] = dailyAmount;
        }

        batch.set(docRef, {
          'products': expenseList,
          'total': expenseList.fold(0.0, (sum, item) => sum + (item['amount'] ?? 0.0)),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Cập nhật danh sách chi phí cố định hàng tháng
      String monthlyKey = appState.getKey('monthlyFixedAmounts_${month.year}_${month.month}');
      DocumentReference monthlyDocRef = firestore
          .collection('users')
          .doc(appState.userId)
          .collection('expenses')
          .doc('monthlyFixed')
          .collection('monthly')
          .doc(monthlyKey);

      DocumentSnapshot monthlyDoc = await monthlyDocRef.get();
      Map<String, double> monthlyData = {};
      if (monthlyDoc.exists && monthlyDoc['amounts'] != null) {
        monthlyData = Map<String, double>.from(monthlyDoc['amounts']);
      }
      monthlyData[name] = amount;

      batch.set(monthlyDocRef, {
        'amounts': monthlyData,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      appState.setSelectedDate(originalDate);
    } catch (e) {
      print("Error saving monthly fixed amount: $e");
      throw Exception("Không thể lưu chi phí cố định hàng tháng: $e");
    }
  }

  // Delete monthly fixed expense
  static Future<void> deleteMonthlyFixedExpense(AppState appState, String name, DateTime month) async {
    try {
      if (appState.userId == null) throw Exception('User ID không tồn tại');
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      int daysInMonth = DateTime(month.year, month.month + 1, 0).day;

      // Lưu ngày ban đầu để khôi phục sau
      DateTime originalDate = appState.selectedDate;

      for (int day = 1; day <= daysInMonth; day++) {
        DateTime currentDate = DateTime(month.year, month.month, day);
        String dateKey = DateFormat('yyyy-MM-dd').format(currentDate);
        String key = appState.getKey('fixedExpenseList_$dateKey');

        DocumentSnapshot doc = await firestore
            .collection('users')
            .doc(appState.userId)
            .collection('expenses')
            .doc('fixed')
            .collection('daily')
            .doc(key)
            .get();

        List<Map<String, dynamic>> expenseList = [];
        if (doc.exists && doc['products'] != null) {
          expenseList = List<Map<String, dynamic>>.from(doc['products']);
        }

        expenseList.removeWhere((item) => item['name'] == name);
        await saveFixedExpenses(appState, expenseList, date: dateKey);
      }

      String monthlyKey = appState.getKey('monthlyFixedAmounts_${month.year}_${month.month}');
      DocumentSnapshot monthlyDoc = await firestore
          .collection('users')
          .doc(appState.userId)
          .collection('expenses')
          .doc('monthlyFixed')
          .collection('monthly')
          .doc(monthlyKey)
          .get();

      Map<String, double> monthlyData = {};
      if (monthlyDoc.exists && monthlyDoc['amounts'] != null) {
        monthlyData = Map<String, double>.from(monthlyDoc['amounts']);
      }
      monthlyData.remove(name);

      await firestore
          .collection('users')
          .doc(appState.userId)
          .collection('expenses')
          .doc('monthlyFixed')
          .collection('monthly')
          .doc(monthlyKey)
          .set({
        'amounts': monthlyData,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Khôi phục selectedDate ban đầu
      appState.setSelectedDate(originalDate);
    } catch (e) {
      print("Error deleting monthly fixed expense: $e");
      throw Exception("Không thể xóa chi phí cố định hàng tháng: $e");
    }
  }
}