import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import '../state/app_state.dart';

class RevenueManager {
  static Future<List<Map<String, dynamic>>> loadProducts(AppState appState, String category) async {
    try {
      if (appState.userId == null) return [];
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      String baseKey = category == "Doanh thu chính" ? 'mainProductList' : 'extraProductList';
      String key = appState.getKey(baseKey);
      String hiveKey = appState.getKey('${category}_productList');

      if (!Hive.isBoxOpen('productsBox')) {
        await Hive.openBox('productsBox');
      }
      var productsBox = Hive.box('productsBox');

      // Tải từ Firestore trước để đảm bảo dữ liệu mới nhất
      DocumentSnapshot doc = await firestore
          .collection('users')
          .doc(appState.userId)
          .collection('products')
          .doc(key)
          .get();

      List<Map<String, dynamic>> products = [];
      if (doc.exists && doc['products'] != null) {
        products = (doc['products'] as List<dynamic>).map((item) {
          var map = item as Map<dynamic, dynamic>;
          return map.map((key, value) {
            return MapEntry(key.toString(), value);
          });
        }).cast<Map<String, dynamic>>().toList();
      }

      // Lưu vào Hive
      await productsBox.put(hiveKey, products);
      print('Tải sản phẩm từ Firestore và lưu vào Hive: $products');
      return products;
    } catch (e) {
      print('Lỗi khi tải sản phẩm: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> loadTransactionHistory(AppState appState, String category) async {
    try {
      if (appState.userId == null) return [];
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      String dateKey = DateFormat('yyyy-MM-dd').format(appState.selectedDate);
      String field = category == 'Doanh thu chính'
          ? 'mainRevenueTransactions'
          : category == 'Doanh thu phụ'
          ? 'secondaryRevenueTransactions'
          : 'otherRevenueTransactions';
      String hiveKey = appState.getKey('${dateKey}_${field}');

      if (!Hive.isBoxOpen('transactionsBox')) {
        await Hive.openBox('transactionsBox');
      }
      var transactionsBox = Hive.box('transactionsBox');
      print('Hive transactionsBox keys: ${transactionsBox.keys}'); // Debug

      // Kiểm tra dữ liệu trong Hive
      if (transactionsBox.containsKey(hiveKey)) {
        var rawData = transactionsBox.get(hiveKey);
        print('Raw transaction data from Hive: $rawData'); // Debug
        List<Map<String, dynamic>> loadedTransactions = [];
        if (rawData != null) {
          loadedTransactions = (rawData as List<dynamic>).map((item) {
            var map = item as Map<dynamic, dynamic>;
            return map.map((key, value) {
              return MapEntry(key.toString(), value);
            });
          }).cast<Map<String, dynamic>>().toList();
        }
        print('Tải giao dịch từ Hive: $loadedTransactions');
        return loadedTransactions;
      }

      // Tải từ Firestore
      DocumentSnapshot doc = await firestore
          .collection('users')
          .doc(appState.userId)
          .collection('daily_data')
          .doc(appState.getKey(dateKey))
          .get();

      List<Map<String, dynamic>> transactions = [];
      if (doc.exists && doc[field] != null) {
        transactions = List<Map<String, dynamic>>.from(doc[field] ?? []);
      }

      // Lưu vào Hive
      await transactionsBox.put(hiveKey, transactions);
      print('Tải giao dịch từ Firestore và lưu vào Hive: $transactions');
      return transactions;
    } catch (e) {
      print('Lỗi khi tải giao dịch: $e');
      return [];
    }
  }

  static Future<void> saveTransactionHistory(AppState appState, String category, List<Map<String, dynamic>> transactions) async {
    try {
      if (appState.userId == null) throw Exception('User ID không tồn tại');
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      String dateKey = DateFormat('yyyy-MM-dd').format(appState.selectedDate);
      String field = category == 'Doanh thu chính'
          ? 'mainRevenueTransactions'
          : category == 'Doanh thu phụ'
          ? 'secondaryRevenueTransactions'
          : 'otherRevenueTransactions';
      String hiveKey = appState.getKey('${dateKey}_${field}');

      // Chuẩn hóa transactions trước khi lưu
      List<Map<String, dynamic>> standardizedTransactions = transactions.map((transaction) {
        return {
          'name': transaction['name'].toString(),
          'total': transaction['total'] as num? ?? transaction['amount'] as num? ?? 0.0,
          'quantity': transaction['quantity'] as num? ?? 1.0,
        };
      }).toList();

      // Lưu vào Firestore
      await firestore
          .collection('users')
          .doc(appState.userId)
          .collection('daily_data')
          .doc(appState.getKey(dateKey))
          .set({
        field: standardizedTransactions,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Đảm bảo box đã mở và lưu vào Hive
      if (!Hive.isBoxOpen('transactionsBox')) {
        await Hive.openBox('transactionsBox');
      }
      var transactionsBox = Hive.box('transactionsBox');
      await transactionsBox.put(hiveKey, standardizedTransactions).catchError((e) {
        print('Lỗi khi lưu vào Hive: $e');
        throw Exception('Không thể lưu vào Hive: $e');
      });

      await updateTotalRevenue(appState, category, standardizedTransactions);
    } catch (e) {
      print('Lỗi khi lưu giao dịch: $e');
    }
  }

  static Future<void> updateTotalRevenue(AppState appState, String category, List<Map<String, dynamic>> transactions) async {
    try {
      if (appState.userId == null) throw Exception('User ID không tồn tại');
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      String dateKey = DateFormat('yyyy-MM-dd').format(appState.selectedDate);
      double total = transactions.fold(0.0, (sum, item) => sum + (item['total'] as num? ?? item['amount'] as num? ?? 0.0).toDouble());
      String revenueField = category == 'Doanh thu chính'
          ? 'mainRevenue'
          : category == 'Doanh thu phụ'
          ? 'secondaryRevenue'
          : 'otherRevenue';
      double main = category == 'Doanh thu chính' ? total : appState.mainRevenue;
      double secondary = category == 'Doanh thu phụ' ? total : appState.secondaryRevenue;
      double other = category == 'Doanh thu khác' ? total : appState.otherRevenue;

      await firestore
          .collection('users')
          .doc(appState.userId)
          .collection('daily_data')
          .doc(appState.getKey(dateKey))
          .set({
        revenueField: total,
        'totalRevenue': main + secondary + other,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await appState.setRevenue(main, secondary, other);
    } catch (e) {
      print('Lỗi khi cập nhật doanh thu: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> loadOtherRevenueTransactions(AppState appState) async {
    try {
      if (appState.userId == null) {
        print('User ID không tồn tại');
        return [];
      }
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      String dateKey = DateFormat('yyyy-MM-dd').format(appState.selectedDate);
      String hiveKey = appState.getKey('${dateKey}_otherRevenueTransactions');

      var transactionsBox = Hive.box('transactionsBox');

      // Kiểm tra dữ liệu trong Hive
      if (transactionsBox.containsKey(hiveKey)) {
        return List<Map<String, dynamic>>.from(transactionsBox.get(hiveKey) ?? []);
      }

      // Tải từ Firestore
      DocumentSnapshot doc = await firestore
          .collection('users')
          .doc(appState.userId)
          .collection('daily_data')
          .doc(appState.getKey(dateKey))
          .get();
      List<Map<String, dynamic>> transactions = [];
      if (doc.exists && doc['otherRevenueTransactions'] != null) {
        transactions = List<Map<String, dynamic>>.from(doc['otherRevenueTransactions'] ?? []);
      }

      // Lưu vào Hive
      await transactionsBox.put(hiveKey, transactions);
      return transactions;
    } catch (e) {
      print('Lỗi khi tải giao dịch Doanh thu khác từ Firestore: $e');
      return [];
    }
  }

  static Future<void> saveOtherRevenueTransactions(AppState appState, List<Map<String, dynamic>> transactions) async {
    try {
      if (appState.userId == null) {
        throw Exception('User ID không tồn tại');
      }
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      String dateKey = DateFormat('yyyy-MM-dd').format(appState.selectedDate);
      String hiveKey = appState.getKey('${dateKey}_otherRevenueTransactions');

      // Lưu vào Firestore
      await firestore
          .collection('users')
          .doc(appState.userId)
          .collection('daily_data')
          .doc(appState.getKey(dateKey))
          .set({
        'otherRevenueTransactions': transactions,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Lưu vào Hive
      var transactionsBox = Hive.box('transactionsBox');
      await transactionsBox.put(hiveKey, transactions);

      await updateTotalRevenue(appState, 'Doanh thu khác', transactions);
    } catch (e) {
      print('Lỗi khi lưu giao dịch Doanh thu khác vào Firestore: $e');
      throw Exception('Không thể lưu giao dịch: $e');
    }
  }

  static Future<void> deleteTransaction(AppState appState, String category, Map<String, dynamic> transactionToDelete) async {
    try {
      if (appState.userId == null) throw Exception('User ID không tồn tại');
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      String dateKey = DateFormat('yyyy-MM-dd').format(appState.selectedDate);
      String field = category == 'Doanh thu chính'
          ? 'mainRevenueTransactions'
          : category == 'Doanh thu phụ'
          ? 'secondaryRevenueTransactions'
          : 'otherRevenueTransactions';
      String hiveKey = appState.getKey('${dateKey}_${field}');

      DocumentSnapshot doc = await firestore
          .collection('users')
          .doc(appState.userId)
          .collection('daily_data')
          .doc(appState.getKey(dateKey))
          .get();
      List<Map<String, dynamic>> transactions = doc.exists
          ? List<Map<String, dynamic>>.from(doc[field] ?? [])
          : [];

      transactions.removeWhere((item) =>
      item['name'] == transactionToDelete['name'] &&
          item['total'] == transactionToDelete['total'] &&
          item['quantity'] == transactionToDelete['quantity']);

      if (transactions.isEmpty) {
        await firestore
            .collection('users')
            .doc(appState.userId)
            .collection('daily_data')
            .doc(appState.getKey(dateKey))
            .set({
          field: [],
          category == 'Doanh thu chính' ? 'mainRevenue' : category == 'Doanh thu phụ' ? 'secondaryRevenue' : 'otherRevenue': 0.0,
          'totalRevenue': (category == 'Doanh thu chính' ? 0.0 : appState.mainRevenue) +
              (category == 'Doanh thu phụ' ? 0.0 : appState.secondaryRevenue) +
              (category == 'Doanh thu khác' ? 0.0 : appState.otherRevenue),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } else {
        await firestore
            .collection('users')
            .doc(appState.userId)
            .collection('daily_data')
            .doc(appState.getKey(dateKey))
            .set({
          field: transactions,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      // Lưu vào Hive
      var transactionsBox = Hive.box('transactionsBox');
      await transactionsBox.put(hiveKey, transactions);

      await updateTotalRevenue(appState, category, transactions);
    } catch (e) {
      print('Lỗi khi xóa giao dịch: $e');
      throw Exception('Không thể xóa giao dịch: $e');
    }
  }
}