// main.dart
import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart'; // Thêm import của RevenueCat

// <<< THÊM CÁC IMPORT CẦN THIẾT >>>
import 'state/app_state.dart';
import 'screens/main_screen.dart';
import 'screens/login_screen.dart';
import 'screens/device_utils.dart';
import 'screens/subscription_service.dart';

Future<void> _configureRevenueCat() async {
  await Purchases.setLogLevel(LogLevel.debug); // Bật log debug để dễ gỡ lỗi

  PurchasesConfiguration configuration;
  if (Platform.isIOS) {
    // Dán Public Apple API Key của bạn vào đây
    configuration = PurchasesConfiguration("appl_OfoRjYgrjnESgkPaEKnSfIQgINU");
  } else if (Platform.isAndroid) {
    // Dán Public Google API Key của bạn vào đây
    configuration = PurchasesConfiguration("goog_YOUR_GOOGLE_API_KEY");
  } else {
    return;
  }
  await Purchases.configure(configuration);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    int retries = 3;
    for (int i = 0; i < retries; i++) {
      try {
        await Firebase.initializeApp();
        await _configureRevenueCat();
        break;
      } catch (e) {
        if (i == retries - 1) throw e;
        await Future.delayed(const Duration(seconds: 1));
      }
    }
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
    await Hive.initFlutter();
    await initializeDateFormatting('vi', null);

    final appState = AppState();
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult != ConnectivityResult.none) {
      await appState.syncWithFirestore();
    }
    initConnectivityListener(appState);

    // Chạy ứng dụng và cung cấp các services bằng MultiProvider
    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (context) => appState),
          ChangeNotifierProvider(create: (context) => SubscriptionService()),
        ],
        child: const MyApp(),
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
  Timer? debounceTimer;
  Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
    if (debounceTimer?.isActive ?? false) return;
    debounceTimer = Timer(const Duration(seconds: 2), () {
      if (results.any((result) => result != ConnectivityResult.none)) {
        if (!appState.isLoadingListenable.value) {
          appState.syncWithFirestore();
        }
      }
    });
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Provider đã được chuyển lên trên MultiProvider
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
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    // Gọi init() của service, không lắng nghe thay đổi ở đây
    context.read<SubscriptionService>().init();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (authSnapshot.hasData && authSnapshot.data != null) {
          final user = authSnapshot.data!;
          Purchases.logIn(user.uid).catchError((error) {
            print("Lỗi khi đăng nhập RevenueCat: $error");
          });
          print("Đã đăng nhập vào RevenueCat với user ID: ${user.uid}");
          return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
            builder: (context, userDocSnapshot) {
              if (userDocSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(body: Center(child: CircularProgressIndicator()));
              }
              if (!userDocSnapshot.hasData || !userDocSnapshot.data!.exists) {
                FirebaseAuth.instance.signOut();
                return LoginScreen();
              }
              final userData = userDocSnapshot.data!.data() as Map<String, dynamic>;
              final appState = Provider.of<AppState>(context, listen: false);
              //appState.updateSubscriptionStatus(userData);
              if (appState.authUserId != user.uid) {
                appState.setUserId(user.uid);
              }
              final storedDeviceId = userData['lastLoginDeviceId'];
              return FutureBuilder<String?>(
                future: getDeviceId(),
                builder: (context, deviceIdSnapshot) {
                  if (deviceIdSnapshot.connectionState == ConnectionState.waiting) {
                    return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
        // === BẮT ĐẦU PHẦN ĐỒNG BỘ REVENUECAT ===
        // Khi người dùng đăng xuất, cũng đăng xuất khỏi RevenueCat
        Purchases.logOut().catchError((error) {
          print("Lỗi khi đăng xuất RevenueCat: $error");
        });
        print("Đã đăng xuất khỏi RevenueCat");
        // === KẾT THÚC PHẦN ĐỒNG BỘ REVENUECAT ===
        return LoginScreen();
      },
    );
  }
}