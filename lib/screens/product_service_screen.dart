import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart'; // Giả định đường dẫn này đúng
import 'package:google_fonts/google_fonts.dart';

class ProductServiceScreen extends StatefulWidget {
  const ProductServiceScreen({Key? key}) : super(key: key);

  @override
  _ProductServiceScreenState createState() => _ProductServiceScreenState();
}

class _ProductServiceScreenState extends State<ProductServiceScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  final NumberFormat currencyFormat =
  NumberFormat.currency(locale: 'vi_VN', symbol: 'VNĐ');
  String selectedCategory = "Sản phẩm/Dịch vụ chính";
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  int _selectedTab = 0;
  late Future<List<Map<String, dynamic>>> _productsFuture;

  static const Color _primaryColor = Color(0xFF2F81D7);
  static const Color _secondaryColor = Color(0xFFF1F5F9);
  static const Color _textColorPrimary = Color(0xFF1D2D3A);
  static const Color _textColorSecondary = Color(0xFF6E7A8A);
  static const Color _cardBackgroundColor = Colors.white;
  static const Color _accentColor = Colors.redAccent;

  final NumberFormat _inputPriceFormatter = NumberFormat("#,##0", "vi_VN");

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
        duration: const Duration(milliseconds: 300), vsync: this);
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
        CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack));
    _animationController.forward();
    final appState = Provider.of<AppState>(context, listen: false);
    _productsFuture = _loadProducts(appState);
    appState.productsUpdated.addListener(_onProductsUpdated);
  }

  @override
  void dispose() {
    nameController.dispose();
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
        _productsFuture = _loadProducts(appState);
      });
    }
  }

  void _showStyledSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
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

  Future<List<Map<String, dynamic>>> _loadProducts(AppState appState) async {
    try {
      if (appState.userId == null) {
        _showStyledSnackBar("Vui lòng đăng nhập để tải sản phẩm.", isError: true);
        return [];
      }
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      String baseKey = selectedCategory == "Sản phẩm/Dịch vụ chính"
          ? 'mainProductList'
          : 'extraProductList';
      String firestoreDocKey = appState.getKey(baseKey);
      String hiveStorageKey = appState.getKey('${selectedCategory}_productList');

      if (!Hive.isBoxOpen('productsBox')) {
        await Hive.openBox('productsBox');
      }
      var productsBox = Hive.box('productsBox');

      if (productsBox.containsKey(hiveStorageKey)) {
        var rawData = productsBox.get(hiveStorageKey);
        if (rawData != null) {
          return (rawData as List<dynamic>)
              .map((item) => (item as Map<dynamic, dynamic>)
              .map((key, value) => MapEntry(key.toString(), value)))
              .cast<Map<String, dynamic>>()
              .toList();
        }
      }

      DocumentSnapshot doc = await firestore
          .collection('users')
          .doc(appState.userId)
          .collection('products')
          .doc(firestoreDocKey)
          .get();
      List<Map<String, dynamic>> productList = [];
      if (doc.exists && doc.data() != null) {
        var data = doc.data() as Map<String, dynamic>;
        if (data['products'] != null) {
          productList = List<Map<String, dynamic>>.from(data['products']);
        }
      }
      await productsBox.put(hiveStorageKey, productList);
      return productList;
    } catch (e) {
      _showStyledSnackBar('Lỗi khi tải sản phẩm: $e', isError: true);
      return [];
    }
  }

  Future<void> _saveProducts(
      AppState appState, List<Map<String, dynamic>> productList) async {
    try {
      if (appState.userId == null) {
        throw Exception('User ID không tồn tại');
      }
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      String baseKey = selectedCategory == "Sản phẩm/Dịch vụ chính"
          ? 'mainProductList'
          : 'extraProductList';
      String firestoreDocKey = appState.getKey(baseKey);
      String hiveStorageKey = appState.getKey('${selectedCategory}_productList');

      List<Map<String, dynamic>> standardizedProductList = productList
          .map((product) => {
        'name': product['name'].toString(),
        'price': (product['price'] as num? ?? 0.0).toDouble(),
      })
          .toList();

      await firestore
          .collection('users')
          .doc(appState.userId)
          .collection('products')
          .doc(firestoreDocKey)
          .set({
        'products': standardizedProductList,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!Hive.isBoxOpen('productsBox')) {
        await Hive.openBox('productsBox');
      }
      var productsBox = Hive.box('productsBox');
      await productsBox.put(hiveStorageKey, standardizedProductList);
      appState.notifyProductsUpdated();
      _showStyledSnackBar("Đã lưu danh sách sản phẩm!");
    } catch (e) {
      _showStyledSnackBar('Lỗi khi lưu sản phẩm: $e', isError: true);
    }
  }

  void addProduct(
      AppState appState, List<Map<String, dynamic>> productList) {
    String name = nameController.text.trim();
    // String priceText = priceController.text.replaceAll(',', '').trim(); // OLD
    String priceTextFromController = priceController.text.trim(); // NEW

    if (name.isEmpty) {
      _showStyledSnackBar("Vui lòng nhập tên sản phẩm/dịch vụ!", isError: true);
      return;
    }

    // if (priceText.isEmpty) { // OLD
    if (priceTextFromController.isEmpty) { // NEW
      _showStyledSnackBar("Vui lòng nhập giá sản phẩm/dịch vụ!", isError: true);
      return;
    }

    // For vi_VN locale used by _inputPriceFormatter (NumberFormat("#,##0", "vi_VN")),
    // the grouping separator is '.' (e.g., 30.000 for thirty thousand).
    // double.tryParse expects '.' as a decimal separator and no grouping separators.
    // So, we need to remove the '.' grouping separators before parsing.
    String parsablePriceText = priceTextFromController.replaceAll('.', ''); // NEW
    // Since FilteringTextInputFormatter.digitsOnly is used, there won't be a decimal separator (like ',') typed by the user.
    // If there was a possibility of a decimal separator (e.g. ',') from the controller,
    // it would also need to be converted to '.' for double.tryParse.
    // parsablePriceText = parsablePriceText.replaceAll(',', '.'); // Not strictly needed here

    // double? price = double.tryParse(priceText); // OLD
    double? price = double.tryParse(parsablePriceText); // NEW

    if (price == null || price < 0) {
      _showStyledSnackBar("Giá sản phẩm không hợp lệ!", isError: true);
      return;
    }

    if (productList.any(
            (p) => p["name"].toString().toLowerCase() == name.toLowerCase())) {
      _showStyledSnackBar("Tên sản phẩm/dịch vụ đã tồn tại!", isError: true);
      return;
    }

    List<Map<String,dynamic>> updatedProductList = List.from(productList);
    updatedProductList.add({"name": name, "price": price});
    _saveProducts(appState, updatedProductList);
    nameController.clear();
    priceController.clear();
    FocusScope.of(context).unfocus();
  }

  void deleteProduct(
      AppState appState, List<Map<String, dynamic>> productList, int index) {
    if (index < 0 || index >= productList.length) return;
    List<Map<String,dynamic>> updatedProductList = List.from(productList);
    final removedProductName = updatedProductList[index]['name'];
    updatedProductList.removeAt(index);
    _saveProducts(appState, updatedProductList);
    _showStyledSnackBar("Đã xóa: $removedProductName");
  }

  void editProduct(
      AppState appState, List<Map<String, dynamic>> productList, int index) {
    if (index < 0 || index >= productList.length) return;
    final productToEdit = productList[index];
    nameController.text = productToEdit["name"]?.toString() ?? '';
    priceController.text = _inputPriceFormatter.format(productToEdit["price"] ?? 0.0);

    showDialog(
      context: context,
      builder: (dialogContext) => GestureDetector(
        onTap: () => FocusScope.of(dialogContext).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: AlertDialog(
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text("Chỉnh sửa sản phẩm",
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600, color: _textColorPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDialogTextField(
                controller: nameController,
                labelText: "Tên sản phẩm/dịch vụ",
                prefixIconData: Icons.label_important_outline,
                maxLength: 50,
              ),
              const SizedBox(height: 16),
              _buildDialogTextField(
                controller: priceController,
                labelText: "Giá tiền",
                prefixIconData: Icons.price_check_outlined,
                keyboardType: TextInputType.numberWithOptions(decimal: false),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  TextInputFormatter.withFunction(
                        (oldValue, newValue) {
                      if (newValue.text.isEmpty) return newValue;
                      final number = int.tryParse(newValue.text.replaceAll(',', '').replaceAll('.', '')); // Ensure parsing raw digits
                      if (number == null) return oldValue;
                      final formattedText = _inputPriceFormatter.format(number);
                      return newValue.copyWith(
                        text: formattedText,
                        selection: TextSelection.collapsed(offset: formattedText.length),
                      );
                    },
                  ),
                ],
                maxLength: 15,
              ),
            ],
          ),
          actionsPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          actions: [
            TextButton(
              onPressed: () {
                nameController.clear();
                priceController.clear();
                Navigator.pop(dialogContext);
              },
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
                String updatedName = nameController.text.trim();
                // String updatedPriceText = priceController.text.replaceAll(',', '').trim(); // OLD
                String updatedPriceTextFromController = priceController.text.trim(); // NEW

                if (updatedName.isEmpty) {
                  _showStyledSnackBar("Vui lòng nhập tên sản phẩm!", isError: true);
                  return;
                }
                // if (updatedPriceText.isEmpty) { // OLD
                if (updatedPriceTextFromController.isEmpty) { // NEW
                  _showStyledSnackBar("Vui lòng nhập giá sản phẩm!", isError: true);
                  return;
                }

                // Similar logic as in addProduct for parsing the price
                String parsableUpdatedPriceText = updatedPriceTextFromController.replaceAll('.', ''); // NEW
                // parsableUpdatedPriceText = parsableUpdatedPriceText.replaceAll(',', '.'); // Not strictly needed

                // double? updatedPrice = double.tryParse(updatedPriceText); // OLD
                double? updatedPrice = double.tryParse(parsableUpdatedPriceText); // NEW

                if (updatedPrice == null || updatedPrice < 0) {
                  _showStyledSnackBar("Giá sản phẩm không hợp lệ!", isError: true);
                  return;
                }

                if (productList.asMap().entries.any((e) =>
                e.key != index &&
                    e.value["name"].toString().toLowerCase() ==
                        updatedName.toLowerCase())) {
                  _showStyledSnackBar("Tên sản phẩm/dịch vụ đã tồn tại!", isError: true);
                  return;
                }
                List<Map<String,dynamic>> updatedProductList = List.from(productList);
                updatedProductList[index] = {"name": updatedName, "price": updatedPrice};
                _saveProducts(appState, updatedProductList);
                nameController.clear();
                priceController.clear();
                Navigator.pop(dialogContext);
                _showStyledSnackBar("Đã cập nhật: $updatedName");
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
            border: isSelected ? Border.all(color: _primaryColor, width:0.5) : null,
            boxShadow: isSelected ? [
              BoxShadow(
                  color: Colors.blue.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 5,
                  offset: Offset(0,2)
              )
            ] : [],
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
            "Sản phẩm & Dịch vụ",
            style: GoogleFonts.poppins(
                fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white),
          ),
          centerTitle: true,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(50),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 5.0),
              child: Container(
                decoration: BoxDecoration(
                  color: _primaryColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    _buildTab("Thêm mới", 0, true, false),
                    _buildTab("Danh sách", 1, false, true),
                  ],
                ),
              ),
            ),
          ),
        ),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          key: ValueKey(selectedCategory),
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
                    key: const ValueKey('productServiceInput'),
                    nameController: nameController,
                    priceController: priceController,
                    selectedCategory: selectedCategory,
                    onAddProduct: () => addProduct(appState, productList),
                    onCategoryChanged: (newCategory) {
                      if (mounted) {
                        setState(() {
                          selectedCategory = newCategory;
                          _productsFuture = _loadProducts(appState);
                        });
                      }
                    },
                    appState: appState,
                    inputPriceFormatter: _inputPriceFormatter,
                  ),
                  ProductListSection(
                    key: ValueKey('productList_${selectedCategory}'),
                    productList: productList,
                    onEditProduct: (index) =>
                        editProduct(appState, productList, index),
                    onDeleteProduct: (index) =>
                        deleteProduct(appState, productList, index),
                    appState: appState,
                    currencyFormat: currencyFormat,
                    primaryColor: _primaryColor,
                    textColorPrimary: _textColorPrimary,
                    textColorSecondary: _textColorSecondary,
                    cardBackgroundColor: _cardBackgroundColor,
                    accentColor: _accentColor,
                    selectedCategoryText: selectedCategory,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDialogTextField({
    required TextEditingController controller,
    required String labelText,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    int? maxLength,
    IconData? prefixIconData,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLength: maxLength,
      style: GoogleFonts.poppins(color: _textColorPrimary, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: GoogleFonts.poppins(color: _textColorSecondary),
        prefixIcon: prefixIconData != null ? Icon(prefixIconData, color: _primaryColor, size: 22) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _primaryColor, width: 1.5)),
        filled: true,
        fillColor: _secondaryColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        counterText: "",
      ),
      maxLines: 1,
    );
  }
}

class ProductInputSection extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController priceController;
  final String selectedCategory;
  final VoidCallback onAddProduct;
  final Function(String) onCategoryChanged;
  final AppState appState;
  final NumberFormat inputPriceFormatter;

  const ProductInputSection({
    required this.nameController,
    required this.priceController,
    required this.selectedCategory,
    required this.onAddProduct,
    required this.onCategoryChanged,
    required this.appState,
    required this.inputPriceFormatter,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    const Color primaryColor = _ProductServiceScreenState._primaryColor;
    const Color secondaryColor = _ProductServiceScreenState._secondaryColor;
    const Color textColorPrimary = _ProductServiceScreenState._textColorPrimary;
    const Color textColorSecondary = _ProductServiceScreenState._textColorSecondary;
    const Color cardBackgroundColor = _ProductServiceScreenState._cardBackgroundColor;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            elevation: 3,
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: cardBackgroundColor,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Thêm Sản phẩm/Dịch vụ",
                    style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: primaryColor),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "Chọn loại:",
                    style: GoogleFonts.poppins(fontSize: 16, color: textColorSecondary, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment<String>(
                        value: "Sản phẩm/Dịch vụ chính",
                        label: Text("Doanh thu chính", overflow: TextOverflow.ellipsis),
                        icon: Icon(Icons.star_border_purple500_outlined, size: 18),
                      ),
                      ButtonSegment<String>(
                        value: "Sản phẩm/Dịch vụ phụ",
                        label: Text("Doanh thu phụ", overflow: TextOverflow.ellipsis),
                        icon: Icon(Icons.star_half_outlined, size: 18),
                      ),
                    ],
                    selected: {selectedCategory},
                    onSelectionChanged: (newSelection) {
                      if (newSelection.isNotEmpty) {
                        onCategoryChanged(newSelection.first);
                      }
                    },
                    style: SegmentedButton.styleFrom(
                      foregroundColor: primaryColor,
                      selectedForegroundColor: Colors.white,
                      selectedBackgroundColor: primaryColor,
                      backgroundColor: primaryColor.withOpacity(0.08),
                      side: BorderSide(color: primaryColor.withOpacity(0.5)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 13.5),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    showSelectedIcon: false,
                  ),
                  const SizedBox(height: 20),
                  _buildInputTextField(
                    controller: nameController,
                    labelText: 'Tên sản phẩm/dịch vụ',
                    prefixIconData: Icons.label_outline,
                    maxLength: 50,
                  ),
                  const SizedBox(height: 16),
                  _buildInputTextField(
                    controller: priceController,
                    labelText: 'Giá tiền',
                    prefixIconData: Icons.attach_money_outlined,
                    keyboardType: TextInputType.numberWithOptions(decimal: false),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      TextInputFormatter.withFunction(
                            (oldValue, newValue) {
                          if (newValue.text.isEmpty) return newValue;
                          // Ensure parsing raw digits by removing any potential separators before int.tryParse
                          final number = int.tryParse(newValue.text.replaceAll(',', '').replaceAll('.', ''));
                          if (number == null) return oldValue;
                          final formattedText = inputPriceFormatter.format(number);
                          return newValue.copyWith(
                            text: formattedText,
                            selection: TextSelection.collapsed(offset: formattedText.length),
                          );
                        },
                      ),
                    ],
                    maxLength: 15,
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
                    onPressed: onAddProduct,
                    child: Text(
                      "Thêm sản phẩm",
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

  Widget _buildInputTextField({
    required TextEditingController controller,
    required String labelText,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    int? maxLength,
    int maxLines = 1,
    IconData? prefixIconData,
  }) {
    const Color primaryColor = _ProductServiceScreenState._primaryColor;
    const Color textColorSecondary = _ProductServiceScreenState._textColorSecondary;
    // const Color cardBackgroundColor = _ProductServiceScreenState._cardBackgroundColor; // Not used
    const Color secondaryColor = _ProductServiceScreenState._secondaryColor;
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLength: maxLength,
      maxLines: maxLines,
      style: GoogleFonts.poppins(color: _ProductServiceScreenState._textColorPrimary, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: GoogleFonts.poppins(color: textColorSecondary),
        prefixIcon: prefixIconData != null ? Icon(prefixIconData, color: primaryColor, size: 22) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primaryColor, width: 1.5)),
        filled: true,
        fillColor: secondaryColor.withOpacity(0.5),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        counterText: "",
      ),
    );
  }
}

class ProductListSection extends StatelessWidget {
  final List<Map<String, dynamic>> productList;
  final Function(int) onEditProduct;
  final Function(int) onDeleteProduct;
  final AppState appState;
  final NumberFormat currencyFormat;
  final Color primaryColor;
  final Color textColorPrimary;
  final Color textColorSecondary;
  final Color cardBackgroundColor;
  final Color accentColor;
  final String selectedCategoryText;

  const ProductListSection({
    required this.productList,
    required this.onEditProduct,
    required this.onDeleteProduct,
    required this.appState,
    required this.currencyFormat,
    required this.primaryColor,
    required this.textColorPrimary,
    required this.textColorSecondary,
    required this.cardBackgroundColor,
    required this.accentColor,
    required this.selectedCategoryText,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 80.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Text(
              "Danh sách: ${selectedCategoryText.replaceFirst("Sản phẩm/Dịch vụ ", "")}",
              style: GoogleFonts.poppins(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: textColorPrimary),
            ),
          ),
          productList.isEmpty
              ? Center(
            child: Padding(
              padding: const EdgeInsets.all(30.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2_outlined, size: 70, color: Colors.grey.shade400),
                  SizedBox(height: 16),
                  Text(
                    "Chưa có sản phẩm/dịch vụ nào",
                    style: GoogleFonts.poppins(fontSize: 17, color: textColorSecondary),
                  ),
                  SizedBox(height: 4),
                  Text(
                    "Thêm mới ở tab bên cạnh để quản lý.",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
          )
              : ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: productList.length,
            itemBuilder: (context, index) {
              final product = productList[index];
              return Dismissible(
                key: Key(product['name'].toString() + index.toString()),
                background: Container(
                  color: accentColor.withOpacity(0.8),
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  child: const Icon(Icons.delete_sweep_outlined,
                      color: Colors.white, size: 26),
                ),
                direction: DismissDirection.endToStart,
                onDismissed: (direction) {
                  onDeleteProduct(index);
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
                      child: Text(
                        product['name'] != null && (product['name'] as String).isNotEmpty
                            ? (product['name'] as String)[0].toUpperCase()
                            : "?",
                        style: GoogleFonts.poppins(
                            color: primaryColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 18),
                      ),
                      radius: 20,
                    ),
                    title: Text(
                      product['name']?.toString() ?? 'N/A',
                      style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: textColorPrimary),
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      "Giá: ${currencyFormat.format(product['price'] ?? 0.0)}",
                      style: GoogleFonts.poppins(
                          fontSize: 13.5,
                          color: textColorSecondary,
                          fontWeight: FontWeight.w500),
                    ),
                    trailing: IconButton(
                      icon: Icon(Icons.edit_note_outlined,
                          color: primaryColor.withOpacity(0.9), size: 22),
                      onPressed: () => onEditProduct(index),
                      splashRadius: 18,
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(minWidth: 30, minHeight: 30),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}