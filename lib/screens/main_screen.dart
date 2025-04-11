import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'revenue_screen.dart';
import 'expense_screen.dart';
import 'report_screen.dart';
import 'recommendation_screen.dart';

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  final List<Widget> _screens = [
    RevenueScreen(),
    ExpenseScreen(),
    ReportScreen(),
    RecommendationScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      _controller.reset();
      _controller.forward();
    });
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    await GoogleSignIn().signOut();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.grey[900]?.withOpacity(0.9) : Colors.white.withOpacity(0.9),
          boxShadow: [
            BoxShadow(
              color: isDarkMode ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.1),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          items: [
            BottomNavigationBarItem(
              icon: _selectedIndex == 0
                  ? ScaleTransition(
                scale: _scaleAnimation,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF1976D2),
                  ),
                  child: const Icon(Icons.attach_money, color: Colors.white),
                ),
              )
                  : const Icon(Icons.attach_money),
              label: 'Doanh Thu',
            ),
            BottomNavigationBarItem(
              icon: _selectedIndex == 1
                  ? ScaleTransition(
                scale: _scaleAnimation,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF1976D2),
                  ),
                  child: const Icon(Icons.money_off, color: Colors.white),
                ),
              )
                  : const Icon(Icons.money_off),
              label: 'Chi Phí',
            ),
            BottomNavigationBarItem(
              icon: _selectedIndex == 2
                  ? ScaleTransition(
                scale: _scaleAnimation,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF1976D2),
                  ),
                  child: const Icon(Icons.bar_chart, color: Colors.white),
                ),
              )
                  : const Icon(Icons.bar_chart),
              label: 'Báo Cáo',
            ),
            BottomNavigationBarItem(
              icon: _selectedIndex == 3
                  ? ScaleTransition(
                scale: _scaleAnimation,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF1976D2),
                  ),
                  child: const Icon(Icons.lightbulb, color: Colors.white),
                ),
              )
                  : const Icon(Icons.lightbulb),
              label: 'Khuyến nghị',
            ),
          ],
          currentIndex: _selectedIndex,
          selectedItemColor: const Color(0xFF1976D2),
          unselectedItemColor: isDarkMode ? Colors.grey[400] : Colors.grey,
          showUnselectedLabels: true,
          onTap: _onItemTapped,
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
      ),
    );
  }
}