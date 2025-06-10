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

class _MainScreenState extends State<MainScreen> { // Removed SingleTickerProviderStateMixin as _controller is removed
  final List<Widget> _screens = [
    RevenueScreen(),
    ExpenseScreen(),
    ReportScreen(),
    AnalysisScreen(),
  ];

  void _onItemTapped(int index, AppState appState) {
    // Mặc định là cho phép điều hướng
    bool canNavigate = true;

    // Nếu người dùng không phải là chủ sở hữu, ta mới cần kiểm tra quyền chi tiết
    if (!appState.isOwner()) {
      if (index == 2 || index == 3) {
        canNavigate = appState.hasPermission('canViewReport');
      }
    }

    if (canNavigate) {
      // Nếu được phép, thực hiện chuyển tab
      appState.setSelectedScreenIndex(index);
    } else {
      // Nếu không được phép, hiển thị thông báo và không làm gì cả
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bạn không có quyền truy cập chức năng này.'),
          backgroundColor: Colors.orangeAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Define colors for BottomNavigationBar based on theme
    final Color navBarBackgroundColor = isDarkMode ? Color(0xFF212121) : Colors.white; // Dark grey for dark, white for light
    final Color selectedItemColor = Color(0xFF1976D2); // Your primary color
    final Color unselectedItemColor = isDarkMode ? Colors.grey[400]! : Colors.grey[600]!;

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
                    color: selectedItemColor, // Use primary color
                    size: 50.0,
                  ),
                  const SizedBox(height: 20),
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
          // The body directly shows the selected screen.
          // SafeArea is handled within each individual screen.
          return _screens[appState.selectedScreenIndex];
        },
      ),
      bottomNavigationBar: Material( // Using Material for elevation and consistent background
        elevation: 8.0, // Add shadow
        color: navBarBackgroundColor, // Set background color here
        child: BottomNavigationBar(
          items: <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Icon(appState.selectedScreenIndex == 0 ? Icons.monetization_on : Icons.monetization_on_outlined),
              label: 'Doanh Thu',
            ),
            BottomNavigationBarItem(
              icon: Icon(appState.selectedScreenIndex == 1 ? Icons.money_off_csred : Icons.money_off_csred_outlined),
              label: 'Chi Phí',
            ),
            BottomNavigationBarItem(
              icon: Icon(appState.selectedScreenIndex == 2 ? Icons.bar_chart : Icons.bar_chart_outlined),
              label: 'Báo Cáo',
            ),
            BottomNavigationBarItem(
              icon: Icon(appState.selectedScreenIndex == 3 ? Icons.lightbulb : Icons.lightbulb_outline),
              label: 'Khuyến nghị',
            ),
          ],
          currentIndex: appState.selectedScreenIndex,
          selectedItemColor: selectedItemColor,
          unselectedItemColor: unselectedItemColor,
          onTap: (index) => _onItemTapped(index, appState),
          type: BottomNavigationBarType.fixed, // Ensures all labels are visible
          backgroundColor: navBarBackgroundColor, // Set background color
          showUnselectedLabels: true, // Keep labels visible for unselected items
          selectedFontSize: 12.5, // Slightly larger font for selected item's label
          unselectedFontSize: 12,
          elevation: 0, // Elevation is handled by the Material widget
        ),
      ),
    );
  }
}