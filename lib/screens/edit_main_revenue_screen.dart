import 'package:fingrowth/screens/report_screen.dart';
import 'package:fingrowth/screens/subscription_screen.dart';
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
  late Future<List<Map<String, dynamic>>> _loadProductsFuture;
  int _selectedTab = 0; // [cite: 7]
  late AppState _appState; // [cite: 7]
  final GlobalKey<_ProductInputSectionState> _productInputSectionKey =
  GlobalKey<_ProductInputSectionState>(); // [cite: 8]

  final currencyFormat =
  NumberFormat.currency(locale: 'vi_VN', symbol: 'VNĐ'); // [cite: 15]

  @override
  void initState() {
    super.initState();
    _appState = Provider.of<AppState>(context, listen: false);
    _loadProductsFuture = RevenueManager.loadProducts(_appState, "Doanh thu chính");
    quantityController.text = "1"; // [cite: 16]
    _animationController = AnimationController(
        duration: const Duration(milliseconds: 300), vsync: this); // [cite: 17]
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
        CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack)); // [cite: 18]
    _animationController.forward(); // [cite: 19]
    _appState = Provider.of<AppState>(context, listen: false); // [cite: 19]
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
    super.dispose(); // [cite: 26]
  }

  void _showStyledSnackBar(String message, {bool isError = false}) {
    if (!mounted) return; // [cite: 27]
    ScaffoldMessenger.of(context).showSnackBar( // [cite: 28]
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins(color: Colors.white)), // [cite: 28]
        backgroundColor: isError ? AppColors.chartRed : AppColors.primaryBlue, // [cite: 28]
        behavior: SnackBarBehavior.floating, // [cite: 28]
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), // [cite: 28]
        margin: const EdgeInsets.all(10), // [cite: 28]
      ),
    );
  }

  // THAY ĐỔI: Cập nhật hàm addTransaction
  // Dán vào class _EditMainRevenueScreenState trong file edit_main_revenue_screen.docx

  void addTransaction(
      AppState appState,
      String? selectedProduct,
      double currentSelectedPriceInDropdown,
      bool isFlexiblePriceEnabled,
      bool isCashReceived,
      String? walletId,
      DateTime cashReceivedDate,
      bool isCashSpent,
      String? spendingWalletId,
      DateTime cashSpentDate,
      ) {

    final now = DateTime.now();
    final correctTransactionDate = DateTime(
        appState.selectedDate.year,
        appState.selectedDate.month,
        appState.selectedDate.day,
        now.hour,
        now.minute,
        now.second
    );
    final correctDateString = correctTransactionDate.toIso8601String();
    final actualPaymentDateString = cashReceivedDate.toIso8601String();
    final actualSpendingDateString = cashSpentDate.toIso8601String();
    // --- PHẦN 1 & 2: VALIDATE VÀ CHUẨN BỊ DỮ LIỆU ---
    if (selectedProduct == null) {
      _showStyledSnackBar("Vui lòng chọn sản phẩm/dịch vụ!", isError: true);
      return;
    }
    final productInputState = _productInputSectionKey.currentState;
    if (productInputState == null) {
      _showStyledSnackBar("Không tìm thấy sản phẩm.", isError: true);
      return;
    }
    double priceToUse;
    if (isFlexiblePriceEnabled) {
      priceToUse = double.tryParse(priceController.text.replaceAll('.', '').replaceAll(',', '')) ?? 0.0;
      if (priceToUse <= 0.0) {
        _showStyledSnackBar("Vui lòng nhập giá trị hợp lệ cho giá bán!", isError: true);
        return;
      }
    } else {
      priceToUse = currentSelectedPriceInDropdown;
      if (priceToUse <= 0.0) {
        _showStyledSnackBar("Giá sản phẩm không hợp lệ trong danh mục!", isError: true);
        return;
      }
    }

    // SỬA LỖI Ở ĐÂY: Đảm bảo quantity là int để validation, nhưng khi lưu sẽ là double
    final int quantity = int.tryParse(quantityController.text) ?? 1;
    if (quantity <= 0) {
      _showStyledSnackBar("Số lượng phải lớn hơn 0!", isError: true);
      return;
    }

    double totalRevenueForSale = priceToUse * quantity;
    if (!appState.isSubscribed && (appState.totalRevenueListenable.value + totalRevenueForSale > 2000000)) {
      _showUpgradeDialog(context);
      return;
    }
    var uuid = Uuid();
    String transactionId = uuid.v4();
    List<Map<String, dynamic>> currentUnitCostComponents = productInputState.currentUnitVariableCostComponents;
    double unitVariableCostForSale = 0;
    List<Map<String, dynamic>> cogsComponentsForStorage = [];
    for (var component in currentUnitCostComponents) {
      double cost = component['cost'] as double? ?? 0.0;
      unitVariableCostForSale += cost;
      cogsComponentsForStorage.add({
        'name': component['name'],
        'cost': cost,
        'originalCost': component['originalCost']
      });
    }
    double totalUnitVariableCostForSale = unitVariableCostForSale * quantity;
    String? cogsSourceType;
    bool cogsWasFlexible = productInputState.isUnitVariableCostFlexible;
    double cogsDefaultCostAtTimeOfSale = 0;
    bool isAnyComponentModified = false;
    for (var component in currentUnitCostComponents) {
      double currentCost = component['cost'] as double? ?? 0.0;
      double originalCost = component['originalCost'] as double? ?? 0.0;
      cogsDefaultCostAtTimeOfSale += originalCost;
      if (currentCost != originalCost) {
        isAnyComponentModified = true;
      }
    }
    List<Map<String, dynamic>>? cogsComponentsUsed = cogsComponentsForStorage.isNotEmpty ? cogsComponentsForStorage : null;
    if (cogsComponentsUsed != null && cogsComponentsUsed.isNotEmpty) {
      cogsSourceType = (cogsWasFlexible && isAnyComponentModified)
          ? "AUTO_COGS_COMPONENT_OVERRIDE"
          : "AUTO_COGS_COMPONENT";
    } else if (unitVariableCostForSale > 0) {
      cogsSourceType = "AUTO_COGS_ESTIMATED";
    }

    Map<String, dynamic> newSalesTransaction = {
      "id": transactionId,
      "name": selectedProduct,
      "category": "Doanh thu chính",
      "price": priceToUse,
      "quantity": quantity.toDouble(), // SỬA LỖI Ở ĐÂY: Chuyển sang double
      "total": totalRevenueForSale,
      "date": correctDateString,
      if (isCashReceived) "paymentDate": actualPaymentDateString,
      "unitVariableCost": unitVariableCostForSale,
      "totalVariableCost": totalUnitVariableCostForSale,
      "createdBy": appState.authUserId,
      if (cogsSourceType != null) "cogsSourceType": cogsSourceType,
      "cogsWasFlexible": cogsWasFlexible,
      if (cogsDefaultCostAtTimeOfSale > 0 && cogsComponentsUsed != null)
        "cogsDefaultCostAtTimeOfSale": cogsDefaultCostAtTimeOfSale,
      if (cogsComponentsUsed != null && cogsComponentsUsed.isNotEmpty)
        "cogsComponentsUsed": cogsComponentsUsed,
    };

    List<Map<String, dynamic>> autoGeneratedExpenseTransactions = [];
    if (cogsSourceType == "AUTO_COGS_COMPONENT" || cogsSourceType == "AUTO_COGS_COMPONENT_OVERRIDE") {
      if (cogsComponentsUsed != null) {
        for (var component in cogsComponentsUsed) {
          double componentCostForTransaction = (component['cost'] as double? ?? 0.0) * quantity;
          if (componentCostForTransaction > 0) {
            autoGeneratedExpenseTransactions.add({
              "name": "${component['name']} (Cho: $selectedProduct)",
              "amount": componentCostForTransaction,
              "date": correctDateString,
              "source": cogsSourceType,
              "sourceSalesTransactionId": transactionId,
              if (isCashSpent) "paymentDate": actualSpendingDateString,
            });
          }
        }
      }
    } else if (cogsSourceType == "AUTO_COGS_ESTIMATED" || cogsSourceType == "AUTO_COGS_OVERRIDE") {
      if (totalUnitVariableCostForSale > 0) {
        autoGeneratedExpenseTransactions.add({
          "name": "Giá vốn hàng bán (${cogsSourceType == "AUTO_COGS_OVERRIDE" ? "Ghi đè" : "Ước tính"}): $selectedProduct",
          "amount": totalUnitVariableCostForSale,
          "date": correctDateString,
          "source": cogsSourceType,
          "sourceSalesTransactionId": transactionId
        });
      }
    }

    // --- PHẦN 3: GỌI HÀM CẬP NHẬT TẬP TRUNG ---
    appState.addTransactionAndUpdateState(
      category: 'Doanh thu chính',
      newSalesTransaction: newSalesTransaction,
      autoGeneratedCogs: autoGeneratedExpenseTransactions,
      isCashReceived: isCashReceived,
      walletId: walletId,
      isCashSpent: isCashSpent,
      spendingWalletId: spendingWalletId,
    ).then((_) {
      _showStyledSnackBar("Đã thêm giao dịch: $selectedProduct");
      if (autoGeneratedExpenseTransactions.isNotEmpty) {
        _showStyledSnackBar("Đã tự động ghi nhận giá vốn cho $selectedProduct");
      }
    }).catchError((e) {
      _showStyledSnackBar("Lỗi khi thêm giao dịch", isError: true);
    });

    // --- PHẦN 4: RESET FORM ---
    if (mounted) {
      setState(() {
        quantityController.text = "1";
      });
      _productInputSectionKey.currentState?.resetForm();
    }
  }

  void _showCollectPaymentDialog(BuildContext context, AppState appState, Map<String, dynamic> transaction) {
    String? selectedWalletId;
    // BIẾN STATE MỚI: Lưu ngày thanh toán được chọn, mặc định là hôm nay
    DateTime paymentDate = DateTime.now();

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            title: Text('Xác nhận Thu tiền', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Giao dịch: "${transaction['name']}"'),
                const SizedBox(height: 4),
                Text('Số tiền: ${currencyFormat.format(transaction['total'] ?? 0.0)}', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),

                // THÊM MỚI: Giao diện chọn ngày thanh toán
                InkWell(
                  onTap: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: paymentDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null && picked != paymentDate) {
                      setDialogState(() {
                        paymentDate = picked;
                      });
                    }
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Ngày thực thu',
                      prefixIcon: Icon(Icons.calendar_today, color: AppColors.primaryBlue), // Thay AppColors.chartGreen cho màn hình DTP nếu cần
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      DateFormat('dd/MM/yyyy').format(paymentDate),
                      style: GoogleFonts.poppins(fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Widget chọn ví tiền (giữ nguyên)
                ValueListenableBuilder<List<Map<String, dynamic>>>(
                  valueListenable: appState.wallets,
                  builder: (context, walletList, child) {
                    if (walletList.isEmpty) return const Text("Vui lòng tạo ví tiền trước.");
                    selectedWalletId ??= appState.defaultWallet?['id'] ?? walletList.first['id'];
                    return DropdownButtonFormField<String>(
                      value: selectedWalletId,
                      items: walletList.map((w) => DropdownMenuItem<String>(value: w['id'] as String, child: Text(w['name']))).toList(),
                      onChanged: (val) => setDialogState(() => selectedWalletId = val),
                      decoration: InputDecoration(
                        labelText: 'Thu vào ví',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    );
                  },
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Hủy')),
              ElevatedButton(
                onPressed: () async {
                  if (selectedWalletId != null) {
                    try {
                      // CẬP NHẬT: Truyền `paymentDate` do người dùng chọn vào hàm
                      await appState.collectPaymentForTransaction(
                        category: transaction['category'], // Lấy category từ chính giao dịch
                        transactionToUpdate: transaction,
                        paymentDate: paymentDate, // << SỬ DỤNG NGÀY ĐÃ CHỌN
                        walletId: selectedWalletId!,
                        transactionRecordDate: DateTime.parse(transaction['date']),
                      );
                      Navigator.pop(dialogContext);
                      _showStyledSnackBar("Đã ghi nhận thu tiền thành công!");
                    } catch (e) {
                      _showStyledSnackBar("Lỗi khi thu tiền: $e", isError: true);
                    }
                  }
                },
                child: const Text('Xác nhận'),
              ),
            ],
          );
        },
      ),
    );
  }

  // Thay thế hàm removeTransaction ở cả 3 màn hình bằng hàm này

  void deleteTransaction(int index) {
    // _appState là biến đã có sẵn trong State, không cần truyền vào nữa
    final transactionsNotifier = _appState.mainRevenueTransactions;

    if (index < 0 || index >= transactionsNotifier.value.length) return;
    final transactionToRemove = transactionsNotifier.value[index];

    _appState.deleteTransactionAndUpdateAll(
      transactionToRemove: transactionToRemove,
    ).then((_) {
      if (mounted) {
        _showStyledSnackBar(
          "Đã xóa: ${transactionToRemove['name']}. Mọi dữ liệu liên quan đã được cập nhật.",
        );
      }
    }).catchError((e) {
      if (mounted) {
        _showStyledSnackBar("Lỗi khi xóa giao dịch: $e", isError: true);
      }
    });
  }

  void _showUpgradeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text("Vượt giới hạn doanh thu", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text(
          "Người dùng miễn phí chỉ có thể ghi nhận tối đa 2.000.000đ doanh thu mỗi ngày. Vui lòng nâng cấp để ghi nhận không giới hạn.",
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            child: Text("Để sau", style: GoogleFonts.poppins()),
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue),
            child: Text("Nâng cấp ngay", style: GoogleFonts.poppins(color: Colors.white)),
            onPressed: () {
              Navigator.of(dialogContext).pop(); // Đóng dialog
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const SubscriptionScreen(),
              ));
            },
          ),
        ],
      ),
    );
  }


  // Thay thế toàn bộ hàm editTransaction trong _EditMainRevenueScreenState
  void editTransaction(AppState appState, List<Map<String, dynamic>> transactions, int index) {
    if (index < 0 || index >= transactions.length) return;

    final transactionToEdit = transactions[index];
    final String? salesTransactionId = transactionToEdit['id'] as String?;
    final num quantity = transactionToEdit['quantity'] as num? ?? 1;
    final String quantityText = quantity.truncateToDouble() == quantity ? quantity.toInt().toString() : quantity.toString();
    final TextEditingController editQuantityController = TextEditingController(text: quantityText);
    final NumberFormat internalPriceFormatter = NumberFormat("#,##0", "vi_VN");
    final TextEditingController editUnitVariableCostController = TextEditingController(
        text: internalPriceFormatter.format(transactionToEdit['unitVariableCost'] ?? 0.0));

    showDialog(
      context: context,
      builder: (dialogContext) => GestureDetector(
        onTap: () => FocusScope.of(dialogContext).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text("Chỉnh sửa: ${transactionToEdit['name']}",
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: AppColors.getTextColor(context))),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  keyboardType: TextInputType.number,
                  controller: editQuantityController,
                  decoration: InputDecoration(
                      labelText: "Nhập số lượng mới",
                      labelStyle: GoogleFonts.poppins(color: AppColors.getTextSecondaryColor(context)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: AppColors.getBackgroundColor(context),
                      prefixIcon: Icon(Icons.production_quantity_limits_outlined, color: AppColors.primaryBlue)),
                  maxLines: 1,
                  maxLength: 5,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                const SizedBox(height: 16),
                TextField(
                  keyboardType: TextInputType.numberWithOptions(decimal: false),
                  controller: editUnitVariableCostController,
                  enabled: false,
                  decoration: InputDecoration(
                      labelText: "Chi phí biến đổi/ĐV mới (Tổng)",
                      labelStyle: GoogleFonts.poppins(color: AppColors.getTextSecondaryColor(context)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: AppColors.getBackgroundColor(context),
                      prefixIcon: Icon(Icons.local_atm_outlined, color: AppColors.primaryBlue)),
                  maxLines: 1,
                ),
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text("Hủy", style: GoogleFonts.poppins(color: AppColors.getTextSecondaryColor(context), fontWeight: FontWeight.w500)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              onPressed: () {
                // PHẦN 1: CHUẨN BỊ DỮ LIỆU
                int newQuantity = int.tryParse(editQuantityController.text) ?? (transactionToEdit['quantity'] as int? ?? 1);
                if (newQuantity <= 0) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(content: Text("Số lượng phải lớn hơn 0")));
                  return;
                }

                final bool revenueWasPaid = transactionToEdit['paymentStatus'] == 'paid';
                final String? walletId = transactionToEdit['walletId'] as String?;

                double price = (transactionToEdit['price'] as num? ?? 0.0).toDouble();
                double unitVariableCost = (transactionToEdit['unitVariableCost'] as double? ?? 0.0);
                Map<String, dynamic> updatedTransaction = Map.from(transactionToEdit);
                updatedTransaction['quantity'] = newQuantity;
                updatedTransaction['total'] = price * newQuantity;
                updatedTransaction['totalVariableCost'] = unitVariableCost * newQuantity;

                List<Map<String, dynamic>> newAutoGeneratedCogs = [];
                if (salesTransactionId != null) {
                  final String? originalCogsSourceType = updatedTransaction['cogsSourceType'] as String?;
                  final List<dynamic>? rawCogs = updatedTransaction['cogsComponentsUsed'] as List<dynamic>?;
                  final List<Map<String, dynamic>>? components = rawCogs?.map((i) => Map<String, dynamic>.from(i as Map)).toList();

                  if (components != null && components.isNotEmpty) {
                    for (var component in components) {
                      double componentCost = (component['cost'] as num? ?? 0.0).toDouble();
                      double newComponentAmount = componentCost * newQuantity;
                      if(newComponentAmount > 0) {
                        newAutoGeneratedCogs.add({
                          "name": "${component['name']} (Cho: ${updatedTransaction['name']})",
                          "amount": newComponentAmount,
                          "date": updatedTransaction['date'],
                          "source": originalCogsSourceType,
                          "sourceSalesTransactionId": salesTransactionId,
                          // === PHẦN SỬA LỖI QUAN TRỌNG ===
                          if (revenueWasPaid && walletId != null) ...{
                            'paymentStatus': 'paid',
                            'walletId': walletId,
                            'paymentDate': transactionToEdit['paymentDate'] ?? DateTime.now().toIso8601String(),
                          } else ...{
                            'paymentStatus': 'unpaid',
                          }
                          // ==============================
                        });
                      }
                    }
                  } else if (unitVariableCost > 0){
                    newAutoGeneratedCogs.add({
                      "name": "Giá vốn hàng bán: ${updatedTransaction['name']}",
                      "amount": updatedTransaction['totalVariableCost'],
                      "date": updatedTransaction['date'],
                      "source": originalCogsSourceType,
                      "sourceSalesTransactionId": salesTransactionId,
                      // === PHẦN SỬA LỖI QUAN TRỌNG ===
                      if (revenueWasPaid && walletId != null) ...{
                        'paymentStatus': 'paid',
                        'walletId': walletId,
                        'paymentDate': transactionToEdit['paymentDate'] ?? DateTime.now().toIso8601String(),
                      } else ...{
                        'paymentStatus': 'unpaid',
                      }
                      // ==============================
                    });
                  }
                }

                // PHẦN 2: GỌI HÀM CẬP NHẬT TẬP TRUNG
                appState.editTransactionAndUpdateState(
                  category: transactionToEdit['category'] as String,
                  originalTransaction: transactionToEdit,
                  updatedTransaction: updatedTransaction,
                  newCogsTransactions: newAutoGeneratedCogs,
                ).then((_) {
                  if (mounted) {
                    _showStyledSnackBar("Đã cập nhật: ${transactionToEdit['name']}. Giá vốn tự động đã được điều chỉnh.");
                  }
                }).catchError((e) {
                  if (mounted) {
                    _showStyledSnackBar("Lỗi khi cập nhật: $e", isError: true);
                  }
                });

                Navigator.pop(dialogContext);
              },
              child: Text("Lưu", style: GoogleFonts.poppins()),
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
            color: isSelected ? AppColors.getCardColor(context) : AppColors.primaryBlue, // [cite: 183]
            borderRadius: BorderRadius.only( // [cite: 183]
              topLeft: isFirst ? const Radius.circular(12) : Radius.zero, // [cite: 183]
              bottomLeft: isFirst ? const Radius.circular(12) : Radius.zero, // [cite: 184]
              topRight: isLast ? const Radius.circular(12) : Radius.zero, // [cite: 184]
              bottomRight: // [cite: 184]
              isLast ? const Radius.circular(12) : Radius.zero, // [cite: 184]
            ),
            border: isSelected
                ? Border.all(color: AppColors.primaryBlue, width: 0.5)
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
                  ? AppColors.primaryBlue // [cite: 188]
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
    //final appState = Provider.of<AppState>(context)
    final appState = context.read<AppState>();
    return GestureDetector( // [cite: 191]
      onTap: () => FocusScope.of(context).unfocus(), // [cite: 191]
      behavior: HitTestBehavior.opaque, // [cite: 191]
      child: Scaffold( // [cite: 191]
        backgroundColor: AppColors.getBackgroundColor(context), // [cite: 191]
        appBar: AppBar( // [cite: 191]
          backgroundColor: AppColors.primaryBlue, // [cite: 191]
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
                  color: AppColors.primaryBlue, // [cite: 195]
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
        body: ValueListenableBuilder<int>(
          valueListenable: appState.permissionVersion, // Lắng nghe tín hiệu thay đổi quyền
          builder: (context, permissionVersion, child) {
            // Logic kiểm tra quyền được đặt bên trong builder
            final bool canEditThisRevenue = appState.hasPermission('canEditRevenue');

            // Trả về phần body cũ, nhưng giờ các quyền đã được cập nhật real-time
            return FutureBuilder<List<Map<String, dynamic>>>(
              future: _loadProductsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                      child: CircularProgressIndicator(color: AppColors.primaryBlue));
                }
                if (snapshot.hasError) {
                  return Center(
                      child: Text("Lỗi tải dữ liệu sản phẩm",
                          style: GoogleFonts.poppins(
                              color: AppColors.getTextSecondaryColor(context))));
                }
                List<Map<String, dynamic>> productList = snapshot.data ?? [];

                return ScaleTransition(
                    scale: _scaleAnimation,
                    child: IndexedStack(
                      index: _selectedTab,
                      children: [
                        ProductInputSection(
                          key: _productInputSectionKey,
                          productList: productList,
                          quantityController: quantityController,
                          priceController: priceController,
                          onAddTransaction: canEditThisRevenue
                              ? (selectedProduct, selectedPrice, isFlexiblePrice, isCashReceived, walletId, cashReceivedDate, isCashSpent, spendingWalletId, cashSpentDate) {
                            addTransaction(
                              appState,
                              selectedProduct,
                              selectedPrice,
                              isFlexiblePrice,
                              isCashReceived,
                              walletId,
                              cashReceivedDate,   // << Truyền vào
                              isCashSpent,
                              spendingWalletId,
                              cashSpentDate,    // << Truyền vào
                            );
                          }
                              : null,
                          appState: appState,
                          currencyFormat: currencyFormat,
                          // Thêm dòng này để truyền màu chính của màn hình
                          screenPrimaryColor: AppColors.primaryBlue,
                        ),
                        TransactionHistorySection(
                          key: const ValueKey('transactionHistory'),
                          transactionsNotifier: appState.mainRevenueTransactions,
                          // `canEditThisRevenue` cũng được cập nhật cho các hành động sửa/xóa
                          onEditTransaction: canEditThisRevenue ? editTransaction : null,
                          onRemoveTransaction: canEditThisRevenue ? deleteTransaction : null,

                          appState: appState,
                          currencyFormat: currencyFormat,
                          primaryColor: AppColors.primaryBlue,
                          textColorPrimary: AppColors.getTextColor(context),
                          textColorSecondary: AppColors.getTextSecondaryColor(context),
                          cardBackgroundColor: AppColors.getCardColor(context),
                        ),
                      ],
                    ));
              },
            );
          },
        ),
      ),
    );
  }
}

class ProductInputSection extends StatefulWidget {
  final List<Map<String, dynamic>> productList;
  final TextEditingController quantityController;
  final TextEditingController priceController;
  // --- THAY ĐỔI CHỮ KÝ HÀM ---
  final Function(String?, double, bool, bool, String?, DateTime, bool, String?, DateTime)? onAddTransaction;
  final AppState appState;
  final NumberFormat currencyFormat;
  // --- THÊM THUỘC TÍNH MỚI ---
  final Color screenPrimaryColor;

  const ProductInputSection({
    Key? key,
    required this.productList,
    required this.quantityController,
    required this.priceController,
    required this.onAddTransaction,
    required this.appState,
    required this.currencyFormat,
    required this.screenPrimaryColor, // Thêm vào constructor
  }) : super(key: key);

  @override
  _ProductInputSectionState createState() => _ProductInputSectionState();
}

class _ProductInputSectionState extends State<ProductInputSection> {
  bool _isCashSpent = false;
  String? _selectedSpendingWalletId;
  bool _isCashReceived = true;
  String? _selectedWalletId;
  DateTime _cashReceivedDate = DateTime.now();
  DateTime _cashSpentDate = DateTime.now();
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

  Future<void> _loadProductVariableCostComponents(String? productId, double sellingPrice) async {
    // Dọn dẹp state cũ
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
      // Tải danh sách các khoản chi phí biến đổi có sẵn
      List<Map<String, dynamic>> allAvailableExpenses =
      await ExpenseManager.loadAvailableVariableExpenses(widget.appState);

      // Lọc ra các chi phí đã được "Gắn" với sản phẩm này
      List<Map<String, dynamic>> productSpecificComponents = allAvailableExpenses
          .where((expense) => expense['linkedProductId'] == productId)
          .toList();

      for (var expenseComponent in productSpecificComponents) {
        String name = expenseComponent['name']?.toString() ?? 'Không rõ';

        // =================================================================
        // <<< SỬA LỖI VÀ CẬP NHẬT LOGIC TÍNH TOÁN NẰM Ở ĐÂY >>>
        //
        // Đọc loại chi phí và giá trị từ cấu trúc dữ liệu mới
        final String costType = expenseComponent['costType']?.toString() ?? 'fixed';
        final double costValue = (expenseComponent['costValue'] as num? ?? 0.0).toDouble();
        double calculatedCost = 0.0; // Chi phí thực tế sau khi tính toán

        if (costType == 'percentage') {
          // Nếu là %, tính chi phí dựa trên giá bán của giao dịch
          calculatedCost = sellingPrice * (costValue / 100.0);
        } else {
          // Nếu là 'fixed', lấy thẳng giá trị đã lưu
          calculatedCost = costValue;
        }
        //
        // <<< KẾT THÚC SỬA LỖI VÀ CẬP NHẬT >>>
        // =================================================================

        var controller =
        TextEditingController(text: _priceInputFormatter.format(calculatedCost)); // Hiển thị chi phí đã tính
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
          'originalCost': calculatedCost, // originalCost giờ là chi phí đã được tính toán
          'cost': calculatedCost,
          'controller': controller,
          'focusNode': focusNode,
        });

        _lastLoadedCogsComponentsForProduct.add({
          'name': name,
          'originalCost': calculatedCost,
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
            ? AppColors.chartRed
            : AppColors.primaryBlue,
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
            color: AppColors.getCardColor(context), // [cite: 302]
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
                        color: AppColors.primaryBlue),
                  ),
                  const SizedBox(height: 24), // [cite: 305]
                  DropdownButtonFormField<String>( // [cite: 305]
                    value: selectedProductId, // [cite: 305]
                    decoration: InputDecoration( // [cite: 305]
                      labelText: "Sản phẩm/Dịch vụ", // [cite: 305, 306]
                      labelStyle: // [cite: 306]
                      GoogleFonts.poppins(color: AppColors.getTextSecondaryColor(context)), // [cite: 307]
                      prefixIcon: const Icon(Icons.sell_outlined, // [cite: 307]
                          color: AppColors.primaryBlue, size: 22), // [cite: 307]
                      border: OutlineInputBorder( // [cite: 307]
                          borderRadius: BorderRadius.circular(12)),
                      filled: true, // [cite: 308]
                      fillColor: AppColors.getBackgroundColor(context).withOpacity(0.5), // [cite: 308]
                      contentPadding: // [cite: 308]
                      const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                    items: widget.productList.isEmpty // [cite: 309]
                        ? [ // [cite: 310]
                      DropdownMenuItem<String>( // [cite: 310]
                        value: null, // [cite: 310]
                        child: Text("Chưa có sản phẩm nào", // [cite: 310]
                            style: TextStyle( // [cite: 311]
                                fontStyle: FontStyle.italic,
                                color: AppColors.getTextSecondaryColor(context))),
                      )
                    ]
                        : widget.productList // [cite: 312]
                        .map((p) => DropdownMenuItem<String>( // [cite: 312]
                      value: p["id"], // [cite: 313]
                      child: Text(p["name"], // [cite: 313]
                          overflow: TextOverflow.ellipsis, // [cite: 313]
                          maxLines: 1, // [cite: 313]
                          style: GoogleFonts.poppins( // [cite: 314]
                              color: AppColors.getTextColor(context))),
                    ))
                        .toList(), // [cite: 315]
                    onChanged: (String? newValue) {
                      setState(() {
                        selectedProductId = newValue;
                        // Cập nhật giá bán trên UI trước
                        _updatePriceControllerBasedOnSelection(newValue);

                        // Lấy giá bán hiện tại từ controller hoặc từ state
                        final double currentSellingPrice = double.tryParse(widget.priceController.text
                            .replaceAll('.', '')
                            .replaceAll(',', '')) ?? selectedPriceFromDropdown;

                        // Gọi hàm với đầy đủ tham số
                        _loadProductVariableCostComponents(newValue, currentSellingPrice);
                      });
                    },
                    style: GoogleFonts.poppins( // [cite: 318, 319]
                        color: AppColors.getTextColor(context), fontSize: 16), // [cite: 319]
                    icon: Icon(Icons.arrow_drop_down_circle_outlined, // [cite: 319]
                        color: AppColors.primaryBlue), // [cite: 319]
                    borderRadius: BorderRadius.circular(12), // [cite: 320]
                    isExpanded: true, // [cite: 320]
                  ),
                  const SizedBox(height: 12), // [cite: 320]
                  SwitchListTile.adaptive( // [cite: 320]
                    title: Text( // [cite: 321]
                      "Giá bán linh hoạt", // [cite: 321]
                      style: GoogleFonts.poppins( // [cite: 321]
                          fontSize: 16, // [cite: 322]
                          color: AppColors.getTextColor(context),
                          fontWeight: FontWeight.w500),
                    ),
                    value: isFlexiblePriceEnabled, // [cite: 323]
                    activeColor: AppColors.primaryBlue, // [cite: 323]
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
                        color: AppColors.primaryBlue, // [cite: 331]
                        size: 22), // [cite: 331]
                  ),
                  _buildModernTextField(
                      context: context,
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
                  _buildModernTextField(
                      context: context,
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
                  SwitchListTile.adaptive(
                    title: Text("Thực thu vào ví?", style: GoogleFonts.poppins(fontSize: 16, color: AppColors.getTextColor(context), fontWeight: FontWeight.w500)),
                    value: _isCashReceived,
                    onChanged: (bool value) {
                      setState(() {
                        _isCashReceived = value;
                        if (!value) {
                          _selectedWalletId = null;
                        }
                      });
                    },
                    activeColor: widget.screenPrimaryColor,
                    contentPadding: EdgeInsets.zero,
                  ),

                if (_isCashReceived) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: InkWell(
                      onTap: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: _cashReceivedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now().add(const Duration(days: 365)), // Giới hạn 1 năm trong tương lai
                        );
                        if (picked != null && picked != _cashReceivedDate) {
                          setState(() {
                            _cashReceivedDate = picked;
                          });
                        }
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Ngày thực thu',
                          prefixIcon: Icon(Icons.calendar_today, color: widget.screenPrimaryColor),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          DateFormat('dd/MM/yyyy').format(_cashReceivedDate),
                          style: GoogleFonts.poppins(fontSize: 16, color: AppColors.getTextColor(context)),
                        ),
                      ),
                    ),
                  ),
                    ValueListenableBuilder<List<Map<String, dynamic>>>(
                      valueListenable: widget.appState.wallets,
                      builder: (context, walletList, child) {
                        if (walletList.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              "Chưa có ví tiền nào được tạo.",
                              style: GoogleFonts.poppins(color: AppColors.getTextSecondaryColor(context)),
                            ),
                          );
                        }

                        final defaultWallet = widget.appState.defaultWallet;
                        if (_selectedWalletId == null || !walletList.any((w) => w['id'] == _selectedWalletId)) {
                          if (defaultWallet != null) {
                            _selectedWalletId = defaultWallet['id'];
                          } else {
                            _selectedWalletId = walletList.first['id'];
                          }
                        }

                        return Padding(
                          padding: const EdgeInsets.only(top: 16.0),
                          child: DropdownButtonFormField<String>(
                            value: _selectedWalletId,
                            items: walletList.map((wallet) {
                              return DropdownMenuItem<String>(
                                value: wallet['id'],
                                child: Text(
                                  wallet['isDefault'] == true
                                      ? "${wallet['name']} (Mặc định)"
                                      : wallet['name'],
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              setState(() {
                                _selectedWalletId = newValue;
                              });
                            },
                            decoration: InputDecoration(
                              labelText: 'Chọn ví nhận tiền',
                              prefixIcon: Icon(Icons.account_balance_wallet_outlined, color: widget.screenPrimaryColor),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        );
                      },
                    ),
                ],
                  const SizedBox(height: 20), // Thêm khoảng cách
                  if (_currentUnitVariableCostComponents.isNotEmpty) ...[
                    Divider(height: 24, thickness: 1),
                    SwitchListTile.adaptive(
                      title: Text("Thực chi ngay từ ví?", style: GoogleFonts.poppins(fontSize: 16, color: AppColors.getTextColor(context), fontWeight: FontWeight.w500)),
                      value: _isCashSpent,
                      onChanged: (bool value) {
                        setState(() {
                          _isCashSpent = value;
                          if (!value) {
                            _selectedSpendingWalletId = null;
                          }
                        });
                      },
                      activeColor: AppColors.chartRed, // Màu đỏ cho chi phí
                      contentPadding: EdgeInsets.zero,
                    ),
                    if (_isCashSpent) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: InkWell(
                          onTap: () async {
                            final DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate: _cashSpentDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (picked != null && picked != _cashSpentDate) {
                              setState(() {
                                _cashSpentDate = picked;
                              });
                            }
                          },
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Ngày thực chi',
                              prefixIcon: Icon(Icons.calendar_today, color: AppColors.chartRed),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(
                              DateFormat('dd/MM/yyyy').format(_cashSpentDate),
                              style: GoogleFonts.poppins(fontSize: 16, color: AppColors.getTextColor(context)),
                            ),
                          ),
                        ),
                      ),
                      ValueListenableBuilder<List<Map<String, dynamic>>>(
                        valueListenable: widget.appState.wallets,
                        builder: (context, walletList, child) {
                          if (walletList.isEmpty) return const SizedBox.shrink();
                          final defaultWallet = widget.appState.defaultWallet;
                          if (_selectedSpendingWalletId == null || !walletList.any((w) => w['id'] == _selectedSpendingWalletId)) {
                            _selectedSpendingWalletId = defaultWallet?['id'] ?? walletList.first['id'];
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 16.0),
                            child: DropdownButtonFormField<String>(
                              value: _selectedSpendingWalletId,
                              items: walletList.map((wallet) {
                                return DropdownMenuItem<String>(
                                  value: wallet['id'],
                                  child: Text( wallet['isDefault'] == true ? "${wallet['name']} (Mặc định)" : wallet['name'], overflow: TextOverflow.ellipsis,),
                                );
                              }).toList(),
                              onChanged: (String? newValue) { setState(() { _selectedSpendingWalletId = newValue; }); },
                              decoration: InputDecoration(
                                labelText: 'Chọn ví thanh toán',
                                prefixIcon: Icon(Icons.outbox_rounded, color: AppColors.chartRed),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                  const SizedBox(height: 20),
                  Text("Chi phí biến đổi của sản phẩm:", // [cite: 347]
                      style: GoogleFonts.poppins( // [cite: 347, 348]
                          fontSize: 16,
                          color: AppColors.getTextColor(context),
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8), // [cite: 349]
                  SwitchListTile.adaptive( // [cite: 349]
                    title: Text( // [cite: 349]
                      "CPBĐ/ĐV linh hoạt", // [cite: 349]
                      style: GoogleFonts.poppins( // [cite: 350]
                          fontSize: 16, // [cite: 350]
                          color: AppColors.getTextColor(context),
                          fontWeight: FontWeight.w500),
                    ),
                    value: isFlexibleUnitVariableCostEnabled, // [cite: 351]
                    activeColor: AppColors.primaryBlue, // [cite: 351]
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
                        color: AppColors.primaryBlue, // [cite: 366]
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
                                              color: AppColors.getTextColor(context)
                                                  .withOpacity(0.9),
                                              fontSize: 14.5), // [cite: 376]
                                          overflow: TextOverflow.ellipsis, // [cite: 376]
                                        )),
                                    const SizedBox(width: 10), // [cite: 378]
                                    Expanded( // [cite: 378]
                                      flex: 3, // [cite: 378]
                                      child: _buildModernTextField(
                                        context: context,
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
                  _buildModernTextField(
                      context: context,
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
                        color: AppColors.primaryBlue.withOpacity(0.08), // [cite: 465]
                        borderRadius: BorderRadius.circular(12), // [cite: 465]
                        border: Border.all(
                            color: AppColors.primaryBlue.withOpacity(0.3))), // [cite: 465]
                    child: Column( // [cite: 465]
                      crossAxisAlignment: CrossAxisAlignment.start, // [cite: 466]
                      children: [ // [cite: 466]
                        Text( // [cite: 466]
                          "TỔNG DOANH THU (ƯỚC TÍNH):", // [cite: 467]
                          style: GoogleFonts.poppins( // [cite: 467]
                              fontSize: 13, // [cite: 467]
                              fontWeight: FontWeight.w600, // [cite: 468]
                              color: AppColors.primaryBlue.withOpacity(0.8), // [cite: 468]
                              letterSpacing: 0.5), // [cite: 468]
                        ),
                        SizedBox(height: 4), // [cite: 469]
                        Text( // [cite: 469]
                          widget.currencyFormat
                              .format(estimatedTotalRevenue), // [cite: 469]
                          style: GoogleFonts.poppins( // [cite: 470]
                              fontSize: 22, // [cite: 470]
                              fontWeight: FontWeight.w700, // [cite: 470]
                              color: AppColors.primaryBlue), // [cite: 471]
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
                      backgroundColor: AppColors.primaryBlue, // [cite: 479]
                      foregroundColor: Colors.white, // [cite: 479, 480]
                      shape: RoundedRectangleBorder( // [cite: 480]
                          borderRadius: BorderRadius.circular(12)),
                      minimumSize: Size(screenWidth, 52), // [cite: 480]
                      padding:
                      const EdgeInsets.symmetric(vertical: 14), // [cite: 481]
                      elevation: 2, // [cite: 481]
                    ),
                    onPressed: widget.onAddTransaction != null ? () {
                      // Tìm lại tên sản phẩm từ ID đã chọn
                      final String? productName = selectedProductId != null
                          ? widget.productList.firstWhere(
                              (p) => p['id'] == selectedProductId,
                          orElse: () => {'name': null})['name']
                          : null;

                      widget.onAddTransaction!(
                        productName,
                        selectedPriceFromDropdown,
                        isFlexiblePriceEnabled,
                        _isCashReceived,
                        _selectedWalletId,
                        _cashReceivedDate,
                        _isCashSpent,
                        _selectedSpendingWalletId,
                        _cashSpentDate,);
                    } : null,
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
    required BuildContext context,
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

    return TextField( // [cite: 488]
      controller: controller, // [cite: 488]
      enabled: enabled, // [cite: 488]
      keyboardType: keyboardType, // [cite: 488]
      inputFormatters: inputFormatters, // [cite: 488]
      maxLength: maxLength, // [cite: 488]
      focusNode: focusNode, // [cite: 488]
      onChanged: onChanged, // [cite: 488]
      style: GoogleFonts.poppins( // [cite: 488]
          color: AppColors.getTextColor(context),
          fontWeight: FontWeight.w500,
          fontSize: 16),
      decoration: InputDecoration( // [cite: 489]
        labelText: labelText, // [cite: 489]
        labelStyle: GoogleFonts.poppins(color: AppColors.getTextSecondaryColor(context)), // [cite: 489]
        prefixIcon: prefixIconData != null // [cite: 489]
            ? Icon(prefixIconData, color: AppColors.primaryBlue, size: 22) // [cite: 489]
            : null, // [cite: 490]
        border: OutlineInputBorder( // [cite: 490]
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.getBorderColor(context))), // [cite: 490, 491]
        enabledBorder: OutlineInputBorder( // [cite: 491]
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.getBorderColor(context))),
        focusedBorder: OutlineInputBorder( // [cite: 491]
            borderRadius: BorderRadius.circular(12), // [cite: 491, 492]
            borderSide: BorderSide(color: AppColors.primaryBlue, width: 1.5)),
        filled: true, // [cite: 492]
        fillColor: enabled // [cite: 492]
            ? AppColors.getBackgroundColor(context).withOpacity(0.5)
            : AppColors.getBorderColor(context),
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
  final Function(AppState, List<Map<String, dynamic>>, int)?
  onEditTransaction; // [cite: 496]
  final Function(int)?
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
                        fontSize: 17, color: AppColors.getTextSecondaryColor(context)),
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
                      color: AppColors.getTextColor(context)),
                ),
              ),
              ListView.builder( // [cite: 511]
                shrinkWrap: true, // [cite: 512]
                physics: const NeverScrollableScrollPhysics(), // [cite: 512]
                itemCount: sortedHistory.length, // [cite: 512]
                itemBuilder: (context, index) { // [cite: 512]
                  final transaction = sortedHistory[index]; // [cite: 512]
                  final bool isUnpaid = transaction['paymentStatus'] == 'unpaid';
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
                      AppColors.chartRed.withOpacity(0.8),
                      alignment: Alignment.centerRight, // [cite: 519]
                      padding: const EdgeInsets.only(right: 20), // [cite: 520]
                      child: const Icon(Icons.delete_sweep_outlined, // [cite: 520]
                          color: Colors.white, size: 26), // [cite: 520]
                    ),
                    direction: DismissDirection.endToStart, // [cite: 521]
                    onDismissed: (direction) { // [cite: 521]
                      if (originalIndex != -1) { // [cite: 521]
                        onRemoveTransaction!( // [cite: 522]
                            originalIndex);
                      }
                    },
                    child: Card( // [cite: 523]
                      elevation: 1.5, // [cite: 523]
                      margin: const EdgeInsets.symmetric(vertical: 5), // [cite: 523]
                      shape: RoundedRectangleBorder( // [cite: 524]
                          borderRadius: BorderRadius.circular(12)),
                      color: AppColors.getCardColor(context), // [cite: 524]
                      child: ListTile( // [cite: 524, 525]
                        contentPadding: const EdgeInsets.symmetric( // [cite: 525]
                            horizontal: 16, vertical: 10),
                        visualDensity: VisualDensity.adaptivePlatformDensity, // [cite: 525]
                        leading: CircleAvatar( // [cite: 526]
                          backgroundColor: AppColors.primaryBlue.withOpacity(0.15), // [cite: 526]
                          radius: 22, // [cite: 526]
                          child: Text( // [cite: 527]
                            transaction['name'] != null && // [cite: 527]
                                (transaction['name'] as String).isNotEmpty // [cite: 527]
                                ? (transaction['name'] as String)[0] // [cite: 528, 529]
                                .toUpperCase() // [cite: 529]
                                : "?", // [cite: 529]
                            style: GoogleFonts.poppins( // [cite: 530]
                                color: AppColors.primaryBlue,
                                fontWeight: FontWeight.w600, // [cite: 530]
                                fontSize: 18), // [cite: 531]
                          ),
                        ),
                        title: Text( // [cite: 531]
                          transaction['name']?.toString() ?? 'N/A', // [cite: 532]
                          style: GoogleFonts.poppins( // [cite: 532]
                              fontSize: 15.5, // [cite: 532]
                              fontWeight: FontWeight.w600, // [cite: 533]
                              color: AppColors.getTextColor(context)),
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
                                    color: AppColors.getTextSecondaryColor(context)), // [cite: 537]
                              ),
                              Text( // [cite: 538]
                                "Tổng DT: ${currencyFormat.format(totalRevenue)}", // [cite: 538]
                                style: GoogleFonts.poppins( // [cite: 539]
                                    fontSize: 13.0, // [cite: 539]
                                    color: AppColors.primaryBlue, // [cite: 539]
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
                                        color: AppColors.getTextSecondaryColor(context) // [cite: 543]
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
                                        color: AppColors.getTextSecondaryColor(context) // [cite: 553]
                                            .withOpacity(0.8)), // [cite: 554]
                                  ),
                                ),
                              if (isUnpaid)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Chip(
                                    label: Text('Chưa thu tiền', style: GoogleFonts.poppins(fontSize: 10, color: Colors.orange.shade900)),
                                    backgroundColor: Colors.orange.withOpacity(0.2),
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    labelPadding: EdgeInsets.zero,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // --- THÊM MỚI: NÚT "THU TIỀN" ---
                            if (isUnpaid && onEditTransaction != null)
                              IconButton(
                                icon: Icon(Icons.price_check_outlined, color: Colors.green.shade600),
                                onPressed: () {
                                  (context.findAncestorStateOfType<_EditMainRevenueScreenState>())
                                      ?._showCollectPaymentDialog(context, appState, transaction);
                                },
                                tooltip: 'Thu tiền',
                                splashRadius: 20,
                              ),
                            // Nút sửa hiện tại
                            if (onEditTransaction != null)
                              IconButton(
                                icon: Icon(Icons.edit_note_outlined, color: AppColors.primaryBlue.withOpacity(0.8), size: 24),
                                onPressed: () {
                                  if (originalIndex != -1) {
                                    onEditTransaction!(appState, transactionsNotifier.value, originalIndex);
                                  }
                                },
                                splashRadius: 20,
                              ),
                          ],
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