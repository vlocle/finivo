import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '/screens/expense_manager.dart';
import 'package:fingrowth/screens/report_screen.dart';

class ManageFixedExpenseRulesScreen extends StatefulWidget {
  const ManageFixedExpenseRulesScreen({Key? key}) : super(key: key);

  @override
  _ManageFixedExpenseRulesScreenState createState() =>
      _ManageFixedExpenseRulesScreenState();
}

class _ManageFixedExpenseRulesScreenState
    extends State<ManageFixedExpenseRulesScreen> {
  late AppState _appState;
  bool _isLoading = true;
  List<Map<String, dynamic>> _expenseRules = [];
  final _currencyFormat =
  NumberFormat.currency(locale: 'vi_VN', symbol: 'VNĐ');

  @override
  void initState() {
    super.initState();
    _appState = Provider.of<AppState>(context, listen: false);
    _loadRules();
  }

  Future<void> _loadRules() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final rules = await ExpenseManager.loadFixedExpenseRules(_appState);
      if (mounted) {
        setState(() {
          _expenseRules = rules;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showStyledSnackBar("Lỗi tải dữ liệu quy tắc: $e", isError: true);
      }
    }
  }

  void _showStyledSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins()),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _deleteRule(Map<String, dynamic> rule) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text("Xác nhận xóa"),
        content: Text('Bạn có chắc muốn xóa quy tắc "${rule['name']}" không? Mọi lịch thanh toán và phân bổ chi phí của quy tắc này sẽ bị xóa.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text("Hủy")),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text("Xóa"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        _showStyledSnackBar("Đang xóa quy tắc và các dữ liệu liên quan...");
        await ExpenseManager.deleteFixedExpenseRule(
          appState: _appState,
          ruleToDelete: rule, // Truyền vào toàn bộ quy tắc
        );
        _showStyledSnackBar("Đã xóa quy tắc thành công!");
        _loadRules(); // Tải lại danh sách quy tắc
      } catch (e) {
        _showStyledSnackBar("Lỗi khi xóa quy tắc: $e", isError: true);
      }
    }
  }

  void _showAddEditRuleDialog({Map<String, dynamic>? existingRule}) {
    final isEditing = existingRule != null;
    // State for Tab 1
    final nameController =
    TextEditingController(text: isEditing ? existingRule['name'] : '');
    final amountController = TextEditingController(
        text: isEditing
            ? (existingRule['totalAmount'] as num).toStringAsFixed(0)
            : '');
    DateTimeRange dateRange = isEditing
        ? DateTimeRange(
        start: DateTime.parse(existingRule['startDate']),
        end: DateTime.parse(existingRule['endDate']))
        : DateTimeRange(
        start: DateTime.now(),
        end: DateTime(DateTime.now().year, DateTime.now().month + 1,
            DateTime.now().day));
    // State for Tab 2
    String paymentType =
    isEditing ? existingRule['paymentType'] ?? 'manual' : 'recurring';
    int paymentDay = isEditing ? existingRule['paymentDay'] ?? 1 : 1;
    DateTime oneTimePaymentDate =
    isEditing && existingRule['oneTimePaymentDate'] != null
        ? DateTime.parse(existingRule['oneTimePaymentDate'])
        : DateTime.now();
    String? walletId =
    isEditing ? existingRule['walletId'] : _appState.defaultWallet?['id'];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        // BỌC DIALOG TRONG WIDGET THEME ĐỂ TÙY CHỈNH MÀU SẮC
        return Theme(
          data: Theme.of(context).copyWith(
            // Đặt màu chủ đạo là màu đỏ
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppColors.chartRed,
            ),
            // Tùy chỉnh màu cho TabBar
            tabBarTheme: Theme.of(context).tabBarTheme.copyWith(
              indicatorColor: AppColors.chartRed,
              labelColor: AppColors.chartRed,
              unselectedLabelColor: Colors.grey,
            ),
            // Đảm bảo các nút trong dialog cũng dùng màu đỏ
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.chartRed,
              ),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.chartRed,
                foregroundColor: Colors.white,
              ),
            ),
          ),
          child: StatefulBuilder(
            builder: (context, setStateInDialog) {
              return DefaultTabController(
                length: 2,
                child: AlertDialog(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                  title:
                  Text(isEditing ? "Chỉnh sửa Quy tắc" : "Thêm Quy tắc Mới"),
                  contentPadding: const EdgeInsets.only(top: 20),
                  content: SizedBox(
                    width: MediaQuery.of(context).size.width,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const TabBar(
                          tabs: [
                            Tab(text: "Bước 1: Phân bổ"),
                            Tab(text: "Bước 2: Thanh toán"),
                          ],
                        ),
                        Container(
                          height: 350,
                          child: TabBarView(
                            children: [
                              // --- Tab 1: Phân bổ ---
                              SingleChildScrollView(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  children: [
                                    TextField(
                                        controller: nameController,
                                        decoration: InputDecoration(
                                            labelText: "Tên khoản chi")),
                                    SizedBox(height: 16),
                                    TextField(
                                        controller: amountController,
                                        decoration: InputDecoration(
                                            labelText:
                                            "Số tiền (cho mỗi chu kỳ)"),
                                        keyboardType: TextInputType.number),
                                    SizedBox(height: 16),
                                    ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: Text("Thời gian phân bổ"),
                                      subtitle: Text(
                                          "${DateFormat('dd/MM/yyyy').format(dateRange.start)} - ${DateFormat('dd/MM/yyyy').format(dateRange.end)}"),
                                      trailing: Icon(Icons.calendar_today),
                                      onTap: () async {
                                        // THÊM BUILDER ĐỂ TÙY CHỈNH THEME CHO DATE RANGE PICKER
                                        final picked = await showDateRangePicker(
                                          context: context,
                                          firstDate: DateTime(2020),
                                          lastDate: DateTime(2030),
                                          initialDateRange: dateRange,
                                          builder: (context, child) {
                                            return Theme(
                                              data: Theme.of(context).copyWith(
                                                  colorScheme: Theme.of(context)
                                                      .colorScheme
                                                      .copyWith(
                                                    primary:
                                                    AppColors.chartRed,
                                                    onPrimary: Colors.white,
                                                  )),
                                              child: child!,
                                            );
                                          },
                                        );
                                        if (picked != null) {
                                          setStateInDialog(
                                                  () => dateRange = picked);
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              // --- Tab 2: Lịch Thanh toán ---
                              SingleChildScrollView(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  children: [
                                    SegmentedButton<String>(
                                      style: SegmentedButton.styleFrom(
                                          selectedBackgroundColor:
                                          AppColors.chartRed,
                                          selectedForegroundColor: Colors.white),
                                      segments: const [
                                        ButtonSegment(
                                            value: 'recurring',
                                            label: Text('Lặp lại')),
                                        ButtonSegment(
                                            value: 'onetime',
                                            label: Text('Một lần')),
                                        ButtonSegment(
                                            value: 'manual',
                                            label: Text('Thủ công')),
                                      ],
                                      selected: {paymentType},
                                      onSelectionChanged: (newSelection) {
                                        setStateInDialog(() =>
                                        paymentType = newSelection.first);
                                      },
                                    ),
                                    SizedBox(height: 20),
                                    if (paymentType == 'recurring') ...[
                                      DropdownButtonFormField<int>(
                                        value: paymentDay,
                                        items: List.generate(
                                            28,
                                                (index) => DropdownMenuItem(
                                                value: index + 1,
                                                child:
                                                Text("Ngày ${index + 1}"))),
                                        onChanged: (value) => setStateInDialog(
                                                () => paymentDay = value!),
                                        decoration: InputDecoration(
                                            labelText:
                                            "Ngày thanh toán hàng tháng"),
                                      ),
                                    ],
                                    if (paymentType == 'onetime') ...[
                                      ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        title: Text("Ngày thanh toán"),
                                        subtitle: Text(
                                            DateFormat('dd/MM/yyyy').format(
                                                oneTimePaymentDate)),
                                        trailing: Icon(Icons.calendar_today),
                                        onTap: () async {
                                          final picked = await showDatePicker(
                                              context: context,
                                              initialDate: oneTimePaymentDate,
                                              firstDate: DateTime(2020),
                                              lastDate: DateTime(2030));
                                          if (picked != null) {
                                            setStateInDialog(() =>
                                            oneTimePaymentDate = picked);
                                          }
                                        },
                                      )
                                    ],
                                    if (paymentType != 'manual') ...[
                                      SizedBox(height: 16),
                                      DropdownButtonFormField<String>(
                                        value: walletId,
                                        items: _appState.wallets.value
                                            .map((w) => DropdownMenuItem(
                                            value: w['id'] as String,
                                            child: Text(w['name'])))
                                            .toList(),
                                        onChanged: (value) => setStateInDialog(
                                                () => walletId = value),
                                        decoration: InputDecoration(
                                            labelText: "Thanh toán từ ví"),
                                      ),
                                    ]
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: Text("Hủy")),
                    ElevatedButton(
                      onPressed: () async {
                        final name = nameController.text.trim();
                        final amount =
                            double.tryParse(amountController.text) ?? 0.0;
                        if (name.isEmpty || amount <= 0) {
                          _showStyledSnackBar(
                              "Vui lòng nhập tên và số tiền hợp lệ.",
                              isError: true);
                          return;
                        }
                        if (paymentType != 'manual' && walletId == null) {
                          _showStyledSnackBar("Vui lòng chọn ví để thanh toán.",
                              isError: true);
                          return;
                        }
                        try {
                          _showStyledSnackBar(
                              "Đang lưu và cập nhật lịch trình...");
                          await ExpenseManager.saveFixedExpenseRule(
                            appState: _appState,
                            name: name,
                            amount: amount,
                            dateRange: dateRange,
                            oldName: isEditing ? existingRule['name'] : null,
                            oldAmount: isEditing
                                ? (existingRule['totalAmount'] as num).toDouble()
                                : null,
                            oldDateRange: isEditing
                                ? DateTimeRange(
                                start:
                                DateTime.parse(existingRule['startDate']),
                                end: DateTime.parse(existingRule['endDate']))
                                : null,
                            paymentType: paymentType,
                            paymentDay:
                            paymentType == 'recurring' ? paymentDay : null,
                            oneTimePaymentDate:
                            paymentType == 'onetime' ? oneTimePaymentDate : null,
                            walletId: paymentType != 'manual' ? walletId : null,
                          );
                          Navigator.pop(dialogContext);
                          _showStyledSnackBar("Đã lưu quy tắc thành công!");
                          _loadRules();
                        } catch (e) {
                          _showStyledSnackBar("Lỗi khi lưu: $e", isError: true);
                        }
                      },
                      child: Text("Lưu Quy tắc"),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Cập nhật lại style của Text widget
        title: Text(
          "Quản lý Chi phí Cố định",
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.chartRed,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppColors.chartRed))
          : _expenseRules.isEmpty
          ? Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text(
              "Chưa có quy tắc chi phí cố định nào được thiết lập.\n\nNhấn (+) để thêm mới.",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey[600]),
            ),
          ))
          : ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: _expenseRules.length,
        itemBuilder: (context, index) {
          final rule = _expenseRules[index];
          final appState = Provider.of<AppState>(context, listen: false);
          final List<Widget> subtitleWidgets = [];
          subtitleWidgets.add(
            Text(
              "Thanh toán: ${_currencyFormat.format(rule['totalAmount'] ?? 0.0)}",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w500,
                color: AppColors.primaryBlue, // Có thể đổi màu cho nổi bật
              ),
            ),
          );
          try {
            final startDate = DateFormat('dd/MM/yy').format(DateTime.parse(rule['startDate']));
            final endDate = DateFormat('dd/MM/yy').format(DateTime.parse(rule['endDate']));
            subtitleWidgets.add(
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  "Phân bổ: $startDate - $endDate",
                  style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade600),
                ),
              ),
            );
          } catch (e) {
            // Bỏ qua nếu ngày tháng không hợp lệ
          }
          final paymentType = rule['paymentType'] ?? 'manual';
          String paymentInfo = "Lịch thanh toán: Thủ công"; // Mặc định
          IconData paymentIcon = Icons.pan_tool_outlined; // Icon cho Thủ công

          if (paymentType != 'manual' && rule['walletId'] != null) {
            // Tìm tên ví từ walletId
            final walletName = appState.wallets.value
                .firstWhere((w) => w['id'] == rule['walletId'], orElse: () => {'name': 'Không rõ'})
            ['name'];

            if (paymentType == 'recurring') {
              paymentInfo = "Hàng tháng, ngày ${rule['paymentDay']} từ ví '$walletName'";
              paymentIcon = Icons.event_repeat_outlined;
            } else if (paymentType == 'onetime') {
              try {
                final paymentDate = DateFormat('dd/MM/yy').format(DateTime.parse(rule['oneTimePaymentDate']));
                paymentInfo = "Một lần, ngày $paymentDate từ ví '$walletName'";
                paymentIcon = Icons.event_available_outlined;
              } catch (e) {
                paymentInfo = "Lỗi ngày thanh toán";
              }
            }
          }
          subtitleWidgets.add(
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(paymentIcon, size: 14, color: Colors.grey.shade700),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      paymentInfo,
                      style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade700),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          );
          return Slidable(
            key: ValueKey(rule['name']),
            endActionPane: ActionPane(
              motion: StretchMotion(),
              children: [
                SlidableAction(
                  onPressed: (context) => _showAddEditRuleDialog(existingRule: rule),
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  icon: Icons.edit,
                  label: 'Sửa',
                ),
                SlidableAction(
                  onPressed: (context) => _deleteRule(rule),
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  icon: Icons.delete,
                  label: 'Xóa',
                ),
              ],
            ),
            child: Card(
              margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              child: ListTile(
                title: Text(rule['name'] ?? 'Không có tên',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: subtitleWidgets,
                ),
                isThreeLine: true,
                onTap: () => _showAddEditRuleDialog(existingRule: rule),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditRuleDialog(),
        child: const Icon(Icons.add),
        backgroundColor: AppColors.chartRed,
        foregroundColor: Colors.white,
      ),
    );
  }
}