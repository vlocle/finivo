import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
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
      bool needsUpdate = false;
      var uuid = Uuid();
      if (doc.exists && doc.data() != null && doc['products'] != null) {
        products = (doc['products'] as List<dynamic>).map((item) {
          var map = item as Map<dynamic, dynamic>;
          var standardizedMap = map.map((key, value) {
            return MapEntry(key.toString(), value);
          });

          if (standardizedMap['id'] == null || standardizedMap['id'].toString().isEmpty) {
            standardizedMap['id'] = uuid.v4();
            needsUpdate = true;
          }

          // Đảm bảo trường price tồn tại và là số hợp lệ
          if (standardizedMap['price'] == null || (standardizedMap['price'] is num && standardizedMap['price'] <= 0)) {
            standardizedMap['price'] = 0.0; // Hoặc báo lỗi tùy theo yêu cầu
            print('Cảnh báo: Sản phẩm ${standardizedMap['name']} có giá không hợp lệ: ${standardizedMap['price']}');
          }
          return standardizedMap;
        }).cast<Map<String, dynamic>>().toList();
      }
      if (needsUpdate) {
        await firestore
            .collection('users')
            .doc(appState.userId)
            .collection('products')
            .doc(key)
            .set({'products': products, 'updatedAt': FieldValue.serverTimestamp()});
        print('Migrated and updated product list with new IDs.');
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

  static Future<List<Map<String, dynamic>>> loadTransactions(AppState appState, String category) async {
    try {
      if (appState.userId == null) return [];
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

      // Thử tải từ Hive trước
      List<dynamic>? cachedTransactions = transactionsBox.get(hiveKey);
      if (cachedTransactions != null) {
        try {
          return cachedTransactions.map((item) {
            final map = item as Map;
            return map.map((key, value) => MapEntry(key.toString(), value));
          }).toList().cast<Map<String, dynamic>>();
        } catch (e) {
          print('Lỗi khi chuyển đổi dữ liệu giao dịch từ Hive: $e');
        }
      }

      // Nếu không có trong Hive, tải từ Firestore
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(appState.userId)
          .collection('daily_data')
          .doc(appState.getKey(dateKey))
          .get();

      List<Map<String, dynamic>> transactions = [];
      if (doc.exists && doc[field] != null) {
        transactions = (doc[field] as List<dynamic>).map((item) {
          var map = item as Map<dynamic, dynamic>;
          return map.map((key, value) => MapEntry(key.toString(), value));
        }).cast<Map<String, dynamic>>().toList();
      }

      // Lưu vào Hive
      await transactionsBox.put(hiveKey, transactions);
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
        double price = (transaction['price'] as num?)?.toDouble() ?? 0.0;
        if (price <= 0.0) {
          print('Cảnh báo: Giao dịch ${transaction['name']} có giá không hợp lệ: $price');
        }
        return {
          "id": transaction['id'],
          'name': transaction['name'].toString(),
          'price': price,
          'total': (transaction['total'] as num?)?.toDouble() ?? (transaction['amount'] as num?)?.toDouble() ?? 0.0,
          'quantity': (transaction['quantity'] as num?)?.toDouble() ?? 1.0,
          'date': transaction['date']?.toString() ?? DateTime.now().toIso8601String(),
          'unitVariableCost': (transaction['unitVariableCost'] as num?)?.toDouble() ?? 0.0,
          'totalVariableCost': (transaction['totalVariableCost'] as num?)?.toDouble() ?? 0.0,
          if (transaction.containsKey('cogsSourceType')) 'cogsSourceType': transaction['cogsSourceType'],
          if (transaction.containsKey('cogsWasFlexible')) 'cogsWasFlexible': transaction['cogsWasFlexible'],
          if (transaction.containsKey('cogsDefaultCostAtTimeOfSale')) 'cogsDefaultCostAtTimeOfSale': transaction['cogsDefaultCostAtTimeOfSale'],
          if (transaction.containsKey('cogsComponentsUsed')) 'cogsComponentsUsed': transaction['cogsComponentsUsed'],
          if (transaction.containsKey('cogsSourceType_Secondary')) 'cogsSourceType_Secondary': transaction['cogsSourceType_Secondary'],
          if (transaction.containsKey('cogsWasFlexible_Secondary')) 'cogsWasFlexible_Secondary': transaction['cogsWasFlexible_Secondary'],
          if (transaction.containsKey('cogsDefaultCostAtTimeOfSale_Secondary')) 'cogsDefaultCostAtTimeOfSale_Secondary': transaction['cogsDefaultCostAtTimeOfSale_Secondary'],
          if (transaction.containsKey('cogsComponentsUsed_Secondary')) 'cogsComponentsUsed_Secondary': transaction['cogsComponentsUsed_Secondary'],
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

      // Lưu vào Hive
      if (!Hive.isBoxOpen('transactionsBox')) {
        await Hive.openBox('transactionsBox');
      }
      var transactionsBox = Hive.box('transactionsBox');
      await transactionsBox.put(hiveKey, standardizedTransactions).catchError((e) {
        print('Lỗi khi lưu vào Hive: $e');
        throw Exception('Không thể lưu vào Hive: $e');
      });

      // Cập nhật tổng doanh thu
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
        final cachedData = transactionsBox.get(hiveKey) as List?;
        if (cachedData != null) {
          try {
            return cachedData.map((item) {
              final map = item as Map;
              return map.map((key, value) => MapEntry(key.toString(), value));
            }).toList().cast<Map<String, dynamic>>();
          } catch (e) {
            print('Lỗi khi chuyển đổi dữ liệu otherRevenue từ Hive: $e');
          }
        }
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

      // Chuẩn hóa dữ liệu trước khi lưu vào Hive
      List<Map<String, dynamic>> standardizedTransactions = transactions.map((transaction) {
        return {
          'name': transaction['name']?.toString().trim().isNotEmpty == true
              ? transaction['name'].toString()
              : transaction['description']?.toString().trim().isNotEmpty == true
              ? transaction['description'].toString()
              : 'Không xác định',
          'total': (transaction['total'] as num?)?.toDouble() ?? (transaction['amount'] as num?)?.toDouble() ?? 0.0,
          'quantity': (transaction['quantity'] as num?)?.toDouble() ?? 1.0,
        };
      }).toList();

      // Lưu vào Hive
      await transactionsBox.put(hiveKey, standardizedTransactions);
      return standardizedTransactions;
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

      // Chuẩn hóa giao dịch trước khi lưu
      List<Map<String, dynamic>> standardizedTransactions = transactions.map((transaction) {
        return {
          'name': transaction['name']?.toString().trim().isNotEmpty == true
              ? transaction['name'].toString()
              : transaction['description']?.toString().trim().isNotEmpty == true
              ? transaction['description'].toString()
              : 'Không xác định',
          'total': (transaction['total'] as num?)?.toDouble() ?? (transaction['amount'] as num?)?.toDouble() ?? 0.0,
          'quantity': (transaction['quantity'] as num?)?.toDouble() ?? 1.0,
          'date': transaction['date']?.toString() ?? DateTime.now().toIso8601String(),
        };
      }).toList();

      // Lưu vào Firestore
      await firestore
          .collection('users')
          .doc(appState.userId)
          .collection('daily_data')
          .doc(appState.getKey(dateKey))
          .set({
        'otherRevenueTransactions': standardizedTransactions,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Lưu vào Hive
      var transactionsBox = Hive.box('transactionsBox');
      await transactionsBox.put(hiveKey, standardizedTransactions);

      await updateTotalRevenue(appState, 'Doanh thu khác', standardizedTransactions);
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