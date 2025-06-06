import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../state/app_state.dart'; // [cite: 1105]
import '/screens/expense_manager.dart'; // [cite: 1105]
import '/screens/revenue_manager.dart'; // Cần import để tải sản phẩm
import 'package:google_fonts/google_fonts.dart'; // [cite: 1106]

class UpdateExpenseListScreen extends StatefulWidget {
  final String category; // [cite: 1106]
  const UpdateExpenseListScreen({Key? key, required this.category}) // [cite: 1107]
      : super(key: key);

  @override
  _UpdateExpenseListScreenState createState() =>
      _UpdateExpenseListScreenState(); // [cite: 1108]
}

class _UpdateExpenseListScreenState extends State<UpdateExpenseListScreen>
    with SingleTickerProviderStateMixin {
  List<TextEditingController> nameControllers = []; // [cite: 1108]
  List<TextEditingController> priceControllers = []; // MỚI
  List<String?> selectedProductIdForExpense = []; // MỚI: Lưu sản phẩm được chọn cho mỗi chi phí
  List<Map<String, dynamic>> availableProductsForDropdown = []; // MỚI: Danh sách sản phẩm cho dropdown
  bool isLoadingProducts = true; // MỚI: Trạng thái tải sản phẩm

  List<FocusNode> nameFocusNodes = []; // [cite: 1109]
  List<FocusNode> priceFocusNodes = []; // MỚI
  late AnimationController _animationController; // [cite: 1109]
  late Animation<Offset> _slideAnimation; // [cite: 1109]
  late Animation<double> _fadeAnimation; // [cite: 1109]
  late Animation<double> _buttonScaleAnimation; // [cite: 1109]
  bool _isLoading = true; // [cite: 1109]
  bool hasError = false; // [cite: 1110]
  final NumberFormat _inputPriceFormatter = NumberFormat("#,##0", "vi_VN"); // [cite: 1110]

  static const Color _appBarColor = Color(0xFFE53935); // [cite: 1110]
  static const Color _accentColor = Color(0xFFD32F2F); // [cite: 1111]
  static const Color _secondaryColor = Color(0xFFF1F5F9); // [cite: 1112]
  static const Color _textColorPrimary = Color(0xFF1D2D3A); // [cite: 1113]
  static const Color _textColorSecondary = Color(0xFF6E7A8A); // [cite: 1113]
  static const Color _cardBackgroundColor = Colors.white; // [cite: 1114]

  @override
  void initState() {
    super.initState();
    if (widget.category != "Chi phí biến đổi") { // [cite: 1116]
      WidgetsBinding.instance.addPostFrameCallback((_) { // [cite: 1116]
        if (mounted) {
          Navigator.pop(context); // [cite: 1117]
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    "Danh sách chi phí cố định được quản lý trong 'Thêm cố định tháng'", // [cite: 1117]
                    style: GoogleFonts.poppins())), // [cite: 1118]
          );
        }
      });
      _isLoading = false; // [cite: 1119]
      return; // Thoát sớm nếu không phải category hợp lệ
    }
    _animationController = AnimationController( // [cite: 1119]
        duration: const Duration(milliseconds: 700), vsync: this);
    _slideAnimation = Tween<Offset>( // [cite: 1120]
        begin: const Offset(0, 0.5), end: Offset.zero) // [cite: 1120]
        .animate(CurvedAnimation( // [cite: 1120]
        parent: _animationController, curve: Curves.easeOut)); // [cite: 1120]
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate( // [cite: 1121]
        CurvedAnimation(parent: _animationController, curve: Curves.easeIn)); // [cite: 1121]
    _buttonScaleAnimation = TweenSequence([ // [cite: 1122]
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.95), weight: 50), // [cite: 1122]
      TweenSequenceItem(tween: Tween<double>(begin: 0.95, end: 1.0), weight: 50), // [cite: 1122]
    ]).animate(CurvedAnimation( // [cite: 1122]
        parent: _animationController, curve: Curves.easeInOut));

    if (widget.category == "Chi phí biến đổi") { // [cite: 1123]
      _loadInitialData();
    }
  }

  Future<void> _loadInitialData() async {
    await _loadProductsForDropdown();
    await _loadInitialExpenseItems();
  }

  Future<void> _loadProductsForDropdown() async {
    if (!mounted) return;
    setState(() {
      isLoadingProducts = true;
    });
    final appState = Provider.of<AppState>(context, listen: false);
    try {
      List<Map<String, dynamic>> mainProducts = await RevenueManager.loadProducts(appState, "Doanh thu chính");
      List<Map<String, dynamic>> extraProducts = await RevenueManager.loadProducts(appState, "Doanh thu phụ"); // Hoặc key danh mục sản phẩm phụ của bạn

      final Set<String> productIds = {}; // Sửa: Dùng Set để lưu các ID đã gặp
      final List<Map<String, dynamic>> combinedProducts = [];
      for (var product in [...mainProducts, ...extraProducts]) {
        final productId = product['id'] as String?;
        // Sửa: Kiểm tra và thêm vào danh sách dựa trên ID, không phải tên
        if (productId != null && productIds.add(productId)) {
          combinedProducts.add(product);
        }
      }
      if (mounted) {
        setState(() {
          availableProductsForDropdown = combinedProducts;
          isLoadingProducts = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoadingProducts = false;
        });
        _showStyledSnackBar("Lỗi tải danh sách sản phẩm: $e", isError: true);
      }
    }
  }

  Future<void> _loadInitialExpenseItems() async {
    if (!mounted) return; // [cite: 1124]
    setState(() {
      _isLoading = true; // [cite: 1125]
      hasError = false; // [cite: 1125]
    });
    try {
      final appState = Provider.of<AppState>(context, listen: false); // [cite: 1126]
      final data = await ExpenseManager.loadAvailableVariableExpenses(appState); // [cite: 1126]
      if (mounted) {
        setState(() {
          nameControllers = data // [cite: 1127]
              .map((item) =>
              TextEditingController(text: item['name']?.toString() ?? ''))
              .toList();
          priceControllers = data // MỚI
              .map((item) => TextEditingController(
              text: _inputPriceFormatter
                  .format(item['price'] as num? ?? 0.0)))
              .toList();
          selectedProductIdForExpense = data //MỚI
              .map((item) => item['linkedProductId'] as String?)
              .toList();
          nameFocusNodes = data.map((_) => FocusNode()).toList(); // [cite: 1127]
          priceFocusNodes = data.map((_) => FocusNode()).toList(); // MỚI
          if (nameControllers.isEmpty) { // [cite: 1127]
            _addControllerInternal(); // [cite: 1127]
          }
          _isLoading = false; // [cite: 1127]
          _animationController.forward(); // [cite: 1128]
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false; // [cite: 1128]
          hasError = true; // [cite: 1128]
        });
        final appState = Provider.of<AppState>(context, listen: false); // [cite: 1129]
        final String monthKey =
        DateFormat('yyyy-MM').format(appState.selectedDate); // [cite: 1130]
        final String hiveKey =
            '${appState.userId}-variableExpenseList-$monthKey'; // [cite: 1130]
        final variableExpenseListBox = Hive.box('variableExpenseListBox'); // [cite: 1130]
        final cachedData = variableExpenseListBox.get(hiveKey); // [cite: 1130]
        if (cachedData != null && mounted) { // [cite: 1131]
          final List<Map<String, dynamic>> castedList =
          List<Map<String, dynamic>>.from(cachedData);
          setState(() {
            nameControllers = castedList // [cite: 1131]
                .map((item) => TextEditingController(
                text: item['name']?.toString() ?? ''))
                .toList();
            priceControllers = castedList // MỚI
                .map((item) => TextEditingController(
                text: _inputPriceFormatter
                    .format(item['price'] as num? ?? 0.0)))
                .toList();
            selectedProductIdForExpense = castedList // MỚI
                .map((item) => item['linkedProductId'] as String?)
                .toList();
            nameFocusNodes =
                castedList.map((_) => FocusNode()).toList(); // [cite: 1131]
            priceFocusNodes = castedList.map((_) => FocusNode()).toList(); // MỚI
            if (nameControllers.isEmpty) { // [cite: 1131]
              _addControllerInternal(); // [cite: 1132]
            }
            _isLoading = false; // [cite: 1132]
            hasError = false; // [cite: 1132]
            _animationController.forward(); // [cite: 1132]
          });
        } else if (mounted) {
          _showStyledSnackBar("Lỗi tải danh sách chi phí và không có dữ liệu cache.", isError: true); // [cite: 1133]
        }
      }
      print("Error in _loadInitialExpenseItems: $e"); // [cite: 1133]
    }
  }

  @override
  void dispose() {
    for (var controller in nameControllers) { // [cite: 1135]
      controller.dispose(); // [cite: 1135]
    }
    for (var controller in priceControllers) { // MỚI
      controller.dispose();
    }
    for (var focusNode in nameFocusNodes) { // [cite: 1136]
      focusNode.dispose(); // [cite: 1136]
    }
    for (var focusNode in priceFocusNodes) { // MỚI
      focusNode.dispose();
    }
    _animationController.dispose(); // [cite: 1137]
    super.dispose();
  }

  void _addControllerInternal() {
    nameControllers.add(TextEditingController()); // [cite: 1137]
    priceControllers.add(TextEditingController(text: _inputPriceFormatter.format(0))); // MỚI
    selectedProductIdForExpense.add(null); // MỚI
    nameFocusNodes.add(FocusNode()); // [cite: 1137]
    priceFocusNodes.add(FocusNode()); // MỚI
  }

  void addController() {
    if (!mounted) return; // [cite: 1138]
    setState(() {
      _animationController.reset(); // [cite: 1139]
      _animationController.forward(); // [cite: 1139]
      nameControllers.add(TextEditingController()); // [cite: 1139]
      priceControllers.add(TextEditingController(text: _inputPriceFormatter.format(0))); // MỚI
      selectedProductIdForExpense.add(null); // MỚI
      nameFocusNodes.add(FocusNode()); // [cite: 1139]
      priceFocusNodes.add(FocusNode()); // MỚI
    });
    WidgetsBinding.instance.addPostFrameCallback((_) { // [cite: 1140]
      if (nameFocusNodes.isNotEmpty && mounted) { // [cite: 1140]
        FocusScope.of(context).requestFocus(nameFocusNodes.last); // [cite: 1140]
      }
    });
  }

  void removeController(int index) {
    if (!mounted || index < 0 || index >= nameControllers.length) return; // [cite: 1141]
    setState(() {
      nameControllers[index].dispose(); // [cite: 1142]
      priceControllers[index].dispose(); // MỚI
      nameFocusNodes[index].dispose(); // [cite: 1142]
      priceFocusNodes[index].dispose(); // MỚI

      nameControllers.removeAt(index); // [cite: 1142]
      priceControllers.removeAt(index); // MỚI
      selectedProductIdForExpense.removeAt(index); // MỚI
      nameFocusNodes.removeAt(index); // [cite: 1142]
      priceFocusNodes.removeAt(index); // MỚI
      if (nameControllers.isEmpty) { // [cite: 1142]
        _addControllerInternal(); // Sửa lại để thêm 1 hàng trống nếu xóa hết // [cite: 1142]
      }
    });
  }

  void _showStyledSnackBar(String message, {bool isError = false}) {
    if (!mounted) return; // [cite: 1143]
    ScaffoldMessenger.of(context).showSnackBar( // [cite: 1143]
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins(color: Colors.white)), // [cite: 1144]
        backgroundColor: isError ? _accentColor : _appBarColor, // [cite: 1144]
        behavior: SnackBarBehavior.floating, // [cite: 1144]
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), // [cite: 1144]
        margin: const EdgeInsets.all(10), // [cite: 1144]
      ),
    );
  }

  void saveUpdatedList(AppState appState) async {
    if (!mounted) return; // [cite: 1145]
    FocusScope.of(context).unfocus(); // [cite: 1145]

    List<Map<String, dynamic>> updatedList = [];
    final Set<String> names = {}; // [cite: 1147]
    for (int i = 0; i < nameControllers.length; i++) {
      String name = nameControllers[i].text.trim();
      String priceText = priceControllers[i].text.trim().replaceAll('.', '');
      String? linkedProductId = selectedProductIdForExpense[i];

      if (name.isNotEmpty) {
        double price = double.tryParse(priceText) ?? 0.0; // [cite: 1147]
        if (price < 0) { // [cite: 1147]
          _showStyledSnackBar(
              "Giá của '$name' không hợp lệ. Vui lòng sửa lại.", // [cite: 1147]
              isError: true);
          return; // [cite: 1147]
        }
        if (!names.add(name.toLowerCase())) { // [cite: 1148]
          _showStyledSnackBar(
              "Tên khoản chi '$name' bị trùng lặp. Vui lòng sửa lại.", // [cite: 1148]
              isError: true);
          return; // [cite: 1149]
        }
        updatedList.add({'name': name, 'price': price, 'linkedProductId': linkedProductId}); // MỚI: Thêm linkedProduct
      } else if (priceText.isNotEmpty && priceText != "0") {
        _showStyledSnackBar(
            "Vui lòng nhập tên cho khoản chi có giá '${priceControllers[i].text.trim()}'.", // [cite: 1150]
            isError: true);
        return; // [cite: 1150]
      } else if (linkedProductId != null && name.isEmpty) {
        _showStyledSnackBar(
            "Vui lòng nhập tên cho khoản chi được gắn với sản phẩm '$linkedProductId'.",
            isError: true);
        return;
      }
    }

    if (updatedList.isEmpty && nameControllers.every((c) => c.text.trim().isEmpty)) { // [cite: 1151]
      _showStyledSnackBar("Danh sách trống, không có gì để lưu.", isError: false); // [cite: 1151]
      return; // [cite: 1152]
    }
    if (updatedList.isEmpty && nameControllers.any((c) => c.text.trim().isNotEmpty)) {
      _showStyledSnackBar("Vui lòng nhập ít nhất một tên chi phí hợp lệ và giá của nó.", isError: true); // [cite: 1152]
      return;
    }

    showDialog(
        context: context, // [cite: 1152]
        barrierDismissible: false, // [cite: 1152]
        builder: (dialogContext) => AlertDialog( // [cite: 1152]
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15)), // [cite: 1152]
          content: Row(
            children: [ // [cite: 1152]
              CircularProgressIndicator(color: _appBarColor), // [cite: 1152]
              const SizedBox(width: 20), // [cite: 1153]
              Text("Đang lưu...", // [cite: 1153]
                  style: GoogleFonts.poppins(color: _textColorSecondary)), // [cite: 1153]
            ],
          ),
        ));
    try {
      if (appState.userId == null) throw Exception('User ID không tồn tại'); // [cite: 1154]
      final FirebaseFirestore firestore = FirebaseFirestore.instance; // [cite: 1155]
      String monthKey = DateFormat('yyyy-MM').format(appState.selectedDate); // [cite: 1156]
      String firestoreDocKey =
      appState.getKey('variableExpenseList_$monthKey'); // [cite: 1157]

      await firestore
          .collection('users')
          .doc(appState.userId) // [cite: 1158]
          .collection('expenses') // [cite: 1158]
          .doc('variableList') // [cite: 1158]
          .collection('monthly') // [cite: 1158]
          .doc(firestoreDocKey) // [cite: 1158]
          .set({ // [cite: 1158]
        'products': updatedList, // [cite: 1158] // Lưu cấu trúc mới
        'updatedAt': FieldValue.serverTimestamp(), // [cite: 1159]
      });

      final String hiveBoxKey =
          '${appState.userId}-variableExpenseList-$monthKey'; // [cite: 1160]
      final variableExpenseListBox = Hive.box('variableExpenseListBox'); // [cite: 1161]
      await variableExpenseListBox.put(hiveBoxKey, updatedList); // [cite: 1162]
      appState.notifyProductsUpdated(); // [cite: 1162]

      Navigator.pop(context); // Đóng dialog "Đang lưu..." // [cite: 1163]
      _showStyledSnackBar("Đã lưu danh sách chi phí biến đổi cho tháng"); // [cite: 1164]
      Navigator.pop(context, true); // [cite: 1165]
    } catch (e) {
      Navigator.pop(context); // [cite: 1166]
      print("Error saving variable expense list: $e"); // [cite: 1167]
      _showStyledSnackBar("Lỗi khi lưu dữ liệu: $e", isError: true); // [cite: 1168]
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context, listen: false); // [cite: 1169]
    final screenWidth = MediaQuery.of(context).size.width; // [cite: 1170]

    if (widget.category != "Chi phí biến đổi") { // [cite: 1171]
      return Scaffold(
        body: Center(
            child: Text("Loại chi phí không hợp lệ cho màn hình này.", // [cite: 1171]
                style: GoogleFonts.poppins())), // [cite: 1171]
      );
    }
    return GestureDetector( // [cite: 1172]
      onTap: () => FocusScope.of(context).unfocus(), // [cite: 1172]
      behavior: HitTestBehavior.opaque, // [cite: 1172]
      child: Scaffold(
        backgroundColor: _secondaryColor, // [cite: 1172]
        body: Stack( // [cite: 1172]
          children: [
            Container( // [cite: 1172]
              height: MediaQuery.of(context).size.height * 0.22, // [cite: 1172]
              color: _appBarColor.withOpacity(0.95), // [cite: 1173]
            ),
            SafeArea( // [cite: 1173]
              child: Column( // [cite: 1173]
                children: [
                  Padding( // [cite: 1173]
                    padding: const EdgeInsets.symmetric( // [cite: 1174]
                        horizontal: 16.0, vertical: 8.0),
                    child: Row( // [cite: 1174]
                      mainAxisAlignment: MainAxisAlignment.spaceBetween, // [cite: 1174]
                      children: [
                        Flexible( // [cite: 1175]
                          child: Row( // [cite: 1175]
                            children: [
                              IconButton( // [cite: 1176]
                                icon: const Icon(Icons.arrow_back_ios_new, // [cite: 1176]
                                    color: Colors.white), // [cite: 1177]
                                onPressed: () => Navigator.pop(context), // [cite: 1177]
                                splashRadius: 20, // [cite: 1178]
                              ),
                              const SizedBox(width: 8), // [cite: 1178]
                              Flexible( // [cite: 1179]
                                child: Column( // [cite: 1179]
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start, // [cite: 1179]
                                  children: [
                                    Text( // [cite: 1180]
                                      "DS Chi phí biến đổi", // [cite: 1181]
                                      style: GoogleFonts.poppins( // [cite: 1181]
                                          fontSize: 20, // [cite: 1181]
                                          fontWeight: FontWeight.w600, // [cite: 1182]
                                          color: Colors.white), // [cite: 1182]
                                      overflow: TextOverflow.ellipsis, // [cite: 1183]
                                    ),
                                    Container( // [cite: 1183]
                                      padding: const EdgeInsets.symmetric( // [cite: 1184]
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration( // [cite: 1185]
                                        color: Colors.white.withOpacity(0.25), // [cite: 1186]
                                        borderRadius:
                                        BorderRadius.circular(8), // [cite: 1186]
                                      ),
                                      child: Text( // [cite: 1187]
                                        "Tháng ${DateFormat('MMMM y', 'vi').format(appState.selectedDate)}", // [cite: 1187]
                                        style: GoogleFonts.poppins( // [cite: 1188]
                                            fontSize: 12, // [cite: 1188]
                                            color: Colors.white, // [cite: 1188]
                                            fontWeight: FontWeight.w500), // [cite: 1189]
                                        overflow: TextOverflow.ellipsis, // [cite: 1189]
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        ScaleTransition( // [cite: 1192]
                          scale: _buttonScaleAnimation, // [cite: 1192]
                          child: IconButton( // [cite: 1193]
                            icon: const Icon(Icons.add_circle_outline, // [cite: 1193]
                                color: Colors.white, // [cite: 1195]
                                size: 28), // [cite: 1195]
                            onPressed: addController, // [cite: 1195]
                            tooltip: "Thêm mục chi phí", // [cite: 1195]
                            splashRadius: 22, // [cite: 1195]
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10), // [cite: 1197]
                  Expanded( // [cite: 1197]
                    child: Padding(
                      padding:
                      const EdgeInsets.symmetric(horizontal: 16.0), // [cite: 1197]
                      child: _isLoading
                          ? Center(child: CircularProgressIndicator(color: _appBarColor)) // [cite: 1198]
                          : hasError
                          ? Center(child: Text("Không thể tải danh sách.", style: GoogleFonts.poppins(color: _textColorSecondary))) // [cite: 1199]
                          : nameControllers.isEmpty && !_isLoading
                          ? Center( // [cite: 1199]
                          child: Text( // [cite: 1199]
                            "Nhấn (+) để thêm mục chi phí biến đổi.", // [cite: 1200]
                            textAlign: TextAlign.center, // [cite: 1200]
                            style: GoogleFonts.poppins( // [cite: 1200]
                                fontSize: 16, color: _textColorSecondary), // [cite: 1201]
                          ))
                          : SlideTransition( // [cite: 1201]
                        position: _slideAnimation, // [cite: 1202]
                        child: FadeTransition( // [cite: 1202]
                          opacity: _fadeAnimation, // [cite: 1202]
                          child: ListView.builder( // [cite: 1202]
                            padding: const EdgeInsets.only(top: 8, bottom: 80), // Điều chỉnh bottom padding
                            shrinkWrap: true, // [cite: 1203]
                            itemCount: nameControllers.length, // [cite: 1203]
                            itemBuilder: (context, index) {
                              return Padding( // [cite: 1204]
                                padding: const EdgeInsets.symmetric(vertical: 6.0), // [cite: 1204]
                                child: Row( // [cite: 1205]
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded( // [cite: 1205]
                                      flex: 3, // [cite: 1205]
                                      child: TextField(
                                        controller: nameControllers[index], // [cite: 1206]
                                        focusNode: nameFocusNodes[index], // [cite: 1206]
                                        style: GoogleFonts.poppins(color: _textColorPrimary, fontWeight: FontWeight.w500), // [cite: 1207]
                                        decoration: InputDecoration( // [cite: 1207]
                                          hintText: "Tên khoản chi ${index + 1}", // [cite: 1208]
                                          hintStyle: GoogleFonts.poppins(color: _textColorSecondary.withOpacity(0.7)), // [cite: 1209]
                                          prefixIcon: Icon(Icons.edit_note_outlined, color: _appBarColor.withOpacity(0.8), size: 22), // [cite: 1209]
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)), // [cite: 1210]
                                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)), // [cite: 1212]
                                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _appBarColor, width: 1.5)), // [cite: 1213]
                                          filled: true, // [cite: 1215]
                                          fillColor: _cardBackgroundColor, // [cite: 1216]
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), // [cite: 1216]
                                          counterText: "", // [cite: 1217]
                                        ),
                                        maxLines: 1, // [cite: 1217]
                                        maxLength: 50, // [cite: 1218]
                                      ),
                                    ),
                                    const SizedBox(width: 8), // [cite: 1219]
                                    Expanded(
                                      flex: 2, // [cite: 1219]
                                      child: TextField(
                                        controller: priceControllers[index], // [cite: 1219]
                                        focusNode: priceFocusNodes[index], // [cite: 1219]
                                        keyboardType: TextInputType.numberWithOptions(decimal: false), // [cite: 1219]
                                        inputFormatters: [ // [cite: 1219]
                                          FilteringTextInputFormatter.digitsOnly, // [cite: 1219]
                                          TextInputFormatter.withFunction( // [cite: 1219]
                                                (oldValue, newValue) { // [cite: 1219]
                                              if (newValue.text.isEmpty) return newValue.copyWith(text: '0'); // [cite: 1219]
                                              final String plainNumberText = newValue.text.replaceAll('.', '').replaceAll(',', ''); // [cite: 1219]
                                              final number = int.tryParse(plainNumberText); // [cite: 1219]
                                              if (number == null) return oldValue; // [cite: 1219]
                                              final formattedText = _inputPriceFormatter.format(number); // [cite: 1220]
                                              return newValue.copyWith( // [cite: 1220]
                                                text: formattedText, // [cite: 1220]
                                                selection: TextSelection.collapsed(offset: formattedText.length), // [cite: 1221]
                                              );
                                            },
                                          ),
                                        ],
                                        textAlign: TextAlign.right, // [cite: 1223]
                                        style: GoogleFonts.poppins(color: _textColorPrimary, fontWeight: FontWeight.w500), // [cite: 1223]
                                        decoration: InputDecoration( // [cite: 1224]
                                          hintText: "Giá", // [cite: 1224]
                                          hintStyle: GoogleFonts.poppins(color: _textColorSecondary.withOpacity(0.7)), // [cite: 1224]
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)), // [cite: 1225]
                                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)), // [cite: 1225]
                                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _appBarColor, width: 1.5)), // [cite: 1226]
                                          filled: true, // [cite: 1226]
                                          fillColor: _cardBackgroundColor, // [cite: 1227]
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14), // [cite: 1227]
                                          counterText: "", // [cite: 1228]
                                        ),
                                        maxLength: 15, // [cite: 1228]
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // Dropdown chọn sản phẩm
                                    Expanded(
                                      flex: 3, // Điều chỉnh flex cho phù hợp
                                      child: isLoadingProducts
                                          ? Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: _appBarColor,)))
                                          : DropdownButtonFormField<String>(
                                        isExpanded: true,
                                        decoration: InputDecoration(
                                          hintText: "Gắn SP",
                                          hintStyle: GoogleFonts.poppins(fontSize: 13, color: _textColorSecondary.withOpacity(0.7)),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _appBarColor, width: 1.5)),
                                          filled: true,
                                          fillColor: _cardBackgroundColor,
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11), // Adjusted padding
                                          isDense: true,
                                        ),
                                        value: selectedProductIdForExpense[index],
                                        style: GoogleFonts.poppins(color: _textColorPrimary, fontSize: 14),
                                        items: [
                                          DropdownMenuItem<String>(
                                            value: null,
                                            child: Text("Không gắn", style: GoogleFonts.poppins(fontStyle: FontStyle.italic, fontSize: 13, color: _textColorSecondary)),
                                          ),
                                          ...availableProductsForDropdown.map((product) {
                                            return DropdownMenuItem<String>(
                                              value: product['id'] as String,
                                              child: Text(
                                                product['name'] as String,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            );
                                          }).toList(),
                                        ],
                                        onChanged: (String? newValue) {
                                          setState(() {
                                            selectedProductIdForExpense[index] = newValue;
                                          });
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 4), // [cite: 1230]
                                    ScaleTransition( // [cite: 1219]
                                      scale: _buttonScaleAnimation, // [cite: 1220]
                                      child: IconButton( // [cite: 1220]
                                        icon: Icon(Icons.remove_circle_outline, color: _accentColor, size: 26), // [cite: 1221]
                                        onPressed: () => removeController(index), // [cite: 1221]
                                        tooltip: "Xóa mục này", // [cite: 1221]
                                        splashRadius: 20, // [cite: 1133]
                                        padding: EdgeInsets.zero, // [cite: 1133]
                                        constraints: const BoxConstraints(), // [cite: 1133]
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (!_isLoading) // [cite: 1225]
                    Padding( // [cite: 1225]
                      padding: const EdgeInsets.fromLTRB(16.0,8.0,16.0,16.0), // Điều chỉnh padding
                      child: ScaleTransition( // [cite: 1226]
                        scale: _buttonScaleAnimation, // [cite: 1226]
                        child: ElevatedButton.icon( // [cite: 1226]
                          style: ElevatedButton.styleFrom( // [cite: 1226]
                            backgroundColor: _appBarColor, // [cite: 1227]
                            foregroundColor: Colors.white, // [cite: 1227]
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), // [cite: 1228]
                            minimumSize: Size(screenWidth, 52), // [cite: 1228]
                            padding: const EdgeInsets.symmetric(vertical: 14), // [cite: 1228]
                            elevation: 2, // [cite: 1228]
                          ),
                          onPressed: () => saveUpdatedList(appState), // [cite: 1229]
                          icon: const Icon(Icons.save_alt_outlined, size: 20), // [cite: 1229]
                          label: Text( // [cite: 1230]
                            "Lưu danh sách", // [cite: 1230]
                            style: GoogleFonts.poppins( // [cite: 1230]
                                fontSize: 16.5, fontWeight: FontWeight.w600), // [cite: 1231]
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}