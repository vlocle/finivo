import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:marquee/marquee.dart'; // Kept from original
import '../state/app_state.dart';
import '/screens/expense_manager.dart'; // Ensure this path is correct
import 'package:google_fonts/google_fonts.dart';

class EditFixedExpenseScreen extends StatefulWidget {
  const EditFixedExpenseScreen({Key? key}) : super(key: key);

  @override
  _EditFixedExpenseScreenState createState() => _EditFixedExpenseScreenState();
}

class _EditFixedExpenseScreenState extends State<EditFixedExpenseScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController amountController = TextEditingController();
  final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'VNĐ');
  final NumberFormat _inputPriceFormatter = NumberFormat("#,##0", "vi_VN");

  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _totalFadeAnimation;
  late Animation<double> _buttonScaleAnimation;

  // Updated Color Palette
  static const Color _appBarColor = Color(0xFFD32F2F); // Original AppBar color, now used for top section
  static const Color _accentColor = Color(0xFFD32F2F); // Deep Red for emphasis/delete
  static const Color _secondaryColor = Color(0xFFF1F5F9); // Light background
  static const Color _textColorPrimary = Color(0xFF1D2D3A);
  static const Color _textColorSecondary = Color(0xFF6E7A8A);
  static const Color _cardBackgroundColor = Colors.white;
  static const Color _editButtonColor = Color(0xFF0A7AFF); // Blue for edit actions


  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
        duration: const Duration(milliseconds: 700), vsync: this);
    _slideAnimation = Tween<Offset>(
        begin: const Offset(0, 0.5), end: Offset.zero)
        .animate(CurvedAnimation(
        parent: _animationController, curve: Curves.easeOut));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _animationController, curve: Curves.easeIn));
    _totalFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
            parent: _animationController,
            curve: const Interval(0.3, 1.0, curve: Curves.easeIn)));
    _buttonScaleAnimation = TweenSequence([
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.95), weight: 50),
      TweenSequenceItem(tween: Tween<double>(begin: 0.95, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(
        parent: _animationController, curve: Curves.easeInOut));

    _animationController.forward();
  }

  @override
  void dispose() {
    amountController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _showStyledSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: isError ? _accentColor : _appBarColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(10),
      ),
    );
  }


  void showEditAmountDialog(int index, AppState appState) {
    final expenseToEdit = appState.fixedExpenseList.value[index];
    amountController.text = _inputPriceFormatter.format(expenseToEdit['amount'] ?? 0.0);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
        title: Text(
          "Chỉnh sửa: ${expenseToEdit['name']}",
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: _textColorPrimary),
        ),
        content: TextField(
          controller: amountController,
          keyboardType: TextInputType.numberWithOptions(decimal: false),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            TextInputFormatter.withFunction(
                  (oldValue, newValue) {
                if (newValue.text.isEmpty) return newValue;
                final String plainNumberText = newValue.text.replaceAll('.', '').replaceAll(',', '');
                final number = int.tryParse(plainNumberText);
                if (number == null) return oldValue;
                final formattedText = _inputPriceFormatter.format(number);
                return newValue.copyWith(
                  text: formattedText,
                  selection: TextSelection.collapsed(offset: formattedText.length),
                );
              },
            ),
          ],
          decoration: InputDecoration(
              labelText: "Nhập số tiền",
              labelStyle: GoogleFonts.poppins(color: _textColorSecondary),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0)),
              filled: true,
              fillColor: _secondaryColor.withOpacity(0.7),
              prefixIcon: Icon(Icons.monetization_on_outlined, color: _appBarColor)
          ),
          maxLines: 1,
          maxLength: 15,
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        actions: [
          TextButton(
            onPressed: () {
              amountController.clear();
              Navigator.pop(dialogContext);
            },
            child: Text("Hủy", style: GoogleFonts.poppins(color: _textColorSecondary, fontWeight: FontWeight.w500)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _appBarColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            onPressed: () async {
              double newAmount = double.tryParse(amountController.text.replaceAll('.', '').replaceAll(',', '')) ?? 0.0;
              if (newAmount >= 0) {
                try {
                  final updatedExpenses = List<Map<String, dynamic>>.from(appState.fixedExpenseList.value);
                  updatedExpenses[index]['amount'] = newAmount;
                  //appState.fixedExpenseList.value = updatedExpenses;

                  await ExpenseManager.saveFixedExpenses(appState, updatedExpenses);
                  //await appState.loadExpenseValues();

                  amountController.clear();
                  Navigator.pop(dialogContext);
                  _showStyledSnackBar("Đã cập nhật số tiền cho ${expenseToEdit['name']}");
                } catch (e) {
                  Navigator.pop(dialogContext);
                  _showStyledSnackBar("Lỗi khi cập nhật: $e", isError: true);
                }
              } else {
                _showStyledSnackBar("Số tiền không thể âm", isError: true);
              }
            },
            child: Text("Lưu", style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }

  Future<void> deleteExpenseItem(int index, AppState appState) async {
    if (index < 0 || index >= appState.fixedExpenseList.value.length) return;
    final expenseName = appState.fixedExpenseList.value[index]['name'];

    bool? confirm = await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
        title: Text("Xác nhận xóa", style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: _textColorPrimary)),
        content: Text(
          "Bạn có chắc muốn xóa '$expenseName' không?",
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
          style: GoogleFonts.poppins(color: _textColorSecondary),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text("Hủy", style: GoogleFonts.poppins(color: _textColorSecondary, fontWeight: FontWeight.w500)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _accentColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0))),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text("Xóa", style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final updatedExpenses = List<Map<String, dynamic>>.from(appState.fixedExpenseList.value);
        updatedExpenses.removeAt(index);
        //appState.fixedExpenseList.value = updatedExpenses;

        await ExpenseManager.saveFixedExpenses(appState, updatedExpenses);
        //await appState.loadExpenseValues();
        _showStyledSnackBar("Đã xóa khoản chi phí: $expenseName");
      } catch (e) {
        _showStyledSnackBar("Lỗi khi xóa: $e", isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context, listen: false);
    // final screenWidth = MediaQuery.of(context).size.width; // Kept from original, not directly used in current build

    return Scaffold(
      backgroundColor: _secondaryColor,
      body: Stack(
        children: [
          Container(
            height: MediaQuery.of(context).size.height * 0.25,
            color: _appBarColor.withOpacity(0.9),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                                    "Chi phí cố định",
                                    style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w600, color: Colors.white ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.25),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      "Ngày ${DateFormat('d MMMM y', 'vi').format(appState.selectedDate)}",
                                      style: GoogleFonts.poppins(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500 ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
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
                const SizedBox(height: 16),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: ValueListenableBuilder<List<Map<String, dynamic>>>(
                      valueListenable: appState.fixedExpenseList,
                      builder: (context, fixedExpenses, _) {
                        if (fixedExpenses.isEmpty && appState.fixedExpenseListenable.value == 0.0) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.receipt_long_outlined, size: 60, color: Colors.grey.shade400),
                                SizedBox(height: 16),
                                Text(
                                  "Chưa có chi phí cố định",
                                  style: GoogleFonts.poppins(fontSize: 17, color: _textColorSecondary),
                                ),
                              ],
                            ),
                          );
                        }
                        return Column(
                          children: [
                            FadeTransition(
                              opacity: _totalFadeAnimation,
                              child: Card(
                                elevation: 4,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
                                color: _cardBackgroundColor,
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Tổng chi phí cố định',
                                        style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w600, color: _textColorPrimary ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Flexible(
                                        child: ValueListenableBuilder<double>(
                                          valueListenable: appState.fixedExpenseListenable,
                                          builder: (context, fixedExpenseTotal, _) {
                                            // Using Text instead of Marquee for cleaner look
                                            return Text(
                                              currencyFormat.format(fixedExpenseTotal),
                                              style: GoogleFonts.poppins(
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold,
                                                color: _accentColor,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                              textAlign: TextAlign.end,
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Expanded(
                              child: SlideTransition(
                                position: _slideAnimation,
                                child: FadeTransition(
                                  opacity: _fadeAnimation,
                                  child: ListView.builder( // No outer Card, each item is a Card
                                    padding: EdgeInsets.zero, // Remove padding if items have their own margin
                                    itemCount: fixedExpenses.length,
                                    itemBuilder: (context, index) {
                                      final expense = fixedExpenses[index];
                                      double amount = expense['amount'] ?? 0.0;
                                      return Card(
                                        elevation: 2,
                                        margin: const EdgeInsets.symmetric(vertical: 6.0),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                                        color: _cardBackgroundColor,
                                        child: ListTile(
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                                          visualDensity: VisualDensity.adaptivePlatformDensity,
                                          leading: CircleAvatar(
                                            backgroundColor: _appBarColor.withOpacity(0.15),
                                            child: Icon(Icons.shield_outlined, color: _appBarColor, size: 22),
                                            radius: 20,
                                          ),
                                          title: Text(
                                            expense['name'],
                                            style: GoogleFonts.poppins(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                                color: _textColorPrimary),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                          subtitle: Text(
                                            currencyFormat.format(amount),
                                            style: GoogleFonts.poppins(
                                              fontSize: 14.5,
                                              fontWeight: FontWeight.w500,
                                              color: _textColorSecondary.withOpacity(0.9),
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          trailing: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              ScaleTransition(
                                                scale: _buttonScaleAnimation,
                                                child: IconButton(
                                                  icon: Icon(Icons.edit_note_outlined,
                                                      color: _editButtonColor, size: 22),
                                                  onPressed: () => showEditAmountDialog(index, appState),
                                                  splashRadius: 20,
                                                  tooltip: "Chỉnh sửa",
                                                ),
                                              ),
                                              ScaleTransition(
                                                scale: _buttonScaleAnimation,
                                                child: IconButton(
                                                  icon: Icon(Icons.delete_outline_rounded,
                                                      color: _accentColor, size: 22),
                                                  onPressed: () => deleteExpenseItem(index, appState),
                                                  splashRadius: 20,
                                                  tooltip: "Xóa",
                                                ),
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
                          ],
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