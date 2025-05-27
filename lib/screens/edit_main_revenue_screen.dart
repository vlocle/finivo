import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart'; // Ensure this path is correct
import '/screens/revenue_manager.dart'; // Ensure this path is correct
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart'; // For currency formatting in history

class EditMainRevenueScreen extends StatefulWidget {
  const EditMainRevenueScreen({Key? key}) : super(key: key);

  @override
  _EditMainRevenueScreenState createState() => _EditMainRevenueScreenState();
}

class _EditMainRevenueScreenState extends State<EditMainRevenueScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController quantityController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Future<List<Map<String, dynamic>>> _productsFuture;
  int _selectedTab = 0;

  // NEW: GlobalKey to access ProductInputSection's state
  final GlobalKey<_ProductInputSectionState> _productInputSectionKey =
  GlobalKey<_ProductInputSectionState>();

  static const Color _primaryColor = Color(0xFF2F81D7);
  static const Color _secondaryColor = Color(0xFFF1F5F9);
  static const Color _textColorPrimary = Color(0xFF1D2D3A);
  static const Color _textColorSecondary = Color(0xFF6E7A8A);
  static const Color _cardBackgroundColor = Colors.white;
  static const Color _accentColor = Colors.redAccent;
  final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'VNĐ');

  @override
  void initState() {
    super.initState();
    quantityController.text = "1"; // Initial value
    _animationController = AnimationController(
        duration: const Duration(milliseconds: 300), vsync: this);
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
        CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack));
    _animationController.forward();
    final appState = Provider.of<AppState>(context, listen: false);
    _productsFuture = RevenueManager.loadProducts(appState, "Doanh thu chính");
    appState.productsUpdated.addListener(_onProductsUpdated);
  }

  @override
  void dispose() {
    quantityController.dispose();
    priceController.dispose();
    _animationController.dispose();
    final appState = Provider.of<AppState>(context, listen: false);
    appState.productsUpdated.removeListener(_onProductsUpdated);
    super.dispose();
  }

  void _onProductsUpdated() {
    if (mounted) {
      setState(() {
        final appState = Provider.of<AppState>(context, listen: false);
        _productsFuture = RevenueManager.loadProducts(appState, "Doanh thu chính");
      });
    }
  }

  void _showStyledSnackBar(String message, {bool isError = false}) {
    if (!mounted) return; // MODIFIED: Added mounted check
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: isError ? _accentColor : _primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(10),
      ),
    );
  }

  // MODIFIED: addTransaction to reset fields
  void addTransaction(
      AppState appState,
      List<Map<String, dynamic>> transactions,
      String? selectedProduct, // This is the product name at the time of pressing 'Add'
      double currentSelectedPriceInDropdown,
      bool isFlexiblePriceEnabled) {
    if (selectedProduct == null) {
      _showStyledSnackBar("Vui lòng chọn sản phẩm/dịch vụ!", isError: true);
      return;
    }
    double priceToUse;
    if (isFlexiblePriceEnabled) {
      priceToUse = double.tryParse(
          priceController.text.replaceAll('.', '').replaceAll(',', '')) ??
          0.0;
      if (priceToUse <= 0.0) {
        _showStyledSnackBar("Vui lòng nhập giá trị hợp lệ cho giá!",
            isError: true);
        return;
      }
    } else {
      priceToUse = currentSelectedPriceInDropdown;
      if (priceToUse <= 0.0) {
        _showStyledSnackBar("Giá sản phẩm không hợp lệ trong danh mục!",
            isError: true);
        return;
      }
    }
    int quantity = int.tryParse(quantityController.text) ?? 1;
    if (quantity <= 0) {
      _showStyledSnackBar("Số lượng phải lớn hơn 0!", isError: true);
      return;
    }
    double total = priceToUse * quantity;
    transactions.add({
      "name": selectedProduct,
      "price": priceToUse,
      "quantity": quantity,
      "total": total,
      "date": DateTime.now().toIso8601String()
    });
    RevenueManager.saveTransactionHistory(
        appState, "Doanh thu chính", transactions);
    _showStyledSnackBar("Đã thêm giao dịch: $selectedProduct");

    // Reset fields after successful addition
    if (mounted) {
      setState(() {
        quantityController.text = "1"; // Reset quantity controller
      });
      // Call reset method on ProductInputSectionState
      _productInputSectionKey.currentState?.resetForm();
    }
  }

  void removeTransaction(AppState appState,
      List<Map<String, dynamic>> transactions, int index) {
    if (index < 0 || index >= transactions.length) return;
    final removedItemName = transactions[index]['name'];
    transactions.removeAt(index);
    RevenueManager.saveTransactionHistory(
        appState, "Doanh thu chính", transactions);
    _showStyledSnackBar("Đã xóa: $removedItemName");
  }

  void editTransaction(AppState appState,
      List<Map<String, dynamic>> transactions, int index) {
    if (index < 0 || index >= transactions.length) return;
    TextEditingController editQuantityController =
    TextEditingController(text: transactions[index]['quantity'].toString());
    final transactionToEdit = transactions[index];
    showDialog(
      context: context,
      builder: (dialogContext) => GestureDetector(
        onTap: () => FocusScope.of(dialogContext).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: AlertDialog(
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text("Chỉnh sửa: ${transactionToEdit['name']}",
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600, color: _textColorPrimary)),
          content: TextField(
            keyboardType: TextInputType.number,
            controller: editQuantityController,
            decoration: InputDecoration(
                labelText: "Nhập số lượng mới",
                labelStyle: GoogleFonts.poppins(color: _textColorSecondary),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: _secondaryColor,
                prefixIcon: Icon(Icons.production_quantity_limits_outlined,
                    color: _primaryColor)),
            maxLines: 1,
            maxLength: 5,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly], // NEW: Added formatter
          ),
          actionsPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text("Hủy",
                  style: GoogleFonts.poppins(
                      color: _textColorSecondary,
                      fontWeight: FontWeight.w500)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              onPressed: () {
                int newQuantity =
                    int.tryParse(editQuantityController.text) ??
                        transactionToEdit['quantity'];
                if (newQuantity <= 0) {
                  // MODIFIED: Use _showStyledSnackBar for consistency if possible, or keep SnackBar if context is tricky
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(
                        content: Text("Số lượng phải lớn hơn 0",
                            style: GoogleFonts.poppins(color: Colors.white)), // MODIFIED: text color
                        backgroundColor: _accentColor,
                        behavior: SnackBarBehavior.floating),
                  );
                  return;
                }
                transactionToEdit['quantity'] = newQuantity;
                transactionToEdit['total'] =
                    (transactionToEdit['price'] as num? ?? 0.0) * newQuantity;
                RevenueManager.saveTransactionHistory(
                    appState, "Doanh thu chính", transactions);
                Navigator.pop(dialogContext);
                _showStyledSnackBar("Đã cập nhật: ${transactionToEdit['name']}");
              },
              child: Text("Lưu", style: GoogleFonts.poppins()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(String title, int tabIndex, bool isFirst, bool isLast) {
    bool isSelected = _selectedTab == tabIndex;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (mounted) setState(() => _selectedTab = tabIndex);
          _animationController.reset();
          _animationController.forward();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? _cardBackgroundColor : _primaryColor,
            borderRadius: BorderRadius.only(
              topLeft: isFirst ? const Radius.circular(12) : Radius.zero,
              bottomLeft: isFirst ? const Radius.circular(12) : Radius.zero,
              topRight: isLast ? const Radius.circular(12) : Radius.zero,
              bottomRight: isLast ? const Radius.circular(12) : Radius.zero,
            ),
            border: isSelected
                ? Border.all(color: _primaryColor, width: 0.5)
                : null,
            boxShadow: isSelected
                ? [
              BoxShadow(
                  color: Colors.blue.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 5,
                  offset: Offset(0, 2))
            ]
                : [],
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 15.5,
              color: isSelected ? _primaryColor : Colors.white.withOpacity(0.9),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        backgroundColor: _secondaryColor,
        appBar: AppBar(
          backgroundColor: _primaryColor,
          elevation: 1,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            "Doanh thu chính",
            style: GoogleFonts.poppins(
                fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white),
          ),
          centerTitle: true,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(50),
            child: Padding(
              padding:
              const EdgeInsets.symmetric(horizontal: 12.0, vertical: 5.0),
              child: Container(
                decoration: BoxDecoration(
                  color: _primaryColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    _buildTab("Thêm giao dịch", 0, true, false),
                    _buildTab("Lịch sử", 1, false, true),
                  ],
                ),
              ),
            ),
          ),
        ),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: _productsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                  child: CircularProgressIndicator(color: _primaryColor));
            }
            if (snapshot.hasError) {
              return Center(
                  child: Text("Lỗi tải dữ liệu sản phẩm",
                      style: GoogleFonts.poppins(color: _textColorSecondary)));
            }
            List<Map<String, dynamic>> productList = snapshot.data ?? [];
            return ScaleTransition(
                scale: _scaleAnimation,
                child: IndexedStack(
                  index: _selectedTab,
                  children: [
                    ProductInputSection(
                      key: _productInputSectionKey, // MODIFIED: Pass the key
                      productList: productList,
                      quantityController: quantityController,
                      priceController: priceController,
                      onAddTransaction: (selectedProduct, selectedPrice,
                          isFlexiblePrice) {
                        addTransaction(
                            appState,
                            appState.mainRevenueTransactions.value,
                            selectedProduct,
                            selectedPrice,
                            isFlexiblePrice);
                      },
                      appState: appState,
                      currencyFormat: currencyFormat,
                    ),
                    TransactionHistorySection(
                      key: const ValueKey('transactionHistory'),
                      transactionsNotifier: appState.mainRevenueTransactions,
                      onEditTransaction: editTransaction,
                      onRemoveTransaction: removeTransaction,
                      appState: appState,
                      currencyFormat: currencyFormat,
                      primaryColor: _primaryColor,
                      textColorPrimary: _textColorPrimary,
                      textColorSecondary: _textColorSecondary,
                      cardBackgroundColor: _cardBackgroundColor,
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
  final List<Map<String, dynamic>> productList;
  final TextEditingController quantityController;
  final TextEditingController priceController;
  final Function(String?, double, bool) onAddTransaction;
  final AppState appState;
  final NumberFormat currencyFormat;

  const ProductInputSection({
    Key? key, // MODIFIED: Accept key
    required this.productList,
    required this.quantityController,
    required this.priceController,
    required this.onAddTransaction,
    required this.appState,
    required this.currencyFormat,
  }) : super(key: key);

  @override
  _ProductInputSectionState createState() => _ProductInputSectionState();
}

class _ProductInputSectionState extends State<ProductInputSection> {
  String? selectedProduct;
  double selectedPriceFromDropdown = 0.0;
  bool isFlexiblePriceEnabled = false;
  final FocusNode _priceFocusNode = FocusNode();
  final NumberFormat _priceInputFormatter = NumberFormat("#,##0", "vi_VN");

  @override
  void initState() {
    super.initState();
    // Initial state for price controller is set based on no product selected
    // and flexible price disabled.
    _resetPriceControllerToDefault();
    widget.priceController.addListener(_onPriceChanged);
  }

  @override
  void dispose() {
    widget.priceController.removeListener(_onPriceChanged);
    _priceFocusNode.dispose();
    super.dispose();
  }

  void _onPriceChanged() {
    // This listener might be used for live validation or formatting if needed.
    // For now, it ensures the UI rebuilds if the controller text changes externally.
    if (mounted) {
      // setState(() {}); // Causing issues, remove if not strictly needed for live total update
    }
  }

  void _resetPriceControllerToDefault() {
    // This is the default state: no product, flexible price off, so price is 0.
    widget.priceController.text = _priceInputFormatter.format(0);
  }


  void _updatePriceControllerBasedOnSelection() {
    if (!isFlexiblePriceEnabled && selectedProduct != null) {
      final product = widget.productList.firstWhere(
              (p) => p["name"] == selectedProduct,
          orElse: () => {"price": 0.0});
      selectedPriceFromDropdown = (product["price"] as num? ?? 0.0).toDouble();
      widget.priceController.text =
          _priceInputFormatter.format(selectedPriceFromDropdown);
    } else if (!isFlexiblePriceEnabled && selectedProduct == null) {
      selectedPriceFromDropdown = 0.0;
      widget.priceController.text = _priceInputFormatter.format(0);
    }
    // If isFlexiblePriceEnabled is true, user input is respected,
    // unless we explicitly want to set it (e.g., when toggling the switch).
  }

  // NEW: Method to reset the form fields in this section
  void resetForm() {
    setState(() {
      selectedProduct = null; // Reset dropdown
      isFlexiblePriceEnabled = false; // Reset switch
      selectedPriceFromDropdown = 0.0; // Reset internal price state

      // Reset priceController to reflect no product selected and flexible price off
      widget.priceController.text = _priceInputFormatter.format(0);

      // widget.quantityController is reset by the parent state

      if (_priceFocusNode.hasFocus) {
        _priceFocusNode.unfocus(); // Remove focus from price field
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    const Color primaryColor = _EditMainRevenueScreenState._primaryColor;
    const Color secondaryColor = _EditMainRevenueScreenState._secondaryColor;
    const Color textColorPrimary = _EditMainRevenueScreenState._textColorPrimary;
    const Color textColorSecondary =
        _EditMainRevenueScreenState._textColorSecondary;
    const Color cardBackgroundColor =
        _EditMainRevenueScreenState._cardBackgroundColor; // NEW: Use defined color

    // Calculate total for display
    double currentPriceForTotal;
    if (isFlexiblePriceEnabled) {
      currentPriceForTotal = double.tryParse(widget.priceController.text.replaceAll('.', '').replaceAll(',', '')) ?? 0.0;
    } else {
      currentPriceForTotal = selectedPriceFromDropdown;
    }
    final int currentQuantityForTotal = int.tryParse(widget.quantityController.text) ?? 1;
    final double estimatedTotal = currentPriceForTotal * currentQuantityForTotal;


    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            elevation: 3,
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: cardBackgroundColor, // MODIFIED
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Thêm giao dịch mới",
                    style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: primaryColor),
                  ),
                  const SizedBox(height: 24),
                  DropdownButtonFormField<String>(
                    value: selectedProduct,
                    decoration: InputDecoration(
                      labelText: "Sản phẩm/Dịch vụ",
                      labelStyle: GoogleFonts.poppins(color: textColorSecondary),
                      prefixIcon: const Icon(Icons.sell_outlined,
                          color: primaryColor, size: 22),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: secondaryColor.withOpacity(0.5),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                    items: widget.productList.isEmpty
                        ? [
                      const DropdownMenuItem<String>(
                        value: null, // MODIFIED: Explicitly null for placeholder
                        child: Text("Chưa có sản phẩm nào",
                            style:
                            TextStyle(fontStyle: FontStyle.italic, color: textColorSecondary)), // MODIFIED: Style placeholder
                      )
                    ]
                        : widget.productList
                        .map((p) => DropdownMenuItem<String>(
                      value: p["name"],
                      child: Text(p["name"],
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: GoogleFonts.poppins(
                              color: textColorPrimary)),
                    ))
                        .toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        selectedProduct = newValue;
                        if (newValue != null) {
                          final productData = widget.productList.firstWhere(
                                  (p) => p["name"] == newValue,
                              orElse: () => {"price": 0.0});
                          selectedPriceFromDropdown =
                              (productData["price"] as num? ?? 0.0).toDouble();
                          if (!isFlexiblePriceEnabled) {
                            widget.priceController.text = _priceInputFormatter
                                .format(selectedPriceFromDropdown);
                          }
                        } else {
                          selectedPriceFromDropdown = 0.0;
                          if (!isFlexiblePriceEnabled) {
                            widget.priceController.text =
                                _priceInputFormatter.format(0);
                          }
                        }
                      });
                    },
                    style:
                    GoogleFonts.poppins(color: textColorPrimary, fontSize: 16),
                    icon: Icon(Icons.arrow_drop_down_circle_outlined,
                        color: primaryColor),
                    borderRadius: BorderRadius.circular(12),
                    isExpanded: true, // MODIFIED: Ensure dropdown text is fully visible
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile.adaptive(
                    title: Text(
                      "Giá linh hoạt",
                      style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: textColorPrimary,
                          fontWeight: FontWeight.w500),
                    ),
                    value: isFlexiblePriceEnabled,
                    activeColor: primaryColor,
                    inactiveThumbColor: Colors.grey.shade400,
                    inactiveTrackColor: Colors.grey.shade200,
                    onChanged: (bool value) {
                      setState(() {
                        isFlexiblePriceEnabled = value;
                        if (!isFlexiblePriceEnabled) {
                          // If turning off flexible price, update price to selected product's price
                          _updatePriceControllerBasedOnSelection();
                          if (_priceFocusNode.hasFocus) {
                            FocusScope.of(context).unfocus();
                          }
                        } else {
                          // If turning on flexible price, set price field from current dropdown selection (or 0 if none)
                          // and request focus.
                          widget.priceController.text = _priceInputFormatter.format(selectedPriceFromDropdown);
                          _priceFocusNode.requestFocus();
                        }
                      });
                    },
                    contentPadding: EdgeInsets.zero,
                    secondary: Icon(
                        isFlexiblePriceEnabled
                            ? Icons.edit_attributes_outlined
                            : Icons.attach_money_outlined,
                        color: primaryColor,
                        size: 22),
                  ),
                  _buildModernTextField(
                      labelText: "Giá sản phẩm/dịch vụ",
                      prefixIconData: Icons.price_change_outlined,
                      controller: widget.priceController,
                      keyboardType: TextInputType.numberWithOptions(decimal: false),
                      enabled: isFlexiblePriceEnabled,
                      focusNode: _priceFocusNode,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        TextInputFormatter.withFunction(
                              (oldValue, newValue) {
                            if (newValue.text.isEmpty) return newValue;
                            final String plainNumberText = newValue.text
                                .replaceAll('.', '')
                                .replaceAll(',', '');
                            final number = int.tryParse(plainNumberText);
                            if (number == null) return oldValue;
                            final formattedText =
                            _priceInputFormatter.format(number);
                            return newValue.copyWith(
                              text: formattedText,
                              selection: TextSelection.collapsed(
                                  offset: formattedText.length),
                            );
                          },
                        ),
                      ],
                      maxLength: 15,
                      onChanged: (_) { // MODIFIED: Add onChanged to trigger UI update for total
                        if(mounted) setState(() {});
                      }
                  ),
                  const SizedBox(height: 16),
                  _buildModernTextField(
                      labelText: "Số lượng",
                      prefixIconData: Icons.production_quantity_limits_rounded,
                      controller: widget.quantityController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      maxLength: 5,
                      onChanged: (_) { // MODIFIED: Add onChanged to trigger UI update for total
                        if(mounted) setState(() {});
                      }
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: primaryColor.withOpacity(0.3))),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "TỔNG TIỀN ƯỚC TÍNH:",
                          style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: primaryColor.withOpacity(0.8),
                              letterSpacing: 0.5),
                        ),
                        SizedBox(height: 4),
                        Text(
                          // MODIFIED: Use pre-calculated estimatedTotal
                          widget.currencyFormat.format(estimatedTotal),
                          style: GoogleFonts.poppins(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: primaryColor),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      minimumSize: Size(screenWidth, 52),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 2,
                    ),
                    onPressed: () => widget.onAddTransaction(selectedProduct,
                        selectedPriceFromDropdown, isFlexiblePriceEnabled),
                    child: Text(
                      "Thêm giao dịch",
                      style: GoogleFonts.poppins(
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
    required String labelText,
    required TextEditingController controller,
    bool enabled = true,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    int? maxLength,
    IconData? prefixIconData,
    FocusNode? focusNode,
    void Function(String)? onChanged,
  }) {
    const Color primaryColor = _EditMainRevenueScreenState._primaryColor;
    const Color secondaryColor = _EditMainRevenueScreenState._secondaryColor;
    const Color textColorSecondary =
        _EditMainRevenueScreenState._textColorSecondary;
    const Color cardBackgroundColorFromParent =
        _EditMainRevenueScreenState._cardBackgroundColor;
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLength: maxLength,
      focusNode: focusNode,
      onChanged: onChanged,
      style: GoogleFonts.poppins(
          color: _EditMainRevenueScreenState._textColorPrimary,
          fontWeight: FontWeight.w500,
          fontSize: 16),
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: GoogleFonts.poppins(color: textColorSecondary),
        prefixIcon: prefixIconData != null
            ? Icon(prefixIconData, color: primaryColor, size: 22)
            : null,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: primaryColor, width: 1.5)),
        filled: true,
        // MODIFIED: Use cardBackgroundColorFromParent when enabled for consistency
        fillColor: enabled ? secondaryColor.withOpacity(0.5) : Colors.grey.shade200,
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        counterText: "",
      ),
      maxLines: 1,
    );
  }
}

class TransactionHistorySection extends StatelessWidget {
  final ValueNotifier<List<Map<String, dynamic>>> transactionsNotifier;
  final Function(AppState, List<Map<String, dynamic>>, int) onEditTransaction;
  final Function(AppState, List<Map<String, dynamic>>, int) onRemoveTransaction;
  final AppState appState;
  final NumberFormat currencyFormat;
  final Color primaryColor;
  final Color textColorPrimary;
  final Color textColorSecondary;
  final Color cardBackgroundColor;

  const TransactionHistorySection({
    Key? key,
    required this.transactionsNotifier,
    required this.onEditTransaction,
    required this.onRemoveTransaction,
    required this.appState,
    required this.currencyFormat,
    required this.primaryColor,
    required this.textColorPrimary,
    required this.textColorSecondary,
    required this.cardBackgroundColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<Map<String, dynamic>>>(
      valueListenable: transactionsNotifier,
      builder: (context, history, _) {
        if (history.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(30.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_toggle_off_outlined,
                      size: 70, color: Colors.grey.shade400),
                  SizedBox(height: 16),
                  Text(
                    "Chưa có giao dịch nào",
                    style:
                    GoogleFonts.poppins(fontSize: 17, color: textColorSecondary),
                  ),
                  SizedBox(height: 4),
                  Text(
                    "Thêm giao dịch mới để xem lịch sử tại đây.",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                        fontSize: 14, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
          );
        }
        // MODIFIED: Sort history by date descending (newest first) for display
        final sortedHistory = List<Map<String, dynamic>>.from(history);
        sortedHistory.sort((a, b) {
          DateTime dateA = DateTime.tryParse(a['date'] ?? '') ?? DateTime(1900);
          DateTime dateB = DateTime.tryParse(b['date'] ?? '') ?? DateTime(1900);
          return dateB.compareTo(dateA); // Sorts newest first
        });


        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 80.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Text(
                  "Lịch sử giao dịch", // MODIFIED: Simpler title
                  style: GoogleFonts.poppins(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: textColorPrimary),
                ),
              ),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: sortedHistory.length, // MODIFIED: Use sortedHistory
                itemBuilder: (context, index) {
                  final transaction = sortedHistory[index]; // MODIFIED: Use sortedHistory
                  // Find original index for editing/deleting if necessary, or adapt functions
                  // For simplicity, if your edit/delete relies on index from original list,
                  // you might need to find it. Or, pass the transaction object itself.
                  // Here, we assume onRemoveTransaction can handle index from the displayed (sorted) list
                  // if it re-fetches or if the underlying data structure is what's modified.
                  // The provided onRemoveTransaction takes an index, which might be problematic if it's for the *original* list.
                  // For robust deletion from sorted list, better to pass ID or object.
                  // However, current `onRemoveTransaction` uses `transactionsNotifier.value.removeAt(originalIndex)`.
                  // So we need to find the original index.
                  final originalIndex = history.indexOf(transaction);


                  return Dismissible(
                    key: Key(transaction['date'].toString() +
                        transaction['name'] +
                        index.toString()), // Key can be based on displayed index
                    background: Container(
                      color:
                      _EditMainRevenueScreenState._accentColor.withOpacity(0.8),
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      child: const Icon(Icons.delete_sweep_outlined,
                          color: Colors.white, size: 26),
                    ),
                    direction: DismissDirection.endToStart,
                    onDismissed: (direction) {
                      // MODIFIED: Use originalIndex for removing from the source list
                      if (originalIndex != -1) {
                        onRemoveTransaction(appState, transactionsNotifier.value, originalIndex);
                      }
                    },
                    child: Card(
                      elevation: 1.5,
                      margin: const EdgeInsets.symmetric(vertical: 5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      color: cardBackgroundColor,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        visualDensity: VisualDensity.compact,
                        leading: CircleAvatar(
                          backgroundColor: primaryColor.withOpacity(0.15),
                          radius: 20,
                          child: Text(
                            transaction['name'] != null &&
                                (transaction['name'] as String).isNotEmpty
                                ? (transaction['name'] as String)[0]
                                .toUpperCase()
                                : "?",
                            style: GoogleFonts.poppins(
                                color: primaryColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 18),
                          ),
                        ),
                        title: Text(
                          transaction['name']?.toString() ?? 'N/A',
                          style: GoogleFonts.poppins(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w600,
                              color: textColorPrimary),
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "SL: ${transaction['quantity']} x ${currencyFormat.format(transaction['price'] ?? 0.0)}",
                              style: GoogleFonts.poppins(
                                  fontSize: 12.5, color: textColorSecondary),
                            ),
                            Text(
                              "Tổng: ${currencyFormat.format(transaction['total'] ?? 0.0)}",
                              style: GoogleFonts.poppins(
                                  fontSize: 13.0,
                                  color: primaryColor,
                                  fontWeight: FontWeight.w500),
                            ),
                            if (transaction['date'] != null) // MODIFIED: Display date
                              Padding(
                                padding: const EdgeInsets.only(top: 2.0),
                                child: Text(
                                  DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(transaction['date'])),
                                  style: GoogleFonts.poppins(fontSize: 11.0, color: textColorSecondary.withOpacity(0.8)),
                                ),
                              ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: Icon(Icons.edit_note_outlined,
                              color: primaryColor.withOpacity(0.8), size: 22),
                          onPressed: () {
                            // MODIFIED: Use originalIndex for editing from the source list
                            if (originalIndex != -1) {
                              onEditTransaction(appState, transactionsNotifier.value, originalIndex);
                            }
                          },
                          splashRadius: 18,
                          padding: EdgeInsets.zero,
                          constraints:
                          BoxConstraints(minWidth: 30, minHeight: 30),
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
