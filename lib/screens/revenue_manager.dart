import 'package:intl/intl.dart';
import '../state/app_state.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RevenueManager {
  // Hàm này là để dropdown danh sách sản phẩm/dịch vụ trong edit_revenue_screen

  static Future<List<Map<String, dynamic>>> loadProducts(AppState appState, String category) async {
    try {
      if (appState.userId == null) return [];
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      String baseKey = category == "Doanh thu chính" ? 'mainProductList' : 'extraProductList';
      String key = appState.getKey(baseKey);
      DocumentSnapshot doc = await firestore
          .collection('users')
          .doc(appState.userId)
          .collection('products')
          .doc(key)
          .get();
      if (doc.exists && doc.data() != null) {
        return List<Map<String, dynamic>>.from(doc['products'] ?? []);
      }
      return [];
    } catch (e) {
      print('Lỗi khi tải sản phẩm: $e');
      return [];
    }
  }

  // Đây là hàm tải lại lịch sử giao dịch lấy từ Hive hoặc Firestore
  static Future<List<Map<String, dynamic>>> loadTransactionHistory(AppState appState, String category) async {
    try {
      if (appState.userId == null) return [];
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      String dateKey = DateFormat('yyyy-MM-dd').format(appState.selectedDate);
      String key = appState.getKey('transactionHistory_${category}_$dateKey');
      DocumentSnapshot doc = await firestore
          .collection('users')
          .doc(appState.userId)
          .collection('transactions')
          .doc(key)
          .get();
      if (doc.exists && doc.data() != null) {
        return List<Map<String, dynamic>>.from(doc['transactions'] ?? []);
      }
      return [];
    } catch (e) {
      print('Lỗi khi tải giao dịch: $e');
      return [];
    }
  }

  // Đây là hàm khi thêm giao dịch thì sẽ lưu vào Hive hoặc Firestore
  static Future<void> saveTransactionHistory(AppState appState, String category, List<Map<String, dynamic>> transactions) async {
    try {
      if (appState.userId == null) throw Exception('User ID không tồn tại');
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      String dateKey = DateFormat('yyyy-MM-dd').format(appState.selectedDate);
      String key = appState.getKey('transactionHistory_${category}_$dateKey');
      await firestore
          .collection('users')
          .doc(appState.userId)
          .collection('transactions')
          .doc(key)
          .set({
        'transactions': transactions,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await updateTotalRevenue(appState, category, transactions);
    } catch (e) {
      print('Lỗi khi lưu giao dịch: $e');
    }
  }

  static Future<void> updateTotalRevenue(AppState appState, String category, List<Map<String, dynamic>> transactions) async {
    try {
      if (appState.userId == null) throw Exception('User ID không tồn tại');
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      String dateKey = DateFormat('yyyy-MM-dd').format(appState.selectedDate);
      String key = appState.getKey('revenue_${category}_$dateKey');
      double total = transactions.fold(0.0, (sum, item) => sum + (item['total'] as num? ?? item['amount'] as num? ?? 0.0).toDouble());
      await firestore
          .collection('users')
          .doc(appState.userId)
          .collection('revenue')
          .doc(key)
          .set({
        'total': total,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      String mainKey = appState.getKey('revenue_Doanh thu chính_$dateKey');
      String secondaryKey = appState.getKey('revenue_Doanh thu phụ_$dateKey');
      String otherKey = appState.getKey('revenue_Doanh thu khác_$dateKey');
      DocumentSnapshot mainDoc = await firestore
          .collection('users')
          .doc(appState.userId)
          .collection('revenue')
          .doc(mainKey)
          .get();
      DocumentSnapshot secondaryDoc = await firestore
          .collection('users')
          .doc(appState.userId)
          .collection('revenue')
          .doc(secondaryKey)
          .get();
      DocumentSnapshot otherDoc = await firestore
          .collection('users')
          .doc(appState.userId)
          .collection('revenue')
          .doc(otherKey)
          .get();

      double main = mainDoc.exists ? mainDoc['total']?.toDouble() ?? 0.0 : 0.0;
      double secondary = secondaryDoc.exists ? secondaryDoc['total']?.toDouble() ?? 0.0 : 0.0;
      double other = otherDoc.exists ? otherDoc['total']?.toDouble() ?? 0.0 : 0.0;
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
      String key = appState.getKey('transactionHistory_Doanh thu khác_$dateKey');

      DocumentSnapshot doc = await firestore
          .collection('users')
          .doc(appState.userId)
          .collection('transactions')
          .doc(key)
          .get();

      if (doc.exists && doc.data() != null) {
        return List<Map<String, dynamic>>.from(doc['transactions'] ?? []);
      }
      return [];
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
      String key = appState.getKey('transactionHistory_Doanh thu khác_$dateKey');

      await firestore
          .collection('users')
          .doc(appState.userId)
          .collection('transactions')
          .doc(key)
          .set({
        'transactions': transactions,
        'updatedAt': FieldValue.serverTimestamp(),
      });

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
      String transactionKey = appState.getKey('transactionHistory_${category}_$dateKey');

      // Lấy transactions hiện tại
      DocumentSnapshot doc = await firestore
          .collection('users')
          .doc(appState.userId)
          .collection('transactions')
          .doc(transactionKey)
          .get();

      List<Map<String, dynamic>> transactions = doc.exists
          ? List<Map<String, dynamic>>.from(doc['transactions'] ?? [])
          : [];

      // Xóa giao dịch khớp (dựa trên ID hoặc các trường duy nhất)
      transactions.removeWhere((item) =>
      item['name'] == transactionToDelete['name'] &&
          item['total'] == transactionToDelete['total'] &&
          item['quantity'] == transactionToDelete['quantity']);

      // Cập nhật Firestore
      if (transactions.isEmpty) {
        // Xóa document nếu không còn giao dịch
        await firestore
            .collection('users')
            .doc(appState.userId)
            .collection('transactions')
            .doc(transactionKey)
            .delete();
        // Xóa revenue tương ứng
        await firestore
            .collection('users')
            .doc(appState.userId)
            .collection('revenue')
            .doc(appState.getKey('revenue_${category}_$dateKey'))
            .delete();
      } else {
        // Cập nhật transactions
        await firestore
            .collection('users')
            .doc(appState.userId)
            .collection('transactions')
            .doc(transactionKey)
            .set({
          'transactions': transactions,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        // Cập nhật total revenue
        await updateTotalRevenue(appState, category, transactions);
      }
    } catch (e) {
      print('Lỗi khi xóa giao dịch: $e');
      throw Exception('Không thể xóa giao dịch: $e');
    }
  }
}