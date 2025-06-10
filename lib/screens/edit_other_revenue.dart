import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart'; // Ensure this path is correct
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
    double total = double.tryParse(
        _totalController.text.replaceAll('.', '').replaceAll(',', '')) ??
        0.0;
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
      'quantity': 1.0, // Default quantity for "other revenue"
      'date': DateTime.now().toIso8601String(),
      'createdBy': appState.authUserId,
    });

    appState.otherRevenueTransactions.value = updatedTransactions;
    RevenueManager.saveOtherRevenueTransactions(
        appState, appState.otherRevenueTransactions.value);
    _showStyledSnackBar('Đã thêm giao dịch: $name');

    // Clear fields after adding - This fulfills the user's request
    _totalController.clear();
    _nameController.clear();
    FocusScope.of(context).unfocus();
    widget.onUpdate(); // Callback to update parent widget if needed
  }

  void _editTransaction(AppState appState, int originalIndexInValueNotifier) {
    // Get the actual transaction from the ValueNotifier using the original index
    final transactionToEdit = appState.otherRevenueTransactions.value[originalIndexInValueNotifier];

    // Create temporary controllers for the dialog to avoid modifying main controllers directly
    final TextEditingController editNameController = TextEditingController(text: transactionToEdit['name']?.toString() ?? '');
    final TextEditingController editTotalController = TextEditingController(text: _inputPriceFormatter.format(transactionToEdit['total'] ?? 0.0));


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
              _buildDialogTextField( // Using a helper for dialog fields
                controller: editNameController,
                labelText: 'Tên giao dịch',
                prefixIconData: Icons.description_outlined,
                maxLength: 100,
              ),
              const SizedBox(height: 16),
              _buildDialogTextField( // Using a helper for dialog fields
                controller: editTotalController,
                labelText: 'Số tiền',
                prefixIconData: Icons.monetization_on_outlined,
                keyboardType: TextInputType.numberWithOptions(decimal: false),
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
                      _inputPriceFormatter.format(number);
                      return newValue.copyWith(
                        text: formattedText,
                        selection: TextSelection.collapsed(
                            offset: formattedText.length),
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
                // No need to clear main controllers here, dialog controllers are local
                Navigator.pop(dialogContext);
              },
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
                double newTotal = double.tryParse(editTotalController.text
                    .replaceAll('.', '')
                    .replaceAll(',', '')) ??
                    0.0;
                String newName = editNameController.text.trim();

                if (newName.isEmpty) {
                  _showStyledSnackBar('Tên giao dịch không được để trống!',
                      isError: true); // Consider showing snackbar on dialogContext if possible
                  return;
                }
                if (newTotal <= 0) {
                  _showStyledSnackBar('Số tiền phải lớn hơn 0!', isError: true);
                  return;
                }

                List<Map<String, dynamic>> updatedTransactions =
                List.from(appState.otherRevenueTransactions.value);

                updatedTransactions[originalIndexInValueNotifier] = {
                  ...updatedTransactions[originalIndexInValueNotifier], // Preserve other fields like date
                  'name': newName,
                  'total': newTotal,
                  // 'quantity' remains 1.0 as per _addTransaction
                  // 'date' is preserved from original transaction
                };

                appState.otherRevenueTransactions.value = updatedTransactions;
                RevenueManager.saveOtherRevenueTransactions(
                    appState, appState.otherRevenueTransactions.value);

                // No need to clear main controllers here after edit
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

  void _deleteTransaction(AppState appState, int originalIndexInValueNotifier) {
    final transactionName = appState.otherRevenueTransactions.value[originalIndexInValueNotifier]['name'];
    List<Map<String, dynamic>> updatedTransactions =
    List.from(appState.otherRevenueTransactions.value);
    updatedTransactions.removeAt(originalIndexInValueNotifier);

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
    final bool canEditThisRevenue = appState.hasPermission('canEditRevenue');
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
        body: ScaleTransition(
          scale: _scaleAnimation,
          child: IndexedStack(
            index: _selectedTab,
            children: [
              TransactionInputSection(
                key: const ValueKey('otherRevenueInput'),
                totalController: _totalController,
                nameController: _nameController,
                onAddTransaction: canEditThisRevenue ? () => _addTransaction(appState) : null,
                appState: appState, // Not strictly needed if only calling callback
                inputPriceFormatter: _inputPriceFormatter,
              ),
              TransactionHistorySection(
                key: const ValueKey('otherRevenueHistory'),
                transactionsNotifier: appState.otherRevenueTransactions, // MODIFIED: Pass ValueNotifier
                onEditTransaction: canEditThisRevenue ? _editTransaction : null,
                onDeleteTransaction: canEditThisRevenue ? _deleteTransaction : null,
                appState: appState, // Pass appState if needed by callbacks directly
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

  // Helper method for TextFields in Dialogs to maintain consistency
  Widget _buildDialogTextField({
    required TextEditingController controller,
    required String labelText,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    int? maxLength,
    IconData? prefixIconData,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLength: maxLength,
      maxLines: maxLines,
      style: GoogleFonts.poppins(color: _textColorPrimary, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: GoogleFonts.poppins(color: _textColorSecondary),
        prefixIcon: prefixIconData != null ? Icon(prefixIconData, color: _primaryColor, size: 22) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _primaryColor, width: 1.5)),
        filled: true,
        fillColor: _secondaryColor, // Dialog fields might have a slightly different background
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        counterText: "",
      ),
    );
  }
}

class TransactionInputSection extends StatelessWidget {
  final TextEditingController totalController;
  final TextEditingController nameController;
  final VoidCallback? onAddTransaction;
  final AppState appState; // Keep if needed for other reasons, though not for clearing
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
    // Use static colors from parent state for consistency
    const Color primaryColor = _EditOtherRevenueScreenState._primaryColor;
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
                  _buildInputTextField( // Uses local helper
                    controller: nameController,
                    labelText: 'Tên giao dịch',
                    prefixIconData: Icons.description_outlined,
                    maxLength: 100,
                    maxLines: 2, // Allow multiple lines for name if desired
                  ),
                  const SizedBox(height: 16),
                  _buildInputTextField( // Uses local helper
                    controller: totalController,
                    labelText: 'Số tiền',
                    prefixIconData: Icons.monetization_on_outlined,
                    keyboardType: TextInputType.numberWithOptions(decimal: false),
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
                          inputPriceFormatter.format(number);
                          return newValue.copyWith(
                            text: formattedText,
                            selection: TextSelection.collapsed(
                                offset: formattedText.length),
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

  // Helper for TextFields within TransactionInputSection for consistency
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
    const Color textColorPrimary = _EditOtherRevenueScreenState._textColorPrimary;
    const Color textColorSecondary = _EditOtherRevenueScreenState._textColorSecondary;
    const Color secondaryColor = _EditOtherRevenueScreenState._secondaryColor; // For fill color

    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLength: maxLength,
      maxLines: maxLines,
      style: GoogleFonts.poppins(color: textColorPrimary, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: GoogleFonts.poppins(color: textColorSecondary),
        prefixIcon: prefixIconData != null ? Icon(prefixIconData, color: primaryColor, size: 22) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primaryColor, width: 1.5)),
        filled: true,
        fillColor: secondaryColor.withOpacity(0.5), // Consistent fill color for inputs
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        counterText: "",
      ),
    );
  }
}

class TransactionHistorySection extends StatelessWidget {
  final ValueNotifier<List<Map<String, dynamic>>> transactionsNotifier; // MODIFIED: Changed name for clarity
  final Function(AppState, int)? onEditTransaction;
  final Function(AppState, int)? onDeleteTransaction;
  final AppState appState; // Passed to be available for callbacks
  final NumberFormat currencyFormat;
  final Color primaryColor;
  final Color textColorPrimary;
  final Color textColorSecondary;
  final Color cardBackgroundColor;
  final Color accentColor;

  const TransactionHistorySection({
    required this.transactionsNotifier, // MODIFIED
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
      valueListenable: transactionsNotifier, // MODIFIED
      builder: (context, List<Map<String, dynamic>> currentHistory, _) { // MODIFIED: variable name
        if (currentHistory.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(30.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_toggle_off_outlined,
                      size: 70, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    "Chưa có giao dịch nào",
                    style:
                    GoogleFonts.poppins(fontSize: 17, color: textColorSecondary),
                  ),
                  const SizedBox(height: 4),
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

        // Sort history by date descending (newest first)
        final sortedHistory = List<Map<String, dynamic>>.from(currentHistory);
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
                  "Lịch sử giao dịch", // Simplified title
                  style: GoogleFonts.poppins(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: textColorPrimary),
                ),
              ),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: sortedHistory.length,
                itemBuilder: (context, index) {
                  final transaction = sortedHistory[index];
                  final bool isOwner = appState.isOwner();
                  final bool isCreator = (transaction['createdBy'] ?? "") == appState.authUserId;
                  final originalIndex = currentHistory.indexOf(transaction);
                  final bool canModifyThisRecord = isOwner || isCreator;

                  return Dismissible(
                    key: Key(transaction['date'].toString() + (transaction['name'] ?? '') + index.toString()), // Ensure name is not null
                    background: Container(
                      color: accentColor.withOpacity(0.8),
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      child: const Icon(Icons.delete_sweep_outlined,
                          color: Colors.white, size: 26),
                    ),
                    direction: (onDeleteTransaction != null && canModifyThisRecord)
                        ? DismissDirection.endToStart
                        : DismissDirection.none,
                    onDismissed: (direction) {
                      // THAY ĐỔI 2: Thêm kiểm tra đầy đủ trước khi thực thi
                      if (onDeleteTransaction != null && canModifyThisRecord) {
                        if (originalIndex != -1) {
                          onDeleteTransaction!(appState, originalIndex);
                        }
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
                            Text( // For "Other Revenue", only total is primary
                              "Tổng: ${currencyFormat.format(transaction['total'] ?? 0.0)}",
                              style: GoogleFonts.poppins(
                                  fontSize: 13.0,
                                  color: primaryColor, // Emphasize total
                                  fontWeight: FontWeight.w500),
                            ),
                            if (transaction['date'] != null)
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
                          onPressed: (onEditTransaction != null && canModifyThisRecord)
                              ? () {
                            if (originalIndex != -1) {
                              onEditTransaction!(appState, originalIndex);
                            }
                          }
                              : null,
                          splashRadius: 18,
                          padding: EdgeInsets.zero,
                          constraints:
                          const BoxConstraints(minWidth: 30, minHeight: 30),
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