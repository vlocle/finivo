import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fingrowth/screens/report_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '/screens/expense_manager.dart';
import '/screens/revenue_manager.dart';


class EditVariableExpenseScreen extends StatefulWidget {
  const EditVariableExpenseScreen({Key? key}) : super(key: key);

  @override
  _EditVariableExpenseScreenState createState() =>
      _EditVariableExpenseScreenState();
}

class _EditVariableExpenseScreenState extends State<EditVariableExpenseScreen>
    with TickerProviderStateMixin {
  // --- Các biến state cho Tab 1: Chi phí trong ngày ---
  final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'VNĐ');
  final NumberFormat _inputPriceFormatter = NumberFormat("#,##0", "vi_VN");
  late AppState appState;
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  List<Map<String, dynamic>> variableExpenses = [];
  bool isLoadingDaily = true;
  bool hasErrorDaily = false;

  // --- Các biến state cho Tab 2: Quản lý danh mục ---
  late TabController _tabController;
  Map<String?, List<Map<String, dynamic>>> _groupedExpenseItems = {};
  Map<String, String> _productIdToNameMap = {};
  List<String?> _groupOrder = [];
  List<Map<String, dynamic>> availableProductsForDropdown = [];
  bool isLoadingProducts = true;
  bool isLoadingDefinitions = true;
  bool hasErrorDefinitions = false;


  @override
  void initState() {
    super.initState();
    appState = Provider.of<AppState>(context, listen: false);

    _tabController = TabController(length: 2, vsync: this);

    _animationController = AnimationController(
        duration: const Duration(milliseconds: 700), vsync: this);
    _slideAnimation = Tween<Offset>(
        begin: const Offset(0, 0.5), end: Offset.zero)
        .animate(CurvedAnimation(
        parent: _animationController, curve: Curves.easeOut));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _animationController, curve: Curves.easeIn));

    _loadDailyExpenses();
    _loadInitialDefinitionsData();

    appState.productsUpdated.addListener(_onExpensesUpdated);
  }

  void _onExpensesUpdated() {
    print("Nhận tín hiệu cập nhật, đang tải lại dữ liệu cho cả 2 tab...");
    if (mounted) {
      _loadDailyExpenses();
      _loadInitialDefinitionsData();
    }
  }

  Future<void> _loadDailyExpenses() async {
    if (!mounted) return;
    setState(() {
      isLoadingDaily = true;
      hasErrorDaily = false;
    });
    try {
      final dailyExpenses = await ExpenseManager.loadVariableExpenses(appState);
      if (mounted) {
        setState(() {
          variableExpenses = dailyExpenses;
          appState.variableExpenseList.value = List.from(dailyExpenses);
          isLoadingDaily = false;
          _animationController.forward(from: 0.0);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          hasErrorDaily = true;
          isLoadingDaily = false;
        });
        _showStyledSnackBar("Lỗi tải chi phí trong ngày. Vui lòng thử lại.", isError: true);
      }
      print("Error loading daily expenses in EditVariableExpenseScreen: $e");
    }
  }

  // --- Logic cho Tab 2: Quản lý danh mục ---

  Future<void> _loadInitialDefinitionsData() async {
    await _loadProductsForDropdown();
    await _loadInitialExpenseItemDefinitions();
  }

  Future<void> _loadProductsForDropdown() async {
    if (!mounted) return;
    setState(() {
      isLoadingProducts = true;
    });
    try {
      List<Map<String, dynamic>> mainProducts = await RevenueManager.loadProducts(appState, "Doanh thu chính"); // [cite: 95]
      List<Map<String, dynamic>> extraProducts = await RevenueManager.loadProducts(appState, "Doanh thu phụ"); // [cite: 96]
      final Set<String> productIds = {}; // [cite: 97]
      final List<Map<String, dynamic>> combinedProducts = []; // [cite: 98]
      final Map<String, String> productIdNameMap = {}; // [cite: 99]

      for (var product in [...mainProducts, ...extraProducts]) { // [cite: 100]
        final productId = product['id'] as String?; // [cite: 101]
        final productName = product['name'] as String?; // [cite: 102]
        if (productId != null && productName != null && productIds.add(productId)) { // [cite: 103]
          combinedProducts.add(product); // [cite: 104]
          productIdNameMap[productId] = productName; // [cite: 105]
        }
      }
      if (mounted) { // [cite: 108]
        setState(() {
          availableProductsForDropdown = combinedProducts; // [cite: 110]
          _productIdToNameMap = productIdNameMap; // [cite: 111]
          isLoadingProducts = false; // [cite: 112]
        });
      }
    } catch (e) { // [cite: 115]
      if (mounted) { // [cite: 116]
        setState(() => isLoadingProducts = false); // [cite: 118]
        _showStyledSnackBar("Lỗi tải danh sách sản phẩm: $e", isError: true); // [cite: 120]
      }
    }
  }

  Future<void> _loadInitialExpenseItemDefinitions() async {
    if (!mounted) return; // [cite: 125]
    setState(() {
      isLoadingDefinitions = true; // [cite: 127]
      hasErrorDefinitions = false; // [cite: 128]
    });
    try {
      final data = await ExpenseManager.loadAvailableVariableExpenses(appState); // [cite: 132]
      if (mounted) { // [cite: 133]
        _groupedExpenseItems.forEach((_, items) { // [cite: 135]
          for (var item in items) { // [cite: 136]
            item['nameController']?.dispose(); // [cite: 137]
            item['priceController']?.dispose(); // [cite: 138]
            item['nameFocusNode']?.dispose(); // [cite: 139]
            item['priceFocusNode']?.dispose(); // [cite: 140]
          }
        });

        final validProductIds = availableProductsForDropdown.map((p) => p['id'] as String?).toSet(); // [cite: 143]
        Map<String?, List<Map<String, dynamic>>> tempGroupedItems = {}; // [cite: 144]
        for (var expense in data) { // [cite: 145]
          final linkedId = validProductIds.contains(expense['linkedProductId']) ? expense['linkedProductId'] as String? : null; // [cite: 146]
          final double value = expense['costValue'] ?? 0.0; // [cite: 147]
          final String textValue = (value == value.truncate()) ? value.toInt().toString() : value.toString(); // [cite: 148]
          final expenseItem = { // [cite: 149]
            'nameController': TextEditingController(text: expense['name']?.toString() ?? ''), // [cite: 150]
            'priceController': TextEditingController(text: textValue), // [cite: 151]
            'costType': expense['costType']?.toString() ?? 'fixed', // [cite: 152]
            'linkedProductId': linkedId, // [cite: 153]
            'nameFocusNode': FocusNode(), // [cite: 154]
            'priceFocusNode': FocusNode(), // [cite: 155]
          };
          if (tempGroupedItems[linkedId] == null) { // [cite: 157]
            tempGroupedItems[linkedId] = []; // [cite: 158]
          }
          tempGroupedItems[linkedId]!.add(expenseItem); // [cite: 160]
        }

        final List<String?> sortedGroupOrder = tempGroupedItems.keys.toList(); // [cite: 163]
        sortedGroupOrder.sort((a, b) { // [cite: 164]
          if (a == null) return -1; // [cite: 165]
          if (b == null) return 1; // [cite: 166]
          return _productIdToNameMap[a]!.compareTo(_productIdToNameMap[b]!); // [cite: 167]
        });

        setState(() {
          _groupedExpenseItems = tempGroupedItems; // [cite: 170]
          _groupOrder = sortedGroupOrder; // [cite: 171]
          if (_groupedExpenseItems.isEmpty) { // [cite: 172]
            _addDefinitionControllerInternal(); // [cite: 173]
          }
          isLoadingDefinitions = false; // [cite: 175]
        });
      }
    } catch (e) { // [cite: 179]
      if (mounted) { // [cite: 180]
        setState(() {
          isLoadingDefinitions = false; // [cite: 182]
          hasErrorDefinitions = true; // [cite: 183]
        });
        _showStyledSnackBar("Lỗi tải danh mục chi phí: $e", isError: true); // [cite: 185]
        print("Error in _loadInitialExpenseItemDefinitions: $e"); // [cite: 186]
      }
    }
  }

  void _addDefinitionControllerInternal() {
    final newItem = { // [cite: 207]
      'nameController': TextEditingController(), // [cite: 208]
      'priceController': TextEditingController(text: "0"), // [cite: 209]
      'costType': 'fixed', // [cite: 210]
      'linkedProductId': null, // [cite: 211]
      'nameFocusNode': FocusNode(), // [cite: 212]
      'priceFocusNode': FocusNode(), // [cite: 213]
    };
    if (_groupedExpenseItems[null] == null) { // [cite: 215]
      _groupedExpenseItems[null] = []; // [cite: 216]
      if (!_groupOrder.contains(null)) { // [cite: 220]
        _groupOrder.insert(0, null); // [cite: 221]
      }
    }
    _groupedExpenseItems[null]!.add(newItem); // [cite: 218]
  }

  void addDefinitionController() {
    if (!mounted) return; // [cite: 225]
    setState(() {
      _addDefinitionControllerInternal(); // [cite: 229]
      WidgetsBinding.instance.addPostFrameCallback((_) { // [cite: 231]
        if (_groupedExpenseItems[null]!.isNotEmpty && mounted) { // [cite: 232]
          FocusScope.of(context).requestFocus(_groupedExpenseItems[null]!.last['nameFocusNode']); // [cite: 233]
        }
      });
    });
  }

  void removeDefinitionController(String? groupId, int index) {
    if (!mounted) return; // [cite: 239]
    setState(() {
      final itemToRemove = _groupedExpenseItems[groupId]!.removeAt(index); // [cite: 241]
      itemToRemove['nameController']?.dispose(); // [cite: 243]
      itemToRemove['priceController']?.dispose(); // [cite: 244]
      itemToRemove['nameFocusNode']?.dispose(); // [cite: 245]
      itemToRemove['priceFocusNode']?.dispose(); // [cite: 246]

      if (_groupedExpenseItems[groupId]!.isEmpty) { // [cite: 248]
        _groupedExpenseItems.remove(groupId); // [cite: 249]
        _groupOrder.remove(groupId); // [cite: 250]
      }
      if (_groupedExpenseItems.values.every((list) => list.isEmpty)) { // [cite: 253]
        _addDefinitionControllerInternal(); // [cite: 254]
      }
    });
  }

  void _regroupItems() {
    final allItems = _groupedExpenseItems.values.expand((list) => list).toList(); // [cite: 261]
    Map<String?, List<Map<String, dynamic>>> tempGroupedItems = {}; // [cite: 262]
    for (var item in allItems) { // [cite: 264]
      final linkedId = item['linkedProductId']; // [cite: 265]
      if (tempGroupedItems[linkedId] == null) { // [cite: 266]
        tempGroupedItems[linkedId] = []; // [cite: 267]
      }
      tempGroupedItems[linkedId]!.add(item); // [cite: 269]
    }

    final List<String?> sortedGroupOrder = tempGroupedItems.keys.toList(); // [cite: 272]
    sortedGroupOrder.sort((a, b) { // [cite: 273]
      if (a == null) return -1; // [cite: 274]
      if (b == null) return 1; // [cite: 275]
      return (_productIdToNameMap[a] ?? '').compareTo(_productIdToNameMap[b] ?? ''); // [cite: 277]
    });

    setState(() {
      _groupedExpenseItems = tempGroupedItems; // [cite: 280]
      _groupOrder = sortedGroupOrder; // [cite: 281]
    });
  }

  void saveUpdatedDefinitionsList(AppState appState) async {
    if (!mounted) return; // [cite: 298]
    FocusScope.of(context).unfocus(); // [cite: 299]
    List<Map<String, dynamic>> updatedList = []; // [cite: 300]
    final Set<String> names = {}; // [cite: 301]

    for (var group in _groupedExpenseItems.values) { // [cite: 303]
      for (var item in group) { // [cite: 304]
        String name = item['nameController'].text.trim(); // [cite: 305]
        String priceText = item['priceController'].text.trim(); // [cite: 306]
        String? linkedProductId = item['linkedProductId']; // [cite: 307]

        if (name.isNotEmpty) { // [cite: 308]
          double price = double.tryParse(priceText) ?? 0.0; // [cite: 309]
          if (price < 0) { // [cite: 310]
            _showStyledSnackBar("Giá trị của '$name' không hợp lệ.", isError: true); // [cite: 311]
            return; // [cite: 312]
          }
          if (!names.add(name.toLowerCase())) { // [cite: 314]
            _showStyledSnackBar("Tên khoản chi '$name' bị trùng lặp.", isError: true); // [cite: 315]
            return; // [cite: 316]
          }
          updatedList.add({ // [cite: 318]
            'name': name, // [cite: 319]
            'costType': item['costType'], // [cite: 320]
            'costValue': price, // [cite: 321]
            'linkedProductId': linkedProductId // [cite: 322]
          });
        } else if (priceText.isNotEmpty && priceText != "0") { // [cite: 324]
          _showStyledSnackBar("Vui lòng nhập tên cho khoản chi có giá trị.", isError: true); // [cite: 325]
          return; // [cite: 326]
        } else if (linkedProductId != null && name.isEmpty) { // [cite: 327]
          _showStyledSnackBar("Vui lòng nhập tên cho khoản chi được gắn với sản phẩm.", isError: true); // [cite: 328]
          return; // [cite: 329]
        }
      }
    }

    if (updatedList.isEmpty && _groupedExpenseItems.values.expand((i) => i).every((item) => item['nameController'].text.trim().isEmpty)) { // [cite: 333]
      _showStyledSnackBar("Danh sách trống, không có gì để lưu.", isError: false); // [cite: 334]
      return; // [cite: 335]
    }

    showDialog( // [cite: 338]
        context: context, // [cite: 339]
        barrierDismissible: false, // [cite: 340]
        builder: (dialogContext) => AlertDialog( // [cite: 341]
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), // [cite: 343]
          content: Row(children: [ // [cite: 344, 345]
            CircularProgressIndicator(color: AppColors.chartRed), // [cite: 346]
            const SizedBox(width: 20), // [cite: 347]
            Text("Đang lưu...", style: GoogleFonts.poppins(color: AppColors.getTextColor(context))), // [cite: 348, 349]
          ]),
        )
    );

    try {
      if (appState.activeUserId == null) throw Exception('User ID không tồn tại'); // [cite: 354]
      final FirebaseFirestore firestore = FirebaseFirestore.instance; // [cite: 355]
      String monthKey = DateFormat('yyyy-MM').format(appState.selectedDate); // [cite: 356]
      String firestoreDocKey = appState.getKey('variableExpenseList_$monthKey'); // [cite: 357]

      await firestore
          .collection('users').doc(appState.activeUserId) // [cite: 360]
          .collection('expenses').doc('variableList') // [cite: 361, 362]
          .collection('monthly').doc(firestoreDocKey) // [cite: 363, 364]
          .set({ // [cite: 365]
        'products': updatedList, // [cite: 366]
        'updatedAt': FieldValue.serverTimestamp(), // [cite: 367]
      });

      final String hiveBoxKey = '${appState.activeUserId}-variableExpenseList-$monthKey'; // [cite: 369, 370]
      final variableExpenseListBox = Hive.box('variableExpenseListBox'); // [cite: 371]
      await variableExpenseListBox.put(hiveBoxKey, updatedList); // [cite: 372]

      appState.notifyProductsUpdated(); // [cite: 373]
      Navigator.pop(context); // [cite: 374]
      _showStyledSnackBar("Đã lưu danh sách chi phí biến đổi cho tháng"); // [cite: 375]
    } catch (e) { // [cite: 377]
      Navigator.pop(context); // [cite: 378]
      print("Error saving variable expense list: $e"); // [cite: 379]
      _showStyledSnackBar("Lỗi khi lưu dữ liệu: $e", isError: true); // [cite: 380]
    }
  }


  @override
  void dispose() {
    appState.productsUpdated.removeListener(_onExpensesUpdated);
    _animationController.dispose();
    _tabController.dispose();

    _groupedExpenseItems.forEach((_, items) { // [cite: 195]
      for (var item in items) { // [cite: 196]
        item['nameController']?.dispose(); // [cite: 197]
        item['priceController']?.dispose(); // [cite: 198]
        item['nameFocusNode']?.dispose(); // [cite: 199]
        item['priceFocusNode']?.dispose(); // [cite: 200]
      }
    });

    super.dispose();
  }

  void _showStyledSnackBar(String message, {bool isError = false}) {
    if (!mounted) return; // [cite: 286]
    ScaffoldMessenger.of(context).showSnackBar( // [cite: 287]
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins(color: Colors.white)), // [cite: 289]
        backgroundColor: isError ? Colors.redAccent : Colors.green, // [cite: 290]
        behavior: SnackBarBehavior.floating, // [cite: 291]
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), // [cite: 292]
        margin: const EdgeInsets.all(10), // [cite: 293]
      ),
    );
  }

  void removeExpense(int index, AppState appState) {
    if (index < 0 || index >= appState.variableExpenseList.value.length) return; // [cite: 3326]
    if (!mounted) return; // [cite: 3327]

    final removedExpenseName = appState.variableExpenseList.value[index]['name']; // [cite: 3329]
    setState(() { // [cite: 3330]
      List<Map<String, dynamic>> currentVariableExpenses = List.from(appState.variableExpenseList.value); // [cite: 3332]
      currentVariableExpenses.removeAt(index); // [cite: 3333]
      appState.variableExpenseList.value = currentVariableExpenses; // [cite: 3334]
      variableExpenses = List.from(currentVariableExpenses); // [cite: 3335]

      ExpenseManager.saveVariableExpenses(appState, currentVariableExpenses) // [cite: 3336]
          .then((_) => ExpenseManager.updateTotalVariableExpense(appState, currentVariableExpenses)) // [cite: 3338]
          .then((total) {
        appState.setExpenses(appState.fixedExpense, total); // [cite: 3341]
        _showStyledSnackBar("Đã xóa: $removedExpenseName"); // [cite: 3342]
      }).catchError((e) { // [cite: 3343]
        _showStyledSnackBar("Lỗi khi xóa chi phí: $e", isError: true); // [cite: 3344]
      });
    });
  }

  void editExpense(int index, AppState appState) {
    if (index < 0 || index >= appState.variableExpenseList.value.length) return; // [cite: 3349]
    final expenseToEdit = appState.variableExpenseList.value[index]; // [cite: 3350]
    final TextEditingController editAmountController = TextEditingController( // [cite: 3351]
        text: _inputPriceFormatter.format(expenseToEdit['amount'] ?? 0.0) // [cite: 3352]
    );

    showDialog( // [cite: 3353]
      context: context, // [cite: 3354]
      builder: (dialogContext) => AlertDialog( // [cite: 3358]
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)), // [cite: 3360]
        title: Text( // [cite: 3361]
          "Chỉnh sửa: ${expenseToEdit['name']}", // [cite: 3362]
          overflow: TextOverflow.ellipsis, // [cite: 3363]
          maxLines: 1, // [cite: 3364]
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: AppColors.getTextColor(context)), // [cite: 3365, 3366]
        ),
        content: TextField( // [cite: 3368]
          controller: editAmountController, // [cite: 3369]
          keyboardType: TextInputType.numberWithOptions(decimal: false), // [cite: 3370]
          inputFormatters: [ // [cite: 3371]
            FilteringTextInputFormatter.digitsOnly, // [cite: 3372]
            TextInputFormatter.withFunction( // [cite: 3373]
                  (oldValue, newValue) {
                if (newValue.text.isEmpty) return newValue.copyWith(text: '0'); // [cite: 3375]
                final String plainNumberText = newValue.text.replaceAll('.', '').replaceAll(',', ''); // [cite: 3376, 3377, 3378]
                final number = int.tryParse(plainNumberText); // [cite: 3379]
                if (number == null) return oldValue; // [cite: 3380]
                final formattedText = _inputPriceFormatter.format(number); // [cite: 3381]
                return newValue.copyWith( // [cite: 3382]
                  text: formattedText, // [cite: 3383]
                  selection: TextSelection.collapsed(offset: formattedText.length), // [cite: 3385]
                );
              },
            ),
          ],
          decoration: InputDecoration( // [cite: 3390]
              labelText: "Nhập số tiền mới", // [cite: 3391]
              labelStyle: GoogleFonts.poppins(color: AppColors.getTextSecondaryColor(context)), // [cite: 3392]
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0)), // [cite: 3393, 3394]
              filled: true, // [cite: 3395]
              fillColor: AppColors.getBackgroundColor(context).withOpacity(0.7), // [cite: 3396]
              prefixIcon: Icon(Icons.monetization_on_outlined, color: AppColors.chartRed) // [cite: 3397, 3398]
          ),
          maxLines: 1, // [cite: 3399]
          maxLength: 15, // [cite: 3400]
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), // [cite: 3403]
        actions: [ // [cite: 3404]
          TextButton( // [cite: 3405]
            onPressed: () => Navigator.pop(dialogContext), // [cite: 3407]
            child: Text("Hủy", style: GoogleFonts.poppins(color: AppColors.getTextSecondaryColor(context), fontWeight: FontWeight.w500)), // [cite: 3409, 3410, 3411, 3412]
          ),
          ElevatedButton( // [cite: 3414]
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.chartRed, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0))), // [cite: 3415, 3416, 3417, 3418, 3419]
            onPressed: () { // [cite: 3423]
              double newAmount = double.tryParse(editAmountController.text.replaceAll('.', '').replaceAll(',', '')) ?? 0.0; // [cite: 3424, 3425, 3426, 3427]
              if (newAmount > 0) { // [cite: 3433]
                if (!mounted) return; // [cite: 3434]
                setState(() { // [cite: 3435]
                  List<Map<String, dynamic>> currentVariableExpenses = List.from(appState.variableExpenseList.value); // [cite: 3437]
                  currentVariableExpenses[index]['amount'] = newAmount; // [cite: 3438]
                  appState.variableExpenseList.value = currentVariableExpenses; // [cite: 3440]
                  variableExpenses = List.from(currentVariableExpenses); // [cite: 3441]

                  ExpenseManager.saveVariableExpenses(appState, currentVariableExpenses) // [cite: 3442]
                      .then((_) => ExpenseManager.updateTotalVariableExpense(appState, currentVariableExpenses)) // [cite: 3445]
                      .then((total) {
                    appState.setExpenses(appState.fixedExpense, total); // [cite: 3448]
                    Navigator.pop(dialogContext); // [cite: 3449]
                    _showStyledSnackBar("Đã cập nhật: ${expenseToEdit['name']}"); // [cite: 3451]
                  }).catchError((e) { // [cite: 3452]
                    _showStyledSnackBar("Lỗi khi cập nhật: $e", isError: true); // [cite: 3453, 3454]
                    Navigator.pop(dialogContext); // [cite: 3455]
                  });
                });
              } else {
                _showStyledSnackBar("Số tiền phải lớn hơn 0!", isError: true); // [cite: 3429]
              }
            },
            child: Text("Lưu", style: GoogleFonts.poppins()), // [cite: 3460]
          ),
        ],
      ),
    );
  }

  List<dynamic> _groupExpenses(List<Map<String, dynamic>> expenses) {
    final Map<String, List<Map<String, dynamic>>> groupedExpenses = {}; // [cite: 3472]
    final List<Map<String, dynamic>> manualExpenses = []; // [cite: 3473]
    for (final expense in expenses) { // [cite: 3474]
      final String? transactionId = expense['sourceSalesTransactionId'] as String?; // [cite: 3475]
      if (transactionId != null) { // [cite: 3476]
        if (groupedExpenses[transactionId] == null) { // [cite: 3477]
          groupedExpenses[transactionId] = []; // [cite: 3478]
        }
        groupedExpenses[transactionId]!.add(expense); // [cite: 3480]
      } else {
        manualExpenses.add(expense); // [cite: 3482]
      }
    }
    final List<dynamic> displayList = []; // [cite: 3485]
    groupedExpenses.forEach((transactionId, items) { // [cite: 3487]
      if (items.isNotEmpty) { // [cite: 3488]
        String productName = "Sản phẩm không xác định"; // [cite: 3489]
        final String firstItemName = items.first['name'] as String? ?? ''; // [cite: 3490]
        RegExp regExp = RegExp(r"\((?:Cho|Cho DTP): (.*?)\)"); // [cite: 3491]
        var match = regExp.firstMatch(firstItemName); // [cite: 3492]
        if (match != null && match.groupCount >= 1) { // [cite: 3493]
          productName = match.group(1)!; // [cite: 3494]
        } else {
          regExp = RegExp(r":\s*(.*)$"); // [cite: 3496]
          match = regExp.firstMatch(firstItemName); // [cite: 3497]
          if (match != null && match.groupCount >= 1) { // [cite: 3498]
            productName = match.group(1)!.trim(); // [cite: 3499]
          }
        }
        displayList.add({ // [cite: 3502]
          'isGroup': true, // [cite: 3503]
          'transactionId': transactionId, // [cite: 3504]
          'groupTitle': "Giá vốn cho: $productName", // [cite: 3505]
          'items': items, // [cite: 3506]
          'totalAmount': items.fold(0.0, (sum, item) => sum + (item['amount'] as num? ?? 0.0)), // [cite: 3507]
          'date': items.first['date'], // [cite: 3508]
        });
      }
    });
    displayList.addAll(manualExpenses); // [cite: 3513]
    displayList.sort((a, b) { // [cite: 3515]
      DateTime dateA = DateTime.tryParse(a['date'] ?? '') ?? DateTime(1900); // [cite: 3516]
      DateTime dateB = DateTime.tryParse(b['date'] ?? '') ?? DateTime(1900); // [cite: 3517]
      return dateB.compareTo(dateA); // [cite: 3518]
    });
    return displayList; // [cite: 3520]
  }

  Widget _buildGroupCard(Map<String, dynamic> group) {
    final String title = group['groupTitle']; // [cite: 3524]
    final double totalAmount = group['totalAmount']; // [cite: 3525]
    final List<Map<String, dynamic>> items = group['items']; // [cite: 3526]
    return Card( // [cite: 3527]
      elevation: 2.0, // [cite: 3528]
      margin: const EdgeInsets.symmetric(vertical: 8.0), // [cite: 3529]
      shape: RoundedRectangleBorder( // [cite: 3530]
          borderRadius: BorderRadius.circular(12.0), // [cite: 3531]
          side: BorderSide(color: AppColors.chartRed.withOpacity(0.4), width: 1)), // [cite: 3532]
      child: ExpansionTile( // [cite: 3533]
        leading: CircleAvatar( // [cite: 3534]
          backgroundColor: AppColors.chartRed.withOpacity(0.15), // [cite: 3535]
          radius: 20, // [cite: 3536]
          child: Icon(Icons.link, color: AppColors.chartRed.withOpacity(0.8), size: 20), // [cite: 3537]
        ),
        title: Text( // [cite: 3539]
          title, // [cite: 3540]
          style: GoogleFonts.poppins( // [cite: 3541]
            fontWeight: FontWeight.w600, // [cite: 3542]
            color: AppColors.getTextColor(context), // [cite: 3543]
            fontSize: 16, // [cite: 3544]
          ),
        ),
        subtitle: Text( // [cite: 3547]
          "Tổng: ${currencyFormat.format(totalAmount)}", // [cite: 3548]
          style: GoogleFonts.poppins( // [cite: 3549]
              fontSize: 14, // [cite: 3550]
              fontWeight: FontWeight.w500, // [cite: 3551]
              color: AppColors.getTextSecondaryColor(context)), // [cite: 3552]
        ),
        childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 8), // [cite: 3554]
        expandedAlignment: Alignment.centerLeft, // [cite: 3555]
        children: items.map((expense) { // [cite: 3556]
          return ListTile( // [cite: 3557]
            dense: true, // [cite: 3558]
            contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0), // [cite: 3559]
            title: Text( // [cite: 3560]
              expense['name'] ?? 'Không có tên', // [cite: 3561]
              style: GoogleFonts.poppins(fontSize: 14), // [cite: 3562]
            ),
            trailing: Text( // [cite: 3564]
              currencyFormat.format((expense['amount'] as num?)?.toDouble() ?? 0.0), // [cite: 3565]
              style: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 14), // [cite: 3566]
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildExpenseTile(Map<String, dynamic> expense, int originalIndex, {required bool isAutoCogs}) {
    final double amount = (expense['amount'] as num?)?.toDouble() ?? 0.0; // [cite: 3575]
    final appState = context.read<AppState>(); // [cite: 3576]
    return Card( // [cite: 3577]
      elevation: 1.5, // [cite: 3578]
      margin: const EdgeInsets.symmetric(vertical: 6.0), // [cite: 3579]
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)), // [cite: 3580]
      color: AppColors.getCardColor(context), // [cite: 3581]
      child: ListTile( // [cite: 3582]
        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0), // [cite: 3583]
        leading: CircleAvatar( // [cite: 3584]
          backgroundColor: AppColors.chartRed.withOpacity(0.15), // [cite: 3585]
          radius: 20, // [cite: 3586]
          child: isAutoCogs
              ? Icon(Icons.link, color: AppColors.chartRed.withOpacity(0.7), size: 20) // [cite: 3588]
              : Icon(Icons.flare_outlined, color: AppColors.chartRed, size: 22), // [cite: 3589]
        ),
        title: Text( // [cite: 3591]
          expense['name'] ?? 'Không có tên', // [cite: 3592]
          style: GoogleFonts.poppins( // [cite: 3593]
              fontSize: 16, // [cite: 3594]
              fontWeight: FontWeight.w600, // [cite: 3595]
              color: AppColors.getTextColor(context)), // [cite: 3596]
          overflow: TextOverflow.ellipsis, // [cite: 3597]
        ),
        subtitle: Text( // [cite: 3599]
          currencyFormat.format(amount), // [cite: 3600]
          style: GoogleFonts.poppins( // [cite: 3601]
              fontSize: 14.5, // [cite: 3602]
              fontWeight: FontWeight.w500, // [cite: 3603]
              color: AppColors.getTextSecondaryColor(context).withOpacity(0.9)), // [cite: 3604]
        ),
        trailing: isAutoCogs
            ? Tooltip( // [cite: 3607]
          message: "Giá vốn tự động, quản lý qua giao dịch doanh thu", // [cite: 3608]
          child: Icon(Icons.info_outline, color: AppColors.getTextSecondaryColor(context), size: 22), // [cite: 3609]
        )
            : Row( // [cite: 3611]
          mainAxisSize: MainAxisSize.min, // [cite: 3612]
          children: [
            IconButton( // [cite: 3614]
              icon: Icon(Icons.edit_note_outlined, color: AppColors.primaryBlue, size: 22), // [cite: 3615]
              onPressed: () { // [cite: 3616]
                if (originalIndex != -1) { // [cite: 3617]
                  editExpense(originalIndex, appState); // [cite: 3618]
                }
              },
              splashRadius: 20, // [cite: 3621]
              tooltip: "Chỉnh sửa", // [cite: 3622]
            ),
            IconButton( // [cite: 3624]
              icon: Icon(Icons.delete_outline_rounded, color: AppColors.chartRed, size: 22), // [cite: 3625]
              onPressed: () { // [cite: 3626]
                if (originalIndex != -1) { // [cite: 3627]
                  removeExpense(originalIndex, appState); // [cite: 3628]
                }
              },
              splashRadius: 20, // [cite: 3631]
              tooltip: "Xóa", // [cite: 3632]
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool canManageTypes = appState.hasPermission('canManageVariableExpenses');

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        backgroundColor: AppColors.getBackgroundColor(context),
        body: Stack(
          children: [
            Container(
              height: MediaQuery.of(context).size.height * 0.2, // Giảm chiều cao một chút
              color: AppColors.chartRed.withOpacity(0.9),
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
                                    Text(
                                      "Chi phí biến đổi",
                                      style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w600, color: Colors.white),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.25), borderRadius: BorderRadius.circular(8)),
                                      child: Text(
                                        "Ngày ${DateFormat('d MMMM y', 'vi').format(appState.selectedDate)}",
                                        style: GoogleFonts.poppins(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  TabBar(
                    controller: _tabController,
                    indicatorColor: Colors.white,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white.withOpacity(0.7),
                    labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    tabs: const [
                      Tab(text: "Chi phí trong ngày"),
                      Tab(text: "Quản lý Danh mục"),
                    ],
                  ),

                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildDailyExpensesTab(),
                        _buildDefinitionsTab(canManageTypes),
                      ],
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

  Widget _buildDailyExpensesTab() {
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: isLoadingDaily
            ? Center(child: Padding(padding: const EdgeInsets.only(top: 40.0), child: CircularProgressIndicator(color: AppColors.chartRed)))
            : hasErrorDaily
            ? Center(child: Padding(padding: const EdgeInsets.only(top: 40.0), child: Text("Có lỗi xảy ra khi tải dữ liệu", style: GoogleFonts.poppins(color: AppColors.getTextSecondaryColor(context)))))
            : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              color: AppColors.getCardColor(context),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Tổng chi phí biến đổi', style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.getTextColor(context))),
                    Flexible(
                      child: Text(
                        currencyFormat.format(appState.variableExpense),
                        style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.chartRed),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            if (variableExpenses.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0, top: 10.0, left: 4.0),
                child: Text(
                  "Chi phí đã thêm trong ngày",
                  style: GoogleFonts.poppins(fontSize: 19, fontWeight: FontWeight.w700, color: AppColors.getTextColor(context)),
                ),
              ),

            SlideTransition(
              position: _slideAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: variableExpenses.isEmpty
                    ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40.0),
                  child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.receipt_long_outlined, size: 50, color: AppColors.getTextSecondaryColor(context)),
                    const SizedBox(height: 16),
                    Text("Chưa có chi phí nào", textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 16, color: AppColors.getTextSecondaryColor(context))),
                  ])),
                )
                    : Builder(
                  builder: (context) {
                    final List<dynamic> displayItems = _groupExpenses(variableExpenses);
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: displayItems.length,
                      itemBuilder: (context, index) {
                        final item = displayItems[index];
                        if (item is Map && item['isGroup'] == true) {
                          return _buildGroupCard(item as Map<String, dynamic>);
                        } else {
                          final expense = item as Map<String, dynamic>;
                          final originalIndex = appState.variableExpenseList.value.indexOf(expense);
                          return _buildExpenseTile(expense, originalIndex, isAutoCogs: expense['sourceSalesTransactionId'] != null);
                        }
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefinitionsTab(bool canManageTypes) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: isLoadingDefinitions
                ? Center(child: CircularProgressIndicator(color: AppColors.chartRed))
                : hasErrorDefinitions
                ? Center(child: Text("Không thể tải danh mục.", style: GoogleFonts.poppins(color: AppColors.getTextColor(context))))
                : _groupedExpenseItems.values.every((list) => list.isEmpty) && !isLoadingDefinitions
                ? Center(child: Text("Nhấn (+) để thêm định nghĩa chi phí.", textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 16, color: AppColors.getTextColor(context))))
                : ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 20),
              itemCount: _groupOrder.length,
              itemBuilder: (context, groupIndex) {
                final String? groupId = _groupOrder[groupIndex];
                final List<Map<String, dynamic>> itemsInGroup = _groupedExpenseItems[groupId]!;
                final String groupTitle = groupId == null
                    ? "Chi phí khác (không gắn sản phẩm)"
                    : "Chi phí cho: ${_productIdToNameMap[groupId] ?? 'Sản phẩm không xác định'}";

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 16, 8, 4),
                      child: Text(
                        groupTitle,
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16, color: AppColors.chartRed),
                      ),
                    ),
                    ...itemsInGroup.asMap().entries.map((entry) {
                      int itemIndex = entry.key;
                      Map<String, dynamic> item = entry.value;
                      final isPercentage = item['costType'] == 'percentage';

                      return Card(
                          elevation: 2, // [cite: 501]
                          margin: const EdgeInsets.symmetric(vertical: 8.0), // [cite: 502]
                          shape: RoundedRectangleBorder( // [cite: 503]
                            borderRadius: BorderRadius.circular(16), // [cite: 504]
                            side: BorderSide(color: AppColors.getBorderColor(context), width: 0.5), // [cite: 505]
                          ),
                          color: AppColors.getCardColor(context), // [cite: 507]
                          clipBehavior: Clip.antiAlias, // [cite: 508]
                          child: Padding(
                              padding: const EdgeInsets.all(12.0), // [cite: 510]
                              child: Column(
                                  mainAxisSize: MainAxisSize.min, // [cite: 512]
                                  crossAxisAlignment: CrossAxisAlignment.start, // [cite: 513]
                                  children: [
                                    Row( // [cite: 516]
                                      crossAxisAlignment: CrossAxisAlignment.center, // [cite: 517]
                                      children: [
                                        Expanded(
                                          child: TextField( // [cite: 520]
                                            controller: item['nameController'], // [cite: 521]
                                            focusNode: item['nameFocusNode'], // [cite: 522]
                                            style: GoogleFonts.poppins(color: AppColors.getTextColor(context), fontWeight: FontWeight.w500), // [cite: 523]
                                            maxLength: 50, // [cite: 524]
                                            maxLines: 1, // [cite: 525]
                                            decoration: InputDecoration( // [cite: 526]
                                              labelText: "Tên khoản chi", // [cite: 527]
                                              labelStyle: GoogleFonts.poppins(color: AppColors.chartRed), // [cite: 528]
                                              border: InputBorder.none, // [cite: 529]
                                              filled: true, // [cite: 530]
                                              fillColor: AppColors.getBackgroundColor(context), // [cite: 531]
                                              prefixIcon: const Icon(Icons.edit_note_outlined, size: 22), // [cite: 532]
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), // [cite: 533]
                                              counterText: "", // [cite: 534]
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8), // [cite: 538]
                                        IconButton( // [cite: 539]
                                          icon: Icon(Icons.remove_circle_outline, color: AppColors.chartRed.withOpacity(0.8), size: 28), // [cite: 540]
                                          onPressed: canManageTypes ? () => removeDefinitionController(groupId, itemIndex) : null, // [cite: 541]
                                          tooltip: "Xóa mục này", // [cite: 542]
                                          padding: EdgeInsets.zero, // [cite: 543]
                                          constraints: const BoxConstraints(), // [cite: 544]
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16), // [cite: 548]
                                    Row( // [cite: 550]
                                      crossAxisAlignment: CrossAxisAlignment.start, // [cite: 551]
                                      children: [
                                        Expanded( // [cite: 554]
                                          flex: 5, // [cite: 555]
                                          child: Column( // [cite: 556]
                                            children: [
                                              SegmentedButton<String>( // [cite: 558]
                                                segments: const [ // [cite: 559]
                                                  ButtonSegment(value: 'fixed', label: Text('VNĐ')), // [cite: 560]
                                                  ButtonSegment(value: 'percentage', label: Text('%')), // [cite: 561]
                                                ],
                                                selected: {item['costType']}, // [cite: 563]
                                                onSelectionChanged: (newSelection) { // [cite: 564]
                                                  setState(() { // [cite: 565]
                                                    item['costType'] = newSelection.first; // [cite: 566]
                                                  });
                                                },
                                                style: SegmentedButton.styleFrom( // [cite: 569]
                                                  backgroundColor: AppColors.getBackgroundColor(context), // [cite: 570]
                                                  selectedBackgroundColor: AppColors.chartRed, // [cite: 571]
                                                  selectedForegroundColor: Colors.white, // [cite: 572]
                                                  foregroundColor: AppColors.getTextSecondaryColor(context), // [cite: 573]
                                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap, // [cite: 574]
                                                  visualDensity: const VisualDensity(horizontal: -2, vertical: -2), // [cite: 575]
                                                ),
                                                showSelectedIcon: false, // [cite: 577]
                                              ),
                                              const SizedBox(height: 8), // [cite: 579]
                                              TextField( // [cite: 580]
                                                controller: item['priceController'], // [cite: 581]
                                                focusNode: item['priceFocusNode'], // [cite: 582]
                                                textAlign: TextAlign.center, // [cite: 583]
                                                keyboardType: const TextInputType.numberWithOptions(decimal: false), // [cite: 584]
                                                inputFormatters: [FilteringTextInputFormatter.digitsOnly], // [cite: 585]
                                                style: GoogleFonts.poppins(color: AppColors.getTextColor(context), fontWeight: FontWeight.bold, fontSize: 18), // [cite: 586]
                                                maxLength: isPercentage ? 3 : 15, // [cite: 587]
                                                decoration: InputDecoration( // [cite: 588]
                                                  hintText: "Giá trị", // [cite: 589]
                                                  filled: true, // [cite: 590]
                                                  fillColor: AppColors.getBackgroundColor(context), // [cite: 591]
                                                  suffixIcon: Padding( // [cite: 592]
                                                    padding: const EdgeInsets.only(right: 12.0), // [cite: 593]
                                                    child: Text(isPercentage ? "%" : "VNĐ", style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.getTextSecondaryColor(context))), // [cite: 594, 595, 596, 597, 598, 599]
                                                  ),
                                                  suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0), // [cite: 602]
                                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.getBorderColor(context))), // [cite: 603, 604, 605]
                                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.getBorderColor(context))), // [cite: 607, 608, 609]
                                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.chartRed, width: 1.5)), // [cite: 611, 612, 613]
                                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), // [cite: 614]
                                                  counterText: "", // [cite: 615]
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 12), // [cite: 621]
                                        Expanded( // [cite: 623]
                                          flex: 4, // [cite: 624]
                                          child: isLoadingProducts
                                              ? const Center(child: Padding(padding: EdgeInsets.only(top: 40.0), child: CircularProgressIndicator(strokeWidth: 2))) // [cite: 626]
                                              : DropdownButtonFormField<String>( // [cite: 627]
                                            isExpanded: true, // [cite: 628]
                                            decoration: InputDecoration( // [cite: 629]
                                              labelText: "Gắn SP", // [cite: 630]
                                              labelStyle: GoogleFonts.poppins(color: AppColors.chartRed), // [cite: 631]
                                              filled: true, // [cite: 632]
                                              fillColor: AppColors.getBackgroundColor(context), // [cite: 633]
                                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.getBorderColor(context))), // [cite: 634, 635, 636]
                                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.getBorderColor(context))), // [cite: 637, 638, 639]
                                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.chartRed, width: 1.5)), // [cite: 640, 641, 642]
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15), // [cite: 643]
                                            ),
                                            value: item['linkedProductId'], // [cite: 645]
                                            style: GoogleFonts.poppins(color: AppColors.getTextColor(context), fontSize: 14), // [cite: 646]
                                            items: [ // [cite: 647]
                                              DropdownMenuItem<String>( // [cite: 648]
                                                value: null, // [cite: 649]
                                                child: Text("Không gắn", style: GoogleFonts.poppins(fontStyle: FontStyle.italic, color: AppColors.getTextSecondaryColor(context))), // [cite: 650]
                                              ),
                                              ...availableProductsForDropdown.map((product) { // [cite: 652]
                                                return DropdownMenuItem<String>(
                                                  value: product['id'] as String, // [cite: 654]
                                                  child: Text(product['name'] as String, overflow: TextOverflow.ellipsis), // [cite: 655]
                                                );
                                              }).toList(), // [cite: 657]
                                            ],
                                            onChanged: (String? newValue) { // [cite: 659]
                                              setState(() { // [cite: 660]
                                                item['linkedProductId'] = newValue; // [cite: 661]
                                              });
                                              _regroupItems(); // [cite: 664]
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ]
                              )
                          )
                      );
                    }).toList(),
                  ],
                );
              },
            ),
          ),
        ),
        if (!isLoadingDefinitions)
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.chartRed,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      minimumSize: Size(screenWidth, 52),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: canManageTypes ? () => saveUpdatedDefinitionsList(appState) : null,
                    icon: const Icon(Icons.save_alt_outlined, size: 20),
                    label: Text("Lưu danh sách", style: GoogleFonts.poppins(fontSize: 16.5, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 10),
                Material(
                  color: AppColors.chartRed,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: canManageTypes ? addDefinitionController : null,
                    borderRadius: BorderRadius.circular(12),
                    child: const SizedBox(
                      width: 52,
                      height: 52,
                      child: Icon(Icons.add, color: Colors.white, size: 28),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
