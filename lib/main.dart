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
    print('Lỗi khởi tạo ứng dụng: $e'); //
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
    // Gọi init() của service, không lắng nghe thay đổi ở đây
    context.read<SubscriptionService>().init();
  }

  // Hàm helper để xử lý logic đăng nhập và định danh
  Future<void> _identifyUser(User user) async {
    try {
      print("Attempting to log in to RevenueCat with UID: ${user.uid}");

      // 1. Đăng nhập và lấy về đối tượng LogInResult
      final logInResult = await Purchases.logIn(user.uid);

      // 2. LẤY ĐÚNG ĐỐI TƯỢNG customerInfo TỪ BÊN TRONG logInResult
      final customerInfo = logInResult.customerInfo;

      print("Successfully logged in to RevenueCat. Checking for subscription ownership...");

      // 3. Kiểm tra xem người dùng có đang active premium không
      final isSubscribed = customerInfo.entitlements.all["premium"]?.isActive ?? false;

      if (isSubscribed && customerInfo.originalAppUserId != user.uid) {
        print("Conflict detected: Subscription is active but belongs to another user (${customerInfo.originalAppUserId}).");

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Gói đăng ký này đã được sử dụng bởi một tài khoản khác trên thiết bị."),
              backgroundColor: Colors.red,
            ),
          );
        }

        await FirebaseAuth.instance.signOut();
        throw Exception("Subscription ownership conflict.");
      }

      // Nếu không có xung đột, tiếp tục cập nhật AppState như bình thường
      print("Ownership check passed. User is clear to proceed.");
      final appState = Provider.of<AppState>(context, listen: false);
      if (appState.authUserId != user.uid) {
        appState.setUserId(user.uid);
      }

    } catch (e) {
      await Purchases.logOut();
      print("Error during user identification or ownership check: $e. User has been logged out.");
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(), //
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) { //
          return const Scaffold(body: Center(child: CircularProgressIndicator())); //
        }

        if (authSnapshot.hasData && authSnapshot.data != null) { //
          final user = authSnapshot.data!; //

          // Sử dụng FutureBuilder để đợi quá trình định danh hoàn tất
          return FutureBuilder(
            future: _identifyUser(user),
            builder: (context, snapshot) {
              // Trong khi đang đợi _identifyUser chạy
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

              // Nếu có lỗi trong quá trình định danh
              if (snapshot.hasError) {
                // Lỗi đã được xử lý bên trong _identifyUser,
                // người dùng sẽ bị đăng xuất và quay về LoginScreen
                return LoginScreen();
              }

              // Khi _identifyUser đã chạy xong, tiếp tục kiểm tra deviceId
              return StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(), //
                builder: (context, userDocSnapshot) {
                  if (userDocSnapshot.connectionState == ConnectionState.waiting) { //
                    return const Scaffold(body: Center(child: CircularProgressIndicator()));
                  }
                  if (!userDocSnapshot.hasData || !userDocSnapshot.data!.exists) { //
                    FirebaseAuth.instance.signOut(); //
                    return LoginScreen(); //
                  }
                  final userData = userDocSnapshot.data!.data() as Map<String, dynamic>; //
                  final storedDeviceId = userData['lastLoginDeviceId']; //

                  return FutureBuilder<String?>(
                    future: getDeviceId(), //
                    builder: (context, deviceIdSnapshot) {
                      if (deviceIdSnapshot.connectionState == ConnectionState.waiting) { //
                        return const Scaffold(body: Center(child: CircularProgressIndicator()));
                      }
                      final currentDeviceId = deviceIdSnapshot.data; //
                      if (storedDeviceId != null && currentDeviceId != null && storedDeviceId == currentDeviceId) { //
                        return MainScreen(); //
                      } else {
                        Future.delayed(Duration.zero, () { //
                          ScaffoldMessenger.of(context).showSnackBar( //
                            const SnackBar(content: Text('Tài khoản đã đăng nhập ở thiết bị khác.')), //
                          );
                          FirebaseAuth.instance.signOut(); //
                        });
                        return LoginScreen(); //
                      }
                    },
                  );
                },
              );
            },
          );
        }

        // Khi người dùng đăng xuất (authSnapshot không có data)
        // Gọi logOut từ RevenueCat và quay về màn hình Login
        return FutureBuilder(
          future: Purchases.logOut(), // Đảm bảo logOut cũng được xử lý
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              print("Error logging out from RevenueCat: ${snapshot.error}"); //
            } else {
              print("Successfully logged out from RevenueCat."); //
            }
            return LoginScreen(); //
          },
        );
      },
    );
  }
}