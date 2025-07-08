// main.dart (Đã cập nhật)
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
import 'package:purchases_flutter/purchases_flutter.dart';

// <<< THÊM CÁC IMPORT CẦN THIẾT >>>
import 'state/app_state.dart';
import 'screens/main_screen.dart';
import 'screens/login_screen.dart';
import 'screens/device_utils.dart';
import 'screens/subscription_service.dart';

Future<void> _configureRevenueCat() async {
  //await Purchases.setLogLevel(LogLevel.debug); // Bật log debug để dễ gỡ lỗi
  PurchasesConfiguration configuration;
  if (Platform.isIOS) {
    // Dán Public Apple API Key của bạn vào đây
    configuration = PurchasesConfiguration("appl_OfoRjYgrjnESgkPaEKnSfIQgINU");
  } else if (Platform.isAndroid) {
    // Dán Public Google API Key của bạn vào đây
    configuration = PurchasesConfiguration("goog_sFJapfxxtsKfENAnOFxhUSllyKa");
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
    final appState = AppState(); //
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult != ConnectivityResult.none) {
      await appState.syncWithFirestore();
    }
    initConnectivityListener(appState);
    // Chạy ứng dụng và cung cấp các services bằng MultiProvider
    runApp(
      MultiProvider(
        providers: [
          // 1. Cung cấp SubscriptionService như một ChangeNotifier bình thường
          ChangeNotifierProvider(create: (_) => SubscriptionService()),
          // 2. Dùng ProxyProvider để AppState có thể "lắng nghe" SubscriptionService
          ChangeNotifierProxyProvider<SubscriptionService, AppState>(
            // create: Tạo ra AppState lần đầu tiên
            create: (context) => AppState(),
            // update: Được gọi mỗi khi SubscriptionService thay đổi
            update: (context, subscriptionService, previousAppState) {
              // Lấy trạng thái isSubscribed mới nhất từ service
              final newSubStatus = subscriptionService.isSubscribed;
              // Cập nhật AppState với trạng thái mới và trả về
              return previousAppState!..updateSubscriptionStatus(newSubStatus);
            },
          ),
        ],
        child: const MyApp(), //
      ),
    );
  } catch (e) {
    runApp(MaterialApp( //
      home: Scaffold( //
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
      themeMode: appState.isDarkMode ? ThemeMode.dark : ThemeMode.light, //
      localizationsDelegates: const [ //
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [ //
        Locale('vi', 'VN'),
        Locale('en', 'US'),
      ],
      locale: const Locale('vi', 'VN'),
      home: const AuthWrapper(), //
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key}); //

  @override
  State<AuthWrapper> createState() => _AuthWrapperState(); //
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SubscriptionService>().init();
    });
  }

  // Hàm helper để xử lý logic đăng nhập và định danh
  Future<void> _identifyUser(User user) async {
    try {
      await Purchases.logIn(user.uid);
      final appState = Provider.of<AppState>(context, listen: false);
      if (appState.authUserId != user.uid) {
        await appState.setUserId(user.uid);
      }

    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Đã xảy ra lỗi khi xác thực tài khoản. Vui lòng thử lại.")),
        );
      }
      await Purchases.logOut();
      // Ném lại lỗi để FutureBuilder có thể xử lý và hiển thị lại LoginScreen
      rethrow;
    }
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
          return FutureBuilder(
            future: _identifyUser(user),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 10),
                        Text("Đang định danh người dùng...")
                      ],
                    ),
                  ),
                );
              }

              if (snapshot.hasError) {
                return LoginScreen();
              }

              return StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
                builder: (context, userDocSnapshot) {
                  if (userDocSnapshot.connectionState == ConnectionState.waiting) {
                    return const Scaffold(body: Center(child: CircularProgressIndicator()));
                  }

                  if (!userDocSnapshot.hasData || !userDocSnapshot.data!.exists) {
                    Future.microtask(() => FirebaseAuth.instance.signOut());
                    return LoginScreen();
                  }

                  final userData = userDocSnapshot.data!.data() as Map<String, dynamic>;
                  final storedDeviceId = userData['lastLoginDeviceId'];

                  return FutureBuilder<String?>(
                    future: getDeviceId(),
                    builder: (context, deviceIdSnapshot) {
                      if (deviceIdSnapshot.connectionState == ConnectionState.waiting) {
                        return const Scaffold(body: Center(child: CircularProgressIndicator()));
                      }

                      // --- LOGIC KIỂM TRA ĐÃ SỬA LỖI ---
                      final currentDeviceId = deviceIdSnapshot.data;
                      bool isAllowed = false;

                      // TRƯỜNG HỢP 1: Chưa có deviceId nào được lưu (đăng nhập lần đầu/sau khi đăng xuất).
                      // Đây là trường hợp hợp lệ, cho phép đăng nhập.
                      if (storedDeviceId == null) {
                        isAllowed = true;
                      }
                      // TRƯỜNG HỢP 2: Đã có deviceId được lưu và nó khớp với deviceId hiện tại.
                      // Đây là trường hợp hợp lệ, cho phép đăng nhập.
                      else if (currentDeviceId != null && storedDeviceId == currentDeviceId) {
                        isAllowed = true;
                      }

                      if (isAllowed) {
                        // Nếu được phép, hiển thị màn hình chính
                        return MainScreen();
                      } else {
                        // Chỉ khi deviceId được lưu KHÁC với deviceId hiện tại
                        // thì mới hiển thị thông báo và đăng xuất.
                        Future.delayed(Duration.zero, () async {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Tài khoản đã đăng nhập ở thiết bị khác.')),
                          );
                          FirebaseAuth.instance.signOut();
                          await Purchases.logOut();
                        });
                        return LoginScreen();
                      }
                    },
                  );
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