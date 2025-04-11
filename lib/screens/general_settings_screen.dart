import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';

class GeneralSettingsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Cài đặt chung"),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1976D2), Color(0xFF42A5F5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        backgroundColor: Colors.transparent, // Để gradient hiển thị
        elevation: 0, // Loại bỏ bóng mặc định
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      body: ListView(
        children: [
          SwitchListTile(
            title: Text(
              "Thông báo",
              style: TextStyle(
                fontSize: 16,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
            subtitle: Text(
              "Bật hoặc tắt thông báo ứng dụng",
              style: TextStyle(
                fontSize: 14,
                color: isDarkMode ? Colors.white70 : Colors.grey[600],
              ),
            ),
            value: appState.notificationsEnabled,
            onChanged: (value) {
              appState.setNotificationsEnabled(value);
            },
            activeColor: const Color(0xFF1976D2), // Màu khi bật
            activeTrackColor: const Color(0xFF42A5F5).withOpacity(0.5), // Đồng bộ với gradient
            inactiveThumbColor: isDarkMode ? Colors.grey[400] : Colors.grey, // Nút gạt khi tắt
            inactiveTrackColor: isDarkMode ? Colors.grey[600]!.withOpacity(0.5) : Colors.grey.withOpacity(0.5), // Thanh gạt khi tắt
          ),
          Divider(color: isDarkMode ? Colors.grey[700] : Colors.grey),
          SwitchListTile(
            title: Text(
              "Chế độ tối",
              style: TextStyle(
                fontSize: 16,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
            subtitle: Text(
              "Bật hoặc tắt chế độ tối",
              style: TextStyle(
                fontSize: 14,
                color: isDarkMode ? Colors.white70 : Colors.grey[600],
              ),
            ),
            value: appState.isDarkMode,
            onChanged: (value) {
              appState.setDarkMode(value);
            },
            activeColor: const Color(0xFF1976D2), // Màu khi bật
            activeTrackColor: const Color(0xFF42A5F5).withOpacity(0.5), // Đồng bộ với gradient
            inactiveThumbColor: isDarkMode ? Colors.grey[400] : Colors.grey, // Nút gạt khi tắt
            inactiveTrackColor: isDarkMode ? Colors.grey[600]!.withOpacity(0.5) : Colors.grey.withOpacity(0.5), // Thanh gạt khi tắt
          ),
        ],
      ),
    );
  }
}