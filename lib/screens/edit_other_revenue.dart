import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '/screens/revenue_manager.dart'; // Ensure this path is correct
import 'package:google_fonts/google_fonts.dart';

class EditOtherRevenueScreen extends StatefulWidget {
  final VoidCallback onUpdate;
  const EditOtherRevenueScreen({required this.onUpdate, Key? key})
      : super(key: key);

  @override
  _EditOtherRevenueScreenState createState() => _EditOtherRevenueScreenState();
}

class _EditOtherRevenueScreenState extends State<EditOtherRevenueScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _totalController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final NumberFormat currencyFormat =
  NumberFormat.currency(locale: 'vi_VN', symbol: 'VNĐ');
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  int _selectedTab = 0;

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
  }

  @override
  void dispose() {
    _totalController.dispose();
    _nameController.dispose();
    _animationController.dispose();
    super.dispose();
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

  void _addTransaction(AppState appState) {
    // Corrected parsing: remove both '.' and ','
    double total = double.tryParse(_totalController.text.replaceAll('.', '').replaceAll(',', '')) ?? 0.0;
    String name = _nameController.text.trim();

    if (name.isEmpty) {
      _showStyledSnackBar('Vui lòng nhập tên giao dịch!', isError: true);
      return;
    }
    if (total <= 0) {
      _showStyledSnackBar('Số tiền phải lớn hơn 0!', isError: true);
      return;
    }

    List<Map<String, dynamic>> updatedTransactions =
    List.from(appState.otherRevenueTransactions.value);
    updatedTransactions.add({
      'name': name,
      'total': total,
      'quantity': 1.0,
      'date': DateTime.now().toIso8601String(),
    });
    appState.otherRevenueTransactions.value = updatedTransactions;

    RevenueManager.saveOtherRevenueTransactions(
        appState, appState.otherRevenueTransactions.value);
    _showStyledSnackBar('Đã thêm giao dịch: $name');

    _totalController.clear();
    _nameController.clear();
    FocusScope.of(context).unfocus();
    widget.onUpdate();
  }

  void _editTransaction(AppState appState, int index) {
    final originalTransaction = appState.otherRevenueTransactions.value[index];
    _totalController.text = _inputPriceFormatter.format(originalTransaction['total'] ?? 0.0);
    _nameController.text = originalTransaction['name']?.toString() ?? '';

    showDialog(
      context: context,
      builder: (dialogContext) => GestureDetector(
        onTap: () => FocusScope.of(dialogContext).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: AlertDialog(
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text('Chỉnh sửa giao dịch',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600, color: _textColorPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildModernTextField(
                controller: _nameController,
                labelText: 'Tên giao dịch',
                prefixIconData: Icons.description_outlined,
                maxLength: 100,
              ),
              const SizedBox(height: 16),
              _buildModernTextField(
                controller: _totalController,
                labelText: 'Số tiền',
                prefixIconData: Icons.monetization_on_outlined,
                keyboardType: TextInputType.numberWithOptions(decimal: false),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  TextInputFormatter.withFunction(
                        (oldValue, newValue) {
                      if (newValue.text.isEmpty) return newValue;
                      // Corrected parsing: remove both '.' and ','
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
                maxLength: 15,
              ),
            ],
          ),
          actionsPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          actions: [
            TextButton(
              onPressed: () {
                _totalController.clear();
                _nameController.clear();
                Navigator.pop(dialogContext);
              } ,
              child: Text('Hủy',
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
                // Corrected parsing: remove both '.' and ','
                double newTotal =
                    double.tryParse(_totalController.text.replaceAll('.', '').replaceAll(',', '')) ?? 0.0;
                String newName = _nameController.text.trim();

                if (newName.isEmpty) {
                  _showStyledSnackBar('Tên giao dịch không được để trống!', isError: true);
                  return;
                }
                if (newTotal <= 0) {
                  _showStyledSnackBar('Số tiền phải lớn hơn 0!', isError: true);
                  return;
                }

                List<Map<String, dynamic>> updatedTransactions =
                List.from(appState.otherRevenueTransactions.value);
                updatedTransactions[index] = {
                  'name': newName,
                  'total': newTotal,
                  'quantity': 1.0,
                  'date': updatedTransactions[index]['date']?.toString() ??
                      DateTime.now().toIso8601String(),
                };
                appState.otherRevenueTransactions.value = updatedTransactions;

                RevenueManager.saveOtherRevenueTransactions(
                    appState, appState.otherRevenueTransactions.value);

                _totalController.clear();
                _nameController.clear();
                Navigator.pop(dialogContext);
                _showStyledSnackBar('Đã cập nhật giao dịch: $newName');
                widget.onUpdate();
              },
              child: Text('Lưu', style: GoogleFonts.poppins()),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteTransaction(AppState appState, int index) {
    final transactionName = appState.otherRevenueTransactions.value[index]['name'];
    List<Map<String, dynamic>> updatedTransactions = [];
    for (int i = 0; i < appState.otherRevenueTransactions.value.length; i++) {
      if (i != index) {
        updatedTransactions.add(appState.otherRevenueTransactions.value[i]);
      }
    }
    appState.otherRevenueTransactions.value = updatedTransactions;

    RevenueManager.saveOtherRevenueTransactions(
        appState, appState.otherRevenueTransactions.value);
    _showStyledSnackBar('Đã xóa giao dịch: $transactionName');
    widget.onUpdate();
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
            "Doanh thu khác",
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
                    _buildTab("Thêm giao dịch", 0, true, false),
                    _buildTab("Lịch sử", 1, false, true),
                  ],
                ),
              ),
            ),
          ),
        ),
        body: ScaleTransition(
          scale: _scaleAnimation,
          child: IndexedStack(
            index: _selectedTab,
            children: [
              TransactionInputSection(
                key: const ValueKey('otherRevenueInput'),
                totalController: _totalController,
                nameController: _nameController,
                onAddTransaction: () => _addTransaction(appState),
                appState: appState,
                inputPriceFormatter: _inputPriceFormatter,
              ),
              TransactionHistorySection(
                key: const ValueKey('otherRevenueHistory'),
                transactions: appState.otherRevenueTransactions,
                onEditTransaction: _editTransaction,
                onDeleteTransaction: _deleteTransaction,
                appState: appState,
                currencyFormat: currencyFormat,
                primaryColor: _primaryColor,
                textColorPrimary: _textColorPrimary,
                textColorSecondary: _textColorSecondary,
                cardBackgroundColor: _cardBackgroundColor,
                accentColor: _accentColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernTextField({
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
        fillColor: _cardBackgroundColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        counterText: "",
      ),
      maxLines: keyboardType == TextInputType.multiline ? null : 1,
    );
  }
}

class TransactionInputSection extends StatelessWidget {
  final TextEditingController totalController;
  final TextEditingController nameController;
  final VoidCallback onAddTransaction;
  final AppState appState;
  final NumberFormat inputPriceFormatter;


  const TransactionInputSection({
    required this.totalController,
    required this.nameController,
    required this.onAddTransaction,
    required this.appState,
    required this.inputPriceFormatter,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    const Color primaryColor = _EditOtherRevenueScreenState._primaryColor;
    // const Color secondaryColor = _EditOtherRevenueScreenState._secondaryColor; // Not used in this widget
    // const Color textColorPrimary = _EditOtherRevenueScreenState._textColorPrimary; // Not used in this widget
    // const Color textColorSecondary = _EditOtherRevenueScreenState._textColorSecondary; // Not used in this widget
    const Color cardBackgroundColor = _EditOtherRevenueScreenState._cardBackgroundColor;


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
                    "Thêm giao dịch mới",
                    style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: primaryColor),
                  ),
                  const SizedBox(height: 24),
                  _buildInputTextField(
                    controller: nameController,
                    labelText: 'Tên giao dịch',
                    prefixIconData: Icons.description_outlined,
                    maxLength: 100,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  _buildInputTextField(
                    controller: totalController,
                    labelText: 'Số tiền',
                    prefixIconData: Icons.monetization_on_outlined,
                    keyboardType: TextInputType.numberWithOptions(decimal: false),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      TextInputFormatter.withFunction(
                            (oldValue, newValue) {
                          if (newValue.text.isEmpty) return newValue;
                          // Corrected parsing: remove both '.' and ','
                          final String plainNumberText = newValue.text.replaceAll('.', '').replaceAll(',', '');
                          final number = int.tryParse(plainNumberText);
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
                    onPressed: onAddTransaction,
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

  Widget _buildInputTextField({
    required TextEditingController controller,
    required String labelText,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    int? maxLength,
    int maxLines = 1,
    IconData? prefixIconData,
  }) {
    const Color primaryColor = _EditOtherRevenueScreenState._primaryColor;
    const Color textColorSecondary = _EditOtherRevenueScreenState._textColorSecondary;
    const Color cardBackgroundColor = _EditOtherRevenueScreenState._cardBackgroundColor;

    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLength: maxLength,
      maxLines: maxLines,
      style: GoogleFonts.poppins(color: _EditOtherRevenueScreenState._textColorPrimary, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: GoogleFonts.poppins(color: textColorSecondary),
        prefixIcon: prefixIconData != null ? Icon(prefixIconData, color: primaryColor, size: 22) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primaryColor, width: 1.5)),
        filled: true,
        fillColor: cardBackgroundColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        counterText: "",
      ),
    );
  }
}

class TransactionHistorySection extends StatelessWidget {
  final ValueNotifier<List<Map<String, dynamic>>> transactions;
  final Function(AppState, int) onEditTransaction;
  final Function(AppState, int) onDeleteTransaction;
  final AppState appState;
  final NumberFormat currencyFormat;
  final Color primaryColor;
  final Color textColorPrimary;
  final Color textColorSecondary;
  final Color cardBackgroundColor;
  final Color accentColor;


  const TransactionHistorySection({
    required this.transactions,
    required this.onEditTransaction,
    required this.onDeleteTransaction,
    required this.appState,
    required this.currencyFormat,
    required this.primaryColor,
    required this.textColorPrimary,
    required this.textColorSecondary,
    required this.cardBackgroundColor,
    required this.accentColor,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<Map<String, dynamic>>>(
      valueListenable: transactions,
      builder: (context, List<Map<String, dynamic>> history, _) {
        if (history.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(30.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_toggle_off_outlined, size: 70, color: Colors.grey.shade400),
                  SizedBox(height: 16),
                  Text(
                    "Chưa có giao dịch nào",
                    style: GoogleFonts.poppins(fontSize: 17, color: textColorSecondary),
                  ),
                  SizedBox(height: 4),
                  Text(
                    "Thêm giao dịch mới để xem lịch sử tại đây.",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
          );
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 80.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Text(
                  "Lịch sử giao dịch",
                  style: GoogleFonts.poppins(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: textColorPrimary),
                ),
              ),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: history.length,
                itemBuilder: (context, index) {
                  final transaction = history[history.length - 1 - index];
                  return Dismissible(
                    key: Key(transaction['date'].toString() + transaction['name'] + index.toString()),
                    background: Container(
                      color: accentColor.withOpacity(0.8),
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      child: const Icon(Icons.delete_sweep_outlined,
                          color: Colors.white, size: 26),
                    ),
                    direction: DismissDirection.endToStart,
                    onDismissed: (direction) {
                      onDeleteTransaction(appState, history.length - 1 - index);
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
                            transaction['name'] != null && (transaction['name'] as String).isNotEmpty
                                ? (transaction['name'] as String)[0].toUpperCase()
                                : "?",
                            style: GoogleFonts.poppins(
                                color: primaryColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 18),
                          ),
                          radius: 20,
                        ),
                        title: Text(
                          transaction['name']?.toString() ?? 'N/A',
                          style: GoogleFonts.poppins(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w600,
                              color: textColorPrimary),
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          "Tổng: ${currencyFormat.format(transaction['total'] ?? 0.0)}",
                          style: GoogleFonts.poppins(
                              fontSize: 13.0,
                              color: primaryColor,
                              fontWeight: FontWeight.w500),
                        ),
                        trailing: IconButton(
                          icon: Icon(Icons.edit_note_outlined, color: primaryColor.withOpacity(0.8), size: 22),
                          onPressed: () => onEditTransaction(appState, history.length - 1 - index),
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
      },
    );
  }
}