import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart'; // [cite: 1]
import '/screens/revenue_manager.dart'; // [cite: 1]
import '/screens/expense_manager.dart'; // [cite: 1]
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart'; // [cite: 2]
import 'package:uuid/uuid.dart'; // [cite: 2]

class EditMainRevenueScreen extends StatefulWidget {
  const EditMainRevenueScreen({Key? key}) : super(key: key); // [cite: 2]

  @override
  _EditMainRevenueScreenState createState() => _EditMainRevenueScreenState(); // [cite: 3]
}

class _EditMainRevenueScreenState extends State<EditMainRevenueScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController quantityController = TextEditingController(); // [cite: 4]
  final TextEditingController priceController = TextEditingController(); // Giá BÁN // [cite: 5]
  late AnimationController _animationController; // [cite: 5]
  late Animation<double> _scaleAnimation; // [cite: 6]
  late Future<List<Map<String, dynamic>>> _productsFuture; // [cite: 6]
  int _selectedTab = 0; // [cite: 7]
  late AppState _appState; // [cite: 7]
  final GlobalKey<_ProductInputSectionState> _productInputSectionKey =
  GlobalKey<_ProductInputSectionState>(); // [cite: 8]

  static const Color _primaryColor = Color(0xFF2F81D7); // [cite: 9]
  static const Color _secondaryColor = Color(0xFFF1F5F9); // [cite: 10]
  static const Color _textColorPrimary = Color(0xFF1D2D3A); // [cite: 11]
  static const Color _textColorSecondary = Color(0xFF6E7A8A); // [cite: 12]
  static const Color _cardBackgroundColor = Colors.white; // [cite: 13]
  static const Color _accentColor = Colors.redAccent; // [cite: 14]
  final currencyFormat =
  NumberFormat.currency(locale: 'vi_VN', symbol: 'VNĐ'); // [cite: 15]

  @override
  void initState() {
    super.initState();
    quantityController.text = "1"; // [cite: 16]
    _animationController = AnimationController(
        duration: const Duration(milliseconds: 300), vsync: this); // [cite: 17]
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
        CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack)); // [cite: 18]
    _animationController.forward(); // [cite: 19]
    _appState = Provider.of<AppState>(context, listen: false); // [cite: 19]
    _productsFuture =
        RevenueManager.loadProducts(_appState, "Doanh thu chính"); // [cite: 20, 21]
    _appState.productsUpdated.addListener(_onProductsUpdated); // [cite: 21]
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // THAY ĐỔI: Không cần gán lại _appState ở đây nếu đã có ở initState và không thay đổi
    // _appState = Provider.of<AppState>(context, listen: false); // [cite: 23]
  }

  @override
  void dispose() {
    quantityController.dispose(); // [cite: 24]
    priceController.dispose(); // [cite: 24]
    _animationController.dispose(); // [cite: 25]
    _appState.productsUpdated.removeListener(_onProductsUpdated); // [cite: 25]
    super.dispose(); // [cite: 26]
  }

  void _onProductsUpdated() {
    if (mounted) { // [cite: 26]
      setState(() {
        // THAY ĐỔI: không cần Provider.of ở đây nếu _appState đã là thành viên
        _productsFuture =
            RevenueManager.loadProducts(_appState, "Doanh thu chính"); // [cite: 26]
      });
    }
  }

  void _showStyledSnackBar(String message, {bool isError = false}) {
    if (!mounted) return; // [cite: 27]
    ScaffoldMessenger.of(context).showSnackBar( // [cite: 28]
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins(color: Colors.white)), // [cite: 28]
        backgroundColor: isError ? _accentColor : _primaryColor, // [cite: 28]
        behavior: SnackBarBehavior.floating, // [cite: 28]
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), // [cite: 28]
        margin: const EdgeInsets.all(10), // [cite: 28]
      ),
    );
  }

  // THAY ĐỔI: Cập nhật hàm addTransaction
  void addTransaction(
      AppState appState,
      List<Map<String, dynamic>> salesTransactions,
      String? selectedProduct,
      double currentSelectedPriceInDropdown, // Giá bán từ dropdown
      bool isFlexiblePriceEnabled, // Giá bán có linh hoạt không
      // THAY ĐỔI: unitVariableCostForSale sẽ được tính toán bên trong dựa trên components
      ) {
    if (selectedProduct == null) {
      _showStyledSnackBar("Vui lòng chọn sản phẩm/dịch vụ!", isError: true); // [cite: 30]
      return; // [cite: 31]
    }
    final productInputState = _productInputSectionKey.currentState; // [cite: 31]
    if (productInputState == null) {
      _showStyledSnackBar("Lỗi nội bộ: Không tìm thấy productInputState.", isError: true); // [cite: 32]
      return; // [cite: 32]
    }

    double priceToUse; // Giá bán sẽ sử dụng // [cite: 33]
    if (isFlexiblePriceEnabled) {
      priceToUse = double.tryParse(priceController.text
          .replaceAll('.', '')
          .replaceAll(',', '')) ??
          0.0; // [cite: 33, 34]
      if (priceToUse <= 0.0) {
        _showStyledSnackBar("Vui lòng nhập giá trị hợp lệ cho giá bán!", isError: true); // [cite: 34]
        return; // [cite: 35]
      }
    } else {
      priceToUse = currentSelectedPriceInDropdown; // [cite: 36]
      if (priceToUse <= 0.0) {
        _showStyledSnackBar("Giá sản phẩm không hợp lệ trong danh mục!", isError: true); // [cite: 37]
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

    // MỚI: Lấy thông tin chi phí biến đổi đơn vị chi tiết từ ProductInputSection
    List<Map<String, dynamic>> currentUnitCostComponents =
        productInputState.currentUnitVariableCostComponents; // [cite: 42]
    double unitVariableCostForSale = 0; // [cite: 43]
    List<Map<String, dynamic>> cogsComponentsForStorage = []; // [cite: 43]
    for (var component in currentUnitCostComponents) {
      double cost = component['cost'] as double? ?? 0.0; // [cite: 43, 44]
      unitVariableCostForSale += cost; // [cite: 44]
      cogsComponentsForStorage.add({ // [cite: 44]
        'name': component['name'], // [cite: 44]
        'cost': cost, // Lưu giá trị cost hiện tại (có thể đã sửa) // [cite: 44]
        'originalCost': component['originalCost'] // Lưu thêm originalCost để tham khảo nếu cần // [cite: 44]
      });
    }
    double totalUnitVariableCostForSale = unitVariableCostForSale * quantity; // [cite: 45]

    var uuid = Uuid(); // [cite: 45]
    String transactionId = uuid.v4(); // [cite: 46]
    String? cogsSourceType; // [cite: 46]
    bool cogsWasFlexible = productInputState.isUnitVariableCostFlexible; // [cite: 47]
    double cogsDefaultCostAtTimeOfSale = 0; // [cite: 47]
    // Tổng các originalCost
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
          ? "AUTO_COGS_COMPONENT_OVERRIDE" // [cite: 54]
          : "AUTO_COGS_COMPONENT"; // [cite: 54]
    } else if (unitVariableCostForSale > 0) { // Trường hợp không có component nhưng CPBĐ > 0 (ví dụ: nhập tay từ dữ liệu cũ) // [cite: 55]
      cogsSourceType = "AUTO_COGS_ESTIMATED"; // [cite: 55]
      // Trong trường hợp này, cogsComponentsUsed sẽ là null // [cite: 56]
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
      "cogsWasFlexible": cogsWasFlexible, // Lưu cờ này bất kể có component hay không // [cite: 57]
      if (cogsDefaultCostAtTimeOfSale > 0 && cogsComponentsUsed != null)
        "cogsDefaultCostAtTimeOfSale": cogsDefaultCostAtTimeOfSale, // [cite: 57]
      if (cogsComponentsUsed != null && cogsComponentsUsed.isNotEmpty)
        "cogsComponentsUsed": cogsComponentsUsed, // [cite: 57]
    };
    salesTransactions.add(newSalesTransaction); // [cite: 58]
    RevenueManager.saveTransactionHistory(
        appState, "Doanh thu chính", salesTransactions); // [cite: 58]
    _showStyledSnackBar("Đã thêm giao dịch bán hàng: $selectedProduct"); // [cite: 59]

    // 2. TỰ ĐỘNG TẠO các bản ghi GIAO DỊCH CHI PHÍ BIẾN ĐỔI (COGS)
    List<Map<String, dynamic>> autoGeneratedExpenseTransactions = []; // [cite: 60]
    if (cogsSourceType == "AUTO_COGS_COMPONENT" ||
        cogsSourceType == "AUTO_COGS_COMPONENT_OVERRIDE") { // [cite: 61]
      if (cogsComponentsUsed != null) {
        for (var component in cogsComponentsUsed) { // [cite: 61]
          double componentCostForTransaction =
              (component['cost'] as double? ?? 0.0) * quantity; // [cite: 61]
          if (componentCostForTransaction > 0) { // [cite: 62]
            autoGeneratedExpenseTransactions.add({
              "name": "${component['name']} (Cho: $selectedProduct)", // [cite: 62]
              "amount": componentCostForTransaction, // [cite: 62]
              "date": DateTime.now().toIso8601String(), // [cite: 62]
              "source": cogsSourceType, // Sử dụng cogsSourceType đã xác định // [cite: 62]
              "sourceSalesTransactionId": transactionId // [cite: 63]
            });
          }
        }
      }
    } else if (cogsSourceType == "AUTO_COGS_ESTIMATED" ||
        cogsSourceType == "AUTO_COGS_OVERRIDE") { // [cite: 64]
      // Trường hợp này thường xảy ra nếu CPBĐ được nhập tổng, không qua components. // [cite: 64]
      // Hoặc là dữ liệu cũ chỉ có unitVariableCost tổng. // [cite: 65]
      // Với logic mới, AUTO_COGS_OVERRIDE (tổng) sẽ ít xảy ra nếu TextField tổng là read-only. // [cite: 66]
      // Tuy nhiên, vẫn giữ lại để xử lý các trường hợp có thể có. // [cite: 67]
      if (totalUnitVariableCostForSale > 0) { // [cite: 68]
        autoGeneratedExpenseTransactions.add({
          "name":
          "Giá vốn hàng bán (${cogsSourceType == "AUTO_COGS_OVERRIDE" ? "Ghi đè" : "Ước tính"}): $selectedProduct", // [cite: 68]
          "amount": totalUnitVariableCostForSale, // [cite: 68]
          "date": DateTime.now().toIso8601String(), // [cite: 68]
          "source": cogsSourceType, // [cite: 68]
          "sourceSalesTransactionId": transactionId // [cite: 68]
        });
      }
    }

    // 3. Xử lý các CHI PHÍ BIẾN ĐỔI CHUNG KHÁC (nhập thủ công) - SECTION REMOVED

    // 4. Gộp và lưu tất cả các giao dịch chi phí biến đổi
    if (autoGeneratedExpenseTransactions.isNotEmpty) { // MODIFIED: Removed || manuallyAddedGeneralExpenses.isNotEmpty // [cite: 80]
      List<Map<String, dynamic>> currentDailyVariableExpenses =
      List.from(appState.variableExpenseList.value); // [cite: 80]
      currentDailyVariableExpenses.addAll(autoGeneratedExpenseTransactions); // [cite: 81]
      // currentDailyVariableExpenses.addAll(manuallyAddedGeneralExpenses); // MODIFIED: Removed // [cite: 81]
      appState.variableExpenseList.value =
          List.from(currentDailyVariableExpenses); // [cite: 82]
      ExpenseManager.saveVariableExpenses(
          appState, currentDailyVariableExpenses) // [cite: 82, 83]
          .then((_) {
        // ExpenseManager.saveVariableExpenses đã tự cập nhật tổng trong AppState qua listener rồi // [cite: 83]
        // nên không cần gọi lại updateTotalVariableExpense hay appState.setExpenses ở đây nữa. // [cite: 83]
        // Chỉ cần đảm bảo listener của variableExpenseList trong AppState hoạt động đúng. // [cite: 83]
        // Tuy nhiên, để đảm bảo profit được cập nhật ngay, chúng ta có thể tính lại tổng // [cite: 83]
        // và gọi setExpenses. // [cite: 84]
        double totalVariableExpenseSum = currentDailyVariableExpenses.fold(
            0.0, (sum, item) => sum + (item['amount'] as num? ?? 0.0)); // [cite: 84]
        appState.setExpenses(appState.fixedExpense, totalVariableExpenseSum); // [cite: 84]
        // if (manuallyAddedGeneralExpenses.isNotEmpty) { // MODIFIED: Removed // [cite: 84]
        // _showStyledSnackBar("Đã thêm chi phí (chung): ${manuallyAddedGeneralExpenses.first['name']}");
        // }
        if (autoGeneratedExpenseTransactions.isNotEmpty) { // [cite: 84]
          _showStyledSnackBar(
              "Đã tự động ghi nhận giá vốn cho $selectedProduct"); // [cite: 84, 85]
        }
      }).catchError((e) {
        _showStyledSnackBar("Lỗi khi lưu một số chi phí biến đổi: $e",
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

  void removeTransaction(AppState appState, List<Map<String, dynamic>> transactions, int index) {
    if (index < 0 || index >= transactions.length) return; // [cite: 87]
    final transactionToRemove = transactions[index]; // [cite: 88]
    final String? salesTransactionId = transactionToRemove['id'] as String?; // [cite: 88, 89]
    final String removedItemName = transactionToRemove['name'] as String? ?? "Không rõ sản phẩm"; // [cite: 89, 90]

    List<Map<String, dynamic>> currentDailyVariableExpenses = List.from(appState.variableExpenseList.value); // [cite: 90]
    int initialVariableExpenseCount = currentDailyVariableExpenses.length; // [cite: 91]

    if (salesTransactionId != null) {
      currentDailyVariableExpenses.removeWhere((expense) =>
      expense['sourceSalesTransactionId'] == salesTransactionId &&
          (expense['source'] == 'AUTO_COGS_OVERRIDE' ||
              expense['source'] == 'AUTO_COGS_COMPONENT' || // [cite: 92]
              expense['source'] == 'AUTO_COGS_ESTIMATED' || // [cite: 92]
              expense['source'] == 'AUTO_COGS_COMPONENT_OVERRIDE')); // [cite: 92]
      // MỚI
      if (currentDailyVariableExpenses.length < initialVariableExpenseCount) { // [cite: 93]
        appState.variableExpenseList.value = List.from(currentDailyVariableExpenses); // [cite: 93]
        ExpenseManager.saveVariableExpenses(appState, currentDailyVariableExpenses) // [cite: 94, 95]
            .then((_) {
          double newTotalVariableExpense = currentDailyVariableExpenses.fold(
              0.0, (sum, item) => sum + (item['amount'] as num? ?? 0.0)); // [cite: 95]
          appState.setExpenses(appState.fixedExpense, newTotalVariableExpense); // [cite: 95]
        }).catchError((e) {
          _showStyledSnackBar( // [cite: 95]
              "Lỗi khi cập nhật chi phí biến đổi sau khi xóa COGS: $e", // [cite: 96]
              isError: true); // [cite: 96]
        });
      }
    } else {
      print(
          "Cảnh báo: Giao dịch doanh thu này không có ID, không thể tự động xóa COGS liên quan."); // [cite: 97]
      _showStyledSnackBar( // [cite: 98]
          "Cảnh báo: Không thể tự động xóa giá vốn của giao dịch cũ này.", // [cite: 98]
          isError: false); // [cite: 98]
    }

    transactions.removeAt(index); // [cite: 99]
    RevenueManager.saveTransactionHistory(appState, "Doanh thu chính", transactions); // [cite: 99]
    _showStyledSnackBar("Đã xóa: $removedItemName. Giá vốn liên quan (nếu có) cũng đã được xóa."); // [cite: 100, 101]
  }

  // THAY ĐỔI: editTransaction cần được cập nhật sâu hơn để xử lý dialog chỉnh sửa component
  // Tạm thời giữ nguyên logic cơ bản, bạn cần mở rộng phần dialog
  void editTransaction(AppState appState, List<Map<String, dynamic>> transactions, int index) {
    if (index < 0 || index >= transactions.length) return; // [cite: 101]
    final transactionToEdit = transactions[index]; // [cite: 102]
    final String? salesTransactionId = transactionToEdit['id'] as String?; // [cite: 102, 103]

    final TextEditingController editQuantityController =
    TextEditingController(text: transactionToEdit['quantity'].toString()); // [cite: 103]
    final NumberFormat internalPriceFormatter = NumberFormat("#,##0", "vi_VN"); // [cite: 104]
    // Tạm thời vẫn sử dụng editUnitVariableCostController tổng, bạn cần thay thế bằng dialog chi tiết
    final TextEditingController editUnitVariableCostController = TextEditingController( // [cite: 105]
        text: internalPriceFormatter.format(transactionToEdit['unitVariableCost'] ?? 0.0)); // [cite: 105]

    showDialog(
      context: context, // [cite: 106]
      builder: (dialogContext) => GestureDetector( // [cite: 106]
        onTap: () => FocusScope.of(dialogContext).unfocus(), // [cite: 106]
        behavior: HitTestBehavior.opaque, // [cite: 106]
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), // [cite: 106]
          title: Text("Chỉnh sửa: ${transactionToEdit['name']}", // [cite: 106]
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: _textColorPrimary)), // [cite: 107]
          content: SingleChildScrollView( // [cite: 107]
            child: Column(
              mainAxisSize: MainAxisSize.min, // [cite: 107]
              children: [
                TextField( // [cite: 107, 108]
                  keyboardType: TextInputType.number, // [cite: 108]
                  controller: editQuantityController, // [cite: 108]
                  decoration: InputDecoration( // [cite: 108]
                      labelText: "Nhập số lượng mới", // [cite: 108]
                      labelStyle: GoogleFonts.poppins(color: _textColorSecondary), // [cite: 109, 110]
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), // [cite: 110]
                      filled: true, // [cite: 110]
                      fillColor: _secondaryColor, // [cite: 110]
                      prefixIcon: Icon(Icons.production_quantity_limits_outlined, color: _primaryColor)), // [cite: 111]
                  maxLines: 1, // [cite: 111]
                  maxLength: 5, // [cite: 111]
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly], // [cite: 111, 112]
                ),
                const SizedBox(height: 16), // [cite: 112]
                // MỚI: Thay thế TextField này bằng danh sách các component có thể sửa
                // nếu bạn xây dựng dialog chỉnh sửa chi tiết.
                TextField( // [cite: 113]
                  keyboardType: TextInputType.numberWithOptions(decimal: false), // [cite: 113]
                  controller: editUnitVariableCostController, // [cite: 113]
                  enabled: false, // THÊM DÒNG NÀY ĐỂ VÔ HIỆU HÓA // [cite: 113]
                  decoration: InputDecoration( // [cite: 113]
                      labelText: "Chi phí biến đổi/ĐV mới (Tổng)", // [cite: 114]
                      labelStyle: GoogleFonts.poppins(color: _textColorSecondary), // [cite: 114]
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), // [cite: 114]
                      filled: true, // [cite: 115]
                      // Cân nhắc đổi màu nền khi bị vô hiệu hóa để trực quan hơn
                      fillColor: Colors.grey.shade200, // THAY ĐỔI MÀU NỀN (TÙY CHỌN) // [cite: 115]
                      prefixIcon: Icon(Icons.local_atm_outlined, color: _primaryColor)), // [cite: 116]
                  maxLines: 1, // [cite: 116]
                  maxLength: 15, // [cite: 116]
                  inputFormatters: [ // [cite: 116]
                    FilteringTextInputFormatter.digitsOnly, // [cite: 117]
                    TextInputFormatter.withFunction((oldValue, newValue) { // [cite: 117]
                      // Input formatter vẫn có thể giữ nguyên vì controller sẽ được set giá trị ban đầu // [cite: 117]
                      // và không cho người dùng sửa đổi. // [cite: 117]
                      if (newValue.text.isEmpty) return newValue.copyWith(text: '0'); // [cite: 118]
                      final String plainNumberText = newValue.text.replaceAll('.', '').replaceAll(',', ''); // [cite: 118]
                      final number = int.tryParse(plainNumberText); // [cite: 118]
                      if (number == null) return oldValue; // [cite: 119]
                      final formattedText = internalPriceFormatter.format(number); // [cite: 119]
                      return newValue.copyWith( // [cite: 119]
                        text: formattedText, // [cite: 119]
                        selection: TextSelection.collapsed(offset: formattedText.length), // [cite: 120]
                      );
                    }),
                  ],
                ),
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), // [cite: 121]
          actions: [ // [cite: 121]
            TextButton( // [cite: 121]
              onPressed: () => Navigator.pop(dialogContext), // [cite: 121, 122]
              child: Text("Hủy", // [cite: 122]
                  style: GoogleFonts.poppins(color: _textColorSecondary, fontWeight: FontWeight.w500)), // [cite: 122]
            ),
            ElevatedButton( // [cite: 122]
              style: ElevatedButton.styleFrom( // [cite: 122]
                backgroundColor: _primaryColor, // [cite: 123]
                foregroundColor: Colors.white, // [cite: 123]
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), // [cite: 123]
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), // [cite: 123]
              ),
              onPressed: () {
                int newQuantity = int.tryParse(editQuantityController.text) ??
                    (transactionToEdit['quantity'] as int? ?? 1); // [cite: 124]
                if (newQuantity <= 0) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar( // [cite: 124]
                    SnackBar(
                        content: Text("Số lượng phải lớn hơn 0", style: GoogleFonts.poppins(color: Colors.white)), // [cite: 125, 126]
                        backgroundColor: _accentColor, // [cite: 126]
                        behavior: SnackBarBehavior.floating), // [cite: 126]
                  );
                  return; // [cite: 127]
                }
                // MỚI: newUnitVariableCost và updatedCogsComponents sẽ đến từ dialog chỉnh sửa chi tiết
                double newUnitVariableCost = double.tryParse( // [cite: 127, 128]
                    editUnitVariableCostController.text
                        .replaceAll('.', '')
                        .replaceAll(',', '')) ??
                    (transactionToEdit['unitVariableCost'] as double? ?? 0.0); // [cite: 128, 129]
                // Giả sử bạn có updatedCogsComponents từ dialog // [cite: 130]
                List<Map<String, dynamic>> updatedCogsComponents =
                List<Map<String, dynamic>>.from(
                    transactionToEdit['cogsComponentsUsed'] ?? []); // [cite: 130]
                // Và newUnitVariableCost là tổng của updatedCogsComponents // [cite: 131]
                // Nếu dialog chỉ trả về tổng, thì updatedCogsComponents cần được suy ra hoặc đánh dấu là đã ghi đè tổng // [cite: 131]
                if (newUnitVariableCost < 0) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar( // [cite: 131, 132]
                    SnackBar(
                        content: Text("Chi phí biến đổi/ĐV không hợp lệ", style: GoogleFonts.poppins(color: Colors.white)), // [cite: 132]
                        backgroundColor: _accentColor, // [cite: 132]
                        behavior: SnackBarBehavior.floating), // [cite: 133]
                  );
                  return; // [cite: 134]
                }

                List<Map<String, dynamic>> currentDailyVariableExpenses = List.from(appState.variableExpenseList.value); // [cite: 134]
                if (salesTransactionId != null) {
                  currentDailyVariableExpenses.removeWhere((expense) => // [cite: 135]
                  expense['sourceSalesTransactionId'] == salesTransactionId &&
                      (expense['source'] == 'AUTO_COGS_OVERRIDE' || // [cite: 135]
                          expense['source'] == 'AUTO_COGS_COMPONENT' || // [cite: 136]
                          expense['source'] == 'AUTO_COGS_ESTIMATED' || // [cite: 136]
                          expense['source'] == 'AUTO_COGS_COMPONENT_OVERRIDE')); // [cite: 136]
                  // MỚI // [cite: 137]
                } else {
                  print(
                      "Cảnh báo: Giao dịch doanh thu (chính) này không có ID, không thể tự động cập nhật COGS liên quan."); // [cite: 137]
                }

                double price = (transactionToEdit['price'] as num? ?? 0.0).toDouble(); // [cite: 138]
                transactionToEdit['quantity'] = newQuantity; // [cite: 139]
                transactionToEdit['total'] = price * newQuantity; // [cite: 140]
                transactionToEdit['unitVariableCost'] = newUnitVariableCost; // [cite: 141]
                transactionToEdit['totalVariableCost'] = newUnitVariableCost * newQuantity; // [cite: 142]

                List<Map<String, dynamic>> newAutoGeneratedCogs = []; // [cite: 143]
                if (salesTransactionId != null) { // [cite: 144]
                  String originalTransactionDate =
                      transactionToEdit['date'] as String? ??
                          DateTime.now().toIso8601String(); // [cite: 144, 145]
                  String productName =
                      transactionToEdit['name'] as String? ?? "Không rõ sản phẩm"; // [cite: 145, 146]

                  // MỚI: Xác định cogsSourceType dựa trên việc components có bị sửa đổi không // [cite: 146]
                  bool wasFlexibleInEdit =
                      transactionToEdit['cogsWasFlexible'] ?? false; // Lấy cờ flexible từ giao dịch gốc, hoặc từ dialog nếu cho phép sửa // [cite: 146, 147]
                  bool componentsWereModifiedInEdit = false; // Cần logic để xác định điều này từ dialog // [cite: 147]
                  String? newCogsSourceType; // [cite: 148, 149]
                  List<Map<String, dynamic>> finalCogsComponentsToUse = []; // [cite: 149]

                  // Nếu dialog chỉnh sửa chi tiết component được sử dụng: // [cite: 149]
                  // finalCogsComponentsToUse = dialog.getUpdatedComponents(); // [cite: 149]
                  // componentsWereModifiedInEdit = dialog.wereComponentsModified(); // [cite: 150]
                  // newUnitVariableCost = dialog.getUpdatedTotalUnitCost(); // [cite: 150]
                  // thì dùng finalCogsComponentsToUse thay cho transactionToEdit['cogsComponentsUsed'] ở dưới // [cite: 150]
                  // Tạm thời dùng logic cũ hơn nếu không có dialog chi tiết // [cite: 150]
                  List<dynamic>? rawOriginalCogsComponents =
                  transactionToEdit['cogsComponentsUsed'] as List<dynamic>?; // [cite: 151]
                  List<Map<String, dynamic>>? originalCogsComponents = // [cite: 151, 152]
                  rawOriginalCogsComponents
                      ?.map((item) => Map<String, dynamic>.from(item as Map)) // [cite: 152]
                      .toList(); // [cite: 152]

                  if (originalCogsComponents != null &&
                      originalCogsComponents.isNotEmpty) { // [cite: 153]
                    finalCogsComponentsToUse = originalCogsComponents; // Nên là component đã được sửa từ dialog // [cite: 153, 154]
                    // Giả sử componentsWereModifiedInEdit được xác định đúng // [cite: 154]
                    newCogsSourceType =
                    (wasFlexibleInEdit && componentsWereModifiedInEdit)
                        ? "AUTO_COGS_COMPONENT_OVERRIDE" // [cite: 154, 155]
                        : "AUTO_COGS_COMPONENT"; // [cite: 155]
                  } else if (newUnitVariableCost > 0) {
                    newCogsSourceType = "AUTO_COGS_OVERRIDE"; // Nếu không có component mà sửa tổng // [cite: 156]
                  }
                  transactionToEdit['cogsSourceType'] = newCogsSourceType; // [cite: 157]
                  transactionToEdit['cogsComponentsUsed'] =
                  finalCogsComponentsToUse.isNotEmpty
                      ? finalCogsComponentsToUse
                      : null; // [cite: 158]
                  // transactionToEdit['cogsWasFlexible'] = wasFlexibleInEdit; (cần cập nhật nếu dialog cho sửa cờ này) // [cite: 158]

                  if (newCogsSourceType == "AUTO_COGS_COMPONENT" ||
                      newCogsSourceType == "AUTO_COGS_COMPONENT_OVERRIDE") { // [cite: 159]
                    if (finalCogsComponentsToUse.isNotEmpty) {
                      double totalNewCalculatedVariableCostForSale = 0; // [cite: 159]
                      for (var component in finalCogsComponentsToUse) {
                        // Giả sử component đã có 'cost' là chi phí / đơn vị sản phẩm // [cite: 160]
                        double componentCostPerUnit = (component['cost']
                        as num? ??
                            component['costPerUnitForProduct'] as num? ??
                            0.0)
                            .toDouble(); // [cite: 160]
                        double newComponentAmount =
                            componentCostPerUnit * newQuantity; // [cite: 161]
                        if (newComponentAmount > 0) { // [cite: 161]
                          newAutoGeneratedCogs.add({ // [cite: 161]
                            "name":
                            "${component['name']} (Cho: $productName)", // [cite: 161]
                            "amount": newComponentAmount, // [cite: 162]
                            "date": originalTransactionDate, // [cite: 162]
                            "source": newCogsSourceType, // [cite: 162]
                            "sourceSalesTransactionId": salesTransactionId // [cite: 163]
                          });
                          totalNewCalculatedVariableCostForSale +=
                              newComponentAmount; // [cite: 164]
                        }
                      }
                      // Cập nhật lại CPBĐ của giao dịch chính nếu nó được tính lại từ component // [cite: 164]
                      if (newQuantity > 0 &&
                          finalCogsComponentsToUse.isNotEmpty) { // [cite: 165]
                        transactionToEdit['unitVariableCost'] =
                            totalNewCalculatedVariableCostForSale / newQuantity; // [cite: 165]
                        transactionToEdit['totalVariableCost'] =
                            totalNewCalculatedVariableCostForSale; // [cite: 166]
                      }
                    }
                  } else if (newCogsSourceType == "AUTO_COGS_OVERRIDE" ||
                      newCogsSourceType == "AUTO_COGS_ESTIMATED") { // [cite: 167]
                    // Nếu người dùng sửa tổng CPBĐ/ĐV // [cite: 167]
                    double totalNewCalculatedVariableCostForSale =
                        newUnitVariableCost * newQuantity; // [cite: 168]
                    if (totalNewCalculatedVariableCostForSale > 0) { // [cite: 169]
                      newAutoGeneratedCogs.add({ // [cite: 169]
                        "name": "Giá vốn hàng bán: $productName", // [cite: 169]
                        "amount": totalNewCalculatedVariableCostForSale, // [cite: 170]
                        "date": originalTransactionDate, // [cite: 170]
                        "source": newCogsSourceType, // [cite: 170]
                        "sourceSalesTransactionId": salesTransactionId // [cite: 170]
                      });
                    }
                  }
                }
                currentDailyVariableExpenses.addAll(newAutoGeneratedCogs); // [cite: 172]
                appState.variableExpenseList.value =
                    List.from(currentDailyVariableExpenses); // [cite: 173]
                ExpenseManager.saveVariableExpenses(
                    appState, currentDailyVariableExpenses) // [cite: 174, 175]
                    .then((_) {
                  double newTotalVariableExpense =
                  currentDailyVariableExpenses.fold(0.0,
                          (sum, item) => sum + (item['amount'] as num? ?? 0.0)); // [cite: 175]
                  appState.setExpenses(
                      appState.fixedExpense, newTotalVariableExpense); // [cite: 175]
                }).catchError((e) {
                  _showStyledSnackBar(
                      "Lỗi khi cập nhật chi phí biến đổi tự động: $e", // [cite: 176]
                      isError: true); // [cite: 176]
                });
                RevenueManager.saveTransactionHistory(
                    appState, "Doanh thu chính", transactions); // [cite: 177]
                Navigator.pop(dialogContext); // [cite: 178, 179]
                _showStyledSnackBar(
                    "Đã cập nhật: ${transactionToEdit['name']}. Giá vốn tự động đã được điều chỉnh."); // [cite: 179]
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
                ? Border.all(color: _primaryColor, width: 0.5)
                : null, // [cite: 185]
            boxShadow: isSelected // [cite: 185]
                ? [
              BoxShadow(
                  color: Colors.blue.withOpacity(0.1), // [cite: 186]
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
    final appState = Provider.of<AppState>(context); // [cite: 190]
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
            "Doanh thu chính", // [cite: 192]
            style: GoogleFonts.poppins( // [cite: 193]
                fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white),
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
                  child: Text("Lỗi tải dữ liệu sản phẩm", // [cite: 199]
                      style: GoogleFonts.poppins(color: _textColorSecondary))); // [cite: 199, 200]
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
                      priceController: priceController, // Controller cho giá BÁN // [cite: 203]
                      onAddTransaction: (selectedProduct, selectedPrice, // [cite: 203]
                          isFlexiblePrice) {
                        addTransaction( // [cite: 204]
                            appState, // [cite: 204]
                            appState.mainRevenueTransactions.value, // [cite: 205]
                            selectedProduct, // [cite: 205]
                            selectedPrice, // giá bán từ dropdown (nếu không flexible) // [cite: 205]
                            isFlexiblePrice // cờ giá bán linh hoạt // [cite: 206]
                          // Removed arguments for general variable expenses
                          // unitVarCost sẽ được tính bên trong addTransaction // [cite: 210]
                        );
                      },
                      appState: appState, // [cite: 211]
                      currencyFormat: currencyFormat, // [cite: 211]
                    ),
                    TransactionHistorySection( // [cite: 211]
                      key: const ValueKey('transactionHistory'), // [cite: 212]
                      transactionsNotifier: appState.mainRevenueTransactions, // [cite: 212]
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

class ProductInputSection extends StatefulWidget {
  final List<Map<String, dynamic>> productList; // [cite: 217]
  final TextEditingController quantityController; // [cite: 217]
  final TextEditingController priceController; // [cite: 218]
  final Function(String?, double, bool) onAddTransaction; // [cite: 218]
  final AppState appState; // [cite: 219]
  final NumberFormat currencyFormat; // [cite: 219]

  const ProductInputSection({
    Key? key, // [cite: 220]
    required this.productList, // [cite: 220]
    required this.quantityController, // [cite: 220]
    required this.priceController, // [cite: 220]
    required this.onAddTransaction, // [cite: 220]
    required this.appState, // [cite: 220]
    required this.currencyFormat, // [cite: 220]
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
    widget.priceController.text = _priceInputFormatter.format(0); // [cite: 235]
    widget.priceController.addListener(_onPriceOrQuantityChanged); // [cite: 236]
    widget.quantityController.addListener(_onPriceOrQuantityChanged); // [cite: 236]
    unitVariableCostController.text = _priceInputFormatter.format(0); // Khởi tạo CPBĐ/ĐV tổng // [cite: 238, 239]
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
    if (mounted) { // [cite: 244]
      setState(() {}); // Cập nhật UI (Tổng tiền ước tính) // [cite: 244, 245]
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

  // MỚI: Hàm tính toán và cập nhật TextField tổng CPBĐ/ĐV
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

  // void _updateVariableExpenseAmountController() { // MODIFIED: Entire function removed
  // }

  void resetForm() {
    setState(() {
      selectedProductId = null; // [cite: 276]
      isFlexiblePriceEnabled = false; // [cite: 276]
      selectedPriceFromDropdown = 0.0; // [cite: 276]
      widget.priceController.text = _priceInputFormatter.format(0); // [cite: 276]
      if (_priceFocusNode.hasFocus) _priceFocusNode.unfocus(); // [cite: 277]
      // if (_amountFocusNode.hasFocus) _amountFocusNode.unfocus(); // MODIFIED: Removed // [cite: 277]

      // MỚI: Reset CPBĐ/ĐV và các thành phần của nó // [cite: 277]
      isFlexibleUnitVariableCostEnabled = false; // [cite: 277]
      for (var component in _currentUnitVariableCostComponents) {
        (component['controller'] as TextEditingController?)?.dispose(); // [cite: 277]
        (component['focusNode'] as FocusNode?)?.dispose(); // [cite: 278]
      }
      _currentUnitVariableCostComponents = []; // [cite: 278]
      _lastLoadedCogsComponentsForProduct = []; // [cite: 279]
      unitVariableCostController.text = _priceInputFormatter.format(0); // [cite: 280]
      // if (_unitVariableCostFocusNode.hasFocus) _unitVariableCostFocusNode.unfocus(); // Không cần nữa // [cite: 281, 282]
    });
  }

  void _showStyledSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: isError
            ? _EditMainRevenueScreenState._accentColor
            : _EditMainRevenueScreenState._primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(10),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width; // [cite: 286]
    const Color primaryColor = _EditMainRevenueScreenState._primaryColor; // [cite: 287]
    const Color secondaryColor = _EditMainRevenueScreenState._secondaryColor; // [cite: 288]
    const Color textColorPrimary =
        _EditMainRevenueScreenState._textColorPrimary; // [cite: 289]
    const Color textColorSecondary =
        _EditMainRevenueScreenState._textColorSecondary; // [cite: 290]
    const Color cardBackgroundColor =
        _EditMainRevenueScreenState._cardBackgroundColor; // [cite: 291]

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
    final double estimatedTotalRevenue = currentSellingPrice * currentQuantity; // [cite: 296]

    // MỚI: Lấy CPBĐ/ĐV tổng từ controller (đã được cập nhật bởi _recalculateTotalUnitVariableCost) // [cite: 297]
    final double currentUnitVarCost = double.tryParse( // [cite: 297, 298]
        unitVariableCostController.text.replaceAll('.', '').replaceAll(',', '')) ??
        0.0; // [cite: 298]
    final double estimatedTotalVarCost = currentUnitVarCost * currentQuantity; // [cite: 299]
    final double estimatedGrossProfit =
        estimatedTotalRevenue - estimatedTotalVarCost; // [cite: 300]

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)), // [cite: 302]
            color: cardBackgroundColor, // [cite: 302]
            child: Padding( // [cite: 302]
              padding: const EdgeInsets.all(20.0), // [cite: 302]
              child: Column( // [cite: 302]
                crossAxisAlignment: CrossAxisAlignment.start, // [cite: 302]
                children: [
                  Text( // [cite: 303]
                    "Thêm giao dịch mới", // [cite: 303]
                    style: GoogleFonts.poppins( // [cite: 303]
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: primaryColor),
                  ),
                  const SizedBox(height: 24), // [cite: 305]
                  DropdownButtonFormField<String>( // [cite: 305]
                    value: selectedProductId, // [cite: 305]
                    decoration: InputDecoration( // [cite: 305]
                      labelText: "Sản phẩm/Dịch vụ", // [cite: 305, 306]
                      labelStyle: // [cite: 306]
                      GoogleFonts.poppins(color: textColorSecondary), // [cite: 307]
                      prefixIcon: const Icon(Icons.sell_outlined, // [cite: 307]
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
                      const DropdownMenuItem<String>( // [cite: 310]
                        value: null, // [cite: 310]
                        child: Text("Chưa có sản phẩm nào", // [cite: 310]
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
                        _updatePriceControllerBasedOnSelection(newValue); // Cập nhật giá bán // [cite: 316]
                        _loadProductVariableCostComponents(
                            newValue); // MỚI: Load thành phần CPBĐ/ĐV // [cite: 317]
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
                      labelText: "Giá bán sản phẩm/dịch vụ", // [cite: 332]
                      prefixIconData: Icons.price_change_outlined, // [cite: 332]
                      controller: widget.priceController, // Controller cho giá BÁN // [cite: 332]
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
                        FilteringTextInputFormatter.digitsOnly // [cite: 345]
                      ],
                      maxLength: 5, // [cite: 345]
                      onChanged: (_) { // [cite: 346]
                        if (mounted) setState(() {}); // [cite: 346]
                      }),
                  const SizedBox(height: 20), // [cite: 346]
                  // === PHẦN NHẬP LIỆU CHO CHI PHÍ BIẾN ĐỔI ĐƠN VỊ CỦA SẢN PHẨM === // [cite: 347]
                  Text("Chi phí biến đổi của sản phẩm:", // [cite: 347]
                      style: GoogleFonts.poppins( // [cite: 347, 348]
                          fontSize: 16,
                          color: textColorPrimary,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8), // [cite: 349]
                  SwitchListTile.adaptive( // [cite: 349]
                    title: Text( // [cite: 349]
                      "CPBĐ/ĐV linh hoạt", // [cite: 349]
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
                          // Reset các component về originalCost // [cite: 353]
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
                                .text = _priceInputFormatter.format(originalCost); // [cite: 355]
                            // Unfocus từng component // [cite: 356]
                            (_currentUnitVariableCostComponents[i]['focusNode']
                            as FocusNode)
                                .unfocus(); // [cite: 356]
                          }
                          _recalculateTotalUnitVariableCost(); // [cite: 357]
                        } else {
                          if (_currentUnitVariableCostComponents.isNotEmpty) { // [cite: 362]
                            (_currentUnitVariableCostComponents.first[
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
                  // MỚI: Hiển thị danh sách các thành phần CPBĐ/ĐV // [cite: 367]
                  if (selectedProductId != null &&
                      _currentUnitVariableCostComponents.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0, bottom: 4.0), // [cite: 367]
                      child: Column( // [cite: 368]
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ListView.builder(
                            shrinkWrap: true, // [cite: 370]
                            physics:
                            const NeverScrollableScrollPhysics(), // [cite: 370]
                            itemCount:
                            _currentUnitVariableCostComponents.length, // [cite: 371]
                            itemBuilder: (context, compIndex) {
                              final component =
                              _currentUnitVariableCostComponents[compIndex]; // [cite: 371]
                              final componentName = component['name'] as String; // [cite: 372]
                              final componentController =
                              component['controller']
                              as TextEditingController; // [cite: 372]
                              final componentFocusNode =
                              component['focusNode'] as FocusNode; // [cite: 372]
                              return Padding( // [cite: 373]
                                padding:
                                const EdgeInsets.symmetric(vertical: 5.0),
                                child: Row( // [cite: 373]
                                  crossAxisAlignment: CrossAxisAlignment.center, // [cite: 374]
                                  children: [
                                    Expanded( // [cite: 374]
                                        flex:
                                        2, // Cho tên nhiều không gian hơn // [cite: 375]
                                        child: Text( // [cite: 375]
                                          componentName, // [cite: 376]
                                          style: GoogleFonts.poppins(
                                              color: textColorPrimary
                                                  .withOpacity(0.9),
                                              fontSize: 14.5), // [cite: 376]
                                          overflow: TextOverflow.ellipsis, // [cite: 376]
                                        )),
                                    const SizedBox(width: 10), // [cite: 378]
                                    Expanded( // [cite: 378]
                                      flex: 3, // [cite: 378]
                                      child: _buildModernTextField( // [cite: 379]
                                        // labelText: "Giá trị", // Không cần label nếu đã có tên bên trái // [cite: 379]
                                        controller: componentController, // [cite: 380]
                                        enabled:
                                        isFlexibleUnitVariableCostEnabled, // [cite: 380]
                                        focusNode: componentFocusNode, // [cite: 381]
                                        keyboardType: TextInputType
                                            .numberWithOptions(decimal: false), // [cite: 381]
                                        inputFormatters: [ // [cite: 381]
                                          FilteringTextInputFormatter.digitsOnly, // [cite: 382, 383]
                                          TextInputFormatter.withFunction(
                                                  (oldValue, newValue) { // [cite: 383]
                                                if (newValue.text.isEmpty) {
                                                  return newValue.copyWith(
                                                      text: '0'); // [cite: 383]
                                                }
                                                final String plainNumberText =
                                                newValue.text
                                                    .replaceAll('.', '')
                                                    .replaceAll(',', ''); // [cite: 384]
                                                final number =
                                                int.tryParse(plainNumberText); // [cite: 384]
                                                if (number == null) return oldValue; // [cite: 385]
                                                // Listener đã được thêm vào controller ở _loadProductVariableCostComponents // [cite: 385]
                                                // để cập nhật state khi text thay đổi và isFlexibleUnitVariableCostEnabled // [cite: 386]
                                                // nên không cần setState trực tiếp ở đây nữa. // [cite: 386, 387]
                                                final formattedText =
                                                _priceInputFormatter
                                                    .format(number); // [cite: 387]
                                                return newValue.copyWith( // [cite: 387]
                                                  text: formattedText, // [cite: 388]
                                                  selection:
                                                  TextSelection.collapsed(
                                                      offset: formattedText
                                                          .length), // [cite: 388]
                                                );
                                              }),
                                        ],
                                        maxLength: 15, labelText: '', // [cite: 390]
                                        // Bỏ prefix icon để tiết kiệm không gian // [cite: 391]
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
                      labelText: "Tổng CPBĐ/ĐV (tự động)", // THAY ĐỔI: Label text // [cite: 394]
                      prefixIconData: Icons.local_atm_outlined, // [cite: 394]
                      controller: unitVariableCostController, // Controller cho CPBĐ/ĐV tổng // [cite: 395]
                      keyboardType: // [cite: 395]
                      TextInputType.numberWithOptions(decimal: false), // [cite: 395]
                      enabled: false, // THAY ĐỔI: TextField này chỉ đọc // [cite: 396]
                      // focusNode: _unitVariableCostFocusNode, // Không cần nữa // [cite: 396]
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
                            final number = int.tryParse(plainNumberText); // [cite: 400]
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

                  const SizedBox(height: 20), // [cite: 463]
                  Container( // [cite: 463]
                    width: double.infinity, // [cite: 464]
                    padding: const EdgeInsets.symmetric( // [cite: 464]
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration( // [cite: 464]
                        color: primaryColor.withOpacity(0.08), // [cite: 465]
                        borderRadius: BorderRadius.circular(12), // [cite: 465]
                        border: Border.all(
                            color: primaryColor.withOpacity(0.3))), // [cite: 465]
                    child: Column( // [cite: 465]
                      crossAxisAlignment: CrossAxisAlignment.start, // [cite: 466]
                      children: [ // [cite: 466]
                        Text( // [cite: 466]
                          "TỔNG DOANH THU (ƯỚC TÍNH):", // [cite: 467]
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
                          "TỔNG LN GỘP (ƯỚC TÍNH):", // [cite: 472]
                          style: GoogleFonts.poppins( // [cite: 472]
                              fontSize: 13, // [cite: 472]
                              fontWeight: FontWeight.w600, // [cite: 473, 474]
                              color: Colors.green.shade700.withOpacity(
                                  0.9), // Màu xanh cho lợi nhuận // [cite: 474, 475]
                              letterSpacing: 0.5), // [cite: 475]
                        ),
                        SizedBox(height: 4), // [cite: 475]
                        Text( // [cite: 476]
                          widget.currencyFormat.format(estimatedGrossProfit), // [cite: 476]
                          style: GoogleFonts.poppins( // [cite: 476]
                              fontSize: 22, // [cite: 477]
                              fontWeight: FontWeight.w700,
                              color: Colors.green.shade700), // Màu xanh // [cite: 477]
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
                      padding:
                      const EdgeInsets.symmetric(vertical: 14), // [cite: 481]
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
                      "Thêm giao dịch", // [cite: 482, 483]
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
    const Color primaryColor = _EditMainRevenueScreenState._primaryColor; // [cite: 485, 486]
    const Color secondaryColor = _EditMainRevenueScreenState._secondaryColor; // [cite: 486]
    const Color textColorSecondary =
        _EditMainRevenueScreenState._textColorSecondary; // [cite: 487]
    return TextField( // [cite: 488]
      controller: controller, // [cite: 488]
      enabled: enabled, // [cite: 488]
      keyboardType: keyboardType, // [cite: 488]
      inputFormatters: inputFormatters, // [cite: 488]
      maxLength: maxLength, // [cite: 488]
      focusNode: focusNode, // [cite: 488]
      onChanged: onChanged, // [cite: 488]
      style: GoogleFonts.poppins( // [cite: 488]
          color: _EditMainRevenueScreenState._textColorPrimary,
          fontWeight: FontWeight.w500,
          fontSize: 16),
      decoration: InputDecoration( // [cite: 489]
        labelText: labelText, // [cite: 489]
        labelStyle: GoogleFonts.poppins(color: textColorSecondary), // [cite: 489]
        prefixIcon: prefixIconData != null // [cite: 489]
            ? Icon(prefixIconData, color: primaryColor, size: 22) // [cite: 489]
            : null, // [cite: 490]
        border: OutlineInputBorder( // [cite: 490]
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300)), // [cite: 490, 491]
        enabledBorder: OutlineInputBorder( // [cite: 491]
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder( // [cite: 491]
            borderRadius: BorderRadius.circular(12), // [cite: 491, 492]
            borderSide: BorderSide(color: primaryColor, width: 1.5)),
        filled: true, // [cite: 492]
        fillColor: enabled // [cite: 492]
            ? secondaryColor.withOpacity(0.5) // [cite: 493]
            : Colors.grey.shade200, // [cite: 493, 494]
        contentPadding: // [cite: 494]
        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        counterText: "", // [cite: 494]
      ),
      maxLines: 1, // [cite: 494]
    );
  }
}

// TransactionHistorySection không thay đổi logic cốt lõi trong bản cập nhật này
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
                    "Chưa có giao dịch nào", // [cite: 503]
                    style: GoogleFonts.poppins( // [cite: 504]
                        fontSize: 17, color: textColorSecondary),
                  ),
                  SizedBox(height: 4), // [cite: 504]
                  Text( // [cite: 505]
                    "Thêm giao dịch mới để xem lịch sử tại đây.", // [cite: 505]
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
          DateTime dateA = DateTime.tryParse(a['date'] ?? '') ?? DateTime(1900); // [cite: 508]
          DateTime dateB = DateTime.tryParse(b['date'] ?? '') ?? DateTime(1900); // [cite: 508]
          return dateB.compareTo(dateA); // [cite: 508]
        });
        return SingleChildScrollView( // [cite: 509]
          padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 80.0), // [cite: 509]
          child: Column( // [cite: 509]
            crossAxisAlignment: CrossAxisAlignment.start, // [cite: 509]
            children: [
              Padding( // [cite: 509]
                padding: const EdgeInsets.only(bottom: 12.0), // [cite: 510]
                child: Text( // [cite: 510]
                  "Lịch sử giao dịch", // [cite: 510]
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
                  final double grossProfit = totalRevenue - totalVariableCost; // [cite: 516]
                  final double profitMargin = totalRevenue > 0 // [cite: 516]
                      ? (grossProfit / totalRevenue) * 100 // [cite: 517]
                      : 0.0; // [cite: 517]
                  return Dismissible( // [cite: 518]
                    key: Key(transaction['date'].toString() + // [cite: 518]
                        (transaction['name'] ?? 'unknown_product') + // [cite: 518]
                        index.toString()), // [cite: 519]
                    background: Container( // [cite: 519]
                      color: // [cite: 519]
                      _EditMainRevenueScreenState._accentColor.withOpacity(0.8), // [cite: 519]
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
                        visualDensity: VisualDensity.adaptivePlatformDensity, // [cite: 525]
                        leading: CircleAvatar( // [cite: 526]
                          backgroundColor: primaryColor.withOpacity(0.15), // [cite: 526]
                          radius: 22, // [cite: 526]
                          child: Text( // [cite: 527]
                            transaction['name'] != null && // [cite: 527]
                                (transaction['name'] as String).isNotEmpty // [cite: 527]
                                ? (transaction['name'] as String)[0] // [cite: 528, 529]
                                .toUpperCase() // [cite: 529]
                                : "?", // [cite: 529]
                            style: GoogleFonts.poppins( // [cite: 530]
                                color: primaryColor,
                                fontWeight: FontWeight.w600, // [cite: 530]
                                fontSize: 18), // [cite: 531]
                          ),
                        ),
                        title: Text( // [cite: 531]
                          transaction['name']?.toString() ?? 'N/A', // [cite: 532]
                          style: GoogleFonts.poppins( // [cite: 532]
                              fontSize: 15.5, // [cite: 532]
                              fontWeight: FontWeight.w600, // [cite: 533]
                              color: textColorPrimary),
                          overflow: TextOverflow.ellipsis, // [cite: 533]
                        ),
                        subtitle: Padding( // [cite: 534]
                          padding: const EdgeInsets.only(top: 4.0), // [cite: 534]
                          child: Column( // [cite: 534]
                            crossAxisAlignment: CrossAxisAlignment.start, // [cite: 535]
                            mainAxisSize: MainAxisSize.min, // [cite: 535]
                            children: [ // [cite: 535]
                              Text( // [cite: 536]
                                "SL: ${transaction['quantity']} x ${currencyFormat.format(transaction['price'] ?? 0.0)}", // [cite: 536, 537]
                                style: GoogleFonts.poppins( // [cite: 537]
                                    fontSize: 12.0,
                                    color: textColorSecondary), // [cite: 537]
                              ),
                              Text( // [cite: 538]
                                "Tổng DT: ${currencyFormat.format(totalRevenue)}", // [cite: 538]
                                style: GoogleFonts.poppins( // [cite: 539]
                                    fontSize: 13.0, // [cite: 539]
                                    color: primaryColor, // [cite: 539]
                                    fontWeight: FontWeight.w500), // [cite: 540]
                              ),
                              if (transaction
                                  .containsKey('totalVariableCost')) // [cite: 540]
                                Padding( // [cite: 541]
                                  padding: const EdgeInsets.only(top: 2.0), // [cite: 541]
                                  child: Text( // [cite: 542]
                                    "Tổng CPBĐ: ${currencyFormat.format(totalVariableCost)}", // [cite: 542]
                                    style: GoogleFonts.poppins( // [cite: 542, 543]
                                        fontSize: 12.0, // [cite: 543]
                                        color: textColorSecondary // [cite: 543]
                                            .withOpacity(0.9)),
                                  ),
                                ),
                              if (transaction
                                  .containsKey('totalVariableCost')) // [cite: 545]
                                Padding( // [cite: 545]
                                  padding:
                                  const EdgeInsets.only(top: 2.0), // [cite: 545, 546]
                                  child: Text( // [cite: 546]
                                    "LN Gộp: ${currencyFormat.format(grossProfit)} (${profitMargin.toStringAsFixed(1)}%)", // [cite: 546]
                                    style: GoogleFonts.poppins( // [cite: 547]
                                        fontSize: 13.0, // [cite: 547]
                                        color: Colors.green.shade700, // [cite: 548]
                                        fontWeight: FontWeight.w500), // [cite: 548]
                                  ),
                                ),
                              if (transaction['date'] != null) // [cite: 549]
                                Padding( // [cite: 549]
                                  padding:
                                  const EdgeInsets.only(top: 3.0), // [cite: 550]
                                  child: Text( // [cite: 550]
                                    DateFormat('dd/MM/yy HH:mm').format( // [cite: 551]
                                        DateTime.parse(transaction['date'])), // [cite: 551, 552]
                                    style: GoogleFonts.poppins( // [cite: 552, 553]
                                        fontSize: 10.5, // [cite: 553]
                                        color: textColorSecondary // [cite: 553]
                                            .withOpacity(0.8)), // [cite: 554]
                                  ),
                                ),
                            ],
                          ),
                        ),
                        trailing: IconButton( // [cite: 556]
                          icon: Icon(Icons.edit_note_outlined, // [cite: 556]
                              color: primaryColor.withOpacity(0.8),
                              size: 24), // [cite: 556]
                          onPressed: () { // [cite: 556]
                            if (originalIndex != -1) { // [cite: 557]
                              onEditTransaction(appState, // [cite: 557]
                                  transactionsNotifier.value, originalIndex); // [cite: 558]
                            }
                          },
                          splashRadius: 20, // [cite: 558]
                          padding: EdgeInsets.zero, // [cite: 559, 560]
                          constraints: // [cite: 560]
                          BoxConstraints(minWidth: 36, minHeight: 36), // [cite: 560]
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