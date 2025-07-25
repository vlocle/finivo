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

  static Future<void> saveVariableExpenses(AppState appState, List<Map<String, dynamic>> expenses, {WriteBatch? batch}) async {
    final String? userId = appState.activeUserId;
    if (userId == null) return;

    final bool isExternalBatch = batch != null;
    final firestore = FirebaseFirestore.instance;
    // Nếu không có batch từ bên ngoài, tự tạo một batch mới. Ngược lại, dùng batch được cung cấp.
    final localBatch = isExternalBatch ? batch : firestore.batch();

    final String dateKey = DateFormat('yyyy-MM-dd').format(appState.selectedDate);
    final String firestoreDocId = appState.getKey('variableTransactionHistory_$dateKey');
    final String hiveKey = '$userId-variableExpenses-$firestoreDocId';

    if (!Hive.isBoxOpen('variableExpensesBox')) {
      await Hive.openBox('variableExpensesBox');
    }
    final variableExpensesBox = Hive.box('variableExpensesBox');

    try {
      double total = expenses.fold(0.0, (sum, item) => sum + (item['amount'] as num? ?? 0.0));

      final docRef = firestore
          .collection('users')
          .doc(userId)
          .collection('expenses')
          .doc('variable')
          .collection('daily')
          .doc(firestoreDocId);

      // Dùng batch để ghi dữ liệu thay vì .set() trực tiếp
      localBatch.set(docRef, {
        'variableExpenses': expenses,
        'total': total,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Chỉ commit nếu đây là batch được tạo nội bộ trong hàm này
      if (!isExternalBatch) {
        await localBatch.commit();
      }

      // Luôn cập nhật cache Hive sau khi thao tác Firestore thành công
      await variableExpensesBox.put(hiveKey, expenses);

    } catch (e) {
      print("Error saving variable expenses: $e");
      // Vẫn cố gắng lưu vào cache Hive để tránh mất dữ liệu nếu offline
      await variableExpensesBox.put(hiveKey, expenses);
      rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>> loadOtherExpenses(AppState appState) async {
    final String? userId = appState.activeUserId;
    if (userId == null) return [];

    final String dateKey = DateFormat('yyyy-MM-dd').format(appState.selectedDate);
    final String firestoreDocId = appState.getKey('otherExpenseList_$dateKey');
    final String hiveKey = '$userId-otherExpenses-$firestoreDocId';

    if (!Hive.isBoxOpen('otherExpensesBox')) {
      await Hive.openBox('otherExpensesBox');
    }
    final otherExpensesBox = Hive.box('otherExpensesBox');

    // Ưu tiên tải từ Firestore nếu online
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('users').doc(userId)
          .collection('expenses').doc('other')
          .collection('daily').doc(firestoreDocId)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        final expenses = List<Map<String, dynamic>>.from(data['otherExpenses'] ?? []);
        await otherExpensesBox.put(hiveKey, expenses); // Cập nhật cache
        return expenses;
      } else {
        await otherExpensesBox.delete(hiveKey); // Xóa cache nếu doc không tồn tại
        return [];
      }
    } catch (e) {
      print("Error loading other expenses from Firestore: $e. Using cache.");
      // Nếu lỗi, dùng cache
      final cachedData = otherExpensesBox.get(hiveKey) as List?;
      return cachedData?.cast<Map<String, dynamic>>() ?? [];
    }
  }

  /// Lưu danh sách chi phí khác và tổng của chúng lên Firestore và Cache.
  static Future<void> saveOtherExpenses(AppState appState, List<Map<String, dynamic>> expenses) async {
    final String? userId = appState.activeUserId;
    if (userId == null) return;

    final String dateKey = DateFormat('yyyy-MM-dd').format(appState.selectedDate);
    final String firestoreDocId = appState.getKey('otherExpenseList_$dateKey');
    final String hiveKey = '$userId-otherExpenses-$firestoreDocId';

    if (!Hive.isBoxOpen('otherExpensesBox')) {
      await Hive.openBox('otherExpensesBox');
    }
    final otherExpensesBox = Hive.box('otherExpensesBox');

    try {
      double total = expenses.fold(0.0, (sum, item) => sum + (item['amount']?.toDouble() ?? 0.0));

      await FirebaseFirestore.instance
          .collection('users').doc(userId)
          .collection('expenses').doc('other')
          .collection('daily').doc(firestoreDocId)
          .set({
        'otherExpenses': expenses,
        'total': total,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await otherExpensesBox.put(hiveKey, expenses);
    } catch (e) {
      print("Error saving other expenses: $e");
      rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>> loadFixedExpenseRules(AppState appState) async {
    if (appState.activeUserId == null) return [];
    final firestore = FirebaseFirestore.instance;

    // Lấy tất cả các tài liệu quy tắc trong collection 'monthly'
    final querySnapshot = await firestore
        .collection('users')
        .doc(appState.activeUserId)
        .collection('expenses')
        .doc('fixed')
        .collection('monthly')
        .get();

    final Map<String, Map<String, dynamic>> rulesMap = {};

    // Lặp qua từng tài liệu của mỗi tháng để tổng hợp các quy tắc
    for (final doc in querySnapshot.docs) {
      if (doc.exists && doc.data().containsKey('expenses')) {
        final expensesInMonth = doc.data()['expenses'] as Map<String, dynamic>;
        expensesInMonth.forEach((name, ruleData) {
          // Chỉ thêm quy tắc vào danh sách nếu nó chưa tồn âtị
          if (!rulesMap.containsKey(name)) {
            rulesMap[name] = {
              'name': name,
              ...ruleData as Map<String, dynamic>,
            };
          }
        });
      }
    }

    // Chuyển Map thành List và sắp xếp theo tên
    final rulesList = rulesMap.values.toList();
    rulesList.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));

    return rulesList;
  }

  static Future<void> saveFixedExpenseRule({
    required AppState appState,
    required String name,
    required double amount,
    required DateTimeRange dateRange,
    String? oldName,
    double? oldAmount,       // <-- Tham số mới
    DateTimeRange? oldDateRange, // <-- Tham số mới
    required String paymentType,
    int? paymentDay,
    DateTime? oneTimePaymentDate,
    String? walletId,
  }) async {
    if (appState.activeUserId == null) return;

    // Nếu là chỉnh sửa, xóa các lịch thanh toán cũ trước
    if (oldName != null) {
      await _deleteScheduledPaymentsForRule(appState, oldName);
    }

    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();

    // 1. Lưu/cập nhật quy tắc vào tài liệu của mỗi tháng
    final monthKeys = _getMonthsInRange(dateRange);
    final ruleData = {
      'totalAmount': amount,
      'paymentType': paymentType,
      'paymentDay': paymentDay,
      'oneTimePaymentDate': oneTimePaymentDate?.toIso8601String(),
      'walletId': walletId,
      'startDate': dateRange.start.toIso8601String(),
      'endDate': dateRange.end.toIso8601String(),
    };

    for (final monthKey in monthKeys) {
      final monthlyDocRef = firestore.collection('users').doc(appState.activeUserId).collection('expenses').doc('fixed').collection('monthly').doc(monthKey);
      if (oldName != null && oldName != name) {
        batch.update(monthlyDocRef, {'expenses.$oldName': FieldValue.delete()});
      }
      batch.set(
          monthlyDocRef,
          {'expenses': {name: ruleData}, 'updatedAt': FieldValue.serverTimestamp()},
          SetOptions(merge: true));
    }

    // 2. Tạo các lịch thanh toán mới dựa trên loại đã chọn
    if (paymentType == 'recurring' && paymentDay != null && walletId != null) {
      DateTime cycleStartDate = dateRange.start;
      while (!cycleStartDate.isAfter(dateRange.end)) {
        DateTime nextCycleStartDate = DateTime(cycleStartDate.year, cycleStartDate.month + 1, cycleStartDate.day);
        DateTime cycleEndDate = nextCycleStartDate.subtract(const Duration(days: 1));
        //if (cycleEndDate.isAfter(dateRange.end)) break;

        final paymentMonth = cycleStartDate.month == 12 ? 1 : cycleStartDate.month + 1;
        final paymentYear = cycleStartDate.month == 12 ? cycleStartDate.year + 1 : cycleStartDate.year;
        final paymentDate = DateTime(paymentYear, paymentMonth, paymentDay);

        final scheduledPaymentRef = firestore.collection('scheduledFixedPayments').doc();
        batch.set(scheduledPaymentRef, {
          'userId': appState.activeUserId, 'expenseName': name, 'amount': amount,
          'paymentDate': Timestamp.fromDate(paymentDate), 'walletId': walletId, 'status': 'scheduled',
        });
        cycleStartDate = nextCycleStartDate;
      }
    } else if (paymentType == 'onetime' && oneTimePaymentDate != null && walletId != null) {
      final scheduledPaymentRef = firestore.collection('scheduledFixedPayments').doc();
      batch.set(scheduledPaymentRef, {
        'userId': appState.activeUserId, 'expenseName': name, 'amount': amount,
        'paymentDate': Timestamp.fromDate(oneTimePaymentDate), 'walletId': walletId, 'status': 'scheduled',
      });
    }

    await batch.commit();

    // 3. Phân bổ chi phí hàng ngày (dọn dẹp cái cũ, tạo cái mới)
    await saveOrUpdateMonthlyFixedAmount(
      appState, name, amount,
      newDateRange: dateRange,
      oldName: oldName,
      oldDateRange: oldDateRange, // <-- Truyền đúng dateRange cũ
      oldAmount: oldAmount,     // <-- Truyền đúng amount cũ
    );
  }

  static Future<void> _deleteScheduledPaymentsForRule(AppState appState, String expenseName) async {
    if (appState.activeUserId == null) return;
    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();

    // Tìm tất cả các lịch thanh toán trong tương lai của quy tắc này
    final querySnapshot = await firestore
        .collection('scheduledFixedPayments')
        .where('userId', isEqualTo: appState.activeUserId)
        .where('expenseName', isEqualTo: expenseName)
        .where('status', isEqualTo: 'scheduled')
        .get();

    // Thêm lệnh xóa cho mỗi lịch thanh toán tìm thấy
    for (final doc in querySnapshot.docs) {
      batch.delete(doc.reference);
    }

    // Thực thi xóa hàng loạt
    if (querySnapshot.docs.isNotEmpty) {
      await batch.commit();
    }
  }

// Hàm mới để xóa quy tắc chi phí cố định và các lịch thanh toán liên quan
  static Future<void> deleteFixedExpenseRule({
    required AppState appState,
    required Map<String, dynamic> ruleToDelete, // Nhận vào toàn bộ quy tắc cần xóa
  }) async {
    final String? userId = appState.activeUserId;
    if (userId == null) return;

    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();

    final String name = ruleToDelete['name'];
    final double amount = (ruleToDelete['totalAmount'] as num).toDouble();
    final dateRange = DateTimeRange(
        start: DateTime.parse(ruleToDelete['startDate']),
        end: DateTime.parse(ruleToDelete['endDate']));

    // 1. Xóa các lịch thanh toán tự động trong tương lai
    await _deleteScheduledPaymentsForRule(appState, name);

    // 2. Xóa quy tắc trong các tài liệu của từng tháng
    final monthKeys = _getMonthsInRange(dateRange);
    for (final monthKey in monthKeys) {
      final monthlyDocRef = firestore.collection('users').doc(userId).collection('expenses').doc('fixed').collection('monthly').doc(monthKey);
      // Sử dụng FieldValue.arrayRemove yêu cầu object phải khớp 100%
      // Để an toàn, chúng ta sẽ đọc, lọc và ghi đè lại (sẽ được xử lý qua listener)
      // Tạm thời dùng FieldValue.delete cho key của map
      // Lưu ý: Cần đảm bảo cấu trúc lưu là Map<String, dynamic> expenses;
      batch.update(monthlyDocRef, {'expenses.$name': FieldValue.delete()});
    }

    // 3. Xóa các phân bổ chi phí hàng ngày
    DateTime cycleStartDate = dateRange.start;
    while (!cycleStartDate.isAfter(dateRange.end)) {
      final DateTime billingCycleStart = cycleStartDate;
      final DateTime nextBillingCycleStart = DateTime(billingCycleStart.year, billingCycleStart.month + 1, billingCycleStart.day);
      final DateTime billingCycleEnd = nextBillingCycleStart.subtract(const Duration(days: 1));
      final int daysInFullCycle = billingCycleEnd.difference(billingCycleStart).inDays + 1;
      if (daysInFullCycle <= 0) break;

      DateTime overlapEnd = billingCycleEnd;
      if (overlapEnd.isAfter(dateRange.end)) {
        overlapEnd = dateRange.end;
      }

      final int daysOfOverlap = overlapEnd.difference(billingCycleStart).inDays + 1;
      if(daysOfOverlap <= 0) break;

      final double dailyAmount = amount / daysInFullCycle;
      final expenseToRemove = {'name': name, 'amount': (dailyAmount * 100).round() / 100};

      for (int i = 0; i < daysOfOverlap; i++) {
        final date = billingCycleStart.add(Duration(days: i));
        final dateKey = DateFormat('yyyy-MM-dd').format(date);
        final firestoreDocId = appState.getKey('fixedExpenseList_$dateKey');
        final dailyDocRef = firestore.collection('users').doc(userId).collection('expenses').doc('fixed').collection('daily').doc(firestoreDocId);
        batch.update(dailyDocRef, {'fixedExpenses': FieldValue.arrayRemove([expenseToRemove])});
      }

      cycleStartDate = nextBillingCycleStart;
    }

    // 4. Thực thi tất cả các lệnh xóa
    await batch.commit();
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

    final cachedData = monthlyFixedExpensesBox.get(hiveKey);
    if (cachedData != null && cachedData is List) {
      return List<Map<String, dynamic>>.from(cachedData.map((item) => Map<String, dynamic>.from(item)));
    }

    try {
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      DocumentSnapshot doc = await firestore
          .collection('users').doc(userId)
          .collection('expenses').doc('fixed')
          .collection('monthly').doc(monthKey)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        // Đọc từ trường 'products' là một List
        final rulesList = List<Map<String, dynamic>>.from(data['products'] ?? []);
        await monthlyFixedExpensesBox.put(hiveKey, rulesList);
        return rulesList;
      }
      return [];
    } catch (e) {
      print("Error loading fixed expense list: $e");
      return [];
    }
  }


  static Future<void> saveFixedExpenseList(AppState appState, List<Map<String, dynamic>> expenses, DateTime month) async {
    final String? userId = appState.activeUserId;
    if (userId == null) return;
    final String monthKey = DateFormat('yyyy-MM').format(month);
    final String hiveKey = '$userId-fixedExpenseList-$monthKey';

    if (!Hive.isBoxOpen('monthlyFixedExpensesBox')) {
      await Hive.openBox('monthlyFixedExpensesBox');
    }
    final monthlyFixedExpensesBox = Hive.box('monthlyFixedExpensesBox');

    try {
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      await firestore
          .collection('users').doc(userId)
          .collection('expenses').doc('fixed')
          .collection('monthly').doc(monthKey)
          .set({
        // Luôn lưu vào trường 'products'
        'products': expenses,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await monthlyFixedExpensesBox.put(hiveKey, expenses);
    } catch (e) {
      print("Error saving fixed expense list: $e");
      await monthlyFixedExpensesBox.put(hiveKey, expenses);
      rethrow;
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
      double newAmount, {
        required DateTimeRange newDateRange,
        String? oldName,
        DateTimeRange? oldDateRange,
        double? oldAmount,
      }) async {
    final String? userId = appState.activeUserId;
    if (userId == null) return;
    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();

    // --- BƯỚC 1: DỌN DẸP DỮ LIỆU CŨ (NẾU LÀ CHỈNH SỬA) ---
    // Logic dọn dẹp cũng được cập nhật để xóa đúng theo từng chu kỳ
    if (oldName != null && oldAmount != null && oldDateRange != null) {
      DateTime cycleStartDate = oldDateRange.start;
      while (!cycleStartDate.isAfter(oldDateRange.end)) {
        DateTime nextCycleStartDate = DateTime(cycleStartDate.year, cycleStartDate.month + 1, cycleStartDate.day);
        DateTime cycleEndDate = nextCycleStartDate.subtract(const Duration(days: 1));

        final int daysInFullCycle = cycleEndDate.difference(cycleStartDate).inDays + 1;
        if (daysInFullCycle <= 0) break;

        DateTime overlapStart = cycleStartDate;
        DateTime overlapEnd = cycleEndDate;
        if (overlapEnd.isAfter(oldDateRange.end)) {
          overlapEnd = oldDateRange.end;
        }

        final int daysOfOverlap = overlapEnd.difference(overlapStart).inDays + 1;
        if(daysOfOverlap <= 0) break;

        final double dailyAmount = oldAmount / daysInFullCycle;
        final expenseToRemove = {'name': oldName, 'amount': (dailyAmount * 100).round() / 100};

        for (int i = 0; i < daysOfOverlap; i++) {
          final date = overlapStart.add(Duration(days: i));
          final dateKey = DateFormat('yyyy-MM-dd').format(date);
          final firestoreDocId = appState.getKey('fixedExpenseList_$dateKey');
          final dailyDocRef = firestore.collection('users').doc(userId).collection('expenses').doc('fixed').collection('daily').doc(firestoreDocId);
          batch.update(dailyDocRef, {'fixedExpenses': FieldValue.arrayRemove([expenseToRemove])});
        }

        cycleStartDate = nextCycleStartDate;
      }
    }

    // --- BƯỚC 2: PHÂN BỔ DỮ LIỆU MỚI THEO TỶ LỆ ---
    DateTime cycleStartDate = newDateRange.start;
    while (!cycleStartDate.isAfter(newDateRange.end)) {
      // Xác định một chu kỳ thanh toán đầy đủ (ví dụ: 05/07 - 04/08)
      final DateTime billingCycleStart = cycleStartDate;
      final DateTime nextBillingCycleStart = DateTime(billingCycleStart.year, billingCycleStart.month + 1, billingCycleStart.day);
      final DateTime billingCycleEnd = nextBillingCycleStart.subtract(const Duration(days: 1));
      final int daysInFullCycle = billingCycleEnd.difference(billingCycleStart).inDays + 1;
      if (daysInFullCycle <= 0) break;

      // Xác định khoảng thời gian thực tế cần phân bổ (phần giao giữa chu kỳ và lựa chọn của người dùng)
      final DateTime overlapStart = billingCycleStart;
      DateTime overlapEnd = billingCycleEnd;
      if (overlapEnd.isAfter(newDateRange.end)) {
        overlapEnd = newDateRange.end;
      }

      final int daysOfOverlap = overlapEnd.difference(overlapStart).inDays + 1;
      if (daysOfOverlap <= 0) break;

      // Tính số tiền phân bổ mỗi ngày dựa trên chu kỳ đầy đủ
      final double dailyAmount = newAmount / daysInFullCycle;
      final expenseToAdd = {'name': newName, 'amount': (dailyAmount * 100).round() / 100};

      // Gán chi phí đã tính cho từng ngày trong khoảng thời gian thực tế
      for (int i = 0; i < daysOfOverlap; i++) {
        final date = overlapStart.add(Duration(days: i));
        final dateKey = DateFormat('yyyy-MM-dd').format(date);
        final firestoreDocId = appState.getKey('fixedExpenseList_$dateKey');
        final dailyDocRef = firestore.collection('users').doc(userId).collection('expenses').doc('fixed').collection('daily').doc(firestoreDocId);
        batch.set(
            dailyDocRef,
            {'fixedExpenses': FieldValue.arrayUnion([expenseToAdd])},
            SetOptions(merge: true));
      }

      // Chuyển sang chu kỳ tiếp theo
      cycleStartDate = nextBillingCycleStart;
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

}