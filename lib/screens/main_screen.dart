import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import 'revenue_screen.dart';
import 'expense_screen.dart';
import 'report_screen.dart';
import 'recommendation_screen.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  final List<Widget> _screens = [
    RevenueScreen(),
    ExpenseScreen(),
    ReportScreen(),
    AnalysisScreen(),
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

  void _onItemTapped(int index, AppState appState) {
    appState.setSelectedScreenIndex(index);
    _controller.reset();
    _controller.forward();
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    await GoogleSignIn().signOut();
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: ValueListenableBuilder<bool>(
        valueListenable: appState.isLoadingListenable,
        builder: (context, isLoading, _) {
          if (isLoading) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SpinKitFadingCube(
                    color: const Color(0xFF1976D2),
                    size: 50.0,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Đang tải dữ liệu, vui lòng đợi...',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }
          return Stack(
            children: [
              _screens[appState.selectedScreenIndex],
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
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
                        icon: appState.selectedScreenIndex == 0
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
                        icon: appState.selectedScreenIndex == 1
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
                        icon: appState.selectedScreenIndex == 2
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
                        icon: appState.selectedScreenIndex == 3
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
                    currentIndex: appState.selectedScreenIndex,
                    selectedItemColor: const Color(0xFF1976D2),
                    unselectedItemColor: isDarkMode ? Colors.grey[400] : Colors.grey,
                    showUnselectedLabels: true,
                    onTap: (index) => _onItemTapped(index, appState),
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}