import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart'; // [cite: 1] // Đảm bảo đường dẫn này đúng
import '/screens/revenue_manager.dart'; // [cite: 1] // Đảm bảo đường dẫn này đúng
import '/screens/expense_manager.dart'; // [cite: 1] // Đảm bảo đường dẫn này đúng
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart'; // [cite: 2]

class EditSecondaryRevenueScreen extends StatefulWidget {
  const EditSecondaryRevenueScreen({Key? key}) : super(key: key); // [cite: 541]

  @override
  _EditSecondaryRevenueScreenState createState() =>
      _EditSecondaryRevenueScreenState(); // [cite: 542]
}

class _EditSecondaryRevenueScreenState
    extends State<EditSecondaryRevenueScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController quantityController = TextEditingController(); // [cite: 543]
  final TextEditingController priceController = TextEditingController(); // Giá BÁN // [cite: 544]
  late AnimationController _animationController; // [cite: 544]
  late Animation<double> _scaleAnimation; // [cite: 545]
  late Future<List<Map<String, dynamic>>> _productsFuture; // [cite: 545]
  int _selectedTab = 0; // [cite: 546]
  late AppState _appState; // [cite: 546]
  final GlobalKey<_ProductInputSectionState> _productInputSectionKey =
  GlobalKey<_ProductInputSectionState>(); // [cite: 547]

  static const Color _primaryColor = Color(0xFF4CAF50); // [cite: 548] // Màu xanh lá cho doanh thu phụ
  static const Color _secondaryColor = Color(0xFFF1F5F9); // [cite: 549]
  static const Color _textColorPrimary = Color(0xFF1D2D3A); // [cite: 550]
  static const Color _textColorSecondary = Color(0xFF6E7A8A); // [cite: 551]
  static const Color _cardBackgroundColor = Colors.white; // [cite: 552]
  static const Color _accentColor = Colors.redAccent; // [cite: 553]
  final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'VNĐ'); // [cite: 554]

  @override
  void initState() {
    super.initState();
    quantityController.text = "1"; // [cite: 555]
    _animationController = AnimationController(
        duration: const Duration(milliseconds: 300), vsync: this); // [cite: 556]
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
        CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack)); // [cite: 557]
    _animationController.forward(); // [cite: 558]
    _appState = Provider.of<AppState>(context, listen: false); // [cite: 558]
    _productsFuture =
        RevenueManager.loadProducts(_appState, "Doanh thu phụ"); // [cite: 559]
    _appState.productsUpdated.addListener(_onProductsUpdated); // [cite: 560]
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies(); // [cite: 561]
    // _appState = Provider.of<AppState>(context, listen: false); // Không cần thiết nếu đã có ở initState và không thay đổi
  }

  @override
  void dispose() {
    quantityController.dispose(); // [cite: 563]
    priceController.dispose(); // [cite: 564]
    _animationController.dispose(); // [cite: 564]
    _appState.productsUpdated.removeListener(_onProductsUpdated); // [cite: 565]
    super.dispose(); // [cite: 565]
  }

  void _onProductsUpdated() {
    if (mounted) { // [cite: 566]
      setState(() {
        // final appState = Provider.of<AppState>(context, listen: false); // _appState đã là thành viên
        _productsFuture =
            RevenueManager.loadProducts(_appState, "Doanh thu phụ"); // [cite: 566]
      });
    }
  }

  void _showStyledSnackBar(String message, {bool isError = false}) {
    if (!mounted) return; // [cite: 567]
    ScaffoldMessenger.of(context).showSnackBar( // [cite: 568]
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins(color: Colors.white)), // [cite: 568]
        backgroundColor: isError ? _accentColor : _primaryColor, // [cite: 568]
        behavior: SnackBarBehavior.floating, // [cite: 568]
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), // [cite: 568]
        margin: const EdgeInsets.all(10), // [cite: 568]
      ),
    );
  }

  // Cập nhật hàm addTransaction tương tự như edit_main_revenue_screen
  void addTransaction(
      AppState appState,
      List<Map<String, dynamic>> salesTransactions,
      String? selectedProduct,
      double currentSelectedPriceInDropdown, // Giá bán từ dropdown
      bool isFlexiblePriceEnabled, // Giá bán có linh hoạt không
      ) {
    if (selectedProduct == null) {
      _showStyledSnackBar("Vui lòng chọn sản phẩm/dịch vụ!", isError: true); // [cite: 30, 31]
      return; // [cite: 31]
    }

    final productInputState = _productInputSectionKey.currentState; // [cite: 31]
    if (productInputState == null) {
      _showStyledSnackBar("Lỗi nội bộ: Không tìm thấy productInputState.",
          isError: true); // [cite: 32]
      return; // [cite: 32]
    }

    double priceToUse; // [cite: 33]
    if (isFlexiblePriceEnabled) {
      priceToUse = double.tryParse(priceController.text
          .replaceAll('.', '')
          .replaceAll(',', '')) ??
          0.0; // [cite: 33, 34]
      if (priceToUse <= 0.0) {
        _showStyledSnackBar("Vui lòng nhập giá trị hợp lệ cho giá bán!",
            isError: true); // [cite: 34]
        return; // [cite: 35]
      }
    } else {
      priceToUse = currentSelectedPriceInDropdown; // [cite: 36]
      if (priceToUse <= 0.0) {
        _showStyledSnackBar("Giá sản phẩm không hợp lệ trong danh mục!",
            isError: true); // [cite: 37]
        return; // [cite: 38]
      }
    }

    int quantity = int.tryParse(quantityController.text) ?? 1; // [cite: 39, 40]
    if (quantity <= 0) {
      _showStyledSnackBar("Số lượng phải lớn hơn 0!", isError: true); // [cite: 40]
      return; // [cite: 41]
    }

    // 1. Xử lý giao dịch BÁN HÀNG (Sales Transaction)
    double totalRevenueForSale = priceToUse * quantity; // [cite: 41]

    List<Map<String, dynamic>> currentUnitCostComponents =
        productInputState.currentUnitVariableCostComponents; // [cite: 42]
    double unitVariableCostForSale = 0; // [cite: 43]
    List<Map<String, dynamic>> cogsComponentsForStorage = []; // [cite: 43]

    for (var component in currentUnitCostComponents) {
      double cost = component['cost'] as double? ?? 0.0; // [cite: 43, 44]
      unitVariableCostForSale += cost; // [cite: 44]
      cogsComponentsForStorage.add({ // [cite: 44]
        'name': component['name'], // [cite: 44]
        'cost': cost, // [cite: 44]
        'originalCost': component['originalCost'] // [cite: 44]
      });
    }
    double totalUnitVariableCostForSale = unitVariableCostForSale * quantity; // [cite: 45]

    var uuid = Uuid(); // [cite: 45]
    String transactionId = uuid.v4(); // [cite: 46]
    String? cogsSourceType; // [cite: 46]
    bool cogsWasFlexible = productInputState.isUnitVariableCostFlexible; // [cite: 47]
    double cogsDefaultCostAtTimeOfSale = 0; // [cite: 47]
    bool isAnyComponentModified = false; // [cite: 48]

    for (var component in currentUnitCostComponents) {
      double currentCost = component['cost'] as double? ?? 0.0; // [cite: 49]
      double originalCost = component['originalCost'] as double? ?? 0.0; // [cite: 50]
      cogsDefaultCostAtTimeOfSale += originalCost; // [cite: 50]
      if (currentCost != originalCost) { // [cite: 51]
        isAnyComponentModified = true; // [cite: 51]
      }
    }

    List<Map<String, dynamic>>? cogsComponentsUsed =
    cogsComponentsForStorage.isNotEmpty ? cogsComponentsForStorage : null; // [cite: 52]

    if (cogsComponentsUsed != null && cogsComponentsUsed.isNotEmpty) {
      cogsSourceType = (cogsWasFlexible && isAnyComponentModified) // [cite: 53]
          ? "AUTO_COGS_COMPONENT_OVERRIDE_SECONDARY" // [cite: 54] // Phân biệt nguồn
          : "AUTO_COGS_COMPONENT_SECONDARY"; // [cite: 54]
    } else if (unitVariableCostForSale > 0) { // [cite: 55]
      cogsSourceType = "AUTO_COGS_ESTIMATED_SECONDARY"; // [cite: 55]
    }

    Map<String, dynamic> newSalesTransaction = {
      "id": transactionId, // [cite: 56]
      "name": selectedProduct, // [cite: 56]
      "price": priceToUse, // [cite: 56]
      "quantity": quantity, // [cite: 56]
      "total": totalRevenueForSale, // [cite: 56]
      "date": DateTime.now().toIso8601String(), // [cite: 56]
      "unitVariableCost": unitVariableCostForSale, // [cite: 56]
      "totalVariableCost": totalUnitVariableCostForSale, // [cite: 57]
      if (cogsSourceType != null) "cogsSourceType": cogsSourceType, // [cite: 57]
      "cogsWasFlexible": cogsWasFlexible, // [cite: 57]
      if (cogsDefaultCostAtTimeOfSale > 0 && cogsComponentsUsed != null)
        "cogsDefaultCostAtTimeOfSale": cogsDefaultCostAtTimeOfSale, // [cite: 57]
      if (cogsComponentsUsed != null && cogsComponentsUsed.isNotEmpty)
        "cogsComponentsUsed": cogsComponentsUsed, // [cite: 57]
    };
    salesTransactions.add(newSalesTransaction); // [cite: 58]
    RevenueManager.saveTransactionHistory(
        _appState, "Doanh thu phụ", salesTransactions); // [cite: 58] // Sử dụng _appState thay vì appState từ tham số
    _showStyledSnackBar("Đã thêm giao dịch (DTP): $selectedProduct"); // [cite: 59]

    // 2. TỰ ĐỘNG TẠO các bản ghi GIAO DỊCH CHI PHÍ BIẾN ĐỔI (COGS)
    List<Map<String, dynamic>> autoGeneratedExpenseTransactions = []; // [cite: 60]
    if (cogsSourceType == "AUTO_COGS_COMPONENT_SECONDARY" ||
        cogsSourceType == "AUTO_COGS_COMPONENT_OVERRIDE_SECONDARY") { // [cite: 61]
      if (cogsComponentsUsed != null) {
        for (var component in cogsComponentsUsed) { // [cite: 61]
          double componentCostForTransaction =
              (component['cost'] as double? ?? 0.0) * quantity; // [cite: 61]
          if (componentCostForTransaction > 0) { // [cite: 62]
            autoGeneratedExpenseTransactions.add({
              "name":
              "${component['name']} (Cho DTP: $selectedProduct)", // [cite: 62] // Thêm (DTP)
              "amount": componentCostForTransaction, // [cite: 62]
              "date": DateTime.now().toIso8601String(), // [cite: 62]
              "source": cogsSourceType, // [cite: 62]
              "sourceSalesTransactionId": transactionId // [cite: 63]
            });
          }
        }
      }
    } else if (cogsSourceType == "AUTO_COGS_ESTIMATED_SECONDARY") { // [cite: 64]
      if (totalUnitVariableCostForSale > 0) { // [cite: 68]
        autoGeneratedExpenseTransactions.add({
          "name":
          "Giá vốn hàng bán (DTP Ước tính): $selectedProduct", // [cite: 68] // Thêm (DTP)
          "amount": totalUnitVariableCostForSale, // [cite: 68]
          "date": DateTime.now().toIso8601String(), // [cite: 68]
          "source": cogsSourceType, // [cite: 68]
          "sourceSalesTransactionId": transactionId // [cite: 68]
        });
      }
    }
    // 3. Bỏ phần xử lý CHI PHÍ BIẾN ĐỔI CHUNG KHÁC (nhập thủ công)

    // 4. Gộp và lưu tất cả các giao dịch chi phí biến đổi
    if (autoGeneratedExpenseTransactions.isNotEmpty) { // [cite: 80] // Chỉ check autoGenerated...
      List<Map<String, dynamic>> currentDailyVariableExpenses =
      List.from(_appState.variableExpenseList.value); // [cite: 80]
      currentDailyVariableExpenses.addAll(autoGeneratedExpenseTransactions); // [cite: 81]
      _appState.variableExpenseList.value =
          List.from(currentDailyVariableExpenses); // [cite: 82]
      ExpenseManager.saveVariableExpenses(
          _appState, currentDailyVariableExpenses) // [cite: 82, 83]
          .then((_) {
        double totalVariableExpenseSum = currentDailyVariableExpenses.fold( // [cite: 84]
            0.0, (sum, item) => sum + (item['amount'] as num? ?? 0.0));
        _appState.setExpenses(
            _appState.fixedExpense, totalVariableExpenseSum); // [cite: 84]
        if (autoGeneratedExpenseTransactions.isNotEmpty) { // [cite: 84]
          _showStyledSnackBar(
              "Đã tự động ghi nhận giá vốn cho DTP: $selectedProduct"); // [cite: 84, 85]
        }
      }).catchError((e) {
        _showStyledSnackBar("Lỗi khi lưu một số chi phí biến đổi (DTP): $e",
            isError: true); // [cite: 85]
      });
    }

    // 5. Reset form
    if (mounted) { // [cite: 86]
      setState(() {
        quantityController.text = "1"; // [cite: 86]
      });
      _productInputSectionKey.currentState?.resetForm(); // [cite: 87]
    }
  }

  void removeTransaction(AppState appState,
      List<Map<String, dynamic>> transactions, int index) {
    if (index < 0 || index >= transactions.length) return; // [cite: 87]

    final transactionToRemove = transactions[index]; // [cite: 88]
    final String? salesTransactionId =
    transactionToRemove['id'] as String?; // [cite: 88, 89]
    final String removedItemName =
        transactionToRemove['name'] as String? ?? "Không rõ sản phẩm"; // [cite: 89, 90]

    List<Map<String, dynamic>> currentDailyVariableExpenses =
    List.from(appState.variableExpenseList.value); // [cite: 90]
    int initialVariableExpenseCount = currentDailyVariableExpenses.length; // [cite: 91]

    if (salesTransactionId != null) {
      currentDailyVariableExpenses.removeWhere((expense) =>
      expense['sourceSalesTransactionId'] == salesTransactionId &&
          (expense['source'] == 'AUTO_COGS_COMPONENT_SECONDARY' || // [cite: 92]
              expense['source'] == 'AUTO_COGS_ESTIMATED_SECONDARY' || // [cite: 92]
              expense['source'] ==
                  'AUTO_COGS_COMPONENT_OVERRIDE_SECONDARY')); // [cite: 92] // Thêm OVERRIDE_SECONDARY

      if (currentDailyVariableExpenses.length < initialVariableExpenseCount) { // [cite: 93]
        appState.variableExpenseList.value =
            List.from(currentDailyVariableExpenses); // [cite: 93]
        ExpenseManager.saveVariableExpenses(
            appState, currentDailyVariableExpenses) // [cite: 94, 95]
            .then((_) {
          double newTotalVariableExpense = currentDailyVariableExpenses.fold( // [cite: 95]
              0.0, (sum, item) => sum + (item['amount'] as num? ?? 0.0));
          appState.setExpenses(
              appState.fixedExpense, newTotalVariableExpense); // [cite: 95]
        }).catchError((e) {
          _showStyledSnackBar( // [cite: 95]
              "Lỗi khi cập nhật chi phí biến đổi (DTP) sau khi xóa COGS: $e", // [cite: 96]
              isError: true); // [cite: 96]
        });
      }
    } else {
      print(
          "Cảnh báo: Giao dịch doanh thu phụ này không có ID, không thể tự động xóa COGS liên quan."); // [cite: 97]
      _showStyledSnackBar( // [cite: 98]
          "Cảnh báo: Không thể tự động xóa giá vốn của giao dịch (DTP) cũ này.", // [cite: 98]
          isError: false); // [cite: 98]
    }

    transactions.removeAt(index); // [cite: 99]
    RevenueManager.saveTransactionHistory(
        appState, "Doanh thu phụ", transactions); // [cite: 99]
    _showStyledSnackBar(
        "Đã xóa (DTP): $removedItemName. Giá vốn liên quan (nếu có) cũng đã được xóa."); // [cite: 100, 101]
  }

  void editTransaction(AppState appState,
      List<Map<String, dynamic>> transactions, int index) {
    if (index < 0 || index >= transactions.length) return; // [cite: 101]

    final transactionToEdit = transactions[index]; // [cite: 102]
    final String? salesTransactionId =
    transactionToEdit['id'] as String?; // [cite: 102, 103]
    final TextEditingController editQuantityController = TextEditingController(
        text: transactionToEdit['quantity'].toString()); // [cite: 103]
    final NumberFormat internalPriceFormatter =
    NumberFormat("#,##0", "vi_VN"); // [cite: 104]

    // TextField tổng CPBĐ/ĐV sẽ bị vô hiệu hóa, cần dialog chi tiết để sửa component
    final TextEditingController editUnitVariableCostController =
    TextEditingController( // [cite: 105]
        text: internalPriceFormatter
            .format(transactionToEdit['unitVariableCost'] ?? 0.0)); // [cite: 105]

    showDialog(
      context: context, // [cite: 106]
      builder: (dialogContext) => GestureDetector( // [cite: 106]
        onTap: () => FocusScope.of(dialogContext).unfocus(), // [cite: 106]
        behavior: HitTestBehavior.opaque, // [cite: 106]
        child: AlertDialog(
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), // [cite: 106]
          title: Text("Chỉnh sửa (DTP): ${transactionToEdit['name']}", // [cite: 106]
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600, color: _textColorPrimary)), // [cite: 107]
          content: SingleChildScrollView( // [cite: 107]
            child: Column(
              mainAxisSize: MainAxisSize.min, // [cite: 107]
              children: [
                TextField( // [cite: 107, 108]
                  keyboardType: TextInputType.number, // [cite: 108]
                  controller: editQuantityController, // [cite: 108]
                  decoration: InputDecoration( // [cite: 108]
                      labelText: "Nhập số lượng mới", // [cite: 108]
                      labelStyle: GoogleFonts.poppins(
                          color: _textColorSecondary), // [cite: 109, 110]
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)), // [cite: 110]
                      filled: true, // [cite: 110]
                      fillColor: _secondaryColor, // [cite: 110]
                      prefixIcon: Icon(
                          Icons.production_quantity_limits_outlined,
                          color: _primaryColor)), // [cite: 111]
                  maxLines: 1, // [cite: 111]
                  maxLength: 5, // [cite: 111]
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly
                  ], // [cite: 111, 112]
                ),
                const SizedBox(height: 16), // [cite: 112]
                // MỚI: TextField này sẽ được thay thế bằng dialog chỉnh sửa component chi tiết sau
                TextField( // [cite: 113]
                  keyboardType:
                  TextInputType.numberWithOptions(decimal: false), // [cite: 113]
                  controller: editUnitVariableCostController, // [cite: 113]
                  enabled: false, // VÔ HIỆU HÓA // [cite: 113]
                  decoration: InputDecoration( // [cite: 113]
                      labelText:
                      "Chi phí biến đổi/ĐV mới (Tổng - Chỉ xem)", // [cite: 114]
                      labelStyle: GoogleFonts.poppins(
                          color: _textColorSecondary), // [cite: 114]
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)), // [cite: 114]
                      filled: true, // [cite: 115]
                      fillColor: Colors.grey.shade200, // [cite: 115]
                      prefixIcon: Icon(Icons.local_atm_outlined,
                          color: _primaryColor)), // [cite: 116]
                  maxLines: 1, // [cite: 116]
                  maxLength: 15, // [cite: 116]
                  inputFormatters: [ // [cite: 116]
                    FilteringTextInputFormatter.digitsOnly, // [cite: 117]
                    TextInputFormatter.withFunction((oldValue, newValue) { // [cite: 117]
                      if (newValue.text.isEmpty)
                        return newValue.copyWith(text: '0'); // [cite: 118]
                      final String plainNumberText = newValue.text
                          .replaceAll('.', '')
                          .replaceAll(',', ''); // [cite: 118]
                      final number = int.tryParse(plainNumberText); // [cite: 118]
                      if (number == null) return oldValue; // [cite: 119]
                      final formattedText =
                      internalPriceFormatter.format(number); // [cite: 119]
                      return newValue.copyWith( // [cite: 119]
                        text: formattedText, // [cite: 119]
                        selection: TextSelection.collapsed(
                            offset: formattedText.length), // [cite: 120]
                      );
                    }),
                  ],
                ),
              ],
            ),
          ),
          actionsPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 10), // [cite: 121]
          actions: [ // [cite: 121]
            TextButton( // [cite: 121]
              onPressed: () => Navigator.pop(dialogContext), // [cite: 121, 122]
              child: Text("Hủy", // [cite: 122]
                  style: GoogleFonts.poppins(
                      color: _textColorSecondary,
                      fontWeight: FontWeight.w500)), // [cite: 122]
            ),
            ElevatedButton( // [cite: 122]
              style: ElevatedButton.styleFrom( // [cite: 122]
                backgroundColor: _primaryColor, // [cite: 123]
                foregroundColor: Colors.white, // [cite: 123]
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)), // [cite: 123]
                padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 10), // [cite: 123]
              ),
              onPressed: () {
                int newQuantity = int.tryParse(editQuantityController.text) ??
                    (transactionToEdit['quantity'] as int? ?? 1); // [cite: 124]
                if (newQuantity <= 0) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar( // [cite: 124]
                    SnackBar(
                        content: Text("Số lượng phải lớn hơn 0",
                            style: GoogleFonts.poppins(
                                color: Colors.white)), // [cite: 125, 126]
                        backgroundColor: _accentColor, // [cite: 126]
                        behavior: SnackBarBehavior.floating), // [cite: 126]
                  );
                  return; // [cite: 127]
                }

                // newUnitVariableCost sẽ được lấy từ dialog chỉnh sửa component chi tiết sau.
                // Tạm thời, nó vẫn là tổng, nhưng không cho sửa trực tiếp.
                // Logic cập nhật COGS sẽ dựa trên components gốc nếu có.
                double newUnitVariableCost = double.tryParse( // [cite: 127, 128]
                    editUnitVariableCostController.text
                        .replaceAll('.', '')
                        .replaceAll(',', '')) ??
                    (transactionToEdit['unitVariableCost'] as double? ??
                        0.0); // [cite: 128, 129]

                // Giả sử bạn có updatedCogsComponents từ dialog sau này
                List<Map<String, dynamic>> updatedCogsComponents = // [cite: 130]
                List<Map<String, dynamic>>.from(
                    transactionToEdit['cogsComponentsUsed'] ?? []); // [cite: 130]

                if (newUnitVariableCost < 0) { // [cite: 131]
                  ScaffoldMessenger.of(dialogContext).showSnackBar( // [cite: 131, 132]
                    SnackBar(
                        content: Text("Chi phí biến đổi/ĐV không hợp lệ",
                            style: GoogleFonts.poppins(
                                color: Colors.white)), // [cite: 132]
                        backgroundColor: _accentColor, // [cite: 132]
                        behavior: SnackBarBehavior.floating), // [cite: 133]
                  );
                  return; // [cite: 134]
                }

                List<Map<String, dynamic>> currentDailyVariableExpenses =
                List.from(appState.variableExpenseList.value); // [cite: 134]

                if (salesTransactionId != null) {
                  currentDailyVariableExpenses.removeWhere((expense) => // [cite: 135]
                  expense['sourceSalesTransactionId'] ==
                      salesTransactionId &&
                      (expense['source'] ==
                          'AUTO_COGS_COMPONENT_SECONDARY' || // [cite: 136]
                          expense['source'] ==
                              'AUTO_COGS_ESTIMATED_SECONDARY' || // [cite: 136]
                          expense['source'] ==
                              'AUTO_COGS_COMPONENT_OVERRIDE_SECONDARY')); // [cite: 136]
                } else {
                  print(
                      "Cảnh báo: Giao dịch doanh thu phụ này không có ID, không thể tự động cập nhật COGS liên quan."); // [cite: 137]
                }

                double price =
                (transactionToEdit['price'] as num? ?? 0.0).toDouble(); // [cite: 138]
                transactionToEdit['quantity'] = newQuantity; // [cite: 139]
                transactionToEdit['total'] = price * newQuantity; // [cite: 140]

                // newUnitVariableCost và các thành phần COGS sẽ được cập nhật phức tạp hơn khi có dialog sửa chi tiết.
                // Tạm thời, nếu người dùng có thể sửa tổng (dù hiện tại đang disable), thì nó sẽ được dùng.
                // Nếu không, unitVariableCost sẽ được tính lại từ component (nếu có) hoặc giữ nguyên.
                // Hiện tại, newUnitVariableCost lấy từ TextField (dù disabled), nên nếu TextField đó
                // được cập nhật bởi logic tính lại từ component (trong tương lai), thì nó sẽ đúng.

                // Giả định: Nếu có dialog sửa component, newUnitVariableCost sẽ là tổng của các component đã sửa.
                // transactionToEdit['unitVariableCost'] = newUnitVariableCost; // Sẽ cập nhật lại ở dưới nếu có component
                // transactionToEdit['totalVariableCost'] = newUnitVariableCost * newQuantity;

                List<Map<String, dynamic>> newAutoGeneratedCogs = []; // [cite: 143]
                if (salesTransactionId != null) { // [cite: 144]
                  String originalTransactionDate =
                      transactionToEdit['date'] as String? ??
                          DateTime.now().toIso8601String(); // [cite: 144, 145]
                  String productName = transactionToEdit['name'] as String? ??
                      "Không rõ sản phẩm"; // [cite: 145, 146]

                  // Logic tái tạo COGS dựa trên thông tin đã lưu và các thay đổi
                  // Đây là phần cần logic phức tạp từ dialog sửa component sau này.
                  // Tạm thời, nếu có component gốc, ta sẽ dùng nó để tính toán lại.
                  // Nếu không, và newUnitVariableCost (từ TextField disabled) > 0, tạo COGS override.

                  List<dynamic>? rawOriginalCogsComponents =
                  transactionToEdit['cogsComponentsUsed']
                  as List<dynamic>?; // [cite: 151]
                  List<Map<String, dynamic>>? originalCogsComponents = // [cite: 151, 152]
                  rawOriginalCogsComponents
                      ?.map((item) =>
                  Map<String, dynamic>.from(item as Map)) // [cite: 152]
                      .toList(); // [cite: 152]

                  bool wasFlexibleInEdit =
                      transactionToEdit['cogsWasFlexible'] ?? false; // [cite: 146, 147]
                  // componentsWereModifiedInEdit sẽ true nếu dialog cho phép sửa và người dùng đã sửa component.
                  // Tạm thời, nếu newUnitVariableCost (từ textfield) khác với tổng originalCost từ component, coi như modified.
                  bool componentsWereModifiedInEdit = false; // [cite: 147]

                  double calculatedOriginalTotalComponentCost = 0;
                  if (originalCogsComponents != null) {
                    for (var comp in originalCogsComponents) {
                      calculatedOriginalTotalComponentCost +=
                          (comp['cost'] as num? ?? 0.0).toDouble();
                    }
                  }
                  if (newUnitVariableCost != calculatedOriginalTotalComponentCost && originalCogsComponents != null && originalCogsComponents.isNotEmpty) {
                    // Điều này ngụ ý là tổng đã bị ghi đè, hoặc từng component đã bị sửa (cần dialog để biết rõ)
                    // Hiện tại, chúng ta không có dialog sửa component, nên nếu newUnitVariableCost khác,
                    // và có component gốc, ta vẫn ưu tiên tạo COGS override cho tổng.
                    // Tuy nhiên, theo logic của main_revenue, nếu có component, nó sẽ cố gắng tạo lại từ component.
                    // Vì editUnitVariableCostController bị disabled, giá trị của nó sẽ là giá trị gốc.
                    // Trừ khi có dialog sửa component, thì newUnitVariableCost mới thực sự thay đổi.
                    // Do đó, componentsWereModifiedInEdit tạm thời sẽ là false.
                  }


                  String? newCogsSourceType; // [cite: 148, 149]
                  List<Map<String, dynamic>> finalCogsComponentsToUse = updatedCogsComponents; // Nên là component đã được sửa từ dialog [cite: 149]

                  if (finalCogsComponentsToUse.isNotEmpty) { // [cite: 153]
                    // Giả sử componentsWereModifiedInEdit được xác định đúng từ dialog
                    newCogsSourceType = (wasFlexibleInEdit &&
                        componentsWereModifiedInEdit) // [cite: 154]
                        ? "AUTO_COGS_COMPONENT_OVERRIDE_SECONDARY" // [cite: 154, 155]
                        : "AUTO_COGS_COMPONENT_SECONDARY"; // [cite: 155]
                  } else if (newUnitVariableCost > 0) {
                    // Nếu không có component mà sửa tổng (hoặc không có component ban đầu nhưng có CPBĐ)
                    newCogsSourceType = "AUTO_COGS_OVERRIDE_SECONDARY"; // [cite: 156]
                  }
                  transactionToEdit['cogsSourceType'] = newCogsSourceType; // [cite: 157]
                  transactionToEdit['cogsComponentsUsed'] =
                  finalCogsComponentsToUse.isNotEmpty
                      ? finalCogsComponentsToUse
                      : null; // [cite: 158]
                  // transactionToEdit['cogsWasFlexible'] = wasFlexibleInEdit; // Cần cập nhật nếu dialog cho sửa cờ này

                  double totalNewCalculatedVariableCostForSale = 0; // [cite: 159]
                  if (newCogsSourceType == "AUTO_COGS_COMPONENT_SECONDARY" ||
                      newCogsSourceType ==
                          "AUTO_COGS_COMPONENT_OVERRIDE_SECONDARY") { // [cite: 159]
                    if (finalCogsComponentsToUse.isNotEmpty) {
                      for (var component in finalCogsComponentsToUse) { // [cite: 160]
                        // Giả sử component['cost'] là chi phí / đơn vị sản phẩm đã được cập nhật từ dialog
                        double componentCostPerUnit =
                        (component['cost'] as num? ?? 0.0)
                            .toDouble(); // [cite: 160]
                        double newComponentAmount =
                            componentCostPerUnit * newQuantity; // [cite: 161]
                        if (newComponentAmount > 0) { // [cite: 161]
                          newAutoGeneratedCogs.add({ // [cite: 161]
                            "name":
                            "${component['name']} (Cho DTP: $productName)", // [cite: 161]
                            "amount": newComponentAmount, // [cite: 162]
                            "date": originalTransactionDate, // [cite: 162]
                            "source": newCogsSourceType, // [cite: 162]
                            "sourceSalesTransactionId": salesTransactionId // [cite: 163]
                          });
                          totalNewCalculatedVariableCostForSale +=
                              newComponentAmount; // [cite: 164]
                        }
                      }
                      // Cập nhật lại CPBĐ của giao dịch chính nếu nó được tính lại từ component
                      if (newQuantity > 0 &&
                          finalCogsComponentsToUse.isNotEmpty) { // [cite: 165]
                        transactionToEdit['unitVariableCost'] =
                            totalNewCalculatedVariableCostForSale /
                                newQuantity; // [cite: 165]
                        transactionToEdit['totalVariableCost'] =
                            totalNewCalculatedVariableCostForSale; // [cite: 166]
                      } else { // Nếu không có component nào có giá trị, nhưng trước đó có thể có newUnitVariableCost
                        transactionToEdit['unitVariableCost'] = newUnitVariableCost;
                        transactionToEdit['totalVariableCost'] = newUnitVariableCost * newQuantity;
                      }
                    } else { // Không có component để dùng, nhưng cogsSourceType lại là component? -> dùng newUnitVariableCost
                      transactionToEdit['unitVariableCost'] = newUnitVariableCost;
                      transactionToEdit['totalVariableCost'] = newUnitVariableCost * newQuantity;
                      totalNewCalculatedVariableCostForSale = newUnitVariableCost * newQuantity;
                      if (totalNewCalculatedVariableCostForSale > 0 && newCogsSourceType != null) { // Chuyển source nếu không có component
                        newCogsSourceType = "AUTO_COGS_OVERRIDE_SECONDARY";
                        transactionToEdit['cogsSourceType'] = newCogsSourceType;
                        newAutoGeneratedCogs.add({
                          "name": "Giá vốn hàng bán (DTP): $productName",
                          "amount": totalNewCalculatedVariableCostForSale,
                          "date": originalTransactionDate,
                          "source": newCogsSourceType,
                          "sourceSalesTransactionId": salesTransactionId
                        });
                      }
                    }
                  } else if (newCogsSourceType ==
                      "AUTO_COGS_OVERRIDE_SECONDARY" ||
                      newCogsSourceType == "AUTO_COGS_ESTIMATED_SECONDARY") { // [cite: 167]
                    // Nếu người dùng sửa tổng CPBĐ/ĐV (qua dialog trong tương lai) hoặc là COGS ước tính
                    transactionToEdit['unitVariableCost'] = newUnitVariableCost;
                    transactionToEdit['totalVariableCost'] = newUnitVariableCost * newQuantity;
                    totalNewCalculatedVariableCostForSale =
                        newUnitVariableCost * newQuantity; // [cite: 168]
                    if (totalNewCalculatedVariableCostForSale > 0) { // [cite: 169]
                      newAutoGeneratedCogs.add({ // [cite: 169]
                        "name": "Giá vốn hàng bán (DTP): $productName", // [cite: 169]
                        "amount": totalNewCalculatedVariableCostForSale, // [cite: 170]
                        "date": originalTransactionDate, // [cite: 170]
                        "source": newCogsSourceType, // [cite: 170]
                        "sourceSalesTransactionId": salesTransactionId // [cite: 170]
                      });
                    }
                  } else { // Trường hợp không có cogsSourceType (CPBĐ = 0 và không có component)
                    transactionToEdit['unitVariableCost'] = 0.0;
                    transactionToEdit['totalVariableCost'] = 0.0;
                  }
                } else { // Không có salesTransactionId
                  transactionToEdit['unitVariableCost'] = newUnitVariableCost;
                  transactionToEdit['totalVariableCost'] = newUnitVariableCost * newQuantity;
                }


                currentDailyVariableExpenses.addAll(newAutoGeneratedCogs); // [cite: 172]
                appState.variableExpenseList.value =
                    List.from(currentDailyVariableExpenses); // [cite: 173]
                ExpenseManager.saveVariableExpenses( // [cite: 174, 175]
                    appState, currentDailyVariableExpenses)
                    .then((_) {
                  double newTotalVariableExpense =
                  currentDailyVariableExpenses.fold(0.0, // [cite: 175]
                          (sum, item) =>
                      sum + (item['amount'] as num? ?? 0.0));
                  appState.setExpenses(
                      appState.fixedExpense, newTotalVariableExpense); // [cite: 175]
                }).catchError((e) {
                  _showStyledSnackBar( // [cite: 176]
                      "Lỗi khi cập nhật chi phí biến đổi tự động (DTP): $e", // [cite: 176]
                      isError: true); // [cite: 176]
                });

                RevenueManager.saveTransactionHistory( // [cite: 177]
                    appState, "Doanh thu phụ", transactions);
                Navigator.pop(dialogContext); // [cite: 178, 179]
                _showStyledSnackBar(
                    "Đã cập nhật (DTP): ${transactionToEdit['name']}. Giá vốn tự động đã được điều chỉnh."); // [cite: 179]
              },
              child: Text("Lưu", style: GoogleFonts.poppins()), // [cite: 180]
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(String title, int tabIndex, bool isFirst, bool isLast) {
    bool isSelected = _selectedTab == tabIndex; // [cite: 181]
    return Expanded( // [cite: 182]
      child: GestureDetector( // [cite: 182]
        onTap: () {
          if (mounted) setState(() => _selectedTab = tabIndex); // [cite: 182]
          _animationController.reset(); // [cite: 182]
          _animationController.forward(); // [cite: 182]
        },
        child: Container( // [cite: 182]
          padding: const EdgeInsets.symmetric(vertical: 14), // [cite: 183]
          decoration: BoxDecoration( // [cite: 183]
            color: isSelected ? _cardBackgroundColor : _primaryColor, // [cite: 183]
            borderRadius: BorderRadius.only( // [cite: 183]
              topLeft: isFirst ? const Radius.circular(12) : Radius.zero, // [cite: 183]
              bottomLeft: isFirst ? const Radius.circular(12) : Radius.zero, // [cite: 184]
              topRight: isLast ? const Radius.circular(12) : Radius.zero, // [cite: 184]
              bottomRight: // [cite: 184]
              isLast ? const Radius.circular(12) : Radius.zero, // [cite: 184]
            ),
            border: isSelected
                ? Border.all(color: _primaryColor, width: 0.5) // [cite: 185]
                : null, // [cite: 185]
            boxShadow: isSelected // [cite: 185]
                ? [
              BoxShadow( // [cite: 186]
                  color: Colors.green.withOpacity(0.1), // [cite: 186] // Thay màu shadow
                  spreadRadius: 1, // [cite: 186]
                  blurRadius: 5, // [cite: 186]
                  offset: Offset(0, 2)) // [cite: 187]
            ]
                : [], // [cite: 187]
          ),
          child: Text( // [cite: 187]
            title, // [cite: 187]
            textAlign: TextAlign.center, // [cite: 187]
            style: GoogleFonts.poppins( // [cite: 188]
              fontSize: 15.5, // [cite: 188]
              color: isSelected // [cite: 188]
                  ? _primaryColor // [cite: 188]
                  : Colors.white.withOpacity(0.9), // [cite: 188]
              fontWeight: FontWeight.w600, // [cite: 189]
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context); // [cite: 190] // appState này sẽ được dùng trong onAddTransaction

    return GestureDetector( // [cite: 191]
      onTap: () => FocusScope.of(context).unfocus(), // [cite: 191]
      behavior: HitTestBehavior.opaque, // [cite: 191]
      child: Scaffold( // [cite: 191]
        backgroundColor: _secondaryColor, // [cite: 191]
        appBar: AppBar( // [cite: 191]
          backgroundColor: _primaryColor, // [cite: 191]
          elevation: 1, // [cite: 191]
          leading: IconButton( // [cite: 192]
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white), // [cite: 192]
            onPressed: () => Navigator.pop(context), // [cite: 192]
          ),
          title: Text( // [cite: 192]
            "Doanh thu phụ", // [cite: 192]
            style: GoogleFonts.poppins( // [cite: 193]
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.white),
          ),
          centerTitle: true, // [cite: 193]
          bottom: PreferredSize( // [cite: 193]
            preferredSize: const Size.fromHeight(50), // [cite: 193]
            child: Padding( // [cite: 194]
              padding:
              const EdgeInsets.symmetric(horizontal: 12.0, vertical: 5.0), // [cite: 194]
              child: Container( // [cite: 194]
                decoration: BoxDecoration( // [cite: 194]
                  color: _primaryColor, // [cite: 195]
                  borderRadius: BorderRadius.circular(12), // [cite: 195]
                ),
                child: Row( // [cite: 195]
                  children: [ // [cite: 195]
                    _buildTab("Thêm giao dịch", 0, true, false), // [cite: 196]
                    _buildTab("Lịch sử", 1, false, true), // [cite: 196]
                  ],
                ),
              ),
            ),
          ),
        ),
        body: FutureBuilder<List<Map<String, dynamic>>>( // [cite: 197]
          future: _productsFuture, // [cite: 197]
          builder: (context, snapshot) { // [cite: 197]
            if (snapshot.connectionState == ConnectionState.waiting) { // [cite: 197]
              return Center(
                  child: CircularProgressIndicator(color: _primaryColor)); // [cite: 198]
            }
            if (snapshot.hasError) { // [cite: 199]
              return Center( // [cite: 199]
                  child: Text("Lỗi tải dữ liệu sản phẩm (DTP)", // [cite: 199]
                      style: GoogleFonts.poppins(
                          color: _textColorSecondary))); // [cite: 199, 200]
            }
            List<Map<String, dynamic>> productList = snapshot.data ?? []; // [cite: 200, 201]

            return ScaleTransition( // [cite: 201]
                scale: _scaleAnimation, // [cite: 201]
                child: IndexedStack( // [cite: 201]
                  index: _selectedTab, // [cite: 201]
                  children: [ // [cite: 202]
                    ProductInputSection( // [cite: 202]
                      key: _productInputSectionKey, // [cite: 202]
                      productList: productList, // [cite: 202]
                      quantityController: quantityController, // [cite: 203]
                      priceController: priceController, // [cite: 203]
                      onAddTransaction: (selectedProduct, selectedPrice,
                          isFlexiblePrice) { // [cite: 203]
                        addTransaction( // [cite: 204]
                            appState, //Sử dụng appState từ scope của _EditSecondaryRevenueScreenState
                            appState.secondaryRevenueTransactions.value, // [cite: 205] // Danh sách cho DTP
                            selectedProduct, // [cite: 205]
                            selectedPrice, // [cite: 205]
                            isFlexiblePrice // [cite: 206]
                        );
                      },
                      appState: appState, // [cite: 211]
                      currencyFormat: currencyFormat, // [cite: 211]
                      // Truyền màu primary của màn hình này cho ProductInputSection
                      screenPrimaryColor: _primaryColor,
                    ),
                    TransactionHistorySection( // [cite: 211]
                      key: const ValueKey('transactionHistorySecondary'), // [cite: 212] // Key khác biệt
                      transactionsNotifier:
                      appState.secondaryRevenueTransactions, // [cite: 212] // Danh sách cho DTP
                      onEditTransaction: editTransaction, // [cite: 212]
                      onRemoveTransaction: removeTransaction, // [cite: 212]
                      appState: appState, // [cite: 213]
                      currencyFormat: currencyFormat, // [cite: 213]
                      primaryColor: _primaryColor, // [cite: 213]
                      textColorPrimary: _textColorPrimary, // [cite: 214]
                      textColorSecondary: _textColorSecondary, // [cite: 214]
                      cardBackgroundColor: _cardBackgroundColor, // [cite: 214]
                    ),
                  ],
                ));
          },
        ),
      ),
    );
  }
}

// ProductInputSection được cập nhật để hoạt động tương tự như trong EditMainRevenueScreen
class ProductInputSection extends StatefulWidget {
  final List<Map<String, dynamic>> productList; // [cite: 217]
  final TextEditingController quantityController; // [cite: 217]
  final TextEditingController priceController; // [cite: 218]
  final Function(String?, double, bool) onAddTransaction; // [cite: 218]
  final AppState appState; // [cite: 219]
  final NumberFormat currencyFormat; // [cite: 219]
  final Color screenPrimaryColor; // Thêm màu từ màn hình cha

  const ProductInputSection({
    Key? key, // [cite: 220]
    required this.productList, // [cite: 220]
    required this.quantityController, // [cite: 220]
    required this.priceController, // [cite: 220]
    required this.onAddTransaction, // [cite: 220]
    required this.appState, // [cite: 220]
    required this.currencyFormat, // [cite: 220]
    required this.screenPrimaryColor,
  }) : super(key: key); // [cite: 220]

  @override
  _ProductInputSectionState createState() => _ProductInputSectionState(); // [cite: 221]
}

class _ProductInputSectionState extends State<ProductInputSection> {
  String? selectedProductId; // << SỬA LẠI TỪ selectedProduct

  double selectedPriceFromDropdown = 0.0;
  bool isFlexiblePriceEnabled = false;
  final FocusNode _priceFocusNode = FocusNode();
  final NumberFormat _priceInputFormatter = NumberFormat("#,##0", "vi_VN");
  final TextEditingController unitVariableCostController = TextEditingController();
  bool isFlexibleUnitVariableCostEnabled = false;
  List<Map<String, dynamic>> _currentUnitVariableCostComponents = [];
  List<Map<String, dynamic>> _lastLoadedCogsComponentsForProduct = [];

  List<Map<String, dynamic>> get currentUnitVariableCostComponents =>
      _currentUnitVariableCostComponents;
  bool get isUnitVariableCostFlexible => isFlexibleUnitVariableCostEnabled;
  List<Map<String, dynamic>> get originalUnitVariableCostComponents =>
      _lastLoadedCogsComponentsForProduct;

  @override
  void initState() {
    super.initState();
    widget.priceController.text = _priceInputFormatter.format(0);
    widget.priceController.addListener(_onPriceOrQuantityChanged);
    widget.quantityController.addListener(_onPriceOrQuantityChanged);
    unitVariableCostController.text = _priceInputFormatter.format(0);
  }

  @override
  void dispose() {
    widget.priceController.removeListener(_onPriceOrQuantityChanged);
    _priceFocusNode.dispose();
    for (var component in _currentUnitVariableCostComponents) {
      (component['controller'] as TextEditingController?)?.dispose();
      (component['focusNode'] as FocusNode?)?.dispose();
    }
    unitVariableCostController.dispose();
    widget.quantityController.removeListener(_onPriceOrQuantityChanged);
    super.dispose();
  }

  void _onPriceOrQuantityChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _updatePriceControllerBasedOnSelection(String? productId) {
    if (!isFlexiblePriceEnabled && productId != null) {
      final product = widget.productList.firstWhere(
        // Sửa logic tìm kiếm theo ID
              (p) => p["id"] == productId,
          orElse: () => {"price": 0.0});
      selectedPriceFromDropdown = (product["price"] as num? ?? 0.0).toDouble();
      widget.priceController.text =
          _priceInputFormatter.format(selectedPriceFromDropdown);
    } else if (!isFlexiblePriceEnabled && productId == null) {
      selectedPriceFromDropdown = 0.0;
      widget.priceController.text = _priceInputFormatter.format(0);
    }
  }

  // Hàm load và khởi tạo các thành phần CPBĐ/ĐV cho sản phẩm (Tương tự Main)
  Future<void> _loadProductVariableCostComponents(String? productId) async {
    for (var component in _currentUnitVariableCostComponents) {
      (component['controller'] as TextEditingController?)?.dispose();
      (component['focusNode'] as FocusNode?)?.dispose();
    }
    _currentUnitVariableCostComponents = [];
    _lastLoadedCogsComponentsForProduct = [];

    if (productId == null) {
      if (mounted) {
        setState(() {
          _recalculateTotalUnitVariableCost();
        });
      }
      return;
    }

    try {
      List<Map<String, dynamic>> allAvailableExpenses =
      await ExpenseManager.loadAvailableVariableExpenses(widget.appState);

      // Sửa logic lọc theo linkedProductId
      List<Map<String, dynamic>> productSpecificComponents = allAvailableExpenses
          .where((expense) => expense['linkedProductId'] == productId)
          .toList();

      for (var expenseComponent in productSpecificComponents) {
        String name = expenseComponent['name']?.toString() ?? 'Không rõ';
        double cost = (expenseComponent['price'] as num? ?? 0.0).toDouble();
        var controller =
        TextEditingController(text: _priceInputFormatter.format(cost));
        var focusNode = FocusNode();

        controller.addListener(() {
          if (isFlexibleUnitVariableCostEnabled && mounted) {
            final componentData = _currentUnitVariableCostComponents.firstWhere(
                  (c) => c['controller'] == controller,
              orElse: () => {},
            );
            if (componentData.isNotEmpty) {
              double newCost = double.tryParse(controller.text
                  .replaceAll('.', '')
                  .replaceAll(',', '')) ??
                  0.0;
              if ((componentData['cost'] as double? ?? 0.0) != newCost) {
                setState(() {
                  componentData['cost'] = newCost;
                  _recalculateTotalUnitVariableCost();
                });
              }
            }
          }
        });

        _currentUnitVariableCostComponents.add({
          'name': name,
          'originalCost': cost,
          'cost': cost,
          'controller': controller,
          'focusNode': focusNode,
        });
        _lastLoadedCogsComponentsForProduct.add({
          'name': name,
          'originalCost': cost,
        });
      }

      if (mounted) {
        setState(() {
          _recalculateTotalUnitVariableCost();
          if (!isFlexibleUnitVariableCostEnabled) {
            for (var component in _currentUnitVariableCostComponents) {
              (component['controller'] as TextEditingController).text =
                  _priceInputFormatter.format(component['originalCost']);
              component['cost'] = component['originalCost'];
            }
            _recalculateTotalUnitVariableCost();
          }
        });
      }
    } catch (e) {
      print("Error loading/processing product variable cost components: $e");
      if (mounted) {
        _showStyledSnackBar("Lỗi tải thành phần CPBĐ cho sản phẩm: $e",
            isError: true);
        setState(() {
          _currentUnitVariableCostComponents = [];
          _lastLoadedCogsComponentsForProduct = [];
          _recalculateTotalUnitVariableCost();
        });
      }
    }
  }

  // Hàm tính toán và cập nhật TextField tổng CPBĐ/ĐV (Tương tự Main)
  void _recalculateTotalUnitVariableCost() {
    double totalCost = 0;
    for (var component in _currentUnitVariableCostComponents) {
      totalCost += (component['cost'] as double? ?? 0.0);
    }
    if (mounted) {
      unitVariableCostController.text = _priceInputFormatter.format(totalCost);
      setState(() {});
    }
  }

  void resetForm() {
    setState(() {
      selectedProductId = null; // Sửa ở đây
      isFlexiblePriceEnabled = false;
      selectedPriceFromDropdown = 0.0;
      widget.priceController.text = _priceInputFormatter.format(0);
      if (_priceFocusNode.hasFocus) _priceFocusNode.unfocus();

      isFlexibleUnitVariableCostEnabled = false;
      for (var component in _currentUnitVariableCostComponents) {
        (component['controller'] as TextEditingController?)?.dispose();
        (component['focusNode'] as FocusNode?)?.dispose();
      }
      _currentUnitVariableCostComponents = [];
      _lastLoadedCogsComponentsForProduct = [];
      unitVariableCostController.text = _priceInputFormatter.format(0);
    });
  }

  void _showStyledSnackBar(String message, {bool isError = false}) {
    if (!mounted) return; // [cite: 283]
    ScaffoldMessenger.of(context).showSnackBar( // [cite: 284]
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins(color: Colors.white)), // [cite: 284]
        backgroundColor: isError
            ? _EditSecondaryRevenueScreenState._accentColor
            : _EditSecondaryRevenueScreenState._primaryColor, // [cite: 284] // Sử dụng màu của màn hình cha
        behavior: SnackBarBehavior.floating, // [cite: 284]
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)), // [cite: 284, 285]
        margin: const EdgeInsets.all(10), // [cite: 285]
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width; // [cite: 286]
    // Sử dụng màu từ widget cha (EditSecondaryRevenueScreen)
    final Color primaryColor = widget.screenPrimaryColor; // [cite: 287]
    final Color secondaryColor =
        _EditSecondaryRevenueScreenState._secondaryColor; // [cite: 288]
    final Color textColorPrimary =
        _EditSecondaryRevenueScreenState._textColorPrimary; // [cite: 289]
    final Color textColorSecondary =
        _EditSecondaryRevenueScreenState._textColorSecondary; // [cite: 290]
    final Color cardBackgroundColor =
        _EditSecondaryRevenueScreenState._cardBackgroundColor; // [cite: 291]

    double currentSellingPrice; // [cite: 292]
    if (isFlexiblePriceEnabled) { // [cite: 292]
      currentSellingPrice = double.tryParse(widget.priceController.text
          .replaceAll('.', '')
          .replaceAll(',', '')) ??
          0.0; // [cite: 292, 293]
    } else {
      currentSellingPrice = selectedPriceFromDropdown; // [cite: 294]
    }
    final int currentQuantity =
        int.tryParse(widget.quantityController.text) ?? 1; // [cite: 295, 296]
    final double estimatedTotalRevenue =
        currentSellingPrice * currentQuantity; // [cite: 296]

    final double currentUnitVarCost = double.tryParse( // [cite: 297, 298]
        unitVariableCostController.text
            .replaceAll('.', '')
            .replaceAll(',', '')) ??
        0.0; // [cite: 298]
    final double estimatedTotalVarCost =
        currentUnitVarCost * currentQuantity; // [cite: 299]
    final double estimatedGrossProfit =
        estimatedTotalRevenue - estimatedTotalVarCost; // [cite: 300]

    return SingleChildScrollView( // [cite: 301]
      padding: const EdgeInsets.all(16.0), // [cite: 301]
      child: Column( // [cite: 301]
        crossAxisAlignment: CrossAxisAlignment.stretch, // [cite: 301]
        children: [
          Card( // [cite: 301]
            elevation: 3, // [cite: 301]
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)), // [cite: 302]
            color: cardBackgroundColor, // [cite: 302]
            child: Padding( // [cite: 302]
              padding: const EdgeInsets.all(20.0), // [cite: 302]
              child: Column( // [cite: 302]
                crossAxisAlignment: CrossAxisAlignment.start, // [cite: 302]
                children: [
                  Text( // [cite: 303]
                    "Thêm giao dịch mới (DTP)", // [cite: 303]
                    style: GoogleFonts.poppins( // [cite: 303]
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: primaryColor), // Sử dụng primaryColor từ widget cha
                  ),
                  const SizedBox(height: 24), // [cite: 305]
                  DropdownButtonFormField<String>( // [cite: 305]
                    value: selectedProductId, // [cite: 305]
                    decoration: InputDecoration( // [cite: 305]
                      labelText: "Sản phẩm/Dịch vụ (DTP)", // [cite: 305, 306]
                      labelStyle: // [cite: 306]
                      GoogleFonts.poppins(color: textColorSecondary), // [cite: 307]
                      prefixIcon: Icon(Icons.sell_outlined, // [cite: 307]
                          color: primaryColor, size: 22), // [cite: 307]
                      border: OutlineInputBorder( // [cite: 307]
                          borderRadius: BorderRadius.circular(12)),
                      filled: true, // [cite: 308]
                      fillColor: secondaryColor.withOpacity(0.5), // [cite: 308]
                      contentPadding: // [cite: 308]
                      const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                    items: widget.productList.isEmpty // [cite: 309]
                        ? [ // [cite: 310]
                      DropdownMenuItem<String>( // [cite: 310]
                        value: null, // [cite: 310]
                        child: Text("Chưa có sản phẩm (DTP) nào", // [cite: 310]
                            style: TextStyle( // [cite: 311]
                                fontStyle: FontStyle.italic,
                                color: textColorSecondary)),
                      )
                    ]
                        : widget.productList // [cite: 312]
                        .map((p) => DropdownMenuItem<String>( // [cite: 312]
                      value: p["id"], // [cite: 313]
                      child: Text(p["name"], // [cite: 313]
                          overflow: TextOverflow.ellipsis, // [cite: 313]
                          maxLines: 1, // [cite: 313]
                          style: GoogleFonts.poppins( // [cite: 314]
                              color: textColorPrimary)),
                    ))
                        .toList(), // [cite: 315]
                    onChanged: (String? newValue) { // [cite: 315, 316]
                      setState(() {
                        selectedProductId = newValue;
                        _updatePriceControllerBasedOnSelection(newValue); // [cite: 316]
                        _loadProductVariableCostComponents(
                            newValue); // Load CPBĐ/ĐV cho sản phẩm // [cite: 317]
                      });
                    },
                    style: GoogleFonts.poppins( // [cite: 318, 319]
                        color: textColorPrimary, fontSize: 16), // [cite: 319]
                    icon: Icon(Icons.arrow_drop_down_circle_outlined, // [cite: 319]
                        color: primaryColor), // [cite: 319]
                    borderRadius: BorderRadius.circular(12), // [cite: 320]
                    isExpanded: true, // [cite: 320]
                  ),
                  const SizedBox(height: 12), // [cite: 320]
                  SwitchListTile.adaptive( // [cite: 320]
                    title: Text( // [cite: 321]
                      "Giá bán linh hoạt", // [cite: 321]
                      style: GoogleFonts.poppins( // [cite: 321]
                          fontSize: 16, // [cite: 322]
                          color: textColorPrimary,
                          fontWeight: FontWeight.w500),
                    ),
                    value: isFlexiblePriceEnabled, // [cite: 323]
                    activeColor: primaryColor, // [cite: 323]
                    inactiveThumbColor: Colors.grey.shade400, // [cite: 323, 324]
                    inactiveTrackColor: Colors.grey.shade200, // [cite: 324, 325]
                    onChanged: (bool value) { // [cite: 325]
                      setState(() {
                        isFlexiblePriceEnabled = value; // [cite: 325]
                        if (!isFlexiblePriceEnabled) { // [cite: 326]
                          _updatePriceControllerBasedOnSelection(selectedProductId); // [cite: 326]
                          if (_priceFocusNode.hasFocus) { // [cite: 326]
                            FocusScope.of(context).unfocus(); // [cite: 326, 327]
                          }
                        } else {
                          widget.priceController.text = _priceInputFormatter
                              .format(selectedPriceFromDropdown); // [cite: 327, 328]
                          _priceFocusNode.requestFocus(); // [cite: 328]
                        }
                      });
                    },
                    contentPadding: EdgeInsets.zero, // [cite: 329, 330]
                    secondary: Icon( // [cite: 330]
                        isFlexiblePriceEnabled
                            ? Icons.edit_attributes_outlined
                            : Icons.attach_money_outlined, // [cite: 330, 331]
                        color: primaryColor, // [cite: 331]
                        size: 22), // [cite: 331]
                  ),
                  _buildModernTextField( // [cite: 332]
                      labelText: "Giá bán sản phẩm/dịch vụ (DTP)", // [cite: 332]
                      prefixIconData: Icons.price_change_outlined, // [cite: 332]
                      controller: widget.priceController, // [cite: 332]
                      keyboardType: // [cite: 333]
                      TextInputType.numberWithOptions(decimal: false), // [cite: 333]
                      enabled: isFlexiblePriceEnabled, // [cite: 333]
                      focusNode: _priceFocusNode, // [cite: 333]
                      inputFormatters: [ // [cite: 334]
                        FilteringTextInputFormatter.digitsOnly, // [cite: 334, 335]
                        TextInputFormatter.withFunction( // [cite: 335]
                              (oldValue, newValue) { // [cite: 335]
                            if (newValue.text.isEmpty) { // [cite: 335]
                              return newValue.copyWith(text: '0'); // [cite: 336]
                            }
                            final String plainNumberText = newValue.text // [cite: 336]
                                .replaceAll('.', '') // [cite: 336]
                                .replaceAll(',', ''); // [cite: 337]
                            final number = int.tryParse(plainNumberText); // [cite: 337]
                            if (number == null) return oldValue; // [cite: 337, 338]
                            final formattedText =
                            _priceInputFormatter.format(number); // [cite: 338]
                            return newValue.copyWith( // [cite: 338]
                              text: formattedText, // [cite: 339]
                              selection: TextSelection.collapsed( // [cite: 339]
                                  offset: formattedText.length),
                            );
                          },
                        ),
                      ],
                      maxLength: 15, // [cite: 341]
                      onChanged: (_) { // [cite: 341]
                        if (mounted) setState(() {}); // [cite: 342]
                      }),
                  const SizedBox(height: 16), // [cite: 343]
                  _buildModernTextField( // [cite: 343]
                      labelText: "Số lượng", // [cite: 343]
                      prefixIconData: // [cite: 344]
                      Icons.production_quantity_limits_rounded, // [cite: 344]
                      controller: widget.quantityController, // [cite: 344]
                      keyboardType: TextInputType.number, // [cite: 344]
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly
                      ], // [cite: 345]
                      maxLength: 5, // [cite: 345]
                      onChanged: (_) { // [cite: 346]
                        if (mounted) setState(() {}); // [cite: 346]
                      }),
                  const SizedBox(height: 20), // [cite: 346]

                  // === PHẦN NHẬP LIỆU CHO CHI PHÍ BIẾN ĐỔI ĐƠN VỊ CỦA SẢN PHẨM (DTP) ===
                  Text("Chi phí biến đổi của sản phẩm (DTP):", // [cite: 347]
                      style: GoogleFonts.poppins( // [cite: 347, 348]
                          fontSize: 16,
                          color: textColorPrimary,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8), // [cite: 349]
                  SwitchListTile.adaptive( // [cite: 349]
                    title: Text( // [cite: 349]
                      "CPBĐ/ĐV (DTP) linh hoạt", // [cite: 349]
                      style: GoogleFonts.poppins( // [cite: 350]
                          fontSize: 16, // [cite: 350]
                          color: textColorPrimary,
                          fontWeight: FontWeight.w500),
                    ),
                    value: isFlexibleUnitVariableCostEnabled, // [cite: 351]
                    activeColor: primaryColor, // [cite: 351]
                    inactiveThumbColor: Colors.grey.shade400, // [cite: 351]
                    inactiveTrackColor: Colors.grey.shade200, // [cite: 352]
                    onChanged: (bool value) { // [cite: 352]
                      setState(() {
                        isFlexibleUnitVariableCostEnabled = value; // [cite: 352]
                        if (!isFlexibleUnitVariableCostEnabled) { // [cite: 353]
                          // Reset các component về originalCost
                          for (int i = 0;
                          i < _currentUnitVariableCostComponents.length;
                          i++) { // [cite: 353]
                            final originalCost =
                                _currentUnitVariableCostComponents[i]
                                ['originalCost'] as double? ??
                                    0.0; // [cite: 354]
                            _currentUnitVariableCostComponents[i]['cost'] =
                                originalCost; // [cite: 355]
                            (_currentUnitVariableCostComponents[i]
                            ['controller'] as TextEditingController)
                                .text =
                                _priceInputFormatter.format(originalCost); // [cite: 355]
                            // Unfocus từng component
                            (_currentUnitVariableCostComponents[i]['focusNode']
                            as FocusNode) // [cite: 356]
                                .unfocus(); // [cite: 356]
                          }
                          _recalculateTotalUnitVariableCost(); // [cite: 357]
                        } else {
                          // Khi bật linh hoạt, nếu có component, focus vào cái đầu tiên
                          if (_currentUnitVariableCostComponents.isNotEmpty) { // [cite: 362]
                            (_currentUnitVariableCostComponents.first[ // [cite: 362]
                            'focusNode'] as FocusNode)
                                .requestFocus(); // [cite: 362]
                          }
                        }
                      });
                    },
                    contentPadding: EdgeInsets.zero, // [cite: 364, 365]
                    secondary: Icon( // [cite: 365]
                        isFlexibleUnitVariableCostEnabled
                            ? Icons.edit_outlined
                            : Icons.settings_suggest_outlined, // [cite: 365, 366]
                        color: primaryColor, // [cite: 366]
                        size: 22), // [cite: 366]
                  ),

                  // Hiển thị danh sách các thành phần CPBĐ/ĐV
                  if (selectedProductId != null &&
                      _currentUnitVariableCostComponents.isNotEmpty)
                    Padding( // [cite: 367]
                      padding:
                      const EdgeInsets.only(top: 8.0, bottom: 4.0), // [cite: 367]
                      child: Column( // [cite: 368]
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ListView.builder( // [cite: 370]
                            shrinkWrap: true, // [cite: 370]
                            physics:
                            const NeverScrollableScrollPhysics(), // [cite: 370]
                            itemCount:
                            _currentUnitVariableCostComponents.length, // [cite: 371]
                            itemBuilder: (context, compIndex) {
                              final component = _currentUnitVariableCostComponents[
                              compIndex]; // [cite: 371]
                              final componentName =
                              component['name'] as String; // [cite: 372]
                              final componentController = component['controller']
                              as TextEditingController; // [cite: 372]
                              final componentFocusNode =
                              component['focusNode'] as FocusNode; // [cite: 372]
                              return Padding( // [cite: 373]
                                padding: const EdgeInsets.symmetric(
                                    vertical: 5.0), // [cite: 373]
                                child: Row( // [cite: 374]
                                  crossAxisAlignment:
                                  CrossAxisAlignment.center, // [cite: 374]
                                  children: [
                                    Expanded( // [cite: 374]
                                        flex: 2, // [cite: 375]
                                        child: Text( // [cite: 375]
                                          componentName, // [cite: 376]
                                          style: GoogleFonts.poppins( // [cite: 376]
                                              color: textColorPrimary
                                                  .withOpacity(0.9),
                                              fontSize: 14.5), // [cite: 376]
                                          overflow:
                                          TextOverflow.ellipsis, // [cite: 376]
                                        )),
                                    const SizedBox(width: 10), // [cite: 378]
                                    Expanded( // [cite: 378]
                                      flex: 3, // [cite: 378]
                                      child: _buildModernTextField( // [cite: 379]
                                        // labelText: "Giá trị", // Không cần nếu có tên bên trái
                                        controller:
                                        componentController, // [cite: 380]
                                        enabled:
                                        isFlexibleUnitVariableCostEnabled, // [cite: 380]
                                        focusNode:
                                        componentFocusNode, // [cite: 381]
                                        keyboardType: TextInputType // [cite: 381]
                                            .numberWithOptions(
                                            decimal: false), // [cite: 381]
                                        inputFormatters: [ // [cite: 381]
                                          FilteringTextInputFormatter
                                              .digitsOnly, // [cite: 382, 383]
                                          TextInputFormatter.withFunction( // [cite: 383]
                                                  (oldValue, newValue) {
                                                if (newValue.text.isEmpty) {
                                                  return newValue.copyWith( // [cite: 383]
                                                      text: '0'); // [cite: 383]
                                                }
                                                final String plainNumberText =
                                                newValue.text // [cite: 384]
                                                    .replaceAll('.', '')
                                                    .replaceAll(',', ''); // [cite: 384]
                                                final number = int.tryParse(
                                                    plainNumberText); // [cite: 384]
                                                if (number == null)
                                                  return oldValue; // [cite: 385]
                                                // Listener đã được thêm, không cần setState ở đây
                                                final formattedText =
                                                _priceInputFormatter // [cite: 387]
                                                    .format(number); // [cite: 387]
                                                return newValue.copyWith( // [cite: 387]
                                                  text: formattedText, // [cite: 388]
                                                  selection: // [cite: 388]
                                                  TextSelection.collapsed(
                                                      offset: formattedText
                                                          .length), // [cite: 388]
                                                );
                                              }),
                                        ],
                                        maxLength: 15, labelText: '', // [cite: 390]
                                        // Bỏ prefix icon để tiết kiệm không gian
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 8), // [cite: 393]
                        ],
                      ),
                    ),

                  _buildModernTextField( // [cite: 394]
                      labelText: "Tổng CPBĐ/ĐV (DTP - Tự động)", // [cite: 394]
                      prefixIconData: Icons.local_atm_outlined, // [cite: 394]
                      controller:
                      unitVariableCostController, // Controller cho CPBĐ/ĐV tổng // [cite: 395]
                      keyboardType: // [cite: 395]
                      TextInputType.numberWithOptions(decimal: false), // [cite: 395]
                      enabled: false, // TextField này chỉ đọc // [cite: 396]
                      // focusNode: _unitVariableCostFocusNode, // Không cần nữa
                      inputFormatters: [ // [cite: 396]
                        FilteringTextInputFormatter.digitsOnly, // [cite: 396]
                        TextInputFormatter.withFunction( // [cite: 397]
                              (oldValue, newValue) { // [cite: 397]
                            if (newValue.text.isEmpty) { // [cite: 397]
                              return newValue.copyWith(text: '0'); // [cite: 398]
                            }
                            final String plainNumberText = newValue.text // [cite: 399]
                                .replaceAll('.', '') // [cite: 399]
                                .replaceAll(',', ''); // [cite: 399]
                            final number =
                            int.tryParse(plainNumberText); // [cite: 400]
                            if (number == null) return oldValue; // [cite: 400, 401]
                            final formattedText =
                            _priceInputFormatter.format(number); // [cite: 401]
                            return newValue.copyWith( // [cite: 402]
                              text: formattedText, // [cite: 402]
                              selection: TextSelection.collapsed( // [cite: 402]
                                  offset: formattedText.length),
                            );
                          },
                        ),
                      ],
                      maxLength: 15, // [cite: 404]
                      onChanged: (_) { // [cite: 404]
                        // Không làm gì vì enabled=false // [cite: 405]
                      }),
                  const SizedBox(height: 20), // [cite: 405]
                  // Loại bỏ phần "Chi phí biến đổi chung khác"

                  const SizedBox(height: 20), // [cite: 463]
                  Container( // [cite: 463]
                    width: double.infinity, // [cite: 464]
                    padding: const EdgeInsets.symmetric( // [cite: 464]
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration( // [cite: 464]
                        color: primaryColor.withOpacity(0.08), // [cite: 465]
                        borderRadius: BorderRadius.circular(12), // [cite: 465]
                        border: Border.all( // [cite: 465]
                            color: primaryColor.withOpacity(0.3))),
                    child: Column( // [cite: 465]
                      crossAxisAlignment: CrossAxisAlignment.start, // [cite: 466]
                      children: [ // [cite: 466]
                        Text( // [cite: 466]
                          "TỔNG DOANH THU (DTP - ƯỚC TÍNH):", // [cite: 467]
                          style: GoogleFonts.poppins( // [cite: 467]
                              fontSize: 13, // [cite: 467]
                              fontWeight: FontWeight.w600, // [cite: 468]
                              color: primaryColor.withOpacity(0.8), // [cite: 468]
                              letterSpacing: 0.5), // [cite: 468]
                        ),
                        SizedBox(height: 4), // [cite: 469]
                        Text( // [cite: 469]
                          widget.currencyFormat
                              .format(estimatedTotalRevenue), // [cite: 469]
                          style: GoogleFonts.poppins( // [cite: 470]
                              fontSize: 22, // [cite: 470]
                              fontWeight: FontWeight.w700, // [cite: 470]
                              color: primaryColor), // [cite: 471]
                        ),
                        const SizedBox(height: 8), // [cite: 471]
                        Text( // [cite: 471]
                          "TỔNG LN GỘP (DTP - ƯỚC TÍNH):", // [cite: 472]
                          style: GoogleFonts.poppins( // [cite: 472]
                              fontSize: 13, // [cite: 472]
                              fontWeight: FontWeight.w600, // [cite: 473, 474]
                              color: Colors.green.shade700
                                  .withOpacity(0.9), // [cite: 474, 475]
                              letterSpacing: 0.5), // [cite: 475]
                        ),
                        SizedBox(height: 4), // [cite: 475]
                        Text( // [cite: 476]
                          widget.currencyFormat
                              .format(estimatedGrossProfit), // [cite: 476]
                          style: GoogleFonts.poppins( // [cite: 476]
                              fontSize: 22, // [cite: 477]
                              fontWeight: FontWeight.w700,
                              color: Colors.green.shade700), // [cite: 477]
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28), // [cite: 478]
                  ElevatedButton( // [cite: 479]
                    style: ElevatedButton.styleFrom( // [cite: 479]
                      backgroundColor: primaryColor, // [cite: 479]
                      foregroundColor: Colors.white, // [cite: 479, 480]
                      shape: RoundedRectangleBorder( // [cite: 480]
                          borderRadius: BorderRadius.circular(12)),
                      minimumSize: Size(screenWidth, 52), // [cite: 480]
                      padding: // [cite: 481]
                      const EdgeInsets.symmetric(vertical: 14),
                      elevation: 2, // [cite: 481]
                    ),
                    onPressed: () {
                      // Tìm lại tên sản phẩm từ ID đã chọn để truyền vào onAddTransaction
                      final String? productName = selectedProductId != null
                          ? widget.productList.firstWhere(
                              (p) => p['id'] == selectedProductId,
                          orElse: () => {'name': null})['name']
                          : null;

                      widget.onAddTransaction(
                          productName,
                          selectedPriceFromDropdown,
                          isFlexiblePriceEnabled);
                    },
                    child: Text( // [cite: 482]
                      "Thêm giao dịch (DTP)", // [cite: 482, 483]
                      style: GoogleFonts.poppins( // [cite: 483]
                          fontSize: 16.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernTextField({
    required String labelText, // [cite: 485]
    required TextEditingController controller, // [cite: 485]
    bool enabled = true, // [cite: 485]
    TextInputType keyboardType = TextInputType.text, // [cite: 485]
    List<TextInputFormatter>? inputFormatters, // [cite: 485]
    int? maxLength, // [cite: 485]
    IconData? prefixIconData, // [cite: 485]
    FocusNode? focusNode, // [cite: 485]
    void Function(String)? onChanged, // [cite: 485]
  }) {
    // Sử dụng màu từ widget cha (EditSecondaryRevenueScreen)
    final Color fieldPrimaryColor = widget.screenPrimaryColor; // [cite: 485, 486]
    final Color fieldSecondaryColor =
        _EditSecondaryRevenueScreenState._secondaryColor; // [cite: 486]
    final Color fieldTextColorSecondary =
        _EditSecondaryRevenueScreenState._textColorSecondary; // [cite: 487]

    return TextField( // [cite: 488]
      controller: controller, // [cite: 488]
      enabled: enabled, // [cite: 488]
      keyboardType: keyboardType, // [cite: 488]
      inputFormatters: inputFormatters, // [cite: 488]
      maxLength: maxLength, // [cite: 488]
      focusNode: focusNode, // [cite: 488]
      onChanged: onChanged, // [cite: 488]
      style: GoogleFonts.poppins( // [cite: 488]
          color: _EditSecondaryRevenueScreenState._textColorPrimary,
          fontWeight: FontWeight.w500,
          fontSize: 16),
      decoration: InputDecoration( // [cite: 489]
        labelText: labelText, // [cite: 489]
        labelStyle:
        GoogleFonts.poppins(color: fieldTextColorSecondary), // [cite: 489]
        prefixIcon: prefixIconData != null // [cite: 489]
            ? Icon(prefixIconData, color: fieldPrimaryColor, size: 22) // [cite: 489]
            : null, // [cite: 490]
        border: OutlineInputBorder( // [cite: 490]
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300)), // [cite: 490, 491]
        enabledBorder: OutlineInputBorder( // [cite: 491]
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder( // [cite: 491]
            borderRadius: BorderRadius.circular(12), // [cite: 491, 492]
            borderSide: BorderSide(color: fieldPrimaryColor, width: 1.5)),
        filled: true, // [cite: 492]
        fillColor: enabled // [cite: 492]
            ? fieldSecondaryColor.withOpacity(0.5) // [cite: 493]
            : Colors.grey.shade200, // [cite: 493, 494]
        contentPadding: // [cite: 494]
        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        counterText: "", // [cite: 494]
      ),
      maxLines: 1, // [cite: 494]
    );
  }
}

// TransactionHistorySection không thay đổi logic cốt lõi và được tái sử dụng
// Nó sẽ nhận primaryColor từ _EditSecondaryRevenueScreenState
class TransactionHistorySection extends StatelessWidget {
  final ValueNotifier<List<Map<String, dynamic>>> transactionsNotifier; // [cite: 495]
  final Function(AppState, List<Map<String, dynamic>>, int)
  onEditTransaction; // [cite: 496]
  final Function(AppState, List<Map<String, dynamic>>, int)
  onRemoveTransaction; // [cite: 497]
  final AppState appState; // [cite: 497]
  final NumberFormat currencyFormat; // [cite: 498]
  final Color primaryColor; // [cite: 498]
  final Color textColorPrimary; // [cite: 499]
  final Color textColorSecondary; // [cite: 499]
  final Color cardBackgroundColor; // [cite: 500]

  const TransactionHistorySection({
    Key? key, // [cite: 500]
    required this.transactionsNotifier, // [cite: 500]
    required this.onEditTransaction, // [cite: 500]
    required this.onRemoveTransaction, // [cite: 500]
    required this.appState, // [cite: 500]
    required this.currencyFormat, // [cite: 500]
    required this.primaryColor, // [cite: 500]
    required this.textColorPrimary, // [cite: 500]
    required this.textColorSecondary, // [cite: 500]
    required this.cardBackgroundColor, // [cite: 500]
  }) : super(key: key); // [cite: 500]

  @override
  Widget build(BuildContext context) { // [cite: 501]
    return ValueListenableBuilder<List<Map<String, dynamic>>>( // [cite: 501]
      valueListenable: transactionsNotifier, // [cite: 501]
      builder: (context, history, _) { // [cite: 501]
        if (history.isEmpty) { // [cite: 501]
          return Center( // [cite: 501]
            child: Padding( // [cite: 501]
              padding: const EdgeInsets.all(30.0), // [cite: 501, 502]
              child: Column( // [cite: 502]
                mainAxisAlignment: MainAxisAlignment.center, // [cite: 502]
                children: [
                  Icon(Icons.history_toggle_off_outlined, // [cite: 502]
                      size: 70, // [cite: 503]
                      color: Colors.grey.shade400),
                  SizedBox(height: 16), // [cite: 503]
                  Text( // [cite: 503]
                    "Chưa có giao dịch (DTP) nào", // [cite: 503]
                    style: GoogleFonts.poppins( // [cite: 504]
                        fontSize: 17, color: textColorSecondary),
                  ),
                  SizedBox(height: 4), // [cite: 504]
                  Text( // [cite: 505]
                    "Thêm giao dịch (DTP) mới để xem lịch sử tại đây.", // [cite: 505]
                    textAlign: TextAlign.center, // [cite: 505]
                    style: GoogleFonts.poppins( // [cite: 505, 506]
                        fontSize: 14, color: Colors.grey.shade500), // [cite: 506]
                  ),
                ],
              ),
            ),
          );
        }
        final sortedHistory = List<Map<String, dynamic>>.from(history); // [cite: 507]
        sortedHistory.sort((a, b) { // [cite: 508]
          DateTime dateA =
              DateTime.tryParse(a['date'] ?? '') ?? DateTime(1900); // [cite: 508]
          DateTime dateB =
              DateTime.tryParse(b['date'] ?? '') ?? DateTime(1900); // [cite: 508]
          return dateB.compareTo(dateA); // [cite: 508]
        });
        return SingleChildScrollView( // [cite: 509]
          padding:
          const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 80.0), // [cite: 509]
          child: Column( // [cite: 509]
            crossAxisAlignment: CrossAxisAlignment.start, // [cite: 509]
            children: [
              Padding( // [cite: 509]
                padding: const EdgeInsets.only(bottom: 12.0), // [cite: 510]
                child: Text( // [cite: 510]
                  "Lịch sử giao dịch (DTP)", // [cite: 510]
                  style: GoogleFonts.poppins( // [cite: 510]
                      fontSize: 19, // [cite: 510]
                      fontWeight: FontWeight.w700,
                      color: textColorPrimary),
                ),
              ),
              ListView.builder( // [cite: 511]
                shrinkWrap: true, // [cite: 512]
                physics: const NeverScrollableScrollPhysics(), // [cite: 512]
                itemCount: sortedHistory.length, // [cite: 512]
                itemBuilder: (context, index) { // [cite: 512]
                  final transaction = sortedHistory[index]; // [cite: 512]
                  final originalIndex = history.indexOf(transaction); // [cite: 513]
                  final double totalRevenue = // [cite: 514]
                  (transaction['total'] as num? ?? 0.0).toDouble(); // [cite: 514]
                  final double totalVariableCost = // [cite: 515]
                  (transaction['totalVariableCost'] as num? ?? 0.0) // [cite: 515]
                      .toDouble(); // [cite: 515]
                  final double grossProfit =
                      totalRevenue - totalVariableCost; // [cite: 516]
                  final double profitMargin = totalRevenue > 0 // [cite: 516]
                      ? (grossProfit / totalRevenue) * 100 // [cite: 517]
                      : 0.0; // [cite: 517]
                  return Dismissible( // [cite: 518]
                    key: Key(transaction['date'].toString() + // [cite: 518]
                        (transaction['name'] ?? 'unknown_product_dtp') + // [cite: 518]
                        index.toString()), // [cite: 519]
                    background: Container( // [cite: 519]
                      color: // [cite: 519]
                      _EditSecondaryRevenueScreenState._accentColor
                          .withOpacity(0.8), // [cite: 519]
                      alignment: Alignment.centerRight, // [cite: 519]
                      padding: const EdgeInsets.only(right: 20), // [cite: 520]
                      child: const Icon(Icons.delete_sweep_outlined, // [cite: 520]
                          color: Colors.white, size: 26), // [cite: 520]
                    ),
                    direction: DismissDirection.endToStart, // [cite: 521]
                    onDismissed: (direction) { // [cite: 521]
                      if (originalIndex != -1) { // [cite: 521]
                        onRemoveTransaction( // [cite: 522]
                            appState, transactionsNotifier.value, originalIndex);
                      }
                    },
                    child: Card( // [cite: 523]
                      elevation: 1.5, // [cite: 523]
                      margin: const EdgeInsets.symmetric(vertical: 5), // [cite: 523]
                      shape: RoundedRectangleBorder( // [cite: 524]
                          borderRadius: BorderRadius.circular(12)),
                      color: cardBackgroundColor, // [cite: 524]
                      child: ListTile( // [cite: 524, 525]
                        contentPadding: const EdgeInsets.symmetric( // [cite: 525]
                            horizontal: 16, vertical: 10),
                        visualDensity:
                        VisualDensity.adaptivePlatformDensity, // [cite: 525]
                        leading: CircleAvatar( // [cite: 500]
                          backgroundColor:
                          primaryColor.withOpacity(0.15), // [cite: 500]
                          radius: 22, // [cite: 500]
                          child: Text( // [cite: 501]
                            transaction['name'] != null && // [cite: 501]
                                (transaction['name'] as String)
                                    .isNotEmpty // [cite: 501]
                                ? (transaction['name'] as String)[0] // [cite: 502, 503]
                                .toUpperCase() // [cite: 503]
                                : "?", // [cite: 503]
                            style: GoogleFonts.poppins( // [cite: 504]
                                color: primaryColor,
                                fontWeight: FontWeight.w600, // [cite: 504]
                                fontSize: 18), // [cite: 505]
                          ),
                        ),
                        title: Text( // [cite: 505]
                          transaction['name']?.toString() ?? 'N/A', // [cite: 506]
                          style: GoogleFonts.poppins( // [cite: 506]
                              fontSize: 15.5, // [cite: 506]
                              fontWeight: FontWeight.w600, // [cite: 507]
                              color: textColorPrimary),
                          overflow: TextOverflow.ellipsis, // [cite: 507]
                        ),
                        subtitle: Padding( // [cite: 508]
                          padding: const EdgeInsets.only(top: 4.0), // [cite: 508]
                          child: Column( // [cite: 509]
                            crossAxisAlignment:
                            CrossAxisAlignment.start, // [cite: 509]
                            mainAxisSize: MainAxisSize.min, // [cite: 509]
                            children: [ // [cite: 509]
                              Text( // [cite: 510]
                                "SL: ${transaction['quantity']} x ${currencyFormat.format(transaction['price'] ?? 0.0)}", // [cite: 510, 511]
                                style: GoogleFonts.poppins( // [cite: 511]
                                    fontSize: 12.0,
                                    color: textColorSecondary), // [cite: 512]
                              ),
                              Text( // [cite: 512]
                                "Tổng DT: ${currencyFormat.format(totalRevenue)}", // [cite: 513]
                                style: GoogleFonts.poppins( // [cite: 513]
                                    fontSize: 13.0, // [cite: 513]
                                    color: primaryColor, // [cite: 514]
                                    fontWeight: FontWeight.w500), // [cite: 514]
                              ),
                              if (transaction // [cite: 515]
                                  .containsKey('totalVariableCost'))
                                Padding( // [cite: 516]
                                  padding:
                                  const EdgeInsets.only(top: 2.0), // [cite: 516]
                                  child: Text( // [cite: 517]
                                    "Tổng CPBĐ: ${currencyFormat.format(totalVariableCost)}", // [cite: 517]
                                    style: GoogleFonts.poppins( // [cite: 517, 518]
                                        fontSize: 12.0, // [cite: 518]
                                        color: textColorSecondary // [cite: 518]
                                            .withOpacity(0.9)),
                                  ),
                                ),
                              if (transaction // [cite: 520]
                                  .containsKey('totalVariableCost'))
                                Padding( // [cite: 521]
                                  padding: const EdgeInsets.only(
                                      top: 2.0), // [cite: 521, 546]
                                  child: Text( // [cite: 522]
                                    "LN Gộp: ${currencyFormat.format(grossProfit)} (${profitMargin.toStringAsFixed(1)}%)", // [cite: 522]
                                    style: GoogleFonts.poppins( // [cite: 523]
                                        fontSize: 13.0, // [cite: 523]
                                        color: Colors.green.shade700, // [cite: 524]
                                        fontWeight: FontWeight.w500), // [cite: 525]
                                  ),
                                ),
                              if (transaction['date'] != null) // [cite: 526]
                                Padding( // [cite: 526]
                                  padding: const EdgeInsets.only(
                                      top: 3.0), // [cite: 527]
                                  child: Text( // [cite: 527]
                                    DateFormat('dd/MM/yy HH:mm').format( // [cite: 528]
                                        DateTime.parse(
                                            transaction['date'])), // [cite: 528, 552]
                                    style: GoogleFonts.poppins( // [cite: 528, 553]
                                        fontSize: 10.5, // [cite: 529]
                                        color: textColorSecondary // [cite: 529]
                                            .withOpacity(0.8)), // [cite: 530]
                                  ),
                                ),
                            ],
                          ),
                        ),
                        trailing: IconButton( // [cite: 531]
                          icon: Icon(Icons.edit_note_outlined, // [cite: 532, 533]
                              color: primaryColor.withOpacity(0.8),
                              size: 24), // [cite: 533]
                          onPressed: () { // [cite: 533]
                            if (originalIndex != -1) { // [cite: 534]
                              onEditTransaction(appState, // [cite: 534]
                                  transactionsNotifier.value, originalIndex); // [cite: 535]
                            }
                          },
                          splashRadius: 20, // [cite: 535]
                          padding: EdgeInsets.zero, // [cite: 536, 537]
                          constraints: // [cite: 537]
                          BoxConstraints(minWidth: 36, minHeight: 36), // [cite: 537]
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}