import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '/screens/revenue_manager.dart';

class EditRevenueScreen extends StatefulWidget {
  final String category;
  const EditRevenueScreen({Key? key, required this.category}) : super(key: key);

  @override
  _EditRevenueScreenState createState() => _EditRevenueScreenState();
}

class _EditRevenueScreenState extends State<EditRevenueScreen> with SingleTickerProviderStateMixin {
  final TextEditingController quantityController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    quantityController.text = "1";
    _controller = AnimationController(duration: const Duration(milliseconds: 700), vsync: this);
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));
    _controller.forward();
  }

  @override
  void dispose() {
    quantityController.dispose();
    priceController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void addTransaction(AppState appState, List<Map<String, dynamic>> transactions, String? selectedProduct, double selectedPrice, bool isFlexiblePrice) {
    if (selectedProduct == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Vui lòng chọn sản phẩm/dịch vụ!")));
      return;
    }
    double price = isFlexiblePrice ? (double.tryParse(priceController.text) ?? 0.0) : selectedPrice;
    int quantity = int.tryParse(quantityController.text) ?? 1;
    double total = price * quantity;
    int existingIndex = transactions.indexWhere((t) => t['name'] == selectedProduct);
    if (existingIndex != -1) {
      transactions[existingIndex]['quantity'] += quantity;
      transactions[existingIndex]['total'] += total;
    } else {
      transactions.add({"name": selectedProduct, "price": price, "quantity": quantity, "total": total});
    }
    RevenueManager.saveTransactionHistory(appState, widget.category, transactions);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Đã thêm giao dịch: $selectedProduct")));
    setState(() {
      quantityController.text = "1";
      priceController.clear();
    });
  }

  void removeTransaction(AppState appState, List<Map<String, dynamic>> transactions, int index) {
    transactions.removeAt(index);
    RevenueManager.saveTransactionHistory(appState, widget.category, transactions);
  }

  void editTransaction(AppState appState, List<Map<String, dynamic>> transactions, int index) {
    TextEditingController editQuantityController = TextEditingController(text: transactions[index]['quantity'].toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Chỉnh sửa số lượng"),
        content: TextField(
          keyboardType: TextInputType.number,
          controller: editQuantityController,
          decoration: const InputDecoration(labelText: "Nhập số lượng mới"),
          maxLines: 1,
          maxLength: 5, // Giới hạn số lượng tối đa
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Hủy")),
          ElevatedButton(
            onPressed: () {
              int newQuantity = int.tryParse(editQuantityController.text) ?? transactions[index]['quantity'];
              transactions[index]['quantity'] = newQuantity;
              transactions[index]['total'] = transactions[index]['price'] * newQuantity;
              RevenueManager.saveTransactionHistory(appState, widget.category, transactions);
              Navigator.pop(context);
            },
            child: const Text("Lưu"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final screenWidth = MediaQuery.of(context).size.width;
    ValueNotifier<List<Map<String, dynamic>>> transactions = widget.category == "Doanh thu chính" ? appState.mainRevenueTransactions : appState.secondaryRevenueTransactions;

    return Scaffold(
      body: Stack(
        children: [
          Container(
            height: MediaQuery.of(context).size.height * 0.25,
            color: const Color(0xFF1976D2).withOpacity(0.9),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "Chỉnh sửa ${widget.category}",
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Colors.white),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: FutureBuilder<List<Map<String, dynamic>>>(
                      future: RevenueManager.loadProducts(appState, widget.category),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                        if (snapshot.hasError) return const Center(child: Text("Lỗi tải dữ liệu"));
                        List<Map<String, dynamic>> productList = snapshot.data ?? [];
                        return SlideTransition(
                          position: _slideAnimation,
                          child: FadeTransition(
                            opacity: _fadeAnimation,
                            child: Card(
                              elevation: 10,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: ProductInputSection(
                                  productList: productList,
                                  quantityController: quantityController,
                                  priceController: priceController,
                                  onAddTransaction: (selectedProduct, selectedPrice, isFlexiblePrice) {
                                    addTransaction(appState, transactions.value, selectedProduct, selectedPrice, isFlexiblePrice);
                                  },
                                  transactions: transactions,
                                  onEditTransaction: editTransaction,
                                  onRemoveTransaction: removeTransaction,
                                  appState: appState,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ProductInputSection extends StatefulWidget {
  final List<Map<String, dynamic>> productList;
  final TextEditingController quantityController;
  final TextEditingController priceController;
  final Function(String?, double, bool) onAddTransaction;
  final ValueNotifier<List<Map<String, dynamic>>> transactions;
  final Function(AppState, List<Map<String, dynamic>>, int) onEditTransaction;
  final Function(AppState, List<Map<String, dynamic>>, int) onRemoveTransaction;
  final AppState appState;

  const ProductInputSection({
    required this.productList,
    required this.quantityController,
    required this.priceController,
    required this.onAddTransaction,
    required this.transactions,
    required this.onEditTransaction,
    required this.onRemoveTransaction,
    required this.appState,
  });

  @override
  _ProductInputSectionState createState() => _ProductInputSectionState();
}

class _ProductInputSectionState extends State<ProductInputSection> {
  String? selectedProduct;
  double selectedPrice = 0.0;
  bool isFlexiblePrice = false;

  @override
  void initState() {
    super.initState();
    widget.priceController.text = selectedPrice.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Chọn sản phẩm/dịch vụ",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 10),
        DropdownButton<String>(
          value: selectedProduct,
          hint: const Text(
            "Chọn sản phẩm/dịch vụ",
            overflow: TextOverflow.ellipsis,
          ),
          isExpanded: true,
          onChanged: (String? newValue) {
            setState(() {
              selectedProduct = newValue;
              if (newValue != null) {
                selectedPrice = widget.productList.firstWhere((p) => p["name"] == newValue, orElse: () => {"price": 0.0})["price"].toDouble();
                widget.priceController.text = selectedPrice.toStringAsFixed(2);
                isFlexiblePrice = false;
              }
            });
          },
          items: widget.productList.isEmpty
              ? [
            const DropdownMenuItem<String>(
              value: null,
              child: Text(
                "Chưa có sản phẩm nào",
                overflow: TextOverflow.ellipsis,
              ),
            )
          ]
              : widget.productList
              .map((p) => DropdownMenuItem<String>(
            value: p["name"],
            child: Text(
              p["name"],
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ))
              .toList(),
        ),
        const SizedBox(height: 20),
        CheckboxListTile(
          title: const Text(
            "Giá linh hoạt",
            overflow: TextOverflow.ellipsis,
          ),
          value: isFlexiblePrice,
          onChanged: (bool? value) {
            setState(() {
              isFlexiblePrice = value ?? false;
              if (!isFlexiblePrice && selectedProduct != null) {
                widget.priceController.text = selectedPrice.toStringAsFixed(2);
              }
            });
          },
        ),
        const SizedBox(height: 10),
        TextField(
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: "Giá",
            border: OutlineInputBorder(),
          ),
          controller: widget.priceController,
          enabled: isFlexiblePrice,
          maxLines: 1,
          maxLength: 15, // Giới hạn số ký tự
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            const Text(
              "Số lượng:",
              style: TextStyle(fontSize: 16),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(width: 10),
            Flexible(
              child: TextField(
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: "Nhập số lượng",
                ),
                controller: widget.quantityController,
                maxLines: 1,
                maxLength: 5, // Giới hạn số ký tự
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          "Tổng tiền: ${(double.tryParse(widget.priceController.text) ?? selectedPrice) * (int.tryParse(widget.quantityController.text) ?? 1)} VNĐ",
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        const SizedBox(height: 30),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF42A5F5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            minimumSize: Size(screenWidth - 32, 50), // Full-width trừ padding
          ),
          onPressed: () => widget.onAddTransaction(selectedProduct, selectedPrice, isFlexiblePrice),
          child: const Text(
            "Thêm giao dịch",
            style: TextStyle(color: Colors.white, fontSize: 16),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 30),
        const Text(
          "Lịch sử giao dịch",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 10),
        Expanded(
          child: ValueListenableBuilder(
            valueListenable: widget.transactions,
            builder: (context, List<Map<String, dynamic>> history, _) {
              return ListView.builder(
                itemCount: history.length,
                itemBuilder: (context, index) {
                  final transaction = history[index];
                  return Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      title: Text(
                        "${transaction['name']} - ${transaction['quantity']} x ${transaction['price']} VNĐ",
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      subtitle: Text(
                        "Tổng: ${transaction['total'].toStringAsFixed(2)} VNĐ",
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue, size: 18),
                            onPressed: () => widget.onEditTransaction(widget.appState, widget.transactions.value, index),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                            onPressed: () => widget.onRemoveTransaction(widget.appState, widget.transactions.value, index),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
