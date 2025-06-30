import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import '/screens/firestore_service.dart';
import '/screens/device_utils.dart';

import '../state/app_state.dart';
import 'main_screen.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _buttonScaleAnimation;
  bool _isLoading = false;

  Future<void> _signInWithGoogle(BuildContext context) async {
    // Nắm bắt context hiện tại để sử dụng an toàn trong các hàm bất đồng bộ
    final currentContext = context;
    if (!mounted) return; // Kiểm tra mounted ở đầu
    setState(() => _isLoading = true);

    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn(); // [cite: 334]

      if (googleUser == null) {
        if (mounted) setState(() => _isLoading = false); // [cite: 335]
        return; // [cite: 335]
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication; // [cite: 336]
      final credential = GoogleAuthProvider.credential( // [cite: 336]
        accessToken: googleAuth.accessToken, // [cite: 337]
        idToken: googleAuth.idToken, // [cite: 337]
      );
      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        final deviceId = await getDeviceId();
        // GỌI HÀM LƯU THÔNG TIN VÀO FIRESTORE
        await FirestoreService().saveUserInfoToFirestore(user, deviceId);

        if (mounted) {
          //Provider.of<AppState>(context, listen: false).setUserId(user.uid);
          //Navigator.pushReplacement(
          //  context,
          //  MaterialPageRoute(builder: (context) => MainScreen()),
          //);
        }
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(currentContext).showSnackBar(
          SnackBar(content: Text('Đăng nhập bằng Google thất bại: $e')), // Sửa thông báo lỗi [cite: 339, 340]
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false); // [cite: 341]
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController( // [cite: 343]
      duration: const Duration(milliseconds: 700), // [cite: 343]
      vsync: this, // [cite: 343]
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0) // [cite: 344]
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn)); // [cite: 344]
    _buttonScaleAnimation = TweenSequence([ // [cite: 345]
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.95), weight: 50), // [cite: 345]
      TweenSequenceItem(tween: Tween<double>(begin: 0.95, end: 1.0), weight: 50), // [cite: 345]
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)); // [cite: 345]
    _controller.forward(); // [cite: 346]
  }

  @override
  void dispose() {
    _controller.dispose(); // [cite: 346]
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Sử dụng Consumer để lắng nghe thay đổi từ AppState
    return Consumer<AppState>(
      builder: (context, appState, child) {
        // Kết hợp cả hai trạng thái:
        // 1. _isLoading: Trạng thái tải cục bộ của màn hình Login.
        // 2. appState.isLoggingOut: Trạng thái xử lý đăng xuất toàn cục.
        final bool isProcessing = _isLoading || appState.isLoggingOut;

        return Scaffold(
          body: Column(
            children: [
              // Phần trên chứa ảnh minh họa
              Expanded(
                flex: 7,
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(50),
                    bottomRight: Radius.circular(50),
                  ),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Container(
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        image: DecorationImage(
                          image: AssetImage('assets/finance_illustration.jpg'),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Phần dưới chứa nút đăng nhập
              Expanded(
                flex: 3,
                child: Container(
                  color: Colors.white,
                  child: SafeArea(
                    top: false,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
                          child: ScaleTransition(
                            scale: _buttonScaleAnimation,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF42A5F5),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                minimumSize: const Size(double.infinity, 50),
                                // Sử dụng màu xám để chỉ thị nút bị vô hiệu hóa
                                disabledBackgroundColor: Colors.grey[400],
                              ),
                              // Vô hiệu hóa nút bấm nếu isProcessing là true
                              onPressed: isProcessing
                                  ? null
                                  : () {
                                _controller.reset();
                                _controller.forward();
                                _signInWithGoogle(context);
                              },
                              // Hiển thị vòng xoay nếu isProcessing là true
                              icon: isProcessing
                                  ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                                  : Image.asset(
                                'assets/google_logo.png',
                                height: 20,
                              ),
                              label: const Text(
                                "Đăng nhập với Google",
                                style: TextStyle(color: Colors.white, fontSize: 16),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}