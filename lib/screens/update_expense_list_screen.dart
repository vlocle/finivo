import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../state/app_state.dart'; //
import '/screens/expense_manager.dart'; //
import '/screens/revenue_manager.dart'; //
import 'package:google_fonts/google_fonts.dart'; //
import 'package:fingrowth/screens/report_screen.dart';

class UpdateExpenseListScreen extends StatefulWidget {
  final String category; //

  const UpdateExpenseListScreen({Key? key, required this.category}) //
      : super(key: key);

  @override
  _UpdateExpenseListScreenState createState() =>
      _UpdateExpenseListScreenState(); //
}

class _UpdateExpenseListScreenState extends State<UpdateExpenseListScreen>
    with SingleTickerProviderStateMixin {
  // --- [START] CẤU TRÚC STATE MỚI ĐỂ PHÂN NHÓM ---
  // Cấu trúc chính để lưu trữ các mục chi phí đã được nhóm
  Map<String?, List<Map<String, dynamic>>> _groupedExpenseItems = {};

  // Map để tra cứu tên sản phẩm từ ID một cách nhanh chóng
  Map<String, String> _productIdToNameMap = {};

  // Danh sách các key của nhóm để đảm bảo thứ tự hiển thị nhất quán
  List<String?> _groupOrder = [];
  // --- [END] CẤU TRÚC STATE MỚI ---

  List<Map<String, dynamic>> availableProductsForDropdown = []; //
  bool isLoadingProducts = true; //

  late AnimationController _animationController; //
  late Animation<Offset> _slideAnimation; //
  late Animation<double> _fadeAnimation; //
  late Animation<double> _buttonScaleAnimation; //
  bool _isLoading = true; //
  bool hasError = false; //
  final NumberFormat _inputPriceFormatter = NumberFormat("#,##0", "vi_VN"); //

  @override
  void initState() {
    super.initState();
    // Giữ nguyên logic initState cũ
    if (widget.category != "Chi phí biến đổi") { //
      WidgetsBinding.instance.addPostFrameCallback((_) { //
        if (mounted) {
          Navigator.pop(context); //
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    "Danh sách chi phí cố định được quản lý trong 'Thêm cố định tháng'", //
                    style: GoogleFonts.poppins())), //
          );
        }
      });
      _isLoading = false; //
      return;
    }
    _animationController = AnimationController( //
        duration: const Duration(milliseconds: 700), vsync: this);
    _slideAnimation = Tween<Offset>( //
        begin: const Offset(0, 0.5), end: Offset.zero)
        .animate(CurvedAnimation( //
        parent: _animationController, curve: Curves.easeOut));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate( //
        CurvedAnimation(parent: _animationController, curve: Curves.easeIn));
    _buttonScaleAnimation = TweenSequence([ //
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.95), weight: 50), //
      TweenSequenceItem(tween: Tween<double>(begin: 0.95, end: 1.0), weight: 50), //
    ]).animate(CurvedAnimation( //
        parent: _animationController, curve: Curves.easeInOut));

    if (widget.category == "Chi phí biến đổi") { //
      _loadInitialData();
      final appState = Provider.of<AppState>(context, listen: false); //
      appState.productsUpdated.addListener(_onExpenseListUpdated); //
    }
  }

  void _onExpenseListUpdated() {
    print("Nhận tín hiệu cập nhật danh sách chi phí, đang tải lại..."); //
    if (mounted) {
      _loadInitialData(); //
    }
  }

  Future<void> _loadInitialData() async {
    await _loadProductsForDropdown(); //
    await _loadInitialExpenseItems(); //
  }

  // --- [START] HÀM ĐƯỢC CẬP NHẬT ---
  Future<void> _loadProductsForDropdown() async {
    if (!mounted) return; //
    setState(() {
      isLoadingProducts = true; //
    });
    final appState = Provider.of<AppState>(context, listen: false); //
    try {
      List<Map<String, dynamic>> mainProducts = await RevenueManager.loadProducts(appState, "Doanh thu chính"); //
      List<Map<String, dynamic>> extraProducts = await RevenueManager.loadProducts(appState, "Doanh thu phụ"); //

      final Set<String> productIds = {}; //
      final List<Map<String, dynamic>> combinedProducts = []; //
      final Map<String, String> productIdNameMap = {};

      for (var product in [...mainProducts, ...extraProducts]) { //
        final productId = product['id'] as String?; //
        final productName = product['name'] as String?;
        if (productId != null && productName != null && productIds.add(productId)) { //
          combinedProducts.add(product); //
          productIdNameMap[productId] = productName;
        }
      }

      if (mounted) {
        setState(() {
          availableProductsForDropdown = combinedProducts; //
          _productIdToNameMap = productIdNameMap;
          isLoadingProducts = false; //
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoadingProducts = false; //
        });
        _showStyledSnackBar("Lỗi tải danh sách sản phẩm: $e", isError: true); //
      }
    }
  }

  Future<void> _loadInitialExpenseItems() async {
    if (!mounted) return; //
    setState(() {
      _isLoading = true; //
      hasError = false; //
    });

    try {
      final appState = Provider.of<AppState>(context, listen: false); //
      final data = await ExpenseManager.loadAvailableVariableExpenses(appState); //

      if (mounted) {
        // Dọn dẹp controller cũ trước khi tạo mới
        _groupedExpenseItems.forEach((_, items) {
          for (var item in items) {
            item['nameController']?.dispose();
            item['priceController']?.dispose();
            item['nameFocusNode']?.dispose();
            item['priceFocusNode']?.dispose();
          }
        });

        final validProductIds = availableProductsForDropdown.map((p) => p['id'] as String?).toSet(); //
        Map<String?, List<Map<String, dynamic>>> tempGroupedItems = {};

        for (var expense in data) { //
          final linkedId = validProductIds.contains(expense['linkedProductId']) ? expense['linkedProductId'] as String? : null; //

          final double value = expense['costValue'] ?? 0.0; //
          final String textValue = (value == value.truncate()) ? value.toInt().toString() : value.toString(); //

          final expenseItem = {
            'nameController': TextEditingController(text: expense['name']?.toString() ?? ''),
            'priceController': TextEditingController(text: textValue),
            'costType': expense['costType']?.toString() ?? 'fixed',
            'linkedProductId': linkedId,
            'nameFocusNode': FocusNode(),
            'priceFocusNode': FocusNode(),
          };

          if (tempGroupedItems[linkedId] == null) {
            tempGroupedItems[linkedId] = [];
          }
          tempGroupedItems[linkedId]!.add(expenseItem);
        }

        // Sắp xếp thứ tự các nhóm: Nhóm không gắn sản phẩm lên đầu
        final List<String?> sortedGroupOrder = tempGroupedItems.keys.toList();
        sortedGroupOrder.sort((a, b) {
          if (a == null) return -1;
          if (b == null) return 1;
          return _productIdToNameMap[a]!.compareTo(_productIdToNameMap[b]!);
        });

        setState(() {
          _groupedExpenseItems = tempGroupedItems;
          _groupOrder = sortedGroupOrder;

          if (_groupedExpenseItems.isEmpty) {
            _addControllerInternal();
          }
          _isLoading = false; //
          _animationController.forward(); //
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false; //
          hasError = true; //
        });
        _showStyledSnackBar("Lỗi tải danh sách chi phí: $e", isError: true); //
        print("Error in _loadInitialExpenseItems: $e"); //
      }
    }
  }

  @override
  void dispose() {
    Provider.of<AppState>(context, listen: false)
        .productsUpdated.removeListener(_onExpenseListUpdated); //

    // Dọn dẹp tất cả controller và focus node
    _groupedExpenseItems.forEach((_, items) {
      for (var item in items) {
        item['nameController']?.dispose();
        item['priceController']?.dispose();
        item['nameFocusNode']?.dispose();
        item['priceFocusNode']?.dispose();
      }
    });

    _animationController.dispose(); //
    super.dispose();
  }

  void _addControllerInternal() {
    final newItem = {
      'nameController': TextEditingController(), //
      'priceController': TextEditingController(text: "0"), //
      'costType': 'fixed', //
      'linkedProductId': null, //
      'nameFocusNode': FocusNode(), //
      'priceFocusNode': FocusNode(), //
    };

    if (_groupedExpenseItems[null] == null) {
      _groupedExpenseItems[null] = [];
    }
    _groupedExpenseItems[null]!.add(newItem);

    // Đảm bảo nhóm 'null' có trong danh sách thứ tự
    if (!_groupOrder.contains(null)) {
      _groupOrder.insert(0, null);
    }
  }

  void addController() {
    if (!mounted) return; //
    setState(() {
      _animationController.reset(); //
      _animationController.forward(); //
      _addControllerInternal();

      // Focus vào mục vừa thêm
      WidgetsBinding.instance.addPostFrameCallback((_) { //
        if (_groupedExpenseItems[null]!.isNotEmpty && mounted) { //
          FocusScope.of(context).requestFocus(_groupedExpenseItems[null]!.last['nameFocusNode']); //
        }
      });
    });
  }

  void removeController(String? groupId, int index) {
    if (!mounted) return; //

    setState(() {
      final itemToRemove = _groupedExpenseItems[groupId]!.removeAt(index);
      // Dọn dẹp tài nguyên
      itemToRemove['nameController']?.dispose(); //
      itemToRemove['priceController']?.dispose(); //
      itemToRemove['nameFocusNode']?.dispose(); //
      itemToRemove['priceFocusNode']?.dispose(); //

      // Nếu nhóm trở nên rỗng, xóa nhóm đó đi
      if (_groupedExpenseItems[groupId]!.isEmpty) {
        _groupedExpenseItems.remove(groupId);
        _groupOrder.remove(groupId);
      }

      // Nếu không còn mục nào, thêm lại một mục trống
      if (_groupedExpenseItems.values.every((list) => list.isEmpty)) { //
        _addControllerInternal(); //
      }
    });
  }

  // --- [START] HÀM MỚI ---
  void _regroupItems() {
    // Thu thập tất cả các mục từ các nhóm khác nhau
    final allItems = _groupedExpenseItems.values.expand((list) => list).toList();
    Map<String?, List<Map<String, dynamic>>> tempGroupedItems = {};

    // Phân loại lại các mục vào nhóm mới dựa trên 'linkedProductId' đã cập nhật
    for (var item in allItems) {
      final linkedId = item['linkedProductId'];
      if (tempGroupedItems[linkedId] == null) {
        tempGroupedItems[linkedId] = [];
      }
      tempGroupedItems[linkedId]!.add(item);
    }

    // Sắp xếp lại thứ tự của các nhóm
    final List<String?> sortedGroupOrder = tempGroupedItems.keys.toList();
    sortedGroupOrder.sort((a, b) {
      if (a == null) return -1;
      if (b == null) return 1;
      // Sắp xếp theo tên sản phẩm để đảm bảo tính nhất quán
      return (_productIdToNameMap[a] ?? '').compareTo(_productIdToNameMap[b] ?? '');
    });

    setState(() {
      _groupedExpenseItems = tempGroupedItems;
      _groupOrder = sortedGroupOrder;
    });
  }
  // --- [END] HÀM MỚI ---

  void _showStyledSnackBar(String message, {bool isError = false}) {
    if (!mounted) return; //
    ScaffoldMessenger.of(context).showSnackBar( //
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins(color: Colors.white)), //
        backgroundColor: isError ? AppColors.chartRed : AppColors.chartRed, //
        behavior: SnackBarBehavior.floating, //
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), //
        margin: const EdgeInsets.all(10), //
      ),
    );
  }

  void saveUpdatedList(AppState appState) async {
    if (!mounted) return; //
    FocusScope.of(context).unfocus(); //

    List<Map<String, dynamic>> updatedList = []; //
    final Set<String> names = {}; //

    // Duyệt qua tất cả các mục trong cấu trúc nhóm
    for (var group in _groupedExpenseItems.values) {
      for (var item in group) {
        String name = item['nameController'].text.trim(); //
        String priceText = item['priceController'].text.trim(); //
        String? linkedProductId = item['linkedProductId']; //

        if (name.isNotEmpty) { //
          double price = double.tryParse(priceText) ?? 0.0; //
          if (price < 0) { //
            _showStyledSnackBar("Giá trị của '$name' không hợp lệ.", isError: true); //
            return;
          }
          if (!names.add(name.toLowerCase())) { //
            _showStyledSnackBar("Tên khoản chi '$name' bị trùng lặp.", isError: true); //
            return;
          }
          updatedList.add({ //
            'name': name,
            'costType': item['costType'],
            'costValue': price,
            'linkedProductId': linkedProductId
          });
        } else if (priceText.isNotEmpty && priceText != "0") { //
          _showStyledSnackBar("Vui lòng nhập tên cho khoản chi có giá trị.", isError: true); //
          return;
        } else if (linkedProductId != null && name.isEmpty) { //
          _showStyledSnackBar("Vui lòng nhập tên cho khoản chi được gắn với sản phẩm.", isError: true); //
          return;
        }
      }
    }

    if (updatedList.isEmpty && _groupedExpenseItems.values.expand((i) => i).every((item) => item['nameController'].text.trim().isEmpty)) { //
      _showStyledSnackBar("Danh sách trống, không có gì để lưu.", isError: false); //
      return;
    }

    // Giữ nguyên phần còn lại của hàm
    showDialog(
        context: context, //
        barrierDismissible: false, //
        builder: (dialogContext) => AlertDialog( //
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15)), //
          content: Row(
            children: [ //
              CircularProgressIndicator(color: AppColors.chartRed), //
              const SizedBox(width: 20), //
              Text("Đang lưu...", //
                  style: GoogleFonts.poppins(color: AppColors.getTextColor(context))), //
            ],
          ),
        ));

    try {
      if (appState.activeUserId == null) throw Exception('User ID không tồn tại'); //
      final FirebaseFirestore firestore = FirebaseFirestore.instance; //
      String monthKey = DateFormat('yyyy-MM').format(appState.selectedDate); //
      String firestoreDocKey = appState.getKey('variableExpenseList_$monthKey'); //
      await firestore
          .collection('users')
          .doc(appState.activeUserId) //
          .collection('expenses') //
          .doc('variableList') //
          .collection('monthly') //
          .doc(firestoreDocKey) //
          .set({ //
        'products': updatedList, //
        'updatedAt': FieldValue.serverTimestamp(), //
      });
      final String hiveBoxKey =
          '${appState.activeUserId}-variableExpenseList-$monthKey'; //
      final variableExpenseListBox = Hive.box('variableExpenseListBox'); //
      await variableExpenseListBox.put(hiveBoxKey, updatedList); //
      appState.notifyProductsUpdated(); //
      Navigator.pop(context); //
      _showStyledSnackBar("Đã lưu danh sách chi phí biến đổi cho tháng"); //
      Navigator.pop(context, true); //
    } catch (e) {
      Navigator.pop(context); //
      print("Error saving variable expense list: $e"); //
      _showStyledSnackBar("Lỗi khi lưu dữ liệu: $e", isError: true); //
    }
  }

  // --- [END] HÀM ĐƯỢC CẬP NHẬT ---
  @override
  Widget build(BuildContext context) {
    final appState = context.read<AppState>(); //
    final screenWidth = MediaQuery.of(context).size.width; //
    final bool canManageTypes = appState.hasPermission('canManageExpenseTypes'); //

    if (widget.category != "Chi phí biến đổi") { //
      return Scaffold(
        body: Center(
            child: Text("Loại chi phí không hợp lệ cho màn hình này.", //
                style: GoogleFonts.poppins())), //
      );
    }

    return GestureDetector( //
      onTap: () => FocusScope.of(context).unfocus(), //
      behavior: HitTestBehavior.opaque, //
      child: Scaffold(
        backgroundColor: AppColors.getBackgroundColor(context), //
        body: ValueListenableBuilder<int>(
          valueListenable: appState.permissionVersion, //
          builder: (context, permissionVersion, child) {
            final bool canManageTypes = appState.hasPermission('canManageExpenseTypes');
            return Stack(
              children: [
                Container(
                  height: MediaQuery.of(context).size.height * 0.14, //
                  color: AppColors.chartRed.withOpacity(0.95), //
                ),
                SafeArea(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0), //
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween, //
                          children: [
                            Flexible(
                              child: Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white), //
                                    onPressed: () => Navigator.pop(context), //
                                    splashRadius: 20,
                                  ),
                                  const SizedBox(width: 8), //
                                  Flexible(
                                    child: Column( //
                                      crossAxisAlignment: CrossAxisAlignment.start, //
                                      children: [
                                        Text("DS Chi phí biến đổi", style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white), overflow: TextOverflow.ellipsis), //
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), //
                                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.25), borderRadius: BorderRadius.circular(8)), //
                                          child: Text("Tháng ${DateFormat('MMMM y', 'vi').format(appState.selectedDate)}", style: GoogleFonts.poppins(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis), //
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ScaleTransition(
                              scale: _buttonScaleAnimation, //
                              child: IconButton(
                                icon: const Icon(Icons.add_circle_outline, color: Colors.white, size: 28), //
                                onPressed: canManageTypes ? addController : null, //
                                tooltip: "Thêm mục chi phí", //
                                splashRadius: 22,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10), //
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0), //
                          child: _isLoading
                              ? Center(child: CircularProgressIndicator(color: AppColors.chartRed)) //
                              : hasError
                              ? Center(child: Text("Không thể tải danh sách.", style: GoogleFonts.poppins(color: AppColors.getTextColor(context)))) //
                              : _groupedExpenseItems.values.every((list) => list.isEmpty) && !_isLoading
                              ? Center(child: Text("Nhấn (+) để thêm mục chi phí biến đổi.", textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 16, color: AppColors.getTextColor(context)))) //
                              : SlideTransition(
                            position: _slideAnimation, //
                            child: FadeTransition(
                              opacity: _fadeAnimation, //
                              // --- [START] GIAO DIỆN PHÂN NHÓM MỚI ---
                              child: ListView.builder(
                                padding: const EdgeInsets.only(top: 8, bottom: 80), //
                                itemCount: _groupOrder.length, // Dựng danh sách dựa trên số lượng nhóm
                                itemBuilder: (context, groupIndex) {
                                  final String? groupId = _groupOrder[groupIndex];
                                  final List<Map<String, dynamic>> itemsInGroup = _groupedExpenseItems[groupId]!;

                                  final String groupTitle = groupId == null
                                      ? "Chi phí khác (không gắn sản phẩm)"
                                      : "Chi phí cho: ${_productIdToNameMap[groupId] ?? 'Sản phẩm không xác định'}";

                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Tiêu đề của nhóm
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(8, 16, 8, 4),
                                        child: Text(
                                          groupTitle,
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 16,
                                            color: AppColors.chartRed,
                                          ),
                                        ),
                                      ),
                                      // Danh sách các thẻ chi phí trong nhóm
                                      ...itemsInGroup.asMap().entries.map((entry) {
                                        int itemIndex = entry.key;
                                        Map<String, dynamic> item = entry.value;
                                        final isPercentage = item['costType'] == 'percentage'; //

                                        return Card(
                                          elevation: 2, //
                                          margin: const EdgeInsets.symmetric(vertical: 8.0), //
                                          shape: RoundedRectangleBorder( //
                                            borderRadius: BorderRadius.circular(16),
                                            side: BorderSide(color: AppColors.getBorderColor(context), width: 0.5), //
                                          ),
                                          color: AppColors.getCardColor(context), //
                                          clipBehavior: Clip.antiAlias, //
                                          child: Padding(
                                            padding: const EdgeInsets.all(12.0), //
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min, //
                                              crossAxisAlignment: CrossAxisAlignment.start, //
                                              children: [
                                                // Dòng 1: Tên khoản chi và nút Xóa
                                                Row(
                                                  crossAxisAlignment: CrossAxisAlignment.center, //
                                                  children: [
                                                    Expanded(
                                                      child: TextField(
                                                        controller: item['nameController'],
                                                        focusNode: item['nameFocusNode'],
                                                        style: GoogleFonts.poppins(color: AppColors.getTextColor(context), fontWeight: FontWeight.w500), //
                                                        maxLength: 50, //
                                                        maxLines: 1, //
                                                        decoration: InputDecoration(
                                                          labelText: "Tên khoản chi", //
                                                          labelStyle: GoogleFonts.poppins(color: AppColors.chartRed), //
                                                          border: InputBorder.none, //
                                                          filled: true, //
                                                          fillColor: AppColors.getBackgroundColor(context), //
                                                          prefixIcon: const Icon(Icons.edit_note_outlined, size: 22), //
                                                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), //
                                                          counterText: "", //
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8), //
                                                    IconButton(
                                                      icon: Icon(Icons.remove_circle_outline, color: AppColors.chartRed.withOpacity(0.8), size: 28), //
                                                      onPressed: canManageTypes ? () => removeController(groupId, itemIndex) : null, //
                                                      tooltip: "Xóa mục này", //
                                                      padding: EdgeInsets.zero, //
                                                      constraints: const BoxConstraints(), //
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 16), //
                                                // Dòng 2: Phần nhập liệu chi phí và gắn sản phẩm
                                                Row(
                                                  crossAxisAlignment: CrossAxisAlignment.start, //
                                                  children: [
                                                    // Cột bên trái: Chọn loại và nhập giá trị
                                                    Expanded(
                                                      flex: 5, //
                                                      child: Column(
                                                        children: [
                                                          SegmentedButton<String>(
                                                            segments: const [ //
                                                              ButtonSegment(value: 'fixed', label: Text('VNĐ')), //
                                                              ButtonSegment(value: 'percentage', label: Text('%')), //
                                                            ],
                                                            selected: {item['costType']}, //
                                                            onSelectionChanged: (newSelection) { //
                                                              setState(() {
                                                                item['costType'] = newSelection.first; //
                                                              });
                                                            },
                                                            style: SegmentedButton.styleFrom(
                                                              backgroundColor: AppColors.getBackgroundColor(context), //
                                                              selectedBackgroundColor: AppColors.chartRed, //
                                                              selectedForegroundColor: Colors.white, //
                                                              foregroundColor: AppColors.getTextSecondaryColor(context), //
                                                              tapTargetSize: MaterialTapTargetSize.shrinkWrap, //
                                                              visualDensity: const VisualDensity(horizontal: -2, vertical: -2), //
                                                            ),
                                                            showSelectedIcon: false, //
                                                          ),
                                                          const SizedBox(height: 8), //
                                                          TextField(
                                                            controller: item['priceController'],
                                                            focusNode: item['priceFocusNode'],
                                                            textAlign: TextAlign.center, //
                                                            keyboardType: const TextInputType.numberWithOptions(decimal: false), //
                                                            inputFormatters: [FilteringTextInputFormatter.digitsOnly], //
                                                            style: GoogleFonts.poppins(color: AppColors.getTextColor(context), fontWeight: FontWeight.bold, fontSize: 18), //
                                                            maxLength: isPercentage ? 3 : 15, //
                                                            decoration: InputDecoration(
                                                              hintText: "Giá trị", //
                                                              filled: true, //
                                                              fillColor: AppColors.getBackgroundColor(context), //
                                                              suffixIcon: Padding(
                                                                padding: const EdgeInsets.only(right: 12.0), //
                                                                child: Text( //
                                                                  isPercentage ? "%" : "VNĐ", //
                                                                  style: GoogleFonts.poppins( //
                                                                      fontSize: 14, //
                                                                      fontWeight: FontWeight.w600, //
                                                                      color: AppColors.getTextSecondaryColor(context)), //
                                                                ),
                                                              ),
                                                              suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0), //
                                                              border: OutlineInputBorder( //
                                                                borderRadius: BorderRadius.circular(12), //
                                                                borderSide: BorderSide(color: AppColors.getBorderColor(context)), //
                                                              ),
                                                              enabledBorder: OutlineInputBorder( //
                                                                borderRadius: BorderRadius.circular(12), //
                                                                borderSide: BorderSide(color: AppColors.getBorderColor(context)), //
                                                              ),
                                                              focusedBorder: OutlineInputBorder( //
                                                                  borderRadius: BorderRadius.circular(12), //
                                                                  borderSide: BorderSide(color: AppColors.chartRed, width: 1.5)), //
                                                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), //
                                                              counterText: "", //
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    const SizedBox(width: 12), //
                                                    // Cột bên phải: Gắn sản phẩm
                                                    Expanded(
                                                      flex: 4, //
                                                      child: isLoadingProducts
                                                          ? const Center(child: Padding(padding: EdgeInsets.only(top: 40.0), child: CircularProgressIndicator(strokeWidth: 2))) //
                                                          : DropdownButtonFormField<String>(
                                                        isExpanded: true, //
                                                        decoration: InputDecoration(
                                                          labelText: "Gắn SP", //
                                                          labelStyle: GoogleFonts.poppins(color: AppColors.chartRed), //
                                                          filled: true, //
                                                          fillColor: AppColors.getBackgroundColor(context), //
                                                          border: OutlineInputBorder( //
                                                              borderRadius: BorderRadius.circular(12), //
                                                              borderSide: BorderSide(color: AppColors.getBorderColor(context))), //
                                                          enabledBorder: OutlineInputBorder( //
                                                              borderRadius: BorderRadius.circular(12), //
                                                              borderSide: BorderSide(color: AppColors.getBorderColor(context))), //
                                                          focusedBorder: OutlineInputBorder( //
                                                              borderRadius: BorderRadius.circular(12), //
                                                              borderSide: BorderSide(color: AppColors.chartRed, width: 1.5)), //
                                                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15), //
                                                        ),
                                                        value: item['linkedProductId'],
                                                        style: GoogleFonts.poppins(color: AppColors.getTextColor(context), fontSize: 14), //
                                                        items: [
                                                          DropdownMenuItem<String>( //
                                                            value: null, //
                                                            child: Text("Không gắn", style: GoogleFonts.poppins(fontStyle: FontStyle.italic, color: AppColors.getTextSecondaryColor(context))), //
                                                          ),
                                                          ...availableProductsForDropdown.map((product) { //
                                                            return DropdownMenuItem<String>(
                                                              value: product['id'] as String, //
                                                              child: Text(product['name'] as String, overflow: TextOverflow.ellipsis), //
                                                            );
                                                          }).toList(), //
                                                        ],
                                                        onChanged: (String? newValue) { //
                                                          setState(() {
                                                            item['linkedProductId'] = newValue; //
                                                          });
                                                          // Gọi hàm phân nhóm lại sau khi người dùng thay đổi
                                                          _regroupItems();
                                                        },
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ],
                                  );
                                },
                              ),
                              // --- [END] GIAO DIỆN PHÂN NHÓM MỚI ---
                            ),
                          ),
                        ),
                      ),
                      if (!_isLoading)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0), //
                          child: ScaleTransition(
                            scale: _buttonScaleAnimation, //
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom( //
                                backgroundColor: AppColors.chartRed, //
                                foregroundColor: Colors.white, //
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), //
                                minimumSize: Size(screenWidth, 52), //
                                padding: const EdgeInsets.symmetric(vertical: 14), //
                                elevation: 2, //
                              ),
                              onPressed: canManageTypes ? () => saveUpdatedList(appState) : null, //
                              icon: const Icon(Icons.save_alt_outlined, size: 20), //
                              label: Text( //
                                "Lưu danh sách", //
                                style: GoogleFonts.poppins(fontSize: 16.5, fontWeight: FontWeight.w600), //
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