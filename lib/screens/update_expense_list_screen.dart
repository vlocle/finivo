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
import 'package:fingrowth/screens/report_screen.dart';

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
  List<String> costTypes = [];
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
      final appState = Provider.of<AppState>(context, listen: false);
      appState.productsUpdated.addListener(_onExpenseListUpdated);
    }
  }

  void _onExpenseListUpdated() {
    // Khi AppState báo có cập nhật, hàm này sẽ được gọi
    // và chúng ta chỉ cần tải lại dữ liệu ban đầu
    print("Nhận tín hiệu cập nhật danh sách chi phí, đang tải lại...");
    if (mounted) {
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
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      hasError = false;
    });

    try {
      final appState = Provider.of<AppState>(context, listen: false);
      final data = await ExpenseManager.loadAvailableVariableExpenses(appState);

      if (mounted) {
        final validProductIds =
        availableProductsForDropdown.map((p) => p['id'] as String?).toSet();

        final cleanedData = data.map((expense) {
          final linkedId = expense['linkedProductId'] as String?;
          if (linkedId != null && !validProductIds.contains(linkedId)) {
            final cleanedExpense = Map<String, dynamic>.from(expense);
            cleanedExpense['linkedProductId'] = null;
            return cleanedExpense;
          }
          return expense;
        }).toList();

        setState(() {
          nameControllers = cleanedData
              .map((item) =>
              TextEditingController(text: item['name']?.toString() ?? ''))
              .toList();

          // =================================================================
          // <<< SỬA LỖI CỐT LÕI NẰM Ở ĐÂY >>>
          priceControllers = cleanedData.map((item) {
            final double value = item['costValue'] ?? 0.0;

            // Chuyển đổi số double thành chuỗi một cách thông minh:
            // Nếu là số nguyên (vd: 100000.0), chỉ lấy phần nguyên (100000).
            // Nếu là số thập phân (vd: 10.5), giữ nguyên.
            final String textValue = (value == value.truncate())
                ? value.toInt().toString()
                : value.toString();

            return TextEditingController(text: textValue);
          }).toList();
          // <<< KẾT THÚC SỬA LỖI >>>
          // =================================================================

          costTypes = cleanedData
              .map((item) => item['costType']?.toString() ?? 'fixed')
              .toList();

          selectedProductIdForExpense = cleanedData
              .map((item) => item['linkedProductId'] as String?)
              .toList();

          nameFocusNodes = cleanedData.map((_) => FocusNode()).toList();
          priceFocusNodes = cleanedData.map((_) => FocusNode()).toList();

          if (nameControllers.isEmpty) {
            _addControllerInternal();
          }
          _isLoading = false;
          _animationController.forward();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          hasError = true;
        });
        _showStyledSnackBar("Lỗi tải danh sách chi phí: $e", isError: true);
        print("Error in _loadInitialExpenseItems: $e");
      }
    }
  }

  @override
  void dispose() {
    Provider.of<AppState>(context, listen: false)
        .productsUpdated.removeListener(_onExpenseListUpdated);

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
    priceControllers.add(TextEditingController(text: "0"));
    costTypes.add('fixed');
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
      priceControllers.add(TextEditingController(text: "0"));
      costTypes.add('fixed');
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
      costTypes.removeAt(index);
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
        backgroundColor: isError ? AppColors.chartRed : AppColors.chartRed, // [cite: 1144]
        behavior: SnackBarBehavior.floating, // [cite: 1144]
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), // [cite: 1144]
        margin: const EdgeInsets.all(10), // [cite: 1144]
      ),
    );
  }

  void saveUpdatedList(AppState appState) async {
    if (!mounted) return;
    FocusScope.of(context).unfocus();

    List<Map<String, dynamic>> updatedList = [];
    final Set<String> names = {};

    for (int i = 0; i < nameControllers.length; i++) {
      String name = nameControllers[i].text.trim();

      // =================================================================
      // <<< SỬA LỖI LOGIC ĐỌC GIÁ TRỊ TẠI ĐÂY >>>
      // Logic mới an toàn hơn, chỉ đọc các ký tự số từ controller
      String priceText = priceControllers[i].text.trim();
      // <<< KẾT THÚC SỬA LỖI >>>
      // =================================================================

      String? linkedProductId = selectedProductIdForExpense[i];

      if (name.isNotEmpty) {
        double price = double.tryParse(priceText) ?? 0.0;

        if (price < 0) {
          _showStyledSnackBar("Giá trị của '$name' không hợp lệ.", isError: true);
          return;
        }
        if (!names.add(name.toLowerCase())) {
          _showStyledSnackBar("Tên khoản chi '$name' bị trùng lặp.", isError: true);
          return;
        }
        updatedList.add({
          'name': name,
          'costType': costTypes[i],
          'costValue': price,
          'linkedProductId': linkedProductId
        });
      } else if (priceText.isNotEmpty && priceText != "0") {
        _showStyledSnackBar("Vui lòng nhập tên cho khoản chi có giá trị.", isError: true);
        return;
      } else if (linkedProductId != null && name.isEmpty) {
        _showStyledSnackBar("Vui lòng nhập tên cho khoản chi được gắn với sản phẩm.", isError: true);
        return;
      }
    }

    if (updatedList.isEmpty && nameControllers.every((c) => c.text.trim().isEmpty)) {
      _showStyledSnackBar("Danh sách trống, không có gì để lưu.", isError: false);
      return;
    }
    if (updatedList.isEmpty && nameControllers.any((c) => c.text.trim().isNotEmpty)) {
      _showStyledSnackBar("Vui lòng nhập ít nhất một tên chi phí hợp lệ.", isError: true);
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
              CircularProgressIndicator(color: AppColors.chartRed), // [cite: 1152]
              const SizedBox(width: 20), // [cite: 1153]
              Text("Đang lưu...", // [cite: 1153]
                  style: GoogleFonts.poppins(color: AppColors.getTextColor(context))), // [cite: 1153]
            ],
          ),
        ));
    try {
      if (appState.activeUserId == null) throw Exception('User ID không tồn tại'); // [cite: 1154]
      final FirebaseFirestore firestore = FirebaseFirestore.instance; // [cite: 1155]
      String monthKey = DateFormat('yyyy-MM').format(appState.selectedDate); // [cite: 1156]
      String firestoreDocKey =
      appState.getKey('variableExpenseList_$monthKey'); // [cite: 1157]

      await firestore
          .collection('users')
          .doc(appState.activeUserId) // [cite: 1158]
          .collection('expenses') // [cite: 1158]
          .doc('variableList') // [cite: 1158]
          .collection('monthly') // [cite: 1158]
          .doc(firestoreDocKey) // [cite: 1158]
          .set({ // [cite: 1158]
        'products': updatedList, // [cite: 1158] // Lưu cấu trúc mới
        'updatedAt': FieldValue.serverTimestamp(), // [cite: 1159]
      });

      final String hiveBoxKey =
          '${appState.activeUserId}-variableExpenseList-$monthKey'; // [cite: 1160]
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
    final appState = context.read<AppState>();
    final screenWidth = MediaQuery.of(context).size.width; // [cite: 1170]
    final bool canManageTypes = appState.hasPermission('canManageExpenseTypes');

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
        backgroundColor: AppColors.getBackgroundColor(context), // [cite: 1172]
        body: ValueListenableBuilder<int>(
          valueListenable: appState.permissionVersion, // Lắng nghe tín hiệu quyền
          builder: (context, permissionVersion, child) {
            // Logic kiểm tra quyền được đặt ở đây và truyền xuống các widget con
            final bool canManageTypes = appState.hasPermission('canManageExpenseTypes');

            return Stack(
              children: [
                Container(
                  height: MediaQuery.of(context).size.height * 0.22,
                  color: AppColors.chartRed.withOpacity(0.95),
                ),
                SafeArea(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                                    onPressed: () => Navigator.pop(context),
                                    splashRadius: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text("DS Chi phí biến đổi", style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white), overflow: TextOverflow.ellipsis),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.25), borderRadius: BorderRadius.circular(8)),
                                          child: Text("Tháng ${DateFormat('MMMM y', 'vi').format(appState.selectedDate)}", style: GoogleFonts.poppins(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ScaleTransition(
                              scale: _buttonScaleAnimation,
                              child: IconButton(
                                icon: const Icon(Icons.add_circle_outline, color: Colors.white, size: 28),
                                // `canManageTypes` giờ đã là giá trị real-time
                                onPressed: canManageTypes ? addController : null,
                                tooltip: "Thêm mục chi phí",
                                splashRadius: 22,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: _isLoading
                              ? Center(child: CircularProgressIndicator(color: AppColors.chartRed))
                              : hasError
                              ? Center(child: Text("Không thể tải danh sách.", style: GoogleFonts.poppins(color: AppColors.getTextColor(context))))
                              : nameControllers.isEmpty && !_isLoading
                              ? Center(child: Text("Nhấn (+) để thêm mục chi phí biến đổi.", textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 16, color: AppColors.getTextColor(context))))
                              : SlideTransition(
                            position: _slideAnimation,
                            child: FadeTransition(
                              opacity: _fadeAnimation,
                              child: ListView.builder(
                                padding: const EdgeInsets.only(top: 8, bottom: 80),
                                itemCount: nameControllers.length,
                                itemBuilder: (context, index) {
                                  final isPercentage = costTypes[index] == 'percentage';

                                  return Card(
                                    elevation: 2,
                                    margin: const EdgeInsets.symmetric(vertical: 8.0),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      side: BorderSide(color: AppColors.getBorderColor(context), width: 0.5),
                                    ),
                                    color: AppColors.getCardColor(context),
                                    clipBehavior: Clip.antiAlias,
                                    child: Padding(
                                      padding: const EdgeInsets.all(12.0),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Dòng 1: Tên khoản chi và nút Xóa
                                          Row(
                                            crossAxisAlignment: CrossAxisAlignment.center,
                                            children: [
                                              Expanded(
                                                child: TextField(
                                                  controller: nameControllers[index],
                                                  focusNode: nameFocusNodes[index],
                                                  style: GoogleFonts.poppins(color: AppColors.getTextColor(context), fontWeight: FontWeight.w500),
                                                  maxLength: 50,
                                                  maxLines: 1,
                                                  decoration: InputDecoration(
                                                    labelText: "Tên khoản chi",
                                                    labelStyle: GoogleFonts.poppins(color: AppColors.chartRed),
                                                    border: InputBorder.none,
                                                    filled: true,
                                                    fillColor: AppColors.getBackgroundColor(context),
                                                    prefixIcon: const Icon(Icons.edit_note_outlined, size: 22),
                                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                                    counterText: "", // <<< ĐÃ DI CHUYỂN VÀO ĐÚNG VỊ TRÍ
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              IconButton(
                                                icon: Icon(Icons.remove_circle_outline, color: AppColors.chartRed.withOpacity(0.8), size: 28),
                                                onPressed: canManageTypes ? () => removeController(index) : null,
                                                tooltip: "Xóa mục này",
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 16),

                                          // Dòng 2: Phần nhập liệu chi phí và gắn sản phẩm
                                          Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              // Cột bên trái: Chọn loại và nhập giá trị
                                              Expanded(
                                                flex: 5,
                                                child: Column(
                                                  children: [
                                                    SegmentedButton<String>(
                                                      segments: const [
                                                        ButtonSegment(value: 'fixed', label: Text('VNĐ')),
                                                        ButtonSegment(value: 'percentage', label: Text('%')),
                                                      ],
                                                      selected: {costTypes[index]},
                                                      onSelectionChanged: (newSelection) {
                                                        setState(() {
                                                          costTypes[index] = newSelection.first;
                                                        });
                                                      },
                                                      style: SegmentedButton.styleFrom(
                                                        backgroundColor: AppColors.getBackgroundColor(context),
                                                        selectedBackgroundColor: AppColors.chartRed,
                                                        selectedForegroundColor: Colors.white,
                                                        foregroundColor: AppColors.getTextSecondaryColor(context),
                                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                        visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
                                                      ),
                                                      showSelectedIcon: false,
                                                    ),
                                                    const SizedBox(height: 8),
                                                    TextField(
                                                      controller: priceControllers[index],
                                                      focusNode: priceFocusNodes[index],
                                                      textAlign: TextAlign.center,
                                                      keyboardType: const TextInputType.numberWithOptions(decimal: false),
                                                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                                      style: GoogleFonts.poppins(color: AppColors.getTextColor(context), fontWeight: FontWeight.bold, fontSize: 18),
                                                      maxLength: isPercentage ? 3 : 15,
                                                      decoration: InputDecoration(
                                                        hintText: "Giá trị",
                                                        filled: true,
                                                        fillColor: AppColors.getBackgroundColor(context),
                                                        suffixIcon: Padding(
                                                          padding: const EdgeInsets.only(right: 12.0),
                                                          child: Text(
                                                            isPercentage ? "%" : "VNĐ",
                                                            style: GoogleFonts.poppins(
                                                                fontSize: 14,
                                                                fontWeight: FontWeight.w600,
                                                                color: AppColors.getTextSecondaryColor(context)),
                                                          ),
                                                        ),
                                                        suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                                                        border: OutlineInputBorder(
                                                          borderRadius: BorderRadius.circular(12),
                                                          borderSide: BorderSide(color: AppColors.getBorderColor(context)),
                                                        ),
                                                        enabledBorder: OutlineInputBorder(
                                                          borderRadius: BorderRadius.circular(12),
                                                          borderSide: BorderSide(color: AppColors.getBorderColor(context)),
                                                        ),
                                                        focusedBorder: OutlineInputBorder(
                                                            borderRadius: BorderRadius.circular(12),
                                                            borderSide: BorderSide(color: AppColors.chartRed, width: 1.5)),
                                                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                                        counterText: "", // <<< ĐÃ DI CHUYỂN VÀO ĐÚNG VỊ TRÍ
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              // Cột bên phải: Gắn sản phẩm
                                              Expanded(
                                                flex: 4,
                                                child: isLoadingProducts
                                                    ? const Center(child: Padding(padding: EdgeInsets.only(top: 40.0), child: CircularProgressIndicator(strokeWidth: 2)))
                                                    : DropdownButtonFormField<String>(
                                                  isExpanded: true,
                                                  decoration: InputDecoration(
                                                    labelText: "Gắn SP",
                                                    labelStyle: GoogleFonts.poppins(color: AppColors.chartRed),
                                                    filled: true,
                                                    fillColor: AppColors.getBackgroundColor(context),
                                                    border: OutlineInputBorder(
                                                        borderRadius: BorderRadius.circular(12),
                                                        borderSide: BorderSide(color: AppColors.getBorderColor(context))),
                                                    enabledBorder: OutlineInputBorder(
                                                        borderRadius: BorderRadius.circular(12),
                                                        borderSide: BorderSide(color: AppColors.getBorderColor(context))),
                                                    focusedBorder: OutlineInputBorder(
                                                        borderRadius: BorderRadius.circular(12),
                                                        borderSide: BorderSide(color: AppColors.chartRed, width: 1.5)),
                                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
                                                  ),
                                                  value: selectedProductIdForExpense[index],
                                                  style: GoogleFonts.poppins(color: AppColors.getTextColor(context), fontSize: 14),
                                                  items: [
                                                    DropdownMenuItem<String>(
                                                      value: null,
                                                      child: Text("Không gắn", style: GoogleFonts.poppins(fontStyle: FontStyle.italic, color: AppColors.getTextSecondaryColor(context))),
                                                    ),
                                                    ...availableProductsForDropdown.map((product) {
                                                      return DropdownMenuItem<String>(
                                                        value: product['id'] as String,
                                                        child: Text(product['name'] as String, overflow: TextOverflow.ellipsis),
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
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (!_isLoading)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),
                          child: ScaleTransition(
                            scale: _buttonScaleAnimation,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.chartRed,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                minimumSize: Size(screenWidth, 52),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                elevation: 2,
                              ),
                              // `canManageTypes` đã được cập nhật real-time
                              onPressed: canManageTypes ? () => saveUpdatedList(appState) : null,
                              icon: const Icon(Icons.save_alt_outlined, size: 20),
                              label: Text(
                                "Lưu danh sách",
                                style: GoogleFonts.poppins(fontSize: 16.5, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}