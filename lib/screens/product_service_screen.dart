import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';

class ProductServiceScreen extends StatefulWidget {
  @override
  _ProductServiceScreenState createState() => _ProductServiceScreenState();
}

class _ProductServiceScreenState extends State<ProductServiceScreen> with SingleTickerProviderStateMixin {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  final NumberFormat currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'VND');
  List<Map<String, dynamic>> productList = [];
  String selectedCategory = "Sản phẩm/Dịch vụ chính";
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    loadProducts();
    _controller = AnimationController(duration: const Duration(milliseconds: 700), vsync: this);
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));
    _controller.forward();
  }

  @override
  void dispose() {
    nameController.dispose();
    priceController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> saveProducts(AppState appState) async {
    try {
      if (appState.userId == null) {
        throw Exception('User ID không tồn tại');
      }
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      String baseKey = selectedCategory == "Sản phẩm/Dịch vụ chính" ? 'mainProductList' : 'extraProductList';
      String key = appState.getKey(baseKey);
      String hiveKey = appState.getKey('${selectedCategory}_productList');

      // Chuẩn hóa productList trước khi lưu
      List<Map<String, dynamic>> standardizedProductList = productList.map((product) {
        return {
          'name': product['name'].toString(),
          'price': product['price'] as num? ?? 0.0,
        };
      }).toList();

      // Lưu vào Firestore
      await firestore
          .collection('users')
          .doc(appState.userId)
          .collection('products')
          .doc(key)
          .set({
        'products': standardizedProductList,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Đảm bảo box đã mở và lưu vào Hive
      if (!Hive.isBoxOpen('productsBox')) {
        await Hive.openBox('productsBox');
      }
      var productsBox = Hive.box('productsBox');
      await productsBox.put(hiveKey, standardizedProductList).catchError((e) {
        print('Lỗi khi lưu vào Hive: $e');
        throw Exception('Không thể lưu vào Hive: $e');
      });

      appState.notifyProductsUpdated();
      print('Lưu sản phẩm thành công cho danh mục: $selectedCategory');
    } catch (e) {
      print('Lỗi khi lưu dữ liệu: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi lưu dữ liệu: $e')),
      );
    }
  }

  Future<void> loadProducts() async {
    final appState = Provider.of<AppState>(context, listen: false);
    try {
      if (appState.userId == null) {
        print('User ID không tồn tại');
        setState(() {
          productList = [];
        });
        return;
      }

      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      String baseKey = selectedCategory == "Sản phẩm/Dịch vụ chính" ? 'mainProductList' : 'extraProductList';
      String key = appState.getKey(baseKey);
      String hiveKey = appState.getKey('${selectedCategory}_productList');

      if (!Hive.isBoxOpen('productsBox')) {
        await Hive.openBox('productsBox');
      }
      var productsBox = Hive.box('productsBox');
      print('Hive productsBox keys: ${productsBox.keys}'); // Debug

      // Kiểm tra dữ liệu trong Hive
      if (productsBox.containsKey(hiveKey)) {
        var rawData = productsBox.get(hiveKey);
        print('Raw data from Hive: $rawData'); // Debug
        List<Map<String, dynamic>> loadedProducts = [];
        if (rawData != null) {
          loadedProducts = (rawData as List<dynamic>).map((item) {
            var map = item as Map<dynamic, dynamic>;
            return map.map((key, value) {
              return MapEntry(key.toString(), value);
            });
          }).cast<Map<String, dynamic>>().toList();
        }
        setState(() {
          productList = loadedProducts;
        });
        print('Tải sản phẩm từ Hive: $productList');
        return;
      }

      // Tải từ Firestore
      DocumentSnapshot doc = await firestore
          .collection('users')
          .doc(appState.userId)
          .collection('products')
          .doc(key)
          .get();

      setState(() {
        if (doc.exists && doc['products'] != null) {
          productList = List<Map<String, dynamic>>.from(doc['products'] ?? []);
        } else {
          productList = [];
        }
      });

      // Lưu vào Hive
      await productsBox.put(hiveKey, productList);
      print('Tải sản phẩm từ Firestore và lưu vào Hive: $productList');
    } catch (e) {
      print('Lỗi khi tải từ Firestore: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi tải dữ liệu: $e')),
      );
    }
  }

  void addProduct(AppState appState) {
    String name = nameController.text.trim();
    String priceText = priceController.text.trim();
    if (name.isEmpty || priceText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Vui lòng nhập đầy đủ thông tin")));
      return;
    }
    double? price = double.tryParse(priceText);
    if (price == null || price < 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Giá sản phẩm không hợp lệ")));
      return;
    }
    if (productList.any((p) => p["name"].toLowerCase() == name.toLowerCase())) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tên sản phẩm/dịch vụ đã tồn tại")));
      return;
    }
    setState(() {
      productList.add({"name": name, "price": price});
      nameController.clear();
      priceController.clear();
    });
    saveProducts(appState);
  }

  void deleteProduct(AppState appState, int index) {
    setState(() => productList.removeAt(index));
    saveProducts(appState);
  }

  void editProduct(AppState appState, int index) {
    nameController.text = productList[index]["name"];
    priceController.text = productList[index]["price"].toString();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Chỉnh sửa sản phẩm"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: "Tên sản phẩm/dịch vụ"),
              maxLength: 50,
              maxLines: 1,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: priceController,
              decoration: const InputDecoration(labelText: "Giá tiền"),
              keyboardType: TextInputType.number,
              maxLength: 15,
              maxLines: 1,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Hủy")),
          ElevatedButton(
            onPressed: () {
              String updatedName = nameController.text.trim();
              String updatedPriceText = priceController.text.trim();
              if (updatedName.isEmpty || updatedPriceText.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Vui lòng nhập đầy đủ thông tin")));
                return;
              }
              double? updatedPrice = double.tryParse(updatedPriceText);
              if (updatedPrice == null || updatedPrice < 0) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Giá sản phẩm không hợp lệ")));
                return;
              }
              if (productList.asMap().entries.any((e) => e.key != index && e.value["name"].toLowerCase() == updatedName.toLowerCase())) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tên sản phẩm/dịch vụ đã tồn tại")));
                return;
              }
              setState(() {
                productList[index] = {"name": updatedName, "price": updatedPrice};
              });
              saveProducts(appState);
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back, color: Colors.white),
                              onPressed: () => Navigator.pop(context),
                            ),
                            const SizedBox(width: 12),
                            Flexible(
                              child: SegmentedButton<String>(
                                segments: const [
                                  ButtonSegment<String>(
                                    value: "Sản phẩm/Dịch vụ chính",
                                    label: Text("Chính", overflow: TextOverflow.ellipsis),
                                  ),
                                  ButtonSegment<String>(
                                    value: "Sản phẩm/Dịch vụ phụ",
                                    label: Text("Phụ", overflow: TextOverflow.ellipsis),
                                  ),
                                ],
                                selected: {selectedCategory},
                                onSelectionChanged: (newSelection) => setState(() {
                                  selectedCategory = newSelection.first;
                                  loadProducts();
                                }),
                                style: SegmentedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  selectedForegroundColor: Colors.white,
                                  selectedBackgroundColor: const Color(0xFF42A5F5),
                                  backgroundColor: Colors.transparent,
                                  side: const BorderSide(color: Colors.white),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: Card(
                          elevation: 10,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextField(
                                  controller: nameController,
                                  decoration: const InputDecoration(
                                    labelText: "Tên sản phẩm/dịch vụ",
                                    border: OutlineInputBorder(),
                                  ),
                                  maxLines: 1,
                                  maxLength: 50,
                                ),
                                const SizedBox(height: 10),
                                TextField(
                                  controller: priceController,
                                  decoration: const InputDecoration(
                                    labelText: "Giá tiền",
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType: TextInputType.number,
                                  maxLines: 1,
                                  maxLength: 15,
                                ),
                                const SizedBox(height: 20),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF42A5F5),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    minimumSize: Size(screenWidth - 32, 50),
                                  ),
                                  onPressed: () => addProduct(appState),
                                  child: const Text(
                                    "Lưu",
                                    style: TextStyle(color: Colors.white, fontSize: 16),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                const Text(
                                  "Danh sách sản phẩm/dịch vụ",
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 10),
                                Expanded(
                                  child: ListView.builder(
                                    itemCount: productList.length,
                                    itemBuilder: (context, index) {
                                      final product = productList[index];
                                      return Card(
                                        child: ListTile(
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                          title: Text(
                                            product["name"],
                                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                          subtitle: Text(
                                            currencyFormat.format(product["price"]),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                          trailing: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                icon: const Icon(Icons.edit, color: Colors.blue, size: 18),
                                                onPressed: () => editProduct(appState, index),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                                                onPressed: () => deleteProduct(appState, index),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
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