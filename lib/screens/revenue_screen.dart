import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import 'edit_revenue_screen.dart';
import 'edit_other_revenue.dart';
import 'product_service_screen.dart';
import 'user_setting_screen.dart';

class RevenueScreen extends StatefulWidget {
  @override
  _RevenueScreenState createState() => _RevenueScreenState();
}

class _RevenueScreenState extends State<RevenueScreen> with SingleTickerProviderStateMixin {
  final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'VND');
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _profitFadeAnimation;
  late Animation<double> _buttonScaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 700), vsync: this);
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));
    _profitFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _controller, curve: const Interval(0.3, 1.0, curve: Curves.easeIn)));
    _buttonScaleAnimation = TweenSequence([
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.95), weight: 50),
      TweenSequenceItem(tween: Tween<double>(begin: 0.95, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final appState = Provider.of<AppState>(context, listen: false);
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: appState.selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      appState.setSelectedDate(picked);
    }
  }

  void _navigateToEditRevenue(String category) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => category == 'Doanh thu khác'
            ? EditOtherRevenueScreen(onUpdate: () {})
            : EditRevenueScreen(category: category),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Consumer<AppState>(
      builder: (context, appState, child) {
        double totalRevenue = appState.getTotalRevenue();
        return Scaffold(
          body: Stack(
            children: [
              Container(height: MediaQuery.of(context).size.height * 0.25, color: const Color(0xFF1976D2).withOpacity(0.9)),
              SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Row(
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => UserSettingsScreen()),
                                    );
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.2),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: CircleAvatar(
                                      radius: 24,
                                      backgroundColor: Colors.white,
                                      backgroundImage: user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
                                      child: user?.photoURL == null
                                          ? const Icon(Icons.person, size: 30, color: Color(0xFF1976D2))
                                          : null,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Flexible(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "${user?.displayName ?? 'Finivo'}",
                                        style: const TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          "Ngày ${DateFormat('d MMMM y', 'vi').format(appState.selectedDate)}",
                                          style: const TextStyle(fontSize: 12, color: Colors.white),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.calendar_today, color: Colors.white),
                            onPressed: () => _selectDate(context),
                            splashRadius: 20,
                            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Column(
                          children: [
                            Flexible(
                              child: SlideTransition(
                                position: _slideAnimation,
                                child: FadeTransition(
                                  opacity: _fadeAnimation,
                                  child: Card(
                                    elevation: 10,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          RevenueCategoryItem(
                                            title: 'Doanh thu chính',
                                            amount: appState.mainRevenue,
                                            icon: Icons.attach_money,
                                            onTap: () => _navigateToEditRevenue('Doanh thu chính'),
                                          ),
                                          const Divider(height: 1, color: Colors.grey),
                                          RevenueCategoryItem(
                                            title: 'Doanh thu phụ',
                                            amount: appState.secondaryRevenue,
                                            icon: Icons.account_balance_wallet,
                                            onTap: () => _navigateToEditRevenue('Doanh thu phụ'),
                                          ),
                                          const Divider(height: 1, color: Colors.grey),
                                          RevenueCategoryItem(
                                            title: 'Doanh thu khác',
                                            amount: appState.otherRevenue,
                                            icon: Icons.add_circle_outline,
                                            onTap: () => _navigateToEditRevenue('Doanh thu khác'),
                                          ),
                                          const Divider(height: 1, color: Colors.grey),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 12.0),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                const Text('Tổng doanh thu', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                                Flexible(
                                                  child: Text(
                                                    currencyFormat.format(totalRevenue),
                                                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1976D2)),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            FadeTransition(
                              opacity: _profitFadeAnimation,
                              child: Card(
                                elevation: 6,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Lợi nhuận hôm nay', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Flexible(
                                            child: Text(
                                              currencyFormat.format(appState.getProfit()),
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: appState.getProfit() > 0
                                                    ? Colors.green
                                                    : appState.getProfit() < 0
                                                    ? Colors.red
                                                    : Colors.grey,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Flexible(
                                            child: Text(
                                              'Biên lợi nhuận: ${appState.getProfitMargin().toStringAsFixed(1)}%',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: appState.getProfitMargin() > 0
                                                    ? Colors.green
                                                    : appState.getProfitMargin() < 0
                                                    ? Colors.red
                                                    : Colors.grey,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: ScaleTransition(
                                scale: _buttonScaleAnimation,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF42A5F5),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    minimumSize: const Size(double.infinity, 50),
                                  ),
                                  onPressed: () {
                                    _controller.reset();
                                    _controller.forward();
                                    Navigator.push(context, MaterialPageRoute(builder: (context) => ProductServiceScreen()));
                                  },
                                  child: const Text("Cập nhật sản phẩm", style: TextStyle(color: Colors.white, fontSize: 16)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class RevenueCategoryItem extends StatelessWidget {
  final String title;
  final double amount;
  final IconData icon;
  final VoidCallback onTap;
  final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'VND');

  RevenueCategoryItem({required this.title, required this.amount, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, size: 24, color: const Color(0xFF1976D2)),
                const SizedBox(width: 12),
                Text(title, style: const TextStyle(fontSize: 16)),
              ],
            ),
            Flexible(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      currencyFormat.format(amount),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
