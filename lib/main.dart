import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart'; // Thêm import này
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'state/app_state.dart';
import 'screens/main_screen.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
    await Hive.initFlutter();
    await Future.wait([
      //Hive.openBox('productBox'),
      //Hive.openBox('expenseBox'),
      //Hive.openBox('transactionBox'),
      //Hive.openBox('revenueBox'),
      Hive.openBox('settingsBox'),
    ]);
    await initializeDateFormatting('vi', null);
  } catch (e) {
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(child: Text('Lỗi khởi tạo ứng dụng: $e')),
      ),
    ));
    return;
  }
  runApp(
    ChangeNotifierProvider(
      create: (context) => AppState(),
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'FinGrowth',
      theme: ThemeData(
        primarySwatch: Colors.red,
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        primarySwatch: Colors.red,
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      themeMode: appState.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      // Thêm các delegate và locale để hỗ trợ MaterialLocalizations
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('vi', 'VN'), // Hỗ trợ tiếng Việt
        Locale('en', 'US'), // Hỗ trợ tiếng Anh (tùy chọn)
      ],
      locale: const Locale('vi', 'VN'), // Đặt ngôn ngữ mặc định là tiếng Việt
      home: AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(child: Text('Lỗi: ${snapshot.error}')),
          );
        }
        if (snapshot.hasData) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Provider.of<AppState>(context, listen: false).setUserId(snapshot.data!.uid);
          });
          return MainScreen();
        }
        return LoginScreen();
      },
    );
  }
}