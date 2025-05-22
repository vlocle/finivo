import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'state/app_state.dart';
import 'screens/main_screen.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    // Thử khởi tạo Firebase với retry
    int retries = 3;
    for (int i = 0; i < retries; i++) {
      try {
        await Firebase.initializeApp();
        break;
      } catch (e) {
        if (i == retries - 1) throw e;
        await Future.delayed(Duration(seconds: 1));
      }
    }

    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );

    // Khởi tạo Hive
    await Hive.initFlutter();
    await Future.wait([
      Hive.openBox('productsBox').then((box) => print('Opened productsBox')),
      Hive.openBox('transactionsBox').then((box) => print('Opened transactionsBox')),
      Hive.openBox('revenueBox').then((box) => print('Opened revenueBox')),
      Hive.openBox('settingsBox').then((box) => print('Opened settingsBox')),
    ]);

    // Khởi tạo định dạng ngày
    await initializeDateFormatting('vi', null);
  } catch (e) {
    print('Lỗi khởi tạo ứng dụng: $e');
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
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('vi', 'VN'),
        Locale('en', 'US'),
      ],
      locale: const Locale('vi', 'VN'),
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