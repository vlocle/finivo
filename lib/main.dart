// main.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

// <<< THÊM CÁC IMPORT CẦN THIẾT >>>
import 'state/app_state.dart';
import 'screens/main_screen.dart';
import 'screens/login_screen.dart';
import 'screens/device_utils.dart';
import 'screens/subscription_service.dart'; // Import service mới

void main() async {
  // Đảm bảo các binding đã được khởi tạo
  WidgetsFlutterBinding.ensureInitialized();

  // Khởi tạo các dịch vụ nền tảng
  try {
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
    await Hive.initFlutter();
    await initializeDateFormatting('vi', null);

    // Chuẩn bị AppState
    final appState = AppState();
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult != ConnectivityResult.none) {
      await appState.syncWithFirestore();
    }
    initConnectivityListener(appState);

    // <<< THAY ĐỔI: Chạy ứng dụng và cung cấp AppState >>>
    // `SubscriptionService` sẽ được cung cấp bên trong MyApp
    runApp(
      ChangeNotifierProvider(
        create: (context) => appState,
        child: MyApp(),
      ),
    );
  } catch (e) {
    print('Lỗi khởi tạo ứng dụng: $e');
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(child: Text('Lỗi khởi tạo ứng dụng: $e')),
      ),
    ));
  }
}

void initConnectivityListener(AppState appState) {
  Timer? _debounceTimer;
  Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
    if (_debounceTimer?.isActive ?? false) return;
    _debounceTimer = Timer(Duration(seconds: 2), () {
      if (results.any((result) => result != ConnectivityResult.none)) {
        if (!appState.isLoadingListenable.value) {
          appState.syncWithFirestore();
        }
      }
    });
  });
}

// <<< THAY ĐỔI: MyApp giờ đây sẽ cung cấp SubscriptionService >>>
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Cung cấp SubscriptionService cho toàn bộ ứng dụng
    return Provider<SubscriptionService>(
      create: (_) => SubscriptionService(),
      child: Builder(
        builder: (context) {
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
            home: const AuthWrapper(),
          );
        },
      ),
    );
  }
}


// <<< THAY ĐỔI LỚN: AuthWrapper được chuyển thành StatefulWidget >>>
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    context.read<SubscriptionService>().init();
  }

  @override
  Widget build(BuildContext context) {
    // Logic StreamBuilder gốc của bạn được giữ nguyên hoàn toàn
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        if (authSnapshot.hasData && authSnapshot.data != null) {
          final user = authSnapshot.data!;
          return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
            builder: (context, userDocSnapshot) {
              if (userDocSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                    body: Center(child: CircularProgressIndicator()));
              }
              if (!userDocSnapshot.hasData || !userDocSnapshot.data!.exists) {
                FirebaseAuth.instance.signOut();
                return LoginScreen();
              }

              final userData = userDocSnapshot.data!.data() as Map<String, dynamic>;

              // Cập nhật AppState với trạng thái subscription mới nhất từ DB
              final appState = Provider.of<AppState>(context, listen: false);
              appState.updateSubscriptionStatus(userData);

              if (appState.authUserId != user.uid) {
                appState.setUserId(user.uid);
              }

              final storedDeviceId = userData['lastLoginDeviceId'];

              return FutureBuilder<String?>(
                future: getDeviceId(),
                builder: (context, deviceIdSnapshot) {
                  if (deviceIdSnapshot.connectionState == ConnectionState.waiting) {
                    return const Scaffold(
                        body: Center(child: CircularProgressIndicator()));
                  }
                  final currentDeviceId = deviceIdSnapshot.data;
                  if (storedDeviceId != null && currentDeviceId != null && storedDeviceId == currentDeviceId) {
                    return MainScreen();
                  } else {
                    Future.delayed(Duration.zero, () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Tài khoản đã đăng nhập ở thiết bị khác.')),
                      );
                      FirebaseAuth.instance.signOut();
                    });
                    return LoginScreen();
                  }
                },
              );
            },
          );
        }
        return LoginScreen();
      },
    );
  }
}