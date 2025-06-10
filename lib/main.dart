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
import 'state/app_state.dart'; // [cite: 367]
import 'screens/main_screen.dart'; // [cite: 367]
import 'screens/login_screen.dart'; // [cite: 367]

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // [cite: 367]
  try {
    int retries = 3; // [cite: 368]
    for (int i = 0; i < retries; i++) { // [cite: 369]
      try {
        await Firebase.initializeApp(); // [cite: 369, 370]
        break; // [cite: 370]
      } catch (e) {
        if (i == retries - 1) throw e; // [cite: 370]
        await Future.delayed(Duration(seconds: 1)); // [cite: 371]
      }
    }
    FirebaseFirestore.instance.settings = const Settings( // [cite: 371, 372]
      persistenceEnabled: true, // [cite: 372]
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED, // [cite: 372]
    );
    await Hive.initFlutter(); // [cite: 373]
    await initializeDateFormatting('vi', null); // [cite: 375]
    final appState = AppState(); // [cite: 376]
    final connectivityResult = await Connectivity().checkConnectivity(); // [cite: 377]
    if (connectivityResult != ConnectivityResult.none) { // [cite: 378]
      await appState.syncWithFirestore(); // [cite: 378]
    }
    initConnectivityListener(appState); // [cite: 379]
    runApp(
      ChangeNotifierProvider( // [cite: 380]
        create: (context) => appState, // [cite: 380]
        child: MyApp(), // [cite: 380]
      ),
    );
  } catch (e) {
    print('Lỗi khởi tạo ứng dụng: $e'); // [cite: 381]
    runApp(MaterialApp( // [cite: 382]
      home: Scaffold(
        body: Center(child: Text('Lỗi khởi tạo ứng dụng: $e')), // [cite: 382]
      ),
    ));
  }
}

void initConnectivityListener(AppState appState) {
  Timer? _debounceTimer;
  Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
    if (_debounceTimer?.isActive ?? false) return; // Skip if debounce is active
    _debounceTimer = Timer(Duration(seconds: 2), () {
      if (results.any((result) => result != ConnectivityResult.none)) {
        if (!appState.isLoadingListenable.value) { // Use existing isLoadingListenable
          appState.syncWithFirestore();
        }
      }
    });
  });
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context); // [cite: 383, 384]
    return MaterialApp(
      debugShowCheckedModeBanner: false, // [cite: 384]
      title: 'FinGrowth', // [cite: 384]
      theme: ThemeData( // [cite: 384]
        primarySwatch: Colors.red, // [cite: 384]
        useMaterial3: true, // [cite: 384]
        brightness: Brightness.light, // [cite: 384]
      ),
      darkTheme: ThemeData( // [cite: 384]
        primarySwatch: Colors.red, // [cite: 384]
        useMaterial3: true, // [cite: 384]
        brightness: Brightness.dark, // [cite: 384]
      ),
      themeMode: appState.isDarkMode ? ThemeMode.dark : ThemeMode.light, // [cite: 385]
      localizationsDelegates: const [ // [cite: 385]
        GlobalMaterialLocalizations.delegate, // [cite: 385]
        GlobalWidgetsLocalizations.delegate, // [cite: 385]
        GlobalCupertinoLocalizations.delegate, // [cite: 385]
      ],
      supportedLocales: const [ // [cite: 385]
        Locale('vi', 'VN'), // [cite: 385]
        Locale('en', 'US'), // [cite: 385]
      ],
      locale: const Locale('vi', 'VN'), // [cite: 385]
      home: AuthWrapper(), // [cite: 386]
    );
  }
}

class AuthWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(), // [cite: 386]
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) { // [cite: 386]
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()), // [cite: 386]
          );
        }
        if (snapshot.hasError) { // [cite: 387]
          return Scaffold(
            body: Center(child: Text('Lỗi: ${snapshot.error}')), // [cite: 387]
          );
        }
        if (snapshot.hasData) {
          final appState = Provider.of<AppState>(context, listen: false);
          if (appState.activeUserId != snapshot.data!.uid) {
            appState.setUserId(snapshot.data!.uid);
          }
          return MainScreen();
        }
        return LoginScreen(); // [cite: 388]
      },
    );
  }
}